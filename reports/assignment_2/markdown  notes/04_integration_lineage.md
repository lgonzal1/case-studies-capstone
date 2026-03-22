# 04 — Integration and Lineage Notes (CRISP-DM Data Preparation)

**Project:** ICU Patient Care Analysis (MIMIC-IV Clinical Database Demo)  
**Phase:** CRISP-DM — Data Preparation (Task 4: Integrate Data)  
**Last updated:** 2026-03-22

---

## 1) Purpose

This document records how multiple source tables are combined into a single modeling-ready dataset. It focuses on:

- the unit of analysis,
- join paths and join types,
- safeguards against row duplication,
- the lineage from raw tables to derived outputs,
- what was deferred from v1 and why.

Integration is one of the easiest places for a healthcare data project to go wrong, so this step is documented explicitly.

---

## 2) Modeling grain (anchor decision)

### v1 unit of analysis
- ICU stay (`stay_id`)

### Anchor table
- `icu.icustays`

This table supplies:
- the modeling entity (`stay_id`)
- ICU timing (`intime`, `outtime`)
- ICU LOS (`los`)
- ICU context (`first_careunit`, `last_careunit`)
- linkage keys (`subject_id`, `hadm_id`)

### Why this grain works
- LOS is naturally defined at the ICU stay level
- the early prediction window can be anchored directly to ICU `intime`
- `chartevents` can be linked cleanly to the stay level before aggregation

---

## 3) Core source relationships

The v1 pipeline relies on three identifiers:

- `subject_id` — patient grain
- `hadm_id` — hospital admission grain
- `stay_id` — ICU stay grain

### 3.1 ICU stay to admission context
Join path:
- `icu.icustays.hadm_id -> hosp.admissions.hadm_id`

Used for:
- `admission_type`

Default join type:
- `LEFT JOIN`

**Why:** preserve the ICU stay cohort even if some upstream context were missing.

### 3.2 ICU stay to event data
Join path:
- `icu.chartevents.stay_id -> icu.icustays.stay_id`

Important rule:
- `chartevents` is **not** joined directly into the final modeling table.
- It is aggregated first to stay level, then joined as a small derived table.

This is the primary protection against row explosion.

---

## 4) Integration pattern used in v1

### Step A — Construct stay-level event features
From `icu.chartevents`:

- filter to the first 24 hours after ICU admission,
- map selected item IDs to core vital concepts,
- aggregate measurements into one row per `stay_id`.

Output:
- `derived.vitals_24h_by_stay_v1`

### Step B — Join stay-level sources into the final modeling table
The final v1 modeling table is built by joining:

- `icu.icustays` (anchor)
- `hosp.admissions` (lightweight context)
- `derived.vitals_24h_by_stay_v1` (constructed predictors)

Output:
- `derived.icu_stay_modeling_24h_v1`

### Step C — Export modeling artifact
The final modeling table is exported to:

- `data/processed/icu_stay_modeling_24h_v1.csv`

---

## 5) Join choices and rationale

### 5.1 Anchor-first integration
All integration begins from the anchor cohort in `icu.icustays`.

This keeps the row contract simple:
- one stay in the anchor table should remain one row in the output table.

### 5.2 LEFT JOIN as default
For context and derived-feature tables, `LEFT JOIN` is preferred unless exclusion is intentional and documented.

This keeps missingness visible rather than silently dropping rows.

### 5.3 Aggregate before join for event tables
High-cardinality event tables must be reduced to the stay grain before integration.

That rule applies to:
- `chartevents` in v1
- likely `labevents` in any later v2 expansion

---

## 6) Validation and guardrails

### 6.1 Grain integrity
The final modeling table must satisfy:

- `COUNT(*) == COUNT(DISTINCT stay_id)`

Verified in v1:
- 140 rows
- 140 distinct stays

### 6.2 Outcome prevalence sanity
The prolonged LOS label was checked after integration to ensure row duplication had not distorted the target.

Verified in v1:
- 16 prolonged stays out of 140 total

### 6.3 Join integrity checks
Core join paths were checked for orphans before finalizing the v1 table.

### 6.4 Cohort preservation
The anchor-first + left-join approach helps ensure that missing context does not become accidental row exclusion.

---

## 7) Lineage from source to final artifact

The v1 lineage is:

1. raw source tables in `hosp` and `icu`
2. filtered / aggregated stay-level vitals table  
   -> `derived.vitals_24h_by_stay_v1`
3. final integrated modeling table  
   -> `derived.icu_stay_modeling_24h_v1`
4. exported modeling file  
   -> `data/processed/icu_stay_modeling_24h_v1.csv`

This versioned naming keeps the data products easy to trace and safe to rebuild.

---

## 8) What was deferred from v1

### 8.1 Labs
`hosp.labevents` was deferred because it is high-cardinality, linked at the admission level, and requires additional temporal alignment decisions before safe stay-level integration.

### 8.2 Diagnoses
`hosp.diagnoses_icd` was deferred because diagnosis timing and availability can blur the line between early prediction and post-hoc knowledge.

### 8.3 Medications / procedures
Medication and procedure tables were deferred because they risk encoding treatment decisions made after the prediction window and would require more careful availability assumptions.

These sources may be reasonable later, but they were not necessary to build a valid v1 baseline dataset.

---

## 9) Reproducibility

### Scripts of record
- `data/sql/07_construct_vitals_24h_features.sql`
- `data/sql/08_build_modeling_table_icu_stay_24h.sql`
- `data/sql/09_report_tables_assignment1.sql`

### Minimal replay order
1. Run script 07  
2. Run script 08  
3. Validate row count, distinct `stay_id`, and label prevalence  
4. Export the processed CSV

---

## 10) Bottom line

The v1 integration strategy is deliberately simple and safe: start from ICU stays, reduce event tables to the same grain before joining, preserve the anchor cohort with left joins, and version the derived artifacts clearly. That keeps the final modeling table interpretable, reproducible, and far less vulnerable to the silent row-multiplication problems that often derail healthcare data projects.
