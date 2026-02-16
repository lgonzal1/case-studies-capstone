SELECT
    a.*,
    icu.*,
    (a.edouttime::TIMESTAMP - a.admittime::TIMESTAMP) AS boarding
FROM hosp.admissions AS a
JOIN icu.icustays AS icu
  ON icu.subject_id = a.subject_id
 AND icu.hadm_id    = a.hadm_id
 AND icu.intime >= a.admittime
 AND icu.intime <= a.edouttime;
