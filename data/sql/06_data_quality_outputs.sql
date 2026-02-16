/*
Data Quality Outputs
  */


-- Missingness table (vitals)
select * from icu.d_items di WHERE label ILIKE ANY(ARRAY[
  '%heart rate%',
  '%respiratory rate%',
  '%o2 saturation%',
  '%spo2%',
  '%temperature%',
  '%blood pressure%'
])
ORDER BY label;

WITH cohort AS (
  SELECT
    stay_id,
    intime::timestamp,
    outtime::timestamp
  FROM icu.icustays
  WHERE stay_id IS NOT NULL
),
vars AS (
  -- var, itemids[]
  SELECT * FROM (VALUES
    ('HR',   ARRAY['220045']),
    ('RR',   ARRAY['220210','224688','224689','224690']),
    ('SpO2', ARRAY['220277']),
    ('Temp', ARRAY['223762','223761']),

    -- Blood pressure: include both non-invasive + arterial + manual L/R
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
    COUNT(DISTINCT ce.stay_id)::int AS n_with_6h
  FROM vars v
  JOIN icu.chartevents ce
    ON ce.itemid = ANY(v.itemids)
  JOIN cohort c
    ON c.stay_id = ce.stay_id
  WHERE ce.charttime::timestamp >= c.intime::timestamp
    AND ce.charttime::timestamp <  c.intime::timestamp + INTERVAL '6 hour'
  GROUP BY v.var
),
presence_24h AS (
  SELECT
    v.var,
    COUNT(DISTINCT ce.stay_id)::int AS n_with_24h
  FROM vars v
  JOIN icu.chartevents ce
    ON ce.itemid = ANY(v.itemids)
  JOIN cohort c
    ON c.stay_id = ce.stay_id
  WHERE ce.charttime::timestamp >= c.intime::timestamp
    AND ce.charttime::timestamp <  c.intime::timestamp + INTERVAL '24 hour'
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

/*
var |n_stays|n_with_6h|pct_with_6h|n_with_24h|pct_with_24h|
----+-------+---------+-----------+----------+------------+
DBP |    140|      137|       97.9|       139|        99.3|
HR  |    140|      139|       99.3|       140|       100.0|
MAP |    140|      137|       97.9|       139|        99.3|
RR  |    140|      139|       99.3|       140|       100.0|
SBP |    140|      137|       97.9|       139|        99.3|
SpO2|    140|      139|       99.3|       140|       100.0|
Temp|    140|      132|       94.3|       135|        96.4|
 */

/*
 Integrity checklis
*/
SELECT
  COUNT(*) AS n_bad_los
FROM icu.icustays
WHERE outtime::timestamp <= intime::timestamp;

/*
  n_bad_los|
---------+
        0|
 */

-- Out-of-order timestamps (charttime before ICU intime)
WITH core_itemids AS (
  SELECT UNNEST(ARRAY[
    '220045','220210','224688','224689','224690','220277','223762','223761',
    '220179','220050','224167','227243','220180','220051','224643','227242','220181','220052'
  ]) AS itemid
)
SELECT
  COUNT(*) AS n_charttime_before_intime
FROM icu.chartevents ce
JOIN icu.icustays i
  ON i.stay_id = ce.stay_id
JOIN core_itemids c
  ON c.itemid = ce.itemid
WHERE ce.charttime::timestamp < i.intime::timestamp;

/*
 * n_charttime_before_intime|
-------------------------+
                      278|
                      
*/
--note this could also possiblt mean charttime before ICU because they where in the ED.



--cohort fragmentation

SELECT stay_id, COUNT(*) AS n
FROM icu.icustays
GROUP BY stay_id
HAVING COUNT(*) > 1;
/* zero*/

SELECT first_careunit, COUNT(*) AS n_stays
FROM icu.icustays
GROUP BY first_careunit
ORDER BY n_stays;


/*
 first_careunit                                  |n_stays|
------------------------------------------------+-------+
Neuro Intermediate                              |      1|
Neuro Stepdown                                  |      1|
Neuro Surgical Intensive Care Unit (Neuro SICU) |      3|
Coronary Care Unit (CCU)                        |     13|
Trauma SICU (TSICU)                             |     16|
Medical/Surgical Intensive Care Unit (MICU/SICU)|     23|
Cardiac Vascular Intensive Care Unit (CVICU)    |     25|
Medical Intensive Care Unit (MICU)              |     29|
Surgical Intensive Care Unit (SICU)             |     29|
 */


-- prolonged positives (LOS >= 8 days)
SELECT
  COUNT(*)::int AS n_stays,
  SUM(CASE WHEN los::numeric >= 8 THEN 1 ELSE 0 END)::int AS n_prolonged,
  ROUND(100.0 * SUM(CASE WHEN los::numeric >= 8 THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_prolonged
FROM icu.icustays;

/*
 n_stays|n_prolonged|pct_prolonged|
-------+-----------+-------------+
    140|         16|         11.4|
 */

-- orphan checks
SELECT COUNT(*) AS n_orphan_admissions_subject
FROM hosp.admissions a
LEFT JOIN hosp.patients p
  ON p.subject_id::int = a.subject_id::int
WHERE p.subject_id IS NULL;

/*
 n_orphan_admissions_subject|
---------------------------+
                          0|
 */


-- Key integrity for joins
-- Roll-up orphan checks for core join paths (TEXT-loaded tables)
SELECT 'admissions.subject_id -> patients.subject_id' AS check,
       COUNT(*) AS n_orphans
FROM hosp.admissions a
LEFT JOIN hosp.patients p
  ON p.subject_id::int = a.subject_id::int
WHERE p.subject_id IS NULL

UNION ALL
SELECT 'icustays.hadm_id -> admissions.hadm_id',
       COUNT(*)
FROM icu.icustays i
LEFT JOIN hosp.admissions a
  ON a.hadm_id::int = i.hadm_id::int
WHERE a.hadm_id IS NULL

UNION ALL
SELECT 'icustays.subject_id -> patients.subject_id',
       COUNT(*)
FROM icu.icustays i
LEFT JOIN hosp.patients p
  ON p.subject_id::int = i.subject_id::int
WHERE p.subject_id IS NULL

UNION ALL
SELECT 'chartevents.stay_id -> icustays.stay_id',
       COUNT(*)
FROM icu.chartevents ce
LEFT JOIN icu.icustays i
  ON i.stay_id::int = ce.stay_id::int
WHERE i.stay_id IS NULL

UNION ALL
SELECT 'labevents.hadm_id -> admissions.hadm_id',
       COUNT(*)
FROM hosp.labevents le
LEFT JOIN hosp.admissions a
  ON a.hadm_id::int = le.hadm_id::int
WHERE a.hadm_id IS NULL

UNION ALL
SELECT 'diagnoses_icd.hadm_id -> admissions.hadm_id',
       COUNT(*)
FROM hosp.diagnoses_icd dx
LEFT JOIN hosp.admissions a
  ON a.hadm_id::int = dx.hadm_id::int
WHERE a.hadm_id IS NULL;

/*
 check                                       |n_orphans|
--------------------------------------------+---------+
admissions.subject_id -> patients.subject_id|        0|
icustays.hadm_id -> admissions.hadm_id      |        0|
icustays.subject_id -> patients.subject_id  |        0|
chartevents.stay_id -> icustays.stay_id     |        0|
labevents.hadm_id -> admissions.hadm_id     |    28420|
diagnoses_icd.hadm_id -> admissions.hadm_id |        0|
 
 labevents may not be actually orphaned but rather labs 
 that where ordered whiel patient in ED
 
 */

SELECT COUNT(*) AS n_orphan_labevents_hadm
FROM hosp.labevents l
LEFT JOIN hosp.admissions a
  ON a.hadm_id::int = l.hadm_id::int
WHERE l.hadm_id IS NOT NULL
  AND NULLIF(TRIM(l.hadm_id), '') IS NOT NULL
  AND a.hadm_id IS NULL;
 
 /*
  n_orphan_labevents_hadm|
-----------------------+
                      0|
  */



