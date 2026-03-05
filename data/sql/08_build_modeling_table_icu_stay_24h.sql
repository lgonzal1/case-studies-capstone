/*
08_build_modeling_table_icu_stay_24h.sql

CRISP-DM Phase: Data Preparation
Task(s): Integrate Data + Format Data

Why this exists:
- We assemble the final “modeling-ready” table at the chosen grain (stay_id).
- We keep a clean separation between:
  (a) early-window predictors (from 07) and
  (b) outcomes / labels (LOS and prolonged flag).
- This table is the artifact you will export to CSV and reference in the report.

Anti-leakage stance:
- Predictors are only from the first 24h (derived.vitals_24h_by_stay_v1).
- We do include los_days and outtime for audit and documentation, BUT:
  they must be excluded from the feature set during actual modeling.

Text-ingest reality:
- Many IDs are TEXT; we standardize them to INT here for safe joins.

Output:
- derived.icu_stay_modeling_24h_v1 (one row per stay_id)

*/

DROP TABLE IF EXISTS derived.icu_stay_modeling_24h_v1;

CREATE TABLE derived.icu_stay_modeling_24h_v1 AS
WITH
/* ---------------------------------------------------------
1) Anchor table: icustays (defines grain + outcomes)
------------------------------------------------------------
Why:
- icu.icustays is the authoritative source for intime/outtime and LOS at the ICU-stay grain.
- We compute the label here (prolonged_los_8d) to keep it consistent and documented.
*/
stays AS (
  SELECT
    NULLIF(TRIM(subject_id), '')::int AS subject_id,
    NULLIF(TRIM(hadm_id), '')::int    AS hadm_id,
    NULLIF(TRIM(stay_id), '')::int    AS stay_id,

    first_careunit,
    last_careunit,

    intime::timestamp  AS intime,
    outtime::timestamp AS outtime,

    los::numeric AS los_days,

    -- Label definition (documented + reproducible)
    (CASE WHEN los::numeric >= 8 THEN 1 ELSE 0 END)::int AS prolonged_los_8d

  FROM icu.icustays
  WHERE NULLIF(TRIM(stay_id), '') IS NOT NULL
),

/* ---------------------------------------------------------
2) Admissions context
------------------------------------------------------------
Why:
- admission_type is simple, interpretable context.
- We keep this lightweight to avoid scope creep; more context can be added later.
*/
admit AS (
  SELECT
    NULLIF(TRIM(hadm_id), '')::int AS hadm_id,
    admission_type
  FROM hosp.admissions
  WHERE NULLIF(TRIM(hadm_id), '') IS NOT NULL
),

/* ---------------------------------------------------------
3) Early-window vitals predictors (from 07)
------------------------------------------------------------
Why:
- This is our predictor set governed by the early-window rule.
- Because 07 created stay_id as INT, join types match and are stable.
*/
vitals AS (
  SELECT * FROM derived.vitals_24h_by_stay_v1
)

/* ---------------------------------------------------------
4) Final integrated dataset
------------------------------------------------------------
Why:
- One row per stay_id.
- IDs + context + predictors + labels in a consistent order.
- ORDER BY is for stable exports and human inspection (not required for modeling, but nice).
*/
SELECT
  s.subject_id,
  s.hadm_id,
  s.stay_id,

  -- Context
  s.first_careunit,
  s.last_careunit,
  a.admission_type,

  -- Audit timestamps (for traceability; will exclude from feature set later)
  s.intime,
  s.outtime,

  -- Early-window predictors
  v.n_chartevents_6h,
  v.n_chartevents_24h,
  v.missing_core_vitals_24h_count,

  v.hr_first,   v.hr_mean,   v.hr_min,   v.hr_max,   v.hr_last,
  v.rr_first,   v.rr_mean,   v.rr_min,   v.rr_max,   v.rr_last,
  v.spo2_first, v.spo2_mean, v.spo2_min, v.spo2_max, v.spo2_last,
  v.temp_first, v.temp_mean, v.temp_min, v.temp_max, v.temp_last,
  v.map_first,  v.map_mean,  v.map_min,  v.map_max,  v.map_last,

  -- Labels / outcomes
  s.los_days,
  s.prolonged_los_8d

FROM stays s
LEFT JOIN admit a
  ON a.hadm_id = s.hadm_id
LEFT JOIN vitals v
  ON v.stay_id = s.stay_id
ORDER BY s.stay_id;

-- integrity additions:
-- 1) enforce grain: one row per stay
ALTER TABLE derived.icu_stay_modeling_24h_v1
  ADD CONSTRAINT pk_icu_stay_modeling_24h_v1 PRIMARY KEY (stay_id);

-- 2) planner stats
ANALYZE derived.icu_stay_modeling_24h_v1;