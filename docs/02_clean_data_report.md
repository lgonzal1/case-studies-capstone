# 02 — Data Cleaning Report (CRISP-DM Data Preparation)

**Project:** ICU Patient Care Analysis (MIMIC-IV Clinical Database Demo)  
**Phase:** CRISP-DM — Data Preparation (Task 2: Clean Data)  
**Last updated:** 2026-03-04

---

## 1) Purpose (what “cleaning” means in this project)

This document records the concrete data-quality issues identified during Data Understanding and the specific cleaning decisions made to reach a modeling-ready v1 dataset.

Important scope note: I do **not** mutate the source MIMIC tables (e.g., `icu.icustays`, `icu.chartevents`) beyond optional constraints added in the local database for guardrails/tooling. Instead, I “clean” by:
- normalizing types during query time (casts),
- filtering/validating timestamps,
- restricting to a defensible prediction window (0–24h),
- materializing cleaned/derived tables under a separate schema (`derived`).

This keeps the workflow reproducible and avoids hidden transformations.

---

## 2) Starting point / ingestion reality

### 2.1 Quick-load decision (TEXT ingest)
For speed, tables were loaded locally in Postgres using a quick workflow that preserved values but left many columns as TEXT. This enabled fast SQL iteration but created predictable friction:
- joins across tables required consistent casting (e.g., `stay_id::int`, `hadm_id::int`)
- timestamp comparisons required consistent `::timestamp` casting
- empty strings can behave differently than NULL

### 2.2 Practical posture
Given the project is a class demo dataset on a local workstation, the priority is:
1) correctness of joins and time logic for v1,
2) reproducibility,
3) minimal “magic” cleaning that would hide assumptions.

---

## 3) Data quality issues identified (what we found)

### 3.1 Type inconsistencies (TEXT vs numeric/time)
**Issue:** keys and timestamps often require casts (`::int`, `::timestamp`) to behave correctly.  
**Risk:** silent join mismatches or timestamp filter failures.  
**Observed symptom:** joining `stay_id` across derived tables can error if one side is text and the other is integer.

### 3.2 Timestamp consistency: ICU in/out times
**Check:** ICU outtime should be after intime.  
**Result:** no negative/invalid ICU LOS detected (0 rows where `outtime <= intime`).  
**Why it matters:** LOS is the core outcome and must be time-consistent.

### 3.3 Event timestamp alignment (charttime before ICU intime)
**Issue:** some chart events occur before ICU `intime`.  
**Observed:** `charttime < intime` exists for core vitals itemids (278 rows in the check performed).  
**Interpretation:** this is plausibly real-world behavior (e.g., documentation begins in ED or pre-ICU location and carries forward).  
**Risk:** if used naively, these records could leak “pre-ICU” signals into an ICU-only early window or distort early-window features.

### 3.4 Join integrity / orphans
**Goal:** ensure core join paths do not have orphans that would break integration.

**Validated join paths (no orphans observed):**
- `hosp.admissions.subject_id → hosp.patients.subject_id`
- `icu.icustays.hadm_id → hosp.admissions.hadm_id`
- `icu.icustays.subject_id → hosp.patients.subject_id`
- `icu.chartevents.stay_id → icu.icustays.stay_id`
- `hosp.diagnoses_icd.hadm_id → hosp.admissions.hadm_id`

**Note on `hosp.labevents`:**
A union-style orphan check can look scary depending on casting/blank handling, but a focused orphan query confirmed **0 true orphans** when excluding NULL/empty hadm_id. Likely explanation: ingestion-as-text + blanks can masquerade as missing join keys if not normalized.

### 3.5 Coverage / missingness in early window
For v1, the primary feasibility requirement was: “Are core vitals actually present within 0–24h for most stays?”  
Result: core vitals coverage was high in both 6h and 24h windows (roughly mid-90s to ~100% across HR/RR/SpO2/BP/MAP; Temp slightly lower but still strong).  
**Risk:** missingness is not random in ICU data; measurement density can proxy acuity/workflow.

