# 01 — Select Data Rationale (CRISP-DM Data Preparation)

**Project:** ICU Patient Care Analysis (MIMIC-IV Clinical Database Demo)  
**Phase:** CRISP-DM — Data Preparation (Task 1: Select Data)  
**Last updated:** 2026-03-04

---

## 1) Purpose (why this document exists)

This document records *what* data was selected (and excluded) for the initial modeling-ready dataset, and *why*. The goal is reproducibility and traceability: if I (or a reviewer) reruns the pipeline later, this explains the inclusion/exclusion logic and the tradeoffs.

This is intentionally written as a **v1 selection decision**. As additional features are introduced (labs/diagnoses/meds), this document should be updated with versioned changes.

---

## 2) Modeling objective (what the dataset must support)

**Primary modeling framing (v1):**  
Early risk stratification at the ICU stay grain (**stay_id**) using only information that would plausibly be available early in the ICU encounter.

- **Unit of analysis:** ICU stay (`icu.icustays.stay_id`)
- **Prediction window:** **0–24 hours from ICU `intime`** (hard leakage constraint)
- **Outcome label (current):** prolonged ICU LOS = **LOS ≥ 8 days**
- **Use case:** decision-support / quality-improvement style context (interpretability + guardrails prioritized over “maximizing AUC”)

---

## 3) Selection criteria (how inclusion/exclusion decisions were made)

### 3.1 Relevance to objective
Include data elements that:
- represent early physiologic state or early measurement processes (e.g., vitals in first 24h),
- or provide minimal stay/admission context (careunit, admission type).

Exclude elements that are not relevant to early prediction or dilute focus.

### 3.2 Leakage control (non-negotiable)
Exclude any feature that uses information *after* the prediction window or that is inherently “full-stay” (e.g., totals across the entire stay).  
This includes common-but-invalid features like “total chart events during stay” because they encode future observation time.

### 3.3 Feasibility / coverage (demo dataset constraints)
Because the demo subset is small, selection prioritizes:
- variables with high coverage in the early window,
- simple, stable join paths,
- avoid over-fragmenting into sparse cohorts.

### 3.4 Technical constraints (local workflow)
Data were loaded quickly as TEXT for iteration speed. This requires consistent casting and normalization when joining tables. For v1, selection prefers tables where join integrity and grain alignment are easy to validate.

---

## 4) Data included in v1 (tables, rows, columns)

### 4.1 Included tables (source-of-truth + predictors)

**Anchor / outcome source**
- `icu.icustays`
  - Used for: `stay_id`, `subject_id`, `hadm_id`, `first_careunit`, `last_careunit`, `intime`, `outtime`, `los`
  - Why: defines the unit of analysis and provides ICU stay timestamps + LOS.

**Context table**
- `hosp.admissions`
  - Used for: `admission_type`
  - Why: lightweight admission context; stable join via `hadm_id`.

**Predictor event table (early window)**
- `icu.chartevents`
  - Used for: vitals measurements filtered to 0–24h from ICU `intime`
  - Why: dense and well-covered in early window for core vitals, making v1 feasible.

### 4.2 Included derived datasets (materialized outputs)
These are the *products* of the selection + construction steps and are the actual modeling artifacts:

- `derived.vitals_24h_by_stay_v1`  
  Early-window vitals features (0–24h), including min/max/mean/first/last and measurement density.

- `derived.icu_stay_modeling_24h_v1`  
  Modeling-ready table at stay grain, joining `icustays + admissions + vitals_24h_by_stay`.

- Export: `data/processed/icu_stay_modeling_24h_v1.csv`

### 4.3 Row selection (records included)
**Inclusion:**
- All ICU stays with non-null `stay_id`.

**Exclusion:**
- No additional exclusions in v1 (e.g., no age exclusions, no service exclusions).
- Rationale: this is feasibility-first; exclusions can introduce bias and reduce already-small sample size.

---

## 5) Features selected (what we actually use)

### 5.1 Outcome
- `prolonged_los_8d = 1` if `icu.icustays.los >= 8 days`, else 0.
- Rationale (v1): produces a workable positive count in the demo cohort and matches the “prolonged stay” concept used in ICU literature (threshold varies; sensitivity analysis / justification can be expanded in later versions).

### 5.2 Early-window predictors (0–24h from ICU admission)
**Vitals summary features (per stay):**
- Heart rate (HR): first/mean/min/max/last
- Respiratory rate (RR): first/mean/min/max/last
- SpO2: first/mean/min/max/last
- Temperature: first/mean/min/max/last
- Mean arterial pressure (MAP): first/mean/min/max/last

**Measurement density / missingness features:**
- `n_chartevents_6h`, `n_chartevents_24h`
- `missing_core_vitals_24h_count`

**Context features:**
- `first_careunit`, `last_careunit`, `admission_type`

### 5.3 Columns retained for auditability (not necessarily used for modeling)
- `intime`, `outtime`, `los_days`
- Rationale: keeping these in the modeling table makes quality checks and debugging easier; they can be dropped at model-fit time.

---

## 6) Data excluded from v1 (and why)

The following sources exist in the demo dataset but are excluded from v1 **by design**:

### 6.1 Labs (`hosp.labevents`)
- Why excluded: adds integration complexity (hadm_id-level events, higher cardinality) and increases feature engineering scope.  
- Plan: include in v2 once baseline model is established (likely a small set of high-value labs within 24h).

### 6.2 Diagnoses (`hosp.diagnoses_icd`)
- Why excluded: diagnosis codes are often finalized later in the encounter and can blur “early prediction” vs post-hoc knowledge; also requires cohort mapping logic.
- Plan: use diagnoses later for cohort definitions or adjustment, but only with clear timing/availability assumptions.

### 6.3 Meds / procedures / microbiology (`pharmacy`, `prescriptions`, `inputevents`, `procedureevents`, etc.)
- Why excluded: these tables may be sparse or require more careful temporal alignment; also risk embedding treatment decisions that occur after the early window.
- Plan: add selectively in v2/v3 after confirming they are available early enough and do not introduce leakage.

### 6.4 Free-text clinical notes
- Not available in the demo extract (and intentionally out-of-scope for this project).

---

## 7) Known limitations introduced by selection decisions

- **Generalizability:** demo subset (100 patients / 140 ICU stays) limits stability and cohort depth.
- **Measurement bias:** vitals measurement frequency can proxy acuity/workflow; missingness is not purely random.
- **Outcome threshold:** “prolonged” does not have a single universal cutoff; v1 uses ≥8d for feasibility and will later be justified/sensitivity-tested.

---

## 8) Traceability (how to reproduce)

### Scripts
- `data/sql/07_construct_vitals_24h_features.sql`
- `data/sql/08_build_modeling_table_icu_stay_24h.sql`
- `data/sql/09_report_tables_assignment1.sql` (evidence tables)

### Primary artifacts
- `derived.vitals_24h_by_stay_v1`
- `derived.icu_stay_modeling_24h_v1`
- `data/processed/icu_stay_modeling_24h_v1.csv`

### One-command rerun (concept)
Run 07 → 08 → 09, then export the processed dataset and evidence CSVs.

---

## 9) Planned changes (v2 roadmap)

- Add a small “top labs within 24h” feature set (e.g., lactate, creatinine, WBC, hemoglobin) if coverage supports it.
- Add a simple cohort indicator (e.g., first_careunit grouping) only if it improves interpretability without fragmenting sample size.
- Run threshold sensitivity for prolonged LOS (e.g., 7d / 10d / 14d or percentile-based) and document the tradeoff.