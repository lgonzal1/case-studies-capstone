# 04 — Integrate Data (Join Strategy + Grain Alignment Notes) — v1.1

**Project:** ICU Patient Care Analysis (MIMIC-IV Clinical Database Demo)  
**Phase:** CRISP-DM — Data Preparation (Task 4: Integrate Data)  
**Last updated:** 2026-03-22

---

## 1) Purpose

This document records how data from multiple MIMIC-IV tables are combined into a single modeling-ready dataset, including:
- the chosen unit of analysis (grain)
- join keys and join types
- safeguards against row duplication
- rationale for what is integrated now versus deferred

Integration is where otherwise-correct analyses often go wrong in healthcare data, because event tables are high-cardinality and many-to-one relative to the modeling grain.

This version updates the earlier v1 notes to reflect the final v1.1 integration path actually used for Assignment 2.

---

## 2) Modeling grain (the anchor decision)

**Unit of analysis:** ICU stay (`stay_id`)

**Anchor table:** `icu.icustays`

This table defines:
- the modeling entity (`stay_id`)
- ICU timing (`intime`, `outtime`)
- ICU length of stay (`los`) used for the outcome label
- ICU context (`first_careunit`, `last_careunit`)
- link keys to higher grains (`subject_id`, `hadm_id`)

**Why this grain still works:**
- LOS is naturally defined at ICU stay level
- ICU timing provides a clean reference point for leakage-safe windows
- event tables like `icu.chartevents` link cleanly to `stay_id`
- higher-level sources like `hosp.admissions` and `hosp.labevents` can still be brought in safely once they are reduced to the stay grain

---

## 3) Source relationships (core join paths)

The integration relies on three key identifiers:

- `subject_id` (patient)
- `hadm_id` (hospital admission)
- `stay_id` (ICU stay)

For the final v1.1 integration:

### 3.1 ICU stay to admission context
**Join:** `icu.icustays.hadm_id -> hosp.admissions.hadm_id`  
**Join type:** `LEFT JOIN`

**Used for:**
- raw `admission_type` for auditability
- grouped `admission_type_grp` after stay-level context construction

**Why:**
- preserve the ICU stay cohort even if admission context is missing
- keep missingness visible rather than silently dropping stays

### 3.2 ICU stay to vitals event data
**Join path:** `icu.chartevents.stay_id -> icu.icustays.stay_id`

**Important rule:**  
`chartevents` is **not** joined directly into the final modeling table.

It is:
1. filtered to the early window
2. aggregated to one row per stay
3. joined back as a small derived table

**Used for:**
- early vitals summaries
- measurement density
- missingness counts

### 3.3 ICU stay to lab event data
**Join path:** `icu.icustays.hadm_id -> hosp.labevents.hadm_id`

**Important rule:**  
`labevents` is also **not** joined directly into the final modeling table.

It is:
1. filtered to the early window using ICU `intime`
2. mapped to a small candidate concept panel
3. aggregated to one row per stay
4. joined back as a small derived table

**Used for:**
- creatinine features
- WBC features
- hemoglobin features
- lactate features

### 3.4 ICU stay to grouped context features
The grouped context table is materialized separately at the stay grain, then joined back to the anchor table.

**Used for:**
- `admission_type_grp`
- `first_careunit_grp`

This keeps the grouping logic explicit and easier to validate.

---

## 4) Integration pattern used in v1.1

The project uses a safe, staged integration pattern.

### Step A — Construct stay-level event features
From `icu.chartevents`:
- filter to the early window (0–24h from ICU `intime`)
- map selected item IDs to vital concepts
- aggregate measurements into one row per `stay_id`

Output:
- `derived.vitals_24h_by_stay_v1`

From `hosp.labevents`:
- filter to the early window using ICU `intime`
- map selected item IDs to a small lab concept panel
- aggregate to one row per `stay_id`

Output:
- `derived.labs_24h_by_stay_v1_1`

### Step B — Construct grouped context features
From:
- `icu.icustays`
- `hosp.admissions`

Build a separate stay-level context table containing grouped variables.

Output:
- `derived.context_features_by_stay_v1_1`

### Step C — Join small stay-level tables into the final modeling table
Build the final v1.1 modeling table by joining:

- `icu.icustays` (anchor)
- `hosp.admissions` (raw admission context for auditability)
- `derived.vitals_24h_by_stay_v1`
- `derived.labs_24h_by_stay_v1_1`
- `derived.context_features_by_stay_v1_1`

