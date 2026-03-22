# 02 — Data Cleaning Report (CRISP-DM Data Preparation)

**Project:** ICU Patient Care Analysis (MIMIC-IV Clinical Database Demo)  
**Phase:** CRISP-DM — Data Preparation (Task 2: Clean Data)  
**Last updated:** 2026-03-22

---

## 1) Purpose

This document records the concrete data-quality issues identified during Data Understanding and the specific cleaning decisions used to reach a modeling-ready v1 dataset.

In this project, “cleaning” does **not** mean rewriting source MIMIC tables. Instead, source tables are preserved and data is cleaned through reproducible query logic and derived artifacts. The v1 cleaning strategy relies on:

- explicit casting of text-loaded keys and timestamps,
- defensive handling of blanks and NULLs,
- strict timestamp filtering for the prediction window,
- validation checks after integration,
- materialization of cleaned outputs in the `derived` schema.

This approach preserves provenance and keeps the workflow auditable.

---

## 2) Starting point / ingestion reality

### 2.1 Quick-load choice
For speed, the demo tables were loaded into local Postgres with many fields preserved as TEXT. This made initial exploration fast but introduced predictable friction:

- joins often required `::int` casts on identifiers,
- time logic required `::timestamp` casts,
- empty strings had to be normalized before joins or orphan checks.

### 2.2 Practical cleaning posture
Given the project is a class case study using a local demo dataset, the priority order for v1 was:

1. protect correctness of joins and time logic,  
2. keep transformations reproducible and visible,  
3. avoid undocumented “magic” cleaning that changes source meaning.

---

## 3) Data quality issues identified

### 3.1 Type inconsistencies
Many identifiers and timestamps behave as strings unless explicitly cast.

**Risk:** silent join mismatches, cast errors, or failed time filtering.

**Handling:** integration and feature-construction queries explicitly cast key identifiers and time fields, including `stay_id`, `hadm_id`, `subject_id`, `intime`, `outtime`, and `charttime`.

### 3.2 ICU timestamp consistency
A basic sanity check confirmed no negative ICU LOS records in `icu.icustays` when comparing `outtime` to `intime`.

**Why it matters:** LOS is the core outcome, so invalid stay timing would undermine the whole assignment.

### 3.3 Event timing before ICU `intime`
Some `chartevents` occur before ICU admission time.

**Interpretation:** these are plausible documentation artifacts from ED/pre-ICU workflow rather than necessarily “bad” records.

**Risk:** if used naively, these records can contaminate an ICU-only early prediction window.

**Handling:** source rows are not edited or deleted. Instead, the feature extraction logic enforces `charttime >= intime`.

### 3.4 Join integrity / orphan risk
Core join paths were checked to ensure the selected v1 sources could be integrated without silent row loss.

Validated paths included:

- `hosp.admissions.subject_id -> hosp.patients.subject_id`
- `icu.icustays.hadm_id -> hosp.admissions.hadm_id`
- `icu.icustays.subject_id -> hosp.patients.subject_id`
- `icu.chartevents.stay_id -> icu.icustays.stay_id`

Focused checks showed no true orphans after normalizing blanks and NULL-like values.

### 3.5 Early-window coverage / missingness
Core vitals had strong presence within the first 6 and 24 hours, making them feasible for a v1 early prediction feature set.

**Caveat:** missingness in ICU data is not random; measurement frequency can reflect acuity or workflow.

---

## 4) Cleaning actions taken

### 4.1 Hard leakage rule via time-window restriction
All predictor extraction for v1 is restricted to the interval:

- `charttime >= intime`
- `charttime < intime + interval '24 hour'`

This is the main anti-leakage rule for the prepared dataset.

### 4.2 Standardized casting conventions
The SQL scripts use explicit casting for keys and timestamps, for example:

- `stay_id::int`
- `hadm_id::int`
- `subject_id::int`
- `intime::timestamp`
- `outtime::timestamp`
- `charttime::timestamp`

This keeps joins and time comparisons consistent.

### 4.3 Blank / NULL normalization
Where relevant, blank strings are treated as missing values with patterns such as:

- `NULLIF(TRIM(col), '')`

This avoids false orphan counts and accidental joins on blank keys.

### 4.4 Preserve source provenance
Source event timestamps are **not** manually corrected. Events before ICU admission are handled by filtering, not by rewriting source data.

This preserves the original source tables and keeps assumptions explicit.

### 4.5 Materialize cleaned outputs under `derived`
Prepared artifacts are created under the `derived` schema rather than back-written into `icu` or `hosp`:

- `derived.vitals_24h_by_stay_v1`
- `derived.icu_stay_modeling_24h_v1`

This separates raw-ish source data from prepared products cleanly.

---

## 5) Validation checks

The following checks were used to verify that cleaning and integration produced a valid modeling table.

### 5.1 One-row-per-stay integrity
Expectation: one row per `stay_id`.

Verified for v1:

- 140 rows
- 140 distinct `stay_id`

### 5.2 Outcome prevalence sanity check
For the prolonged LOS label (LOS >= 8 days), the v1 table contains:

- 16 positives out of 140 stays (11.4%)

This is a useful sanity check against accidental duplication or filtering.

### 5.3 Core join integrity
The selected v1 join paths showed no true orphan problems after blank handling and casting logic were applied.

### 5.4 Early-window feasibility
Coverage checks confirmed that the selected core vitals are sufficiently present in the 0–24 hour window to support a simple first-pass model.

---

## 6) Remaining issues / limitations

### 6.1 TEXT-ingested schema remains technical debt
Repeated casting is workable for v1 but increases verbosity and the chance of an avoidable mistake.

**Future improvement:** typed ingestion or typed views.

### 6.2 Missingness can encode workflow
Measurement density is not purely noise. More observations may reflect sicker patients or different documentation patterns.

**Mitigation in v1:** keep measurement-density and missingness counts explicit rather than hiding them.

### 6.3 Small demo cohort
Cleaning can improve validity, but it cannot solve sample-size limitations. Conclusions must remain modest.

---

## 7) Traceability and reproducibility

### Scripts of record
- `data/sql/07_construct_vitals_24h_features.sql`
- `data/sql/08_build_modeling_table_icu_stay_24h.sql`
- `data/sql/09_report_tables_assignment1.sql`

### Artifacts
- `derived.vitals_24h_by_stay_v1`
- `derived.icu_stay_modeling_24h_v1`
- `data/processed/icu_stay_modeling_24h_v1.csv`

---

## 8) Bottom line

The v1 cleaning strategy prioritizes validity, traceability, and leakage control over aggressive intervention. Rather than “fixing” the raw MIMIC demo tables, the project creates a reproducible prepared dataset through explicit casts, timestamp filtering, blank handling, and derived-table materialization. That choice is intentionally conservative and well suited to a course project where methodological clarity matters more than invisible data massaging.
