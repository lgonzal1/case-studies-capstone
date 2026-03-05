/*
07_construct_vitals_24h_features.sql

CRISP-DM Phase: Data Preparation
Task(s): Construct Data + (light) Clean Data

Why this exists:
- We want predictors that are available early in the ICU stay.
- We explicitly avoid "full-stay" variables that leak outcome information (e.g., total chartevents over the entire stay).
- This script produces stay-level predictors derived ONLY from the first 24 hours after ICU admission time (intime).

Key design decisions:
1) Anti-leakage rule:
   - Only use chart events with charttime in [intime, intime + 24h).
   - This reflects what could plausibly be known at a fixed prediction time.
2) Type discipline:
   - Many source columns are TEXT because the data was loaded "quick and dirty".
   - We cast keys to INT in the derived table so downstream joins do not fail.
   - Use NULLIF(TRIM(x),'') to prevent false "orphans" and cast errors.
3) Interpretability-first feature set:
   - Use a small, clinically intuitive set of vitals and summarize them (first/last/min/max/mean, n_obs).
   - Add measurement-density features (n_chartevents_6h, n_chartevents_24h) and missingness indicators.
     These capture workflow/acuity patterns and are important for responsible interpretation.

Output:
- derived.vitals_24h_by_stay_v1 (one row per stay_id, stay_id is INT)

*/

DROP TABLE IF EXISTS derived.vitals_24h_by_stay_v1;

CREATE TABLE derived.vitals_24h_by_stay_v1 AS
WITH
/* ---------------------------------------------------------
0) Cohort anchor (stay_id grain)
------------------------------------------------------------
Why:
- We define the modeling grain as ICU stay (stay_id).
- We also standardize types here so every downstream join is safe and consistent.
*/
cohort AS (
  SELECT
    NULLIF(TRIM(stay_id), '')::int AS stay_id,
    intime::timestamp            AS intime
  FROM icu.icustays
  WHERE NULLIF(TRIM(stay_id), '') IS NOT NULL
),

/* ---------------------------------------------------------
1) Vital definitions (itemid sets)
------------------------------------------------------------
Why:
- MIMIC records vitals under multiple itemids for the "same concept" (e.g., RR).
- We explicitly define the mapping so it is auditable and reproducible.
- This mirrors a “feature spec” document in code form.
*/
vars AS (
  SELECT * FROM (VALUES
    ('HR',   ARRAY['220045']),
    ('RR',   ARRAY['220210','224688','224689','224690']),
    ('SpO2', ARRAY['220277']),
    ('Temp', ARRAY['223762','223761']),
    -- BP: include non-invasive + arterial + manual
    ('SBP',  ARRAY['220179','220050','224167','227243']),
    ('DBP',  ARRAY['220180','220051','224643','227242']),
    ('MAP',  ARRAY['220181','220052'])
  ) AS v(var, itemids)
),

/* ---------------------------------------------------------
2) Filter chart events to the prediction window (0–24h)
------------------------------------------------------------
Why:
- This is the hard anti-leakage boundary.
- We drop events before intime. In real workflows this may reflect ED/OR charting,
  but for early ICU prediction we want "post-ICU-admit availability".
- We keep only numeric values (valuenum), since we are building numeric features.
*/
ce_24h AS (
  SELECT
    NULLIF(TRIM(ce.stay_id), '')::int AS stay_id,
    ce.itemid,
    ce.charttime::timestamp            AS charttime,
    ce.valuenum::numeric               AS val
  FROM icu.chartevents ce
  JOIN cohort c
    ON c.stay_id = NULLIF(TRIM(ce.stay_id), '')::int
  WHERE ce.charttime::timestamp >= c.intime
    AND ce.charttime::timestamp <  c.intime + INTERVAL '24 hour'
    AND ce.valuenum IS NOT NULL
),

