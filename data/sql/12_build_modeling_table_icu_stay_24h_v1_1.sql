/*
===============================================================================
12_build_modeling_table_icu_stay_24h_v1_1.sql
Project: ICU Patient Care Analysis (MIMIC-IV Clinical Database Demo)
Author: Luis Gonzalez
Phase: Assignment 2 v1.1 modeling table rebuild
Last updated: 2026-03-22

Purpose
-------
This script rebuilds the stay-level modeling table after the targeted v1.1
feature refresh.

The point is not to redesign the whole project. The point is to keep the same
basic modeling grain and leakage rule, but improve the feature mix with:
- grouped context variables
- a small early lab panel

What this script creates
------------------------
- derived.icu_stay_modeling_24h_v1_1

Why this table exists
---------------------
The first v1 model run worked, but it leaned heavily on charting-intensity
features. The v1.1 table is meant to keep the good parts of v1 while giving the
model a more balanced set of early signals.

Design rules
------------
- one row per ICU stay
- same target definition as v1
- only early-window features
- no direct joins to raw event tables here
- versioned artifact so v1 stays untouched
===============================================================================
*/

CREATE SCHEMA IF NOT EXISTS derived;

-------------------------------------------------------------------------------
-- Section 1: Build the v1.1 stay-level modeling table
--
-- Why this section exists:
-- This is the main integration step for v1.1. It starts from the ICU stay
-- anchor and joins the already-aggregated feature tables.
--
-- Tables used:
-- - icu.icustays (anchor / target / audit)
-- - hosp.admissions (raw admission_type for audit)
-- - derived.vitals_24h_by_stay_v1
-- - derived.labs_24h_by_stay_v1_1
-- - derived.context_features_by_stay_v1_1
-------------------------------------------------------------------------------

DROP TABLE IF EXISTS derived.icu_stay_modeling_24h_v1_1;

CREATE TABLE derived.icu_stay_modeling_24h_v1_1 AS
WITH icu_anchor AS (
    SELECT
        NULLIF(TRIM(stay_id), '')::int      AS stay_id,
        NULLIF(TRIM(subject_id), '')::int   AS subject_id,
        NULLIF(TRIM(hadm_id), '')::int      AS hadm_id,
        NULLIF(TRIM(first_careunit), '')    AS first_careunit,
        NULLIF(TRIM(last_careunit), '')     AS last_careunit,
        intime::timestamp                   AS intime,
        outtime::timestamp                  AS outtime,
        los::numeric                        AS los_days,
        CASE
            WHEN los::numeric >= 8 THEN 1
            ELSE 0
        END AS prolonged_los_8d
    FROM icu.icustays
    WHERE NULLIF(TRIM(stay_id), '') IS NOT NULL
),

adm AS (
    SELECT
        NULLIF(TRIM(hadm_id), '')::int      AS hadm_id,
        NULLIF(TRIM(admission_type), '')    AS admission_type
    FROM hosp.admissions
),

vitals AS (
    SELECT
        *
    FROM derived.vitals_24h_by_stay_v1
),

labs AS (
    SELECT
        *
    FROM derived.labs_24h_by_stay_v1_1
),

context_grp AS (
    SELECT
        *
    FROM derived.context_features_by_stay_v1_1
)

SELECT
    -- identifiers / audit
    a.subject_id,
    a.hadm_id,
    a.stay_id,

    -- raw context kept for auditability
    a.first_careunit,
    a.last_careunit,
    adm.admission_type,

    -- grouped context intended for cleaner v1.1 modeling
    cg.first_careunit_grp,
    cg.admission_type_grp,

    -- timing audit fields
    a.intime,
    a.outtime,

    -- original v1 early-window density / missingness / vitals
    v.n_chartevents_6h,
    v.n_chartevents_24h,
    v.missing_core_vitals_24h_count,

    v.hr_first,
    v.hr_mean,
    v.hr_min,
    v.hr_max,
    v.hr_last,

    v.rr_first,
    v.rr_mean,
    v.rr_min,
    v.rr_max,
    v.rr_last,

    v.spo2_first,
    v.spo2_mean,
    v.spo2_min,
    v.spo2_max,
    v.spo2_last,

    v.temp_first,
    v.temp_mean,
    v.temp_min,
    v.temp_max,
    v.temp_last,

    v.map_first,
    v.map_mean,
    v.map_min,
    v.map_max,
    v.map_last,

    -- new v1.1 labs
    l.creatinine_first_24h,
    l.creatinine_mean_24h,
    l.has_creatinine_24h,

    l.wbc_first_24h,
    l.wbc_mean_24h,
    l.has_wbc_24h,

    l.hemoglobin_first_24h,
    l.hemoglobin_mean_24h,
    l.has_hemoglobin_24h,

    l.lactate_first_24h,
    l.lactate_max_24h,
    l.has_lactate_24h,

    -- audit outcome fields
    a.los_days,
    a.prolonged_los_8d

