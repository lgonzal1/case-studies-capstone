# 02 — Data Cleaning Report (CRISP-DM Data Preparation)

**Project:** ICU Patient Care Analysis (MIMIC-IV Clinical Database Demo)  
**Phase:** CRISP-DM — Data Preparation (Task 2: Clean Data)  
**Last updated:** 2026-03-22

---

## 1) Purpose

This document records the concrete data-quality issues identified during Data Understanding and the specific cleaning decisions made to reach a modeling-ready dataset.

Important scope note: we do **not** mutate the source MIMIC tables (for example, `icu.icustays`, `icu.chartevents`, `hosp.labevents`) beyond optional constraints added in the local database for guardrails and tooling. Instead, we “clean” by:
- normalizing types during query time
- filtering and validating timestamps
- restricting events to a defensible prediction window (0–24h)
- materializing cleaned and derived tables under a separate schema (`derived`)

This keeps the workflow reproducible and avoids hidden transformations.

This file started as the v1 cleaning report and is still mostly valid. The main update is that the later Assignment 2 work added a targeted v1.1 refresh rather than stopping at the original vitals-only build.

---

## 2) Starting point / ingestion reality

### 2.1 Quick-load decision (TEXT ingest)
For speed, tables were loaded locally in Postgres using a quick workflow that preserved values but left many columns as TEXT. This enabled fast SQL iteration but created predictable friction:
- joins across tables required consistent casting (for example, `stay_id::int`, `hadm_id::int`)
- timestamp comparisons required consistent `::timestamp` casting
- empty strings can behave differently than NULL

### 2.2 Practical posture
Given the project is a class demo dataset on a local workstation, the priority is:
1. correctness of joins and time logic
2. reproducibility
3. minimal “magic” cleaning that would hide assumptions

That posture stayed the same in both v1 and v1.1.

---

## 3) Data quality issues identified

### 3.1 Type inconsistencies (TEXT vs numeric/time)
**Issue:** keys and timestamps often require casts (`::int`, `::timestamp`) to behave correctly.  
**Risk:** silent join mismatches or timestamp filter failures.

### 3.2 Timestamp consistency: ICU in/out times
**Check:** ICU `outtime` should be after `intime`.  
**Result:** no negative/invalid ICU LOS detected in the original QC checks.  
**Why it matters:** LOS is the core outcome and must be time-consistent.

### 3.3 Event timestamp alignment (charttime before ICU intime)
**Issue:** some chart events occur before ICU `intime`.  
**Interpretation:** this is plausibly real-world behavior, such as ED or transfer documentation carrying forward.  
**Risk:** if used naively, these records could leak pre-ICU information into an ICU-only early window or distort early-window features.

### 3.4 Join integrity / orphans
The project checked the main join paths needed for v1 and found no true orphan problem on the core routes when blanks / nulls were handled correctly.

That mattered because once the source tables were quick-loaded as text, a sloppy orphan check could make the situation look worse than it actually was.

### 3.5 Coverage / missingness in early windows
The original feasibility checks showed that core vitals had strong enough coverage within 6h and 24h windows to support a stay-level v1 dataset.

That same general issue came back again in v1.1 when deciding whether a small lab panel was worth adding. The lab audit showed that a small number of early labs also had enough coverage to justify inclusion.

---

## 4) Cleaning actions taken

### 4.1 Hard rule: leakage control via time-window restriction
All predictor extraction is restricted to **0–24 hours after ICU `intime`**.

This is enforced at query time rather than by rewriting source tables.

**Why:** this is the main leakage-control rule in the project.

### 4.2 Standardized casting conventions in integration queries
Integration queries explicitly cast join keys and timestamps:
- `stay_id::int`
- `hadm_id::int`
- `subject_id::int`
- `intime::timestamp`
- `outtime::timestamp`
- event times cast to timestamp as needed

**Why:** this prevents type errors and removes ambiguity from TEXT-ingested columns.

