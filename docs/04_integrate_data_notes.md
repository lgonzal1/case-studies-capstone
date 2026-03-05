# 04 — Integrate Data (Join Strategy + Grain Alignment Notes) — v1

**Project:** ICU Patient Care Analysis (MIMIC-IV Clinical Database Demo)  
**Phase:** CRISP-DM — Data Preparation (Task 4: Integrate Data)  
**Last updated:** 2026-03-04

---

## 1) Purpose

This document records how data from multiple MIMIC-IV tables are combined into a single, modeling-ready dataset, including:
- the chosen unit of analysis (grain),
- join keys and join types,
- safeguards against row duplication ("join explosions"),
- rationale for what is integrated in v1 vs deferred.

Integration is where otherwise-correct analyses frequently go wrong in healthcare data, because event tables are high-cardinality and many-to-one relative to the modeling grain.

---

## 2) Modeling grain (the anchor decision)

**v1 unit of analysis:** ICU stay (`stay_id`)

**Anchor table:** `icu.icustays`  
This table defines:
- the modeling entity (`stay_id`)
- ICU timing (`intime`, `outtime`)
- ICU length of stay (`los`) used for outcome label
- ICU context (`first_careunit`, `last_careunit`)
- link keys to higher grains (`subject_id`, `hadm_id`)

**Why this grain works for v1:**
- LOS is naturally defined at ICU stay level.
- ICU timing provides a clean reference point for leakage-safe windows (0–24h from ICU `intime`).
- Event tables like `icu.chartevents` link cleanly to `stay_id`.

---

## 3) Source relationships (core join paths)

The integration relies on three key identifiers:

- `subject_id` (patient)
- `hadm_id` (hospital admission)
- `stay_id` (ICU stay)

For v1 integration:

### 3.1 ICU stay to admission context
**Join:** `icu.icustays.hadm_id → hosp.admissions.hadm_id`  
**Join type:** LEFT JOIN (keep all ICU stays even if admission context is missing)

**Rationale:**
- `admission_type` is a lightweight contextual feature.
- Using LEFT JOIN prevents accidental row loss if a record is missing upstream.

### 3.2 ICU stay to vitals event data
**Join:** `icu.chartevents.stay_id → icu.icustays.stay_id`  
**Join type:** not joined directly into the modeling table; instead it is **aggregated first**, then joined.

**Rationale:**
- `icu.chartevents` is many-to-one relative to `stay_id`.
- Direct joining `chartevents` into a stay-level table would multiply rows and corrupt modeling grain.
- Therefore, integration is two-step: aggregate → wide features → join.

---

## 4) Integration pattern used in v1 (safe two-step approach)

v1 integration uses a disciplined pattern:

### Step A — Construct stay-level features from event tables
- `icu.chartevents` is filtered to the early window (0–24h from ICU `intime`)
- Relevant `itemid`s are mapped to vital concepts
- Values are aggregated per `stay_id` into summary features

**Output table:**
- `derived.vitals_24h_by_stay_v1` (one row per `stay_id`)

This table is the integration-friendly representation of the event data.

### Step B — Join small, stay-level tables into the modeling table
Build final modeling table by joining:

- `icu.icustays` (anchor)
- `hosp.admissions` (context)
- `derived.vitals_24h_by_stay_v1` (constructed predictors)

**Output table:**
- `derived.icu_stay_modeling_24h_v1` (one row per stay)

---

## 5) Join types and why they were chosen

### 5.1 Anchor-first mindset
Integration always starts from the anchor entity (icustays) and adds fields.

### 5.2 LEFT JOIN as the default for context/features
- LEFT JOIN preserves the anchor cohort and keeps missingness explicit.
- This is preferred to INNER JOIN unless exclusion is intentional and documented.

### 5.3 Aggregation before integration for event tables
- Event tables (`chartevents`, later possibly `labevents`) must be **summarized to stay grain** before joining.
- This is the primary control against join explosions.

---

## 6) Guardrails and validation checks

Integration correctness is validated using the following checks:

### 6.1 Grain integrity check (required)
The modeling table must satisfy:
- `COUNT(*) == COUNT(DISTINCT stay_id)`

This confirms:
- one row per stay
- no duplicate rows from joins

### 6.2 Outcome sanity check (label prevalence)
Validate:
- expected positives count for `prolonged_los_8d`

In v1:
- 140 stays total
- 16 prolonged (LOS ≥ 8 days)

This confirms:
- no accidental row duplication
- no accidental row filtering

### 6.3 Key integrity checks (orphan checks)
Core paths are checked for orphans:
- admissions → patients
- icustays → admissions
- chartevents → icustays
- diagnoses_icd → admissions (future use)

These reduce the risk of silent join failures or dropped records.

---

## 7) Integration decisions deferred (why not included in v1)

v1 intentionally integrates only the minimum necessary sources to create a valid baseline dataset.

### 7.1 Labs (`hosp.labevents`) deferred
**Why:**  
- high cardinality; hadm_id-level (not always stay_id-level)
- requires careful temporal alignment and selection of a small lab panel
- increases risk of row explosion if joined directly

**Planned v2 integration:**  
- filter to early window using ICU `intime` (or admit time with explicit assumptions)
- aggregate to stay-level features (like vitals)
- join aggregated lab features to the modeling table

### 7.2 Diagnoses (`hosp.diagnoses_icd`) deferred
**Why:**  
- diagnosis timing/availability is often unclear (codes can be finalized later)
- cohort mapping logic is non-trivial and can become subjective
- better used later for stratification or risk adjustment once baseline model exists

### 7.3 Medications / procedures deferred
**Why:**  
- risk of encoding post-window treatment decisions (leakage)
- requires careful "available by prediction time" assumptions
- some tables may be sparse in demo subset

---

## 8) Naming / lineage conventions

v1 uses explicit versioned derived artifacts:

- `derived.vitals_24h_by_stay_v1`
- `derived.icu_stay_modeling_24h_v1`
- export: `data/processed/icu_stay_modeling_24h_v1.csv`

This provides clean lineage and makes it safe to create v2 tables without overwriting v1.

---

## 9) Reproducibility (how to re-run)

### Scripts of record
- `data/sql/07_construct_vitals_24h_features.sql` (construct)
- `data/sql/08_build_modeling_table_icu_stay_24h.sql` (integrate)
- `data/sql/09_report_tables_assignment1.sql` (evidence/QA exports)

### Minimal replay order
1) Run 07 (creates vitals-by-stay)
2) Run 08 (creates modeling table)
3) Run QA checks (row count, distinct stay_id, prevalence)
4) Export CSV for modeling

---

## 10) Planned integration changes (v2 roadmap)
- Add a small early-window lab panel (coverage-gated), aggregated to stay grain.
- Consider adding a minimal diagnoses-derived cohort indicator (only if timing assumptions are defensible).
- Maintain the rule: **event tables must be aggregated to stay-level before integration**.

