/*
  Project: MIMIC-IV Demo (mimic_demo) — Data Inventory / Data Description profiling
  Generated: 2026-02-03

  Purpose
  - Document the exact SQL used to profile the demo dataset for Assignment 1 (Data Understanding)
  - Capture key results (counts, date ranges, distribution summaries) directly in this file for auditability

  Notes
  - In the initial load, raw CSV columns were preserved (schema-on-read). Some ID fields may contain empty strings.
    Where relevant, these queries use NULLIF(col,'') to treat empty strings as missing.
  - Schemas assumed:
      hosp.* and icu.* in database mimic_demo
*/

-- ============================================================================
-- Q1) Database footprint
-- ============================================================================
/*
  What it does:
  - Returns the on-disk size of the local PostgreSQL database.

  Result (2026-02-03):
  - db_size_pretty = 185 MB
*/
SELECT pg_size_pretty(pg_database_size('mimic_demo')) AS db_size_pretty;


-- ============================================================================
-- Q2) Row counts for key tables (inventory)
-- ============================================================================
/*
  What it does:
  - Returns row counts for key tables used in the capstone scope.

  Result (2026-02-03):

    table_name       | row_count
    -----------------|----------
    hosp.patients    |      100
    hosp.admissions  |      275
    icu.icustays     |      140
    hosp.diagnoses_icd |   4506
    hosp.labevents   |   107727
    icu.chartevents  |   668862
    hosp.transfers   |     1190
    icu.inputevents  |    20404
    icu.procedureevents | 1468
*/
SELECT 'hosp.patients'       AS table_name, COUNT(*) AS row_count FROM hosp.patients
UNION ALL
SELECT 'hosp.admissions'     AS table_name, COUNT(*) AS row_count FROM hosp.admissions
UNION ALL
SELECT 'icu.icustays'        AS table_name, COUNT(*) AS row_count FROM icu.icustays
UNION ALL
SELECT 'hosp.diagnoses_icd'  AS table_name, COUNT(*) AS row_count FROM hosp.diagnoses_icd
UNION ALL
SELECT 'hosp.labevents'      AS table_name, COUNT(*) AS row_count FROM hosp.labevents
UNION ALL
SELECT 'icu.chartevents'     AS table_name, COUNT(*) AS row_count FROM icu.chartevents
UNION ALL
SELECT 'hosp.transfers'      AS table_name, COUNT(*) AS row_count FROM hosp.transfers
UNION ALL
SELECT 'icu.inputevents'     AS table_name, COUNT(*) AS row_count FROM icu.inputevents
UNION ALL
SELECT 'icu.procedureevents' AS table_name, COUNT(*) AS row_count FROM icu.procedureevents
ORDER BY row_count DESC;


-- ============================================================================
-- Q3) Cardinalities: distinct patients, admissions, ICU stays
-- ============================================================================
/*
  What it does:
  - Counts distinct identifiers at each grain.

  Result (2026-02-03):
  - distinct_patients (subject_id) = 100
  - distinct_admissions (hadm_id)  = 275
  - distinct_stays (stay_id)       = 140
*/
SELECT
  COUNT(DISTINCT NULLIF(subject_id, '')) AS distinct_patients
FROM hosp.patients;

SELECT
  COUNT(DISTINCT NULLIF(hadm_id, '')) AS distinct_admissions
FROM hosp.admissions;

SELECT
  COUNT(DISTINCT NULLIF(stay_id, '')) AS distinct_stays
FROM icu.icustays;


-- ============================================================================
-- Q4) Referential integrity: ICU stays should link to admissions
-- ============================================================================
/*
  What it does:
  - Counts ICU stays with missing admission IDs (hadm_id).

  Result (2026-02-15):
  - icustays_missing_hadm = 0
*/
SELECT
  COUNT(*) AS icustays_missing_hadm
FROM icu.icustays
WHERE NULLIF(hadm_id, '') IS NULL;