/* ---------------------------------------------------------
3) Measurement density counts (0–6h and 0–24h)
------------------------------------------------------------
Why:
- A stay with more frequent charting is often sicker OR monitored more intensely.
- This is *not* purely "noise": it can proxy acuity and workflow.
- Importantly: we count only within the early window to avoid leaking LOS (longer stays → more charting).
*/
counts AS (
  SELECT
    c.stay_id,

    COUNT(*) FILTER (
      WHERE ce.charttime::timestamp < c.intime + INTERVAL '6 hour'
    )::int AS n_chartevents_6h,

    COUNT(*)::int AS n_chartevents_24h

  FROM cohort c
  LEFT JOIN icu.chartevents ce
    ON NULLIF(TRIM(ce.stay_id), '')::int = c.stay_id
   AND ce.charttime::timestamp >= c.intime
   AND ce.charttime::timestamp <  c.intime + INTERVAL '24 hour'
  GROUP BY c.stay_id
),

/* ---------------------------------------------------------
4) Per-vital aggregation within 24h
------------------------------------------------------------
Why:
- We summarize each vital using simple, interpretable statistics.
- first_val and last_val reflect early trajectory (but still bounded to 24h).
- n_obs helps interpret missingness and confidence in the summary.
*/
vital_aggs AS (
  SELECT
    c.stay_id,
    v.var,

    COUNT(ce.val)::int AS n_obs,
    MIN(ce.val)        AS min_val,
    MAX(ce.val)        AS max_val,
    AVG(ce.val)        AS mean_val,

    (ARRAY_AGG(ce.val ORDER BY ce.charttime ASC))[1]  AS first_val,
    (ARRAY_AGG(ce.val ORDER BY ce.charttime DESC))[1] AS last_val

  FROM cohort c
  CROSS JOIN vars v
  LEFT JOIN ce_24h ce
    ON ce.stay_id = c.stay_id
   AND ce.itemid = ANY(v.itemids)
  GROUP BY c.stay_id, v.var
),

/* ---------------------------------------------------------
5) Pivot to wide format (one row per stay)
------------------------------------------------------------
Why:
- Modeling libraries expect a “wide” feature matrix: 1 row per unit, many columns.
- This also makes the final dataset easy to inspect and document.
*/
wide AS (
  SELECT
    stay_id,

    -- HR
    MAX(n_obs)     FILTER (WHERE var='HR')   AS hr_n,
    MAX(min_val)   FILTER (WHERE var='HR')   AS hr_min,
    MAX(max_val)   FILTER (WHERE var='HR')   AS hr_max,
    MAX(mean_val)  FILTER (WHERE var='HR')   AS hr_mean,
    MAX(first_val) FILTER (WHERE var='HR')   AS hr_first,
    MAX(last_val)  FILTER (WHERE var='HR')   AS hr_last,

    -- RR
    MAX(n_obs)     FILTER (WHERE var='RR')   AS rr_n,
    MAX(min_val)   FILTER (WHERE var='RR')   AS rr_min,
    MAX(max_val)   FILTER (WHERE var='RR')   AS rr_max,
    MAX(mean_val)  FILTER (WHERE var='RR')   AS rr_mean,
    MAX(first_val) FILTER (WHERE var='RR')   AS rr_first,
    MAX(last_val)  FILTER (WHERE var='RR')   AS rr_last,

    -- SpO2
    MAX(n_obs)     FILTER (WHERE var='SpO2') AS spo2_n,
    MAX(min_val)   FILTER (WHERE var='SpO2') AS spo2_min,
    MAX(max_val)   FILTER (WHERE var='SpO2') AS spo2_max,
    MAX(mean_val)  FILTER (WHERE var='SpO2') AS spo2_mean,
    MAX(first_val) FILTER (WHERE var='SpO2') AS spo2_first,
    MAX(last_val)  FILTER (WHERE var='SpO2') AS spo2_last,

    -- Temp
    MAX(n_obs)     FILTER (WHERE var='Temp') AS temp_n,
    MAX(min_val)   FILTER (WHERE var='Temp') AS temp_min,
    MAX(max_val)   FILTER (WHERE var='Temp') AS temp_max,
    MAX(mean_val)  FILTER (WHERE var='Temp') AS temp_mean,
    MAX(first_val) FILTER (WHERE var='Temp') AS temp_first,
    MAX(last_val)  FILTER (WHERE var='Temp') AS temp_last,

    -- SBP
    MAX(n_obs)     FILTER (WHERE var='SBP')  AS sbp_n,
    MAX(min_val)   FILTER (WHERE var='SBP')  AS sbp_min,
    MAX(max_val)   FILTER (WHERE var='SBP')  AS sbp_max,
    MAX(mean_val)  FILTER (WHERE var='SBP')  AS sbp_mean,
    MAX(first_val) FILTER (WHERE var='SBP')  AS sbp_first,
    MAX(last_val)  FILTER (WHERE var='SBP')  AS sbp_last,

    -- DBP
    MAX(n_obs)     FILTER (WHERE var='DBP')  AS dbp_n,
    MAX(min_val)   FILTER (WHERE var='DBP')  AS dbp_min,
    MAX(max_val)   FILTER (WHERE var='DBP')  AS dbp_max,
    MAX(mean_val)  FILTER (WHERE var='DBP')  AS dbp_mean,
    MAX(first_val) FILTER (WHERE var='DBP')  AS dbp_first,
    MAX(last_val)  FILTER (WHERE var='DBP')  AS dbp_last,

    -- MAP
    MAX(n_obs)     FILTER (WHERE var='MAP')  AS map_n,
    MAX(min_val)   FILTER (WHERE var='MAP')  AS map_min,
    MAX(max_val)   FILTER (WHERE var='MAP')  AS map_max,
    MAX(mean_val)  FILTER (WHERE var='MAP')  AS map_mean,
    MAX(first_val) FILTER (WHERE var='MAP')  AS map_first,
    MAX(last_val)  FILTER (WHERE var='MAP')  AS map_last

  FROM vital_aggs
  GROUP BY stay_id
)

