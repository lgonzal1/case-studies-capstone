/*
===============================================================================
11_construct_labs_24h_features_v1_1.sql
Project: ICU Patient Care Analysis (MIMIC-IV Clinical Database Demo)
Author: Luis Gonzalez
Phase: Assignment 2 v1.1 feature refresh
Last updated: 2026-03-22

Purpose
-------
This script builds the new stay-level feature tables for the v1.1 refresh.

The point here is not to rebuild the whole project from scratch. The point is
to make a small, targeted improvement to the feature set after reviewing the
first final-model run.

What this script creates
------------------------
1. derived.labs_24h_by_stay_v1_1
   - one row per ICU stay
   - small early lab panel
   - simple 24-hour summaries

2. derived.context_features_by_stay_v1_1
   - one row per ICU stay
   - grouped admission type
   - grouped first careunit

Why this is being done
----------------------
The first final-model run worked, but it showed that the model was leaning
heavily on charting-intensity features. That is not necessarily wrong, but it
suggests the model would benefit from a slightly better mix of:
- workflow / process features
- early physiologic features
- basic early lab features

The goal of v1.1 is to improve the feature mix without turning this into a much
bigger project.

Working rule
------------
Keep it targeted. Keep it early (within 24 hours or arrival). Keep it easy to explain.
===============================================================================
*/

CREATE SCHEMA IF NOT EXISTS derived;

-------------------------------------------------------------------------------
-- Section 1: Build a small 24-hour lab feature table
--
-- Why this section exists:
-- I want a small early lab panel that is available within the first 24 hours
-- of the ICU stay. The goal is not to add every lab in the database. The goal
-- is to add a few strong, interpretable features that have good coverage.
--
-- Current candidate panel:
-- - creatinine
-- - lactate
-- - wbc
-- - hemoglobin
--
-- Summary choices:
-- - first + mean for creatinine, wbc, hemoglobin
-- - first + max for lactate
-- - keep a has_* flag for each concept
-------------------------------------------------------------------------------

DROP TABLE IF EXISTS derived.labs_24h_by_stay_v1_1;

CREATE TABLE derived.labs_24h_by_stay_v1_1 AS
WITH icu_anchor AS (
    SELECT
        NULLIF(TRIM(stay_id), '')::int    AS stay_id,
        NULLIF(TRIM(subject_id), '')::int AS subject_id,
        NULLIF(TRIM(hadm_id), '')::int    AS hadm_id,
        intime::timestamp                 AS intime
    FROM icu.icustays
    WHERE NULLIF(TRIM(stay_id), '') IS NOT NULL
),

lab_concept_map AS (
    /*
    ---------------------------------------------------------------------------
    These item IDs came from the audit step and are being used as the first
    pass for v1.1.

    If I later decide that any concept should combine multiple item IDs, this is
    the only section that needs to be updated.
    ---------------------------------------------------------------------------
    */
    SELECT *
    FROM (
        VALUES
            (50912, 'creatinine'),
            (50813, 'lactate'),
            (51301, 'wbc'),
            (51222, 'hemoglobin')
    ) AS t(itemid, lab_concept)
),

raw_labs AS (
    SELECT
        NULLIF(TRIM(hadm_id), '')::int AS hadm_id,
        NULLIF(TRIM(itemid), '')::int  AS itemid,
        COALESCE(charttime::timestamp, storetime::timestamp) AS labtime,
        valuenum::numeric              AS valuenum
    FROM hosp.labevents
    WHERE NULLIF(TRIM(hadm_id), '') IS NOT NULL
      AND NULLIF(TRIM(itemid), '') IS NOT NULL
      AND valuenum IS NOT NULL
),

early_labs AS (
    SELECT
        a.stay_id,
        a.subject_id,
        a.hadm_id,
        m.lab_concept,
        l.labtime,
        l.valuenum
    FROM icu_anchor a
    JOIN raw_labs l
      ON a.hadm_id = l.hadm_id
     AND l.labtime >= a.intime
     AND l.labtime <  a.intime + interval '24 hour'
    JOIN lab_concept_map m
      ON l.itemid = m.itemid
),