-- ============================================================================
-- Q5) ICU temporal coverage (note: calendar dates are date-shifted)
-- ============================================================================
/*
  What it does:
  - Reports the min/max ICU stay timestamps.

  Result (2026-02-15):
  - min_intime  = 2110-04-11 15:52:22
  - max_outtime = 2201-12-13 18:29:00
*/
SELECT
  MIN(intime::timestamp)  AS min_intime,
  MAX(outtime::timestamp) AS max_outtime
FROM icu.icustays;


-- ============================================================================
-- Q6) ICU LOS summary statistics (outtime - intime)
-- ============================================================================
/*
  What it does:
  - Computes LOS intervals from outtime/intime and summarizes.

  Result (2026-02-03):
  - min_los    = 00:34:10
  - median_los = 2 days 03:43:20
  - mean_los   = 3 days 16:18:18
  - p90_los    = 8 days 20:39:08
  - max_los    = 20 days 12:41:18
*/
WITH los AS (
  SELECT (outtime::timestamp - intime::timestamp) AS los_interval
  FROM icu.icustays
)
SELECT
  MIN(los_interval) AS min_los,
  percentile_cont(0.5) WITHIN GROUP (ORDER BY los_interval) AS median_los,
  (SUM(EXTRACT(EPOCH FROM los_interval)) / COUNT(*)) * INTERVAL '1 second' AS mean_los,
  percentile_cont(0.9) WITHIN GROUP (ORDER BY los_interval) AS p90_los,
  MAX(los_interval) AS max_los
FROM los;


-- ============================================================================
-- Q7) Admissions-per-patient distribution
-- ============================================================================
/*
  What it does:
  - Counts admissions per patient (subject_id) and summarizes the distribution.

  Result (2026-02-03):
  - num_patients = 100
  - min_admissions_per_patient = 1
  - median_admissions_per_patient = 1
  - max_admissions_per_patient = 20
*/
WITH adm_counts AS (
  SELECT
    NULLIF(subject_id, '') AS subject_id,
    COUNT(DISTINCT NULLIF(hadm_id, '')) AS admissions
  FROM hosp.admissions
  GROUP BY NULLIF(subject_id, '')
)
SELECT
  COUNT(*) AS num_patients,
  MIN(admissions) AS min_admissions_per_patient,
  percentile_cont(0.5) WITHIN GROUP (ORDER BY admissions) AS median_admissions_per_patient,
  MAX(admissions) AS max_admissions_per_patient
FROM adm_counts;


-- ============================================================================
-- Q8) Charted events per ICU stay distribution (chartevents density)
-- ============================================================================
/*
  What it does:
  - Counts ICU charted rows per stay_id and summarizes.

  Result (2026-02-03):
  - num_stays = 140
  - min_events_per_stay = 35
  - median_events_per_stay = 2520.5
  - max_events_per_stay = 37061
*/
WITH event_counts AS (
  SELECT
    NULLIF(stay_id, '') AS stay_id,
    COUNT(*) AS event_rows
  FROM icu.chartevents
  GROUP BY NULLIF(stay_id, '')
)
SELECT
  COUNT(*) AS num_stays,
  MIN(event_rows) AS min_events_per_stay,
  percentile_cont(0.5) WITHIN GROUP (ORDER BY event_rows) AS median_events_per_stay,
  MAX(event_rows) AS max_events_per_stay
FROM event_counts;


-- ============================================================================
-- Q9) Column inventory for key tables
-- ============================================================================
/*
  What it does:
  - Lists columns for selected tables using information_schema.
  - Use this to confirm schema consistency with expected MIMIC-IV demo table layouts.
*/
SELECT
  table_schema,
  table_name,
  ordinal_position,
  column_name,
  data_type
FROM information_schema.columns
WHERE (table_schema, table_name) IN (
  ('hosp','patients'),
  ('hosp','admissions'),
  ('icu','icustays'),
  ('hosp','labevents'),
  ('icu','chartevents'),
  ('hosp','diagnoses_icd')
)
ORDER BY table_schema, table_name, ordinal_position;

