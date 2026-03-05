# 05 — Format Data (Modeling Dataset Spec) — v1

**Project:** ICU Patient Care Analysis (MIMIC-IV Clinical Database Demo)  
**Phase:** CRISP-DM — Data Preparation (Task 5: Format Data)  
**Last updated:** 2026-03-04

---

## 1) Purpose

This document defines the final **modeling-ready dataset format** for v1:
- exact dataset artifact(s),
- column-level contract (targets vs predictors vs audit-only),
- data types and encoding expectations,
- missing value conventions,
- minimal QA checks to ensure the dataset is safe to model.

In CRISP-DM terms, “Format Data” is about making the dataset compatible with the modeling toolchain (Python/R/Sklearn), *without changing meaning*.

---

## 2) v1 artifacts (source of truth)

### 2.1 Database table (authoritative)
- `derived.icu_stay_modeling_24h_v1`

### 2.2 Flat file export (model input)
- `data/processed/icu_stay_modeling_24h_v1.csv`

**Export command (reference):**
- `\copy (SELECT * FROM derived.icu_stay_modeling_24h_v1 ORDER BY stay_id) TO 'data/processed/icu_stay_modeling_24h_v1.csv' CSV HEADER`

---

## 3) Grain and row contract

- **One row per ICU stay (`stay_id`)**
- Row contract must hold:
  - `COUNT(*) == COUNT(DISTINCT stay_id)`

v1 verified:
- `n_rows = 140`, `n_distinct stay_id = 140`

---

## 4) Targets, predictors, and audit-only columns

A common failure mode is accidentally training on post-outcome information.  
To prevent that, columns are explicitly categorized:

### 4.1 Target label(s)
- `prolonged_los_8d` (int: 0/1)  
  Definition: `icu.icustays.los >= 8 days`

### 4.2 Predictors allowed for modeling (v1)
All predictors must be derived from data available within **0–24 hours** of ICU `intime` or be static context known at/near admission.

**Context predictors**
- `first_careunit` (categorical)
- `admission_type` (categorical)

**Early-window measurement density / missingness**
- `n_chartevents_6h` (int)
- `n_chartevents_24h` (int)
- `missing_core_vitals_24h_count` (int)

**Early-window vitals summary features (numeric)**
- HR: `hr_first`, `hr_mean`, `hr_min`, `hr_max`, `hr_last`
- RR: `rr_first`, `rr_mean`, `rr_min`, `rr_max`, `rr_last`
- SpO2: `spo2_first`, `spo2_mean`, `spo2_min`, `spo2_max`, `spo2_last`
- Temp: `temp_first`, `temp_mean`, `temp_min`, `temp_max`, `temp_last`
- MAP: `map_first`, `map_mean`, `map_min`, `map_max`, `map_last`

### 4.3 Audit-only columns (NOT allowed as predictors)
These are retained for traceability, debugging, and reporting—but **must be excluded from model training**:

- Identifiers:
  - `subject_id`, `hadm_id`, `stay_id`
- Timing (post-hoc / label-related):
  - `intime`, `outtime`
- Outcome continuous value:
  - `los_days`
- Potential leakage context:
  - `last_careunit`  
    Rationale: last careunit is determined at the end of the ICU stay; it is not reliably known at 24h and can encode downstream trajectory.

**Implementation note:** it is fine to keep these in the CSV for auditability as long as the modeling notebook explicitly drops them.

---

## 5) Expected column types (modeling layer)

Because the ingestion path initially used TEXT for speed, the *SQL output* has correct semantics but the *CSV* will be read by Python/R and will need explicit typing.

### 5.1 Identifiers
- `subject_id`, `hadm_id`, `stay_id`: integer (treat as IDs; drop before training)

### 5.2 Categorical predictors
- `first_careunit`: categorical/string → encode (one-hot or target encoding with caution)
- `admission_type`: categorical/string → encode

### 5.3 Numeric predictors
All vitals and density features should be numeric (float or int).

### 5.4 Target
- `prolonged_los_8d`: integer/bool (0/1)

---

## 6) Missing values (conventions)

### 6.1 Numeric features
- Missing numeric values remain **NULL/NaN** in the export.
- v1 strategy: do not impute silently; treat missingness as signal and/or handle with:
  - simple imputation (median) + missingness indicator, or
  - model types that tolerate missing values (if used later)

### 6.2 Categorical features
- Missing categories should be encoded as explicit `"Unknown"` (if present), or left as NaN and handled in preprocessing.

### 6.3 Why this choice
ICU missingness is often systematic (workflow/acuity-driven). “Filling it in” without documenting assumptions can introduce bias and hide uncertainty.

---

## 7) Encoding / scaling expectations (modeling tool compatibility)

### 7.1 Categorical encoding
Default v1 approach:
- one-hot encode `first_careunit` and `admission_type` (drop one level to avoid collinearity for linear models)

### 7.2 Scaling
For logistic regression:
- scale continuous vitals features (e.g., standardize), especially if mixing with count features.

### 7.3 Feature set minimalism
Given small N and 16 positives, keep v1 feature set simple and interpretable; avoid high-dimensional expansions.

---

## 8) Splitting and evaluation constraints (format implications)

Because the dataset is small and the unit is ICU stay:
- prefer stratified cross-validation (stratify on `prolonged_los_8d`)
- avoid splitting in a way that leaks patient identity:
  - if multiple stays per patient exist, consider group splits by `subject_id` (optional; check how many subjects repeat)

This is not strictly “formatting,” but it affects how IDs should be retained for grouping even if dropped from predictors.

---

## 9) Required QA checks (must pass before modeling)

Run these checks after (re)building v1:

1) Grain integrity:
- `COUNT(*) == COUNT(DISTINCT stay_id)`

2) Target prevalence sanity:
- `SELECT prolonged_los_8d, COUNT(*) ...` should match expectations (v1: 16 positives)

3) No negative ICU LOS:
- `outtime > intime` for all `icu.icustays`

4) Early-window enforcement (spot-check):
- constructed features are derived only from `charttime >= intime` and `< intime + 24h`

---

## 10) Versioning policy

- This spec describes **v1** artifacts:
  - `derived.icu_stay_modeling_24h_v1`
  - `data/processed/icu_stay_modeling_24h_v1.csv`

Any changes that alter:
- the label definition,
- prediction window,
- included feature families,
- or column meanings/types

…should increment the version (`v2`, `v3`) and update this document.

---

## 11) Planned v2 improvements (format-layer)
- Add a schema export (`outputs/tables/icu_stay_modeling_24h_v1_schema.csv`) describing each column and intended type/use.
- Add lab features (0–24h) only if coverage supports it and after aggregating to stay grain.
- Add outlier flags (not automatic deletion) for vitals.

