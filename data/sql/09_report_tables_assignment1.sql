/*
09_report_tables_assignment1.sql

Purpose (Assignment 1 / CRISP-DM Data Understanding + Prep documentation):
  Produce "report-ready" summary tables that support the Data Understanding section:
    - Table inventory / row counts
    - Key integrity / join-rail checks
    - Vitals coverage in early windows (6h and 24h)
    - Cohort fragmentation proxy (first_careunit counts)
    - Outcome prevalence for prolonged ICU LOS (>= 8 days)
    - Basic LOS distribution summary

Why this exists:
  Up to now, many outputs lived as inline comments inside exploratory SQL files.
  For the report, we want deterministic, rerunnable, exportable artifacts that
  can be referenced in LaTeX tables (or included as CSVs).

Design notes:
  - Source tables were loaded as TEXT "quick and dirty", so joins often require
    NULLIF(TRIM(x),'')::int casting. We standardize that here when needed.
  - Derived tables should already exist from scripts 07/08:
      derived.vitals_24h_by_stay_v1
      derived.icu_stay_modeling_24h_v1
  - We materialize report tables under derived.report_* so they can be exported
    consistently and referenced in documentation.

Run:
  psql "$PGURI" -v ON_ERROR_STOP=1 -f data/sql/09_report_tables_assignment1.sql

Export:
  Use \copy commands (provided separately) to write CSVs into outputs/tables/.
*/

-- =========================================================
-- 0) Pre-flight: confirm derived artifacts exist
-- =========================================================
-- Why: avoids silent failure where exports run against empty/nonexistent tables.
DO $$
BEGIN
  IF to_regclass('derived.vitals_24h_by_stay_v1') IS NULL THEN
    RAISE EXCEPTION 'Missing derived.vitals_24h_by_stay_v1. Run 07_construct_vitals_24h_features.sql first.';
  END IF;

  IF to_regclass('derived.icu_stay_modeling_24h_v1') IS NULL THEN
    RAISE EXCEPTION 'Missing derived.icu_stay_modeling_24h_v1. Run 08_build_modeling_table_icu_stay_24h.sql first.';
  END IF;
END$$;

-- =========================================================
-- 1) Table inventory: row counts for in-scope core tables
-- =========================================================
DROP TABLE IF EXISTS derived.report_table_inventory_v1;
CREATE TABLE derived.report_table_inventory_v1 AS
WITH tbls AS (
  -- Keep this list aligned to what you discuss in Data Inventory / ERD narrative.
  SELECT * FROM (VALUES
    ('hosp.patients'),
    ('hosp.admissions'),
    ('icu.icustays'),
    ('hosp.transfers'),
    ('icu.chartevents'),
    ('hosp.labevents'),
    ('hosp.diagnoses_icd'),
    ('icu.d_items'),
    ('hosp.d_labitems'),
    ('hosp.d_icd_diagnoses'),
    ('icu.inputevents'),
    ('icu.outputevents'),
    ('icu.procedureevents')
  ) AS t(table_name)
),
counts AS (
  SELECT
    table_name,
    -- Use format() to safely count rows from arbitrary tables.
    (SELECT reltuples::bigint
       FROM pg_class c
       JOIN pg_namespace n ON n.oid = c.relnamespace
      WHERE n.nspname = split_part(table_name, '.', 1)
        AND c.relname  = split_part(table_name, '.', 2)
    ) AS approx_rows
  FROM tbls
)
SELECT
  table_name,
  approx_rows
FROM counts
ORDER BY table_name;

COMMENT ON TABLE derived.report_table_inventory_v1 IS
  'Assignment 1: approximate row counts for core MIMIC demo tables (pg_class.reltuples).';

-- NOTE:
-- reltuples is approximate unless ANALYZE has been run. For exact counts, you can
-- replace this table with explicit COUNT(*) queries, but that may be slow for chartevents.