Output:
- `derived.icu_stay_modeling_24h_v1_1`

### Step D — Export modeling artifact
The final modeling table is exported to:

- `data/processed/icu_stay_modeling_24h_v1_1.csv`

---

## 5) Join choices and rationale

### 5.1 Anchor-first integration
All integration begins from the anchor cohort in `icu.icustays`.

This keeps the row contract simple:
- one stay in the anchor table should remain one row in the output table

### 5.2 LEFT JOIN as default
For context and derived-feature tables, `LEFT JOIN` is preferred unless exclusion is intentional and documented.

This keeps missingness visible rather than silently dropping rows.

### 5.3 Aggregate before join for event tables
High-cardinality event tables must be reduced to the stay grain before integration.

That rule applies to:
- `chartevents`
- `labevents`

This is the primary protection against join explosions.

### 5.4 Keep raw and grouped context separate on purpose
The project retains raw context fields for auditability, but the grouped versions are the intended modeling inputs in v1.1.

That split keeps the final dataset easier to debug without forcing the model to rely on sparse raw categories.

---

## 6) Validation and guardrails

### 6.1 Grain integrity
The final modeling table must satisfy:

- `COUNT(*) == COUNT(DISTINCT stay_id)`

This confirms:
- one row per stay
- no duplicate rows from joins

### 6.2 Outcome prevalence sanity
The prolonged LOS label is checked after integration to ensure row duplication has not distorted the target.

### 6.3 Join integrity checks
Core paths should be checked for orphans as needed:
- admissions -> patients
- icustays -> admissions
- chartevents -> icustays
- labevents -> admissions

### 6.4 Cohort preservation
The anchor-first + left-join approach helps ensure that missing context or missing labs do not become accidental row exclusion.

### 6.5 Event-window guardrail
Event tables are filtered to the early window before aggregation. This is the main protection against turning later information into early predictors.

---

## 7) Lineage from source to final artifact

The final v1.1 lineage is:

1. raw source tables in `hosp` and `icu`
2. filtered / aggregated stay-level vitals table  
   -> `derived.vitals_24h_by_stay_v1`
3. filtered / aggregated stay-level labs table  
   -> `derived.labs_24h_by_stay_v1_1`
4. grouped stay-level context table  
   -> `derived.context_features_by_stay_v1_1`
5. final integrated modeling table  
   -> `derived.icu_stay_modeling_24h_v1_1`
6. exported modeling file  
   -> `data/processed/icu_stay_modeling_24h_v1_1.csv`

This versioned naming keeps the data products easy to trace and safe to rebuild.

---

## 8) What is still deferred

The final v1.1 integration is broader than v1, but it is still intentionally not exhaustive.

### 8.1 Diagnoses
`hosp.diagnoses_icd` is still deferred.

**Why:**
- diagnosis timing and availability can be unclear
- coding may reflect post-hoc information
- cohort mapping logic can become subjective

### 8.2 Medications / procedures
Medication and procedure sources are still deferred.

**Why:**
- they risk encoding treatment decisions made after the prediction window
- they require more careful availability assumptions
- they add scope without being necessary for a defensible Assignment 2 result

### 8.3 Larger lab expansion
Only a small lab panel was added in v1.1.

**Why:**
- the goal was a targeted refresh, not a full lab-feature build
- the project needed a better feature mix, not a massive expansion

---

## 9) Reproducibility (how to re-run)

### Scripts of record
- `data/sql/07_construct_vitals_24h_features.sql`
- `data/sql/10_assignment2_feature_audit_v1_1.sql`
- `data/sql/11_construct_labs_24h_features_v1_1.sql`
- `data/sql/12_build_modeling_table_icu_stay_24h_v1_1.sql`

### Minimal replay order
1. run 07 (vitals-by-stay)
2. run 10 if audit refresh needs to be revisited
3. run 11 (labs + grouped context)
4. run 12 (final v1.1 modeling table)
5. validate row count, distinct `stay_id`, and target prevalence
6. export CSV for modeling

---

## 10) Bottom line

The v1.1 integration strategy is still simple by design: start from ICU stays, reduce event tables to the stay grain before joining, preserve the anchor cohort with left joins, and version the derived artifacts clearly. The difference from v1 is that the final pipeline now includes a small early lab panel and grouped context features, which gave the modeling dataset a more balanced and defensible feature mix.
