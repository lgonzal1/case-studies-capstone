# 05 — Format Data (Modeling Dataset Spec) — v1.1

**Project:** ICU Patient Care Analysis (MIMIC-IV Clinical Database Demo)  
**Phase:** CRISP-DM — Data Preparation (Task 5: Format Data)  
**Last updated:** 2026-03-22

---

## 1) Purpose

This document defines the final **modeling-ready dataset format** for the current Assignment 2 workflow:
- exact dataset artifact(s)
- column-level contract (targets vs predictors vs audit-only)
- data types and encoding expectations
- missing value conventions
- minimal QA checks to ensure the dataset is safe to model

In CRISP-DM terms, “Format Data” is about making the dataset compatible with the modeling toolchain without changing meaning.

This version updates the earlier v1 spec to reflect the final v1.1 prepared dataset used in the final model comparison.

---

## 2) Final artifacts (source of truth)

### 2.1 Database table (authoritative)
- `derived.icu_stay_modeling_24h_v1_1`

### 2.2 Flat file export (model input)
- `data/processed/icu_stay_modeling_24h_v1_1.csv`

**Export command (reference):**
- `\copy (SELECT * FROM derived.icu_stay_modeling_24h_v1_1 ORDER BY stay_id) TO 'data/processed/icu_stay_modeling_24h_v1_1.csv' CSV HEADER`

### 2.3 Supporting derived tables used to build the final artifact
- `derived.vitals_24h_by_stay_v1`
- `derived.labs_24h_by_stay_v1_1`
- `derived.context_features_by_stay_v1_1`

---

## 3) Grain and row contract

- **One row per ICU stay (`stay_id`)**
- Row contract must hold:
  - `COUNT(*) == COUNT(DISTINCT stay_id)`

v1.1 expectation:
- the final modeling table preserves the same stay-level row contract as v1
- no duplicate `stay_id` rows are allowed

This row contract is the core formatting rule for the dataset.

---

## 4) Targets, predictors, and audit-only columns

A common failure mode is accidentally training on post-outcome information. To prevent that, columns are explicitly categorized.

### 4.1 Target label
- `prolonged_los_8d` (int: 0/1)  
  Definition: `icu.icustays.los >= 8 days`

### 4.2 Predictors allowed for modeling (v1.1)
All predictors must be derived from data available within **0–24 hours** of ICU `intime` or be grouped context known at or near admission.

#### Grouped context predictors
- `admission_type_grp`
- `first_careunit_grp`

#### Early-window measurement density / missingness
- `n_chartevents_6h`
- `n_chartevents_24h`
- `missing_core_vitals_24h_count`

#### Early-window vitals summary features
- HR: `hr_first`, `hr_mean`, `hr_min`, `hr_max`, `hr_last`
- RR: `rr_first`, `rr_mean`, `rr_min`, `rr_max`, `rr_last`
- SpO2: `spo2_first`, `spo2_mean`, `spo2_min`, `spo2_max`, `spo2_last`
- Temp: `temp_first`, `temp_mean`, `temp_min`, `temp_max`, `temp_last`
- MAP: `map_first`, `map_mean`, `map_min`, `map_max`, `map_last`

#### Early-window lab features
- Creatinine:
  - `creatinine_first_24h`
  - `creatinine_mean_24h`
  - `has_creatinine_24h`
- WBC:
  - `wbc_first_24h`
  - `wbc_mean_24h`
  - `has_wbc_24h`
- Hemoglobin:
  - `hemoglobin_first_24h`
  - `hemoglobin_mean_24h`
  - `has_hemoglobin_24h`
- Lactate:
  - `lactate_first_24h`
  - `lactate_max_24h`
  - `has_lactate_24h`

### 4.3 Audit-only columns (NOT allowed as predictors)
These are retained for traceability, debugging, and reporting, but must be excluded from model training.

#### Identifiers
- `subject_id`
- `hadm_id`
- `stay_id`

#### Timing / label-related fields
- `intime`
- `outtime`
- `los_days`

#### Raw context retained for auditability
- `first_careunit`
- `last_careunit`
- `admission_type`

**Why these are audit-only:**
- `last_careunit` is too close to hindsight and can encode downstream trajectory.
- raw context fields are retained for auditability, but the grouped versions are the intended modeling inputs in v1.1.
- identifiers and timing fields should not be available to the model.