early_labs_ranked AS (
    SELECT
        stay_id,
        subject_id,
        hadm_id,
        lab_concept,
        labtime,
        valuenum,
        ROW_NUMBER() OVER (
            PARTITION BY stay_id, lab_concept
            ORDER BY labtime ASC, valuenum ASC
        ) AS rn_first
    FROM early_labs
)

SELECT
    a.stay_id,
    a.subject_id,
    a.hadm_id,

    /* creatinine */
    MAX(CASE WHEN e.lab_concept = 'creatinine' AND e.rn_first = 1 THEN e.valuenum END) AS creatinine_first_24h,
    AVG(CASE WHEN e.lab_concept = 'creatinine' THEN e.valuenum END)                      AS creatinine_mean_24h,
    MAX(CASE WHEN e.lab_concept = 'creatinine' THEN 1 ELSE 0 END)                       AS has_creatinine_24h,

    /* wbc */
    MAX(CASE WHEN e.lab_concept = 'wbc' AND e.rn_first = 1 THEN e.valuenum END)         AS wbc_first_24h,
    AVG(CASE WHEN e.lab_concept = 'wbc' THEN e.valuenum END)                             AS wbc_mean_24h,
    MAX(CASE WHEN e.lab_concept = 'wbc' THEN 1 ELSE 0 END)                               AS has_wbc_24h,

    /* hemoglobin */
    MAX(CASE WHEN e.lab_concept = 'hemoglobin' AND e.rn_first = 1 THEN e.valuenum END)  AS hemoglobin_first_24h,
    AVG(CASE WHEN e.lab_concept = 'hemoglobin' THEN e.valuenum END)                      AS hemoglobin_mean_24h,
    MAX(CASE WHEN e.lab_concept = 'hemoglobin' THEN 1 ELSE 0 END)                        AS has_hemoglobin_24h,

    /* lactate */
    MAX(CASE WHEN e.lab_concept = 'lactate' AND e.rn_first = 1 THEN e.valuenum END)     AS lactate_first_24h,
    MAX(CASE WHEN e.lab_concept = 'lactate' THEN e.valuenum END)                         AS lactate_max_24h,
    MAX(CASE WHEN e.lab_concept = 'lactate' THEN 1 ELSE 0 END)                           AS has_lactate_24h

FROM icu_anchor a
LEFT JOIN early_labs_ranked e
  ON a.stay_id = e.stay_id
GROUP BY
    a.stay_id,
    a.subject_id,
    a.hadm_id
;

-------------------------------------------------------------------------------
-- Section 2: Build grouped stay-level context features
--
-- Why this section exists:
-- The raw admission_type and first_careunit fields are a little too sparse
-- and noisy for this demo cohort. The grouped versions are cleaner, easier to
-- explain, and more stable for modeling.
-------------------------------------------------------------------------------

DROP TABLE IF EXISTS derived.context_features_by_stay_v1_1;

CREATE TABLE derived.context_features_by_stay_v1_1 AS
WITH icu_anchor AS (
    SELECT
        NULLIF(TRIM(stay_id), '')::int     AS stay_id,
        NULLIF(TRIM(subject_id), '')::int  AS subject_id,
        NULLIF(TRIM(hadm_id), '')::int     AS hadm_id,
        UPPER(NULLIF(TRIM(first_careunit), '')) AS first_careunit
    FROM icu.icustays
    WHERE NULLIF(TRIM(stay_id), '') IS NOT NULL
),

adm AS (
    SELECT
        NULLIF(TRIM(hadm_id), '')::int AS hadm_id,
        UPPER(NULLIF(TRIM(admission_type), '')) AS admission_type
    FROM hosp.admissions
)