---

## 4) Cleaning actions taken (what we did)

### 4.1 Hard rule: leakage control via time-window restriction
**Action:** all predictor extraction for v1 is restricted to **0–24 hours after ICU `intime`**.  
This is enforced in `07_construct_vitals_24h_features.sql` by filtering:
- `charttime >= intime`
- `charttime < intime + interval '24 hour'`

**Why:** prevents using information that would not be available at prediction time, and also blocks post-ICU or late-stay signals.

### 4.2 Standardized casting conventions in integration queries
**Action:** integration queries explicitly cast join keys and timestamps:
- `stay_id::int`, `hadm_id::int`, `subject_id::int`
- `intime::timestamp`, `outtime::timestamp`, `charttime::timestamp`

**Why:** prevents type errors and removes ambiguity from TEXT-ingested columns.

### 4.3 Null/blank handling (defensive)
**Action:** where relevant, queries treat empty strings as missing values (e.g., `NULLIF(TRIM(col),'')`).  
**Why:** avoids false “orphans” and prevents accidental joins on blank keys.

### 4.4 Do not “fix” source event timestamps; instead, filter them
**Action:** chart events with `charttime < intime` are not edited or deleted in source tables.  
Instead, the early-window feature extraction filters to `charttime >= intime`.  
**Why:** preserves provenance; avoids inventing a “corrected” time.

### 4.5 Materialize cleaned derived tables under `derived` schema
**Action:** derived artifacts are created under `derived` (not in `icu`/`hosp` schemas):
- `derived.vitals_24h_by_stay_v1`
- `derived.icu_stay_modeling_24h_v1`

**Why:** clean separation between “raw-ish source” and “prepared data products,” enabling clear lineage.

---

## 5) Validation (how we know cleaning worked)

The following checks were executed and are reproducible via SQL scripts:

### 5.1 Row count and uniqueness (modeling table)
- Expectation: one row per stay_id for v1 modeling.
- Verified: 140 rows, 140 distinct `stay_id`.

### 5.2 Outcome prevalence sanity (prolonged LOS label)
- Verified: 16 positives out of 140 stays (11.4%) for LOS ≥ 8 days.

### 5.3 Key integrity checks
- Verified: 0 orphans on all core join paths used for v1 (`patients/admissions/icustays/chartevents/admission_type`).

### 5.4 Early-window coverage checks
- Verified: high presence rates for core vitals within 6h and 24h windows.

---

## 6) Remaining issues / limitations (what we are NOT solving yet)

### 6.1 TEXT-ingested schema (technical debt)
Current approach relies on repeated casting in queries. This is acceptable for v1, but:
- it increases query verbosity
- it increases the chance of “one missed cast” causing an error or silent mismatch

**Future improvement:** run a typed ingestion (COPY into typed tables) or create typed views.

### 6.2 Systematic missingness and measurement bias
Measurement frequency is a feature, but it is also a bias mechanism. A sicker patient may have more measurements, and “missingness” can encode workflow rather than physiology.

**Mitigation used in v1:** include measurement density (`n_chartevents_6h/24h`) and missingness counts as explicit predictors/controls.

### 6.3 External validity
This is a demo subset (100 patients). Cleaning cannot fix sample size limitations; conclusions must remain conservative.

---

## 7) Traceability (how to reproduce)

### Scripts
- `data/sql/07_construct_vitals_24h_features.sql`
- `data/sql/08_build_modeling_table_icu_stay_24h.sql`
- `data/sql/09_report_tables_assignment1.sql` (evidence exports)

### Artifacts
- `derived.vitals_24h_by_stay_v1`
- `derived.icu_stay_modeling_24h_v1`
- `data/processed/icu_stay_modeling_24h_v1.csv`

---

## 8) Next cleaning step (v2)
If expanding beyond vitals:
- add a small lab feature set (0–24h) with strict timing rules and coverage profiling,
- document any imputation strategy explicitly (likely “no imputation for v2; add missingness indicators first”),
- consider typed views to remove repeated casts.