### 4.3 Null/blank handling
Where relevant, queries treat empty strings as missing values using defensive logic such as:
- `NULLIF(TRIM(col), '')`

**Why:** avoids false orphan checks and prevents accidental joins on blank keys.

### 4.4 Do not “fix” source event timestamps; filter them instead
Events with timestamps before ICU `intime` are not edited or deleted in source tables.  
Instead, the feature extraction queries filter to the approved early window.

**Why:** this preserves provenance and avoids inventing corrected timestamps.

### 4.5 Materialize cleaned / derived tables under `derived`
Derived artifacts are created under `derived`, not in the source schemas.

This now includes both the original v1 artifacts and the later v1.1 additions.

Examples:
- `derived.vitals_24h_by_stay_v1`
- `derived.labs_24h_by_stay_v1_1`
- `derived.context_features_by_stay_v1_1`
- `derived.icu_stay_modeling_24h_v1_1`

**Why:** this keeps the separation between raw-ish source data and prepared analytical artifacts clear.

---

## 5) Validation (how we know cleaning worked)

The following checks were part of the reproducible cleaning / preparation workflow:

### 5.1 Row count and uniqueness
The modeling table is expected to have one row per `stay_id`.

This was checked for v1 and again for v1.1.

### 5.2 Outcome prevalence sanity
The prolonged LOS label was checked after integration to make sure the target distribution still made sense and had not been distorted by joins.

### 5.3 Key integrity checks
The core join paths used for the actual project workflow were checked and did not show a real orphan problem once text-ingest quirks were handled correctly.

### 5.4 Early-window coverage checks
The early-window feature sources used in the final project had enough coverage to justify inclusion:
- core vitals in v1
- grouped context and small early lab panel in v1.1

---

## 6) Remaining issues / limitations

### 6.1 TEXT-ingested schema (technical debt)
The current approach still relies on repeated casting in queries.

That is acceptable for this project, but it does mean:
- the SQL is more verbose than it would be in a typed ingestion
- one missed cast can still cause confusion

A fully typed reload would be cleaner, but it was not necessary for this capstone.

### 6.2 Systematic missingness and measurement bias
Measurement frequency is a feature, but it is also a bias mechanism. A sicker patient may have more measurements, and missingness can reflect workflow as much as physiology.

The project dealt with that by keeping density and missingness explicit rather than pretending they did not exist.

### 6.3 External validity
This is still a demo subset. Cleaning can improve the workflow, but it cannot fix sample size limitations or make the cohort more representative than it is.

---

## 7) Traceability (how to reproduce)

### SQL scripts
- `data/sql/07_construct_vitals_24h_features.sql`
- `data/sql/10_assignment2_feature_audit_v1_1.sql`
- `data/sql/11_construct_labs_24h_features_v1_1.sql`
- `data/sql/12_build_modeling_table_icu_stay_24h_v1_1.sql`

### Main artifacts
- `derived.vitals_24h_by_stay_v1`
- `derived.labs_24h_by_stay_v1_1`
- `derived.context_features_by_stay_v1_1`
- `derived.icu_stay_modeling_24h_v1_1`
- `data/processed/icu_stay_modeling_24h_v1_1.csv`

---

## 8) v1.1 cleaning update

The original version of this file treated labs as a possible future step. That is no longer the current state.

The later Assignment 2 work added a small lab panel and grouped context variables through a targeted refresh. That update did **not** change the basic cleaning posture. The same principles still applied:
- keep event timing explicit
- cast types defensively
- aggregate event tables to stay level before joining
- keep missingness visible
- preserve source provenance

So the v1.1 refresh was an extension of the same cleaning logic, not a different cleaning philosophy.

---

## 9) Bottom line

The cleaning strategy in this project stays pretty simple: do not hide assumptions, do not mutate source data unless there is a very strong reason, and do not let loose typing or timestamp sloppiness quietly break the modeling dataset.

The later v1.1 refresh expanded the prepared dataset, but it did not change the core cleaning posture. It just carried the same rules forward into a slightly richer final dataset.