-- =========================================================
-- 2) Key integrity summary (join-rails)
-- =========================================================
DROP TABLE IF EXISTS derived.report_key_integrity_v1;
CREATE TABLE derived.report_key_integrity_v1 AS
WITH
-- Why: source IDs are TEXT in your ingest; normalize consistently.
admissions AS (
  SELECT
    NULLIF(TRIM(subject_id),'')::int AS subject_id,
    NULLIF(TRIM(hadm_id),'')::int    AS hadm_id
  FROM hosp.admissions
  WHERE NULLIF(TRIM(hadm_id),'') IS NOT NULL
),
patients AS (
  SELECT NULLIF(TRIM(subject_id),'')::int AS subject_id
  FROM hosp.patients
  WHERE NULLIF(TRIM(subject_id),'') IS NOT NULL
),
icustays AS (
  SELECT
    NULLIF(TRIM(subject_id),'')::int AS subject_id,
    NULLIF(TRIM(hadm_id),'')::int    AS hadm_id,
    NULLIF(TRIM(stay_id),'')::int    AS stay_id
  FROM icu.icustays
  WHERE NULLIF(TRIM(stay_id),'') IS NOT NULL
),
chartevents AS (
  SELECT NULLIF(TRIM(stay_id),'')::int AS stay_id
  FROM icu.chartevents
  WHERE NULLIF(TRIM(stay_id),'') IS NOT NULL
),
labevents AS (
  SELECT NULLIF(TRIM(hadm_id),'')::int AS hadm_id
  FROM hosp.labevents
  WHERE NULLIF(TRIM(hadm_id),'') IS NOT NULL
),
diagnoses AS (
  SELECT NULLIF(TRIM(hadm_id),'')::int AS hadm_id
  FROM hosp.diagnoses_icd
  WHERE NULLIF(TRIM(hadm_id),'') IS NOT NULL
)
SELECT
  check_name,
  n_orphans
FROM (
  SELECT
    'admissions.subject_id -> patients.subject_id' AS check_name,
    COUNT(*) AS n_orphans
  FROM admissions a
  LEFT JOIN patients p USING (subject_id)
  WHERE p.subject_id IS NULL

  UNION ALL
  SELECT
    'icustays.hadm_id -> admissions.hadm_id',
    COUNT(*)
  FROM icustays i
  LEFT JOIN admissions a USING (hadm_id)
  WHERE a.hadm_id IS NULL

  UNION ALL
  SELECT
    'icustays.subject_id -> patients.subject_id',
    COUNT(*)
  FROM icustays i
  LEFT JOIN patients p USING (subject_id)
  WHERE p.subject_id IS NULL

  UNION ALL
  SELECT
    'chartevents.stay_id -> icustays.stay_id',
    COUNT(*)
  FROM chartevents ce
  LEFT JOIN icustays i USING (stay_id)
  WHERE i.stay_id IS NULL

  UNION ALL
  SELECT
    'labevents.hadm_id -> admissions.hadm_id',
    COUNT(*)
  FROM labevents le
  LEFT JOIN admissions a USING (hadm_id)
  WHERE a.hadm_id IS NULL

  UNION ALL
  SELECT
    'diagnoses_icd.hadm_id -> admissions.hadm_id',
    COUNT(*)
  FROM diagnoses dx
  LEFT JOIN admissions a USING (hadm_id)
  WHERE a.hadm_id IS NULL
) x
ORDER BY check_name;

COMMENT ON TABLE derived.report_key_integrity_v1 IS
  'Assignment 1: orphan checks for core join paths using normalized INT keys.';