/* ---------------------------------------------------------
6) Final select + missingness features
------------------------------------------------------------
Why:
- Missingness is not random in healthcare data.
- We therefore explicitly encode it to support responsible interpretation and modeling.
- “missing_core_vitals_24h_count” is a compact missingness summary.
*/
SELECT
  w.*,
  c.n_chartevents_6h,
  c.n_chartevents_24h,

  (CASE WHEN w.hr_n   > 0 THEN 1 ELSE 0 END) AS has_hr_24h,
  (CASE WHEN w.rr_n   > 0 THEN 1 ELSE 0 END) AS has_rr_24h,
  (CASE WHEN w.spo2_n > 0 THEN 1 ELSE 0 END) AS has_spo2_24h,
  (CASE WHEN w.temp_n > 0 THEN 1 ELSE 0 END) AS has_temp_24h,
  (CASE WHEN w.map_n  > 0 THEN 1 ELSE 0 END) AS has_map_24h,

  ( (CASE WHEN w.hr_n   > 0 THEN 0 ELSE 1 END)
  + (CASE WHEN w.rr_n   > 0 THEN 0 ELSE 1 END)
  + (CASE WHEN w.spo2_n > 0 THEN 0 ELSE 1 END)
  + (CASE WHEN w.temp_n > 0 THEN 0 ELSE 1 END)
  + (CASE WHEN w.map_n  > 0 THEN 0 ELSE 1 END)
  ) AS missing_core_vitals_24h_count

FROM wide w
JOIN counts c USING (stay_id)
ORDER BY stay_id;

-- Optional integrity/ergonomics additions (recommended for repeatability):
-- 1) enforce grain: one row per stay_id
ALTER TABLE derived.vitals_24h_by_stay_v1
  ADD CONSTRAINT pk_vitals_24h_by_stay_v1 PRIMARY KEY (stay_id);

-- 2) help planner and speed joins downstream
ANALYZE derived.vitals_24h_by_stay_v1;