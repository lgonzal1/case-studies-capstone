/*
05_extract_stay_level_features_for_eda.sql

Purpose:
- Build a single “stay-level” dataset (1 row per ICU stay) that supports:
  (A) LOS by first_careunit (boxplot)
  (B) LOS vs chart-event volume (scatter)
  (C) Prolonged LOS rate by admission_type (bar chart)

Output columns:
- subject_id, hadm_id, stay_id
- first_careunit, last_careunit
- intime, outtime, los_days
- admission_type
- n_chartevents
- prolonged_los_8d (boolean)
*/

WITH stays AS (
  SELECT
    NULLIF(s.subject_id,'')::int      AS subject_id,
    NULLIF(s.hadm_id,'')::int         AS hadm_id,
    NULLIF(s.stay_id,'')::int         AS stay_id,
    s.first_careunit,
    s.last_careunit,
    NULLIF(s.intime,'')::timestamp    AS intime,
    NULLIF(s.outtime,'')::timestamp   AS outtime,
    EXTRACT(EPOCH FROM (
      NULLIF(s.outtime,'')::timestamp - NULLIF(s.intime,'')::timestamp
    )) / 86400.0                      AS los_days
  FROM icu.icustays s
  WHERE NULLIF(s.intime,'')  IS NOT NULL
    AND NULLIF(s.outtime,'') IS NOT NULL
),
ce AS (
  SELECT
    NULLIF(stay_id,'')::int AS stay_id,
    COUNT(*)                AS n_chartevents
  FROM icu.chartevents
  WHERE NULLIF(stay_id,'') IS NOT NULL
  GROUP BY 1
),
adm AS (
  SELECT
    NULLIF(hadm_id,'')::int    AS hadm_id,
    NULLIF(subject_id,'')::int AS subject_id,
    admission_type
  FROM hosp.admissions
  WHERE NULLIF(hadm_id,'') IS NOT NULL
)
SELECT
  st.subject_id,
  st.hadm_id,
  st.stay_id,
  st.first_careunit,
  st.last_careunit,
  st.intime,
  st.outtime,
  st.los_days,
  a.admission_type,
  COALESCE(ce.n_chartevents, 0) AS n_chartevents,
  (st.los_days > 8.0)           AS prolonged_los_8d
FROM stays st
LEFT JOIN adm a ON a.hadm_id = st.hadm_id
LEFT JOIN ce  ON ce.stay_id = st.stay_id
ORDER BY st.stay_id;