FROM icu_anchor a
LEFT JOIN adm
    ON a.hadm_id = adm.hadm_id
LEFT JOIN vitals v
    ON a.stay_id = v.stay_id
LEFT JOIN labs l
    ON a.stay_id = l.stay_id
LEFT JOIN context_grp cg
    ON a.stay_id = cg.stay_id
;

-------------------------------------------------------------------------------
-- Section 2: Basic QA checks
--
-- Why these checks exist:
-- Before exporting and modeling, I want to confirm that the rebuilt table
-- still follows the same row contract and still looks sane.
-------------------------------------------------------------------------------

-- 2.1 one-row-per-stay check
SELECT
    COUNT(*) AS n_rows,
    COUNT(DISTINCT stay_id) AS n_distinct_stays
FROM derived.icu_stay_modeling_24h_v1_1;

-- 2.2 duplicate stay check
SELECT
    stay_id,
    COUNT(*) AS n_rows
FROM derived.icu_stay_modeling_24h_v1_1
GROUP BY stay_id
HAVING COUNT(*) > 1
ORDER BY n_rows DESC, stay_id;

-- 2.3 target prevalence sanity check
SELECT
    prolonged_los_8d,
    COUNT(*) AS n_stays,
    ROUND(COUNT(*)::numeric / SUM(COUNT(*)) OVER (), 4) AS pct_stays
FROM derived.icu_stay_modeling_24h_v1_1
GROUP BY prolonged_los_8d
ORDER BY prolonged_los_8d;

-- 2.4 grouped context counts
SELECT
    admission_type_grp,
    COUNT(*) AS n_stays
FROM derived.icu_stay_modeling_24h_v1_1
GROUP BY admission_type_grp
ORDER BY n_stays DESC, admission_type_grp;

SELECT
    first_careunit_grp,
    COUNT(*) AS n_stays
FROM derived.icu_stay_modeling_24h_v1_1
GROUP BY first_careunit_grp
ORDER BY n_stays DESC, first_careunit_grp;

-- 2.5 lab coverage in final modeling table
SELECT
    SUM(has_creatinine_24h) AS n_stays_with_creatinine,
    SUM(has_wbc_24h) AS n_stays_with_wbc,
    SUM(has_hemoglobin_24h) AS n_stays_with_hemoglobin,
    SUM(has_lactate_24h) AS n_stays_with_lactate
FROM derived.icu_stay_modeling_24h_v1_1;

-- 2.6 quick missingness spot check for new numeric lab fields
SELECT
    COUNT(*) FILTER (WHERE creatinine_first_24h IS NULL) AS creatinine_first_nulls,
    COUNT(*) FILTER (WHERE wbc_first_24h IS NULL) AS wbc_first_nulls,
    COUNT(*) FILTER (WHERE hemoglobin_first_24h IS NULL) AS hemoglobin_first_nulls,
    COUNT(*) FILTER (WHERE lactate_first_24h IS NULL) AS lactate_first_nulls
FROM derived.icu_stay_modeling_24h_v1_1;

-------------------------------------------------------------------------------
-- Section 3: Optional export command
--
-- Run this manually from psql if the QA checks look good.
-------------------------------------------------------------------------------
-- \copy (
--     SELECT *
--     FROM derived.icu_stay_modeling_24h_v1_1
--     ORDER BY stay_id
-- ) TO 'data/processed/icu_stay_modeling_24h_v1_1.csv' CSV HEADER;

-------------------------------------------------------------------------------
-- End note
--
-- If this table looks good, the next live step is to update the final modeling
-- notebook/script so it uses:
-- ../data/processed/icu_stay_modeling_24h_v1_1.csv
--
-- After that:
-- - rerun the final comparison
-- - review whether the feature mix improved the model story
-- - then freeze evaluation and recommendation
-------------------------------------------------------------------------------