**Implementation note:** it is fine to keep these in the CSV for auditability as long as the modeling notebook explicitly drops them before fitting.

---

## 5) Expected column types (modeling layer)

Because the ingestion path initially used TEXT for speed, the SQL output has correct semantics but the CSV still needs explicit typing in Python/R.

### 5.1 Identifiers
- `subject_id`, `hadm_id`, `stay_id`: integer-like  
  These are IDs and should be dropped before training.

### 5.2 Categorical predictors
- `admission_type_grp`: categorical/string
- `first_careunit_grp`: categorical/string

These should be encoded inside the modeling pipeline rather than manually one-hot encoded in the raw export.

### 5.3 Numeric predictors
Expected as numeric:
- vitals summaries
- event counts
- missingness counts
- lab summary values
- lab presence flags
- LOS-derived audit measures

### 5.4 Target
- `prolonged_los_8d`: integer/bool (0/1)

---

## 6) Missing values (conventions)

### 6.1 Numeric features
- Missing numeric values remain **NULL/NaN** in the export.
- The dataset does not silently impute values before modeling.

### 6.2 Categorical features
- Missing categories can remain missing in the export and be handled inside the modeling pipeline.
- Grouped context fields should be encoded in a way that preserves the distinction between known and unknown values.

### 6.3 Why this choice
ICU missingness is often systematic. Filling it in too early can hide signal and blur assumptions.

### 6.4 Learned imputation belongs in the model pipeline
If imputation is used, it should be fit on training data only, not on the full dataset before splitting.

This is a core methodological rule in the final Assignment 2 workflow.

---

## 7) Encoding / scaling expectations

### 7.1 Categorical encoding
Default v1.1 approach:
- one-hot encode grouped context predictors inside the modeling pipeline

### 7.2 Scaling
For logistic regression:
- scale continuous numeric features inside the modeling pipeline

### 7.3 Keep the prepared dataset simple
The exported CSV is not treated as a fully baked machine-learning matrix with all preprocessing done in advance. It is a prepared analytical dataset that still expects modeling-pipeline steps later.

---

## 8) Splitting and evaluation constraints (format implications)

Because the dataset is small and the unit is ICU stay:
- keep `subject_id` available for group-aware splitting
- separate predictors from audit-only fields before fitting
- fit learned preprocessing on training data only
- tune the final decision threshold using training-only out-of-fold predictions
- evaluate once on the held-out test set

This is not just a modeling detail. It affects why the dataset is formatted the way it is.

---

## 9) Required QA checks (must pass before modeling)

Run these checks after building or exporting v1.1:

1. **Grain integrity**
   - `COUNT(*) == COUNT(DISTINCT stay_id)`

2. **Target prevalence sanity**
   - `SELECT prolonged_los_8d, COUNT(*) ...`

3. **No invalid ICU timing**
   - `outtime > intime` for all ICU stays

4. **Audit-only fields retained**
   - IDs / timings / raw context present for QA, but explicitly excluded in modeling code

5. **New lab feature coverage sanity**
   - check non-null rates / `has_*` counts for the v1.1 lab panel

---

## 10) Safe handoff into modeling

The correct modeling handoff for v1.1 is:

1. load the exported prepared dataset  
2. separate target, predictors, and audit-only fields  
3. perform grouped train / validation / test splitting using `subject_id`  
4. fit any learned preprocessing on training data only  
5. tune thresholds on training-only out-of-fold predictions  
6. evaluate on held-out data  

This matters because formatting choices should support valid modeling, not accidentally bake in leakage.

---

## 11) Related artifact support

Related outputs in the repo include:
- schema / table exports
- model metric tables
- coefficient / importance outputs
- held-out prediction tables
- selected threshold outputs

These help keep the final report tied to stable exported artifacts.

---

## 12) Bottom line

The v1.1 formatting strategy is meant to make the prepared dataset usable, auditable, and safe for downstream modeling. The exported table is intentionally not the final fully preprocessed machine-learning matrix. It is a stable stay-level analytical dataset with explicit column roles, versioned lineage, and enough auditability to support both the Assignment 2 report and the final modeling workflow cleanly.