-- =========================================================
-- 3) Early-window vitals coverage (6h/24h) -- report version
-- =========================================================
DROP TABLE IF EXISTS derived.report_vitals_coverage_v1;
CREATE TABLE derived.report_vitals_coverage_v1 AS
WITH cohort AS (
  SELECT
    NULLIF(TRIM(stay_id),'')::int AS stay_id,
    intime::timestamp AS intime
  FROM icu.icustays
  WHERE NULLIF(TRIM(stay_id),'') IS NOT NULL
),
vars AS (
  SELECT * FROM (VALUES
    ('HR',   ARRAY['220045']),
    ('RR',   ARRAY['220210','224688','224689','224690']),
    ('SpO2', ARRAY['220277']),
    ('Temp', ARRAY['223762','223761']),
    ('SBP',  ARRAY['220179','220050','224167','227243']),
    ('DBP',  ARRAY['220180','220051','224643','227242']),
    ('MAP',  ARRAY['220181','220052'])
  ) AS v(var, itemids)
),
n AS (
  SELECT COUNT(*)::int AS n_stays FROM cohort
),
presence_6h AS (
  SELECT
    v.var,
    COUNT(DISTINCT NULLIF(TRIM(ce.stay_id),'')::int)::int AS n_with_6h
  FROM vars v
  JOIN icu.chartevents ce
    ON ce.itemid = ANY(v.itemids)
  JOIN cohort c
    ON c.stay_id = NULLIF(TRIM(ce.stay_id),'')::int
  WHERE ce.charttime::timestamp >= c.intime
    AND ce.charttime::timestamp <  c.intime + INTERVAL '6 hour'
  GROUP BY v.var
),
presence_24h AS (
  SELECT
    v.var,
    COUNT(DISTINCT NULLIF(TRIM(ce.stay_id),'')::int)::int AS n_with_24h
  FROM vars v
  JOIN icu.chartevents ce
    ON ce.itemid = ANY(v.itemids)
  JOIN cohort c
    ON c.stay_id = NULLIF(TRIM(ce.stay_id),'')::int
  WHERE ce.charttime::timestamp >= c.intime
    AND ce.charttime::timestamp <  c.intime + INTERVAL '24 hour'
  GROUP BY v.var
)
SELECT
  v.var,
  n.n_stays,
  COALESCE(p6.n_with_6h, 0)  AS n_with_6h,
  ROUND(100.0 * COALESCE(p6.n_with_6h,0) / n.n_stays, 1) AS pct_with_6h,
  COALESCE(p24.n_with_24h,0) AS n_with_24h,
  ROUND(100.0 * COALESCE(p24.n_with_24h,0) / n.n_stays, 1) AS pct_with_24h
FROM vars v
CROSS JOIN n
LEFT JOIN presence_6h  p6  ON p6.var  = v.var
LEFT JOIN presence_24h p24 ON p24.var = v.var
ORDER BY v.var;

COMMENT ON TABLE derived.report_vitals_coverage_v1 IS
  'Assignment 1: % of stays with at least one measurement for each core vital in first 6h and 24h after ICU intime.';

-- =========================================================
-- 4) Cohort fragmentation proxy: first_careunit distribution
-- =========================================================
DROP TABLE IF EXISTS derived.report_first_careunit_counts_v1;
CREATE TABLE derived.report_first_careunit_counts_v1 AS
SELECT
  first_careunit,
  COUNT(*)::int AS n_stays
FROM icu.icustays
WHERE NULLIF(TRIM(stay_id),'') IS NOT NULL
GROUP BY first_careunit
ORDER BY n_stays DESC, first_careunit;

COMMENT ON TABLE derived.report_first_careunit_counts_v1 IS
  'Assignment 1: distribution of stays by first_careunit (used to discuss fragmentation risk and coarse cohorting).';

-- =========================================================
-- 5) Outcome prevalence: prolonged ICU LOS (>= 8 days)
-- =========================================================
DROP TABLE IF EXISTS derived.report_outcome_prevalence_v1;
CREATE TABLE derived.report_outcome_prevalence_v1 AS
SELECT
  COUNT(*)::int AS n_stays,
  SUM(CASE WHEN prolonged_los_8d = 1 THEN 1 ELSE 0 END)::int AS n_prolonged_8d,
  ROUND(100.0 * SUM(CASE WHEN prolonged_los_8d = 1 THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_prolonged_8d
FROM derived.icu_stay_modeling_24h_v1;

COMMENT ON TABLE derived.report_outcome_prevalence_v1 IS
  'Assignment 1: prevalence of prolonged ICU LOS using threshold LOS >= 8 days.';

-- =========================================================
-- 6) LOS distribution summary (report-friendly)
-- =========================================================
DROP TABLE IF EXISTS derived.report_los_summary_v1;
CREATE TABLE derived.report_los_summary_v1 AS
SELECT
  COUNT(*)::int AS n_stays,
  MIN(los_days) AS los_min_days,
  PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY los_days) AS los_p25_days,
  PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY los_days) AS los_median_days,
  PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY los_days) AS los_p75_days,
  MAX(los_days) AS los_max_days,
  AVG(los_days) AS los_mean_days
FROM derived.icu_stay_modeling_24h_v1;

COMMENT ON TABLE derived.report_los_summary_v1 IS
  'Assignment 1: LOS distribution summary (min, quartiles, median, max, mean) in days.';

-- =========================================================
-- Done
-- =========================================================