SELECT
    a.stay_id,
    a.subject_id,
    a.hadm_id,

    CASE
        WHEN adm.admission_type IN ('ELECTIVE', 'SURGICAL SAME DAY ADMISSION') THEN 'elective'
        WHEN adm.admission_type IN ('URGENT', 'EMERGENCY', 'DIRECT EMER.', 'EW EMER.') THEN 'urgent_emergent'
        WHEN adm.admission_type IS NULL THEN 'unknown'
        ELSE 'other'
    END AS admission_type_grp,

    CASE
        WHEN a.first_careunit IS NULL THEN 'unknown'
        WHEN a.first_careunit LIKE '%MICU/SICU%' THEN 'mixed_micu_sicu'
        WHEN a.first_careunit LIKE '%(MICU)%'
          OR a.first_careunit LIKE '%MEDICAL INTENSIVE CARE UNIT%' THEN 'medical'
        WHEN a.first_careunit LIKE '%(SICU)%'
          OR a.first_careunit LIKE '%(TSICU)%'
          OR a.first_careunit LIKE '%SURGICAL INTENSIVE CARE UNIT%'
          OR a.first_careunit LIKE '%TRAUMA SURGICAL%' THEN 'surgical_trauma'
        WHEN a.first_careunit LIKE '%(CVICU)%'
          OR a.first_careunit LIKE '%(CCU)%'
          OR a.first_careunit LIKE '%(CSRU)%'
          OR a.first_careunit LIKE '%CARDIAC%' THEN 'cardiac'
        WHEN a.first_careunit LIKE '%NEURO%'
          OR a.first_careunit LIKE '%NICU%'
          OR a.first_careunit LIKE '%NEONATAL%' THEN 'specialty'
        ELSE 'other'
    END AS first_careunit_grp

FROM icu_anchor a
LEFT JOIN adm
  ON a.hadm_id = adm.hadm_id
;

-------------------------------------------------------------------------------
-- Section 3: Simple QA checks
--
-- Why these are here:
-- Before moving on to the rebuilt modeling table, I want to confirm that the
-- new derived tables are:
-- - one row per stay
-- - covering the expected cohort
-- - producing features that are not all null
-------------------------------------------------------------------------------

-- 3.1 labs table row integrity
SELECT
    COUNT(*) AS n_rows,
    COUNT(DISTINCT stay_id) AS n_distinct_stays
FROM derived.labs_24h_by_stay_v1_1;

/*
n_rows|n_distinct_stays|
------+----------------+
   140|             140|
 */

-- 3.2 context table row integrity
SELECT
    COUNT(*) AS n_rows,
    COUNT(DISTINCT stay_id) AS n_distinct_stays
FROM derived.context_features_by_stay_v1_1;
/*
n_rows|n_distinct_stays|
------+----------------+
   140|             140|
*/

-- 3.3 lab feature coverage
SELECT
    SUM(has_creatinine_24h) AS n_stays_with_creatinine,
    SUM(has_wbc_24h) AS n_stays_with_wbc,
    SUM(has_hemoglobin_24h) AS n_stays_with_hemoglobin,
    SUM(has_lactate_24h) AS n_stays_with_lactate
FROM derived.labs_24h_by_stay_v1_1;
/*
n_stays_with_creatinine|n_stays_with_wbc|n_stays_with_hemoglobin|n_stays_with_lactate|
-----------------------+----------------+-----------------------+--------------------+
                    138|             136|                    136|                  86| 
 */

-- 3.4 grouped admission_type counts
SELECT
    admission_type_grp,
    COUNT(*) AS n_stays
FROM derived.context_features_by_stay_v1_1
GROUP BY admission_type_grp
ORDER BY n_stays DESC, admission_type_grp;
/*
 admission_type_grp|n_stays|
------------------+-------+
urgent_emergent   |    103|
elective          |     20|
other             |     17|
  
 */


-- 3.5 grouped first_careunit counts
SELECT
    first_careunit_grp,
    COUNT(*) AS n_stays
FROM derived.context_features_by_stay_v1_1
GROUP BY first_careunit_grp
ORDER BY n_stays DESC, first_careunit_grp;
/*
 * first_careunit_grp|n_stays|
------------------+-------+
surgical_trauma   |     48|
cardiac           |     38|
medical           |     29|
mixed_micu_sicu   |     23|
specialty         |      2|
 */

/*
===============================================================================
End note

If the QA checks look reasonable, the next step is:

12_build_modeling_table_icu_stay_24h_v1_1.sql

That script should:
- start from icu.icustays
- join the original vitals table
- join the new labs table
- join the new grouped context table
- produce a new modeling artifact:
  derived.icu_stay_modeling_24h_v1_1
===============================================================================
*/