# 05 — Format Data Notes (CRISP-DM Data Preparation)

**Project:** ICU Patient Care Analysis (MIMIC-IV Clinical Database Demo)  
**Phase:** CRISP-DM — Data Preparation (Task 5: Format Data)  
**Last updated:** 2026-03-22

---

## 1) Purpose

This document records how the final v1 modeling dataset is structured for downstream analysis and how it should be used safely during modeling.

Formatting, in this project, means more than file export. It includes:

- the row contract,
- column roles,
- type expectations,
- missingness conventions,
- what remains in the modeling table for audit/debugging,
- what should happen later inside the model pipeline.

---

## 2) Final dataset artifact

### Primary prepared dataset
- `derived.icu_stay_modeling_24h_v1`

### Exported file
- `data/processed/icu_stay_modeling_24h_v1.csv`

This is the main dataset intended for Assignment 2 modeling work.

---

## 3) Row contract

### Unit of analysis
- one row per ICU stay (`stay_id`)

### Expected integrity condition
- `COUNT(*) == COUNT(DISTINCT stay_id)`

Verified in v1:
- 140 rows
- 140 distinct stays

This row contract is the core formatting rule for the dataset.

---

## 4) Column-role design

The dataset intentionally mixes three kinds of columns, but they should not all be treated the same way during modeling.

### 4.1 Target column
Primary target:
- `prolonged_los_8d`

Derived from ICU LOS and used for binary classification.

### 4.2 Predictor columns
These include the actual model-input candidates, such as:

- early-window vital summaries,
- measurement-density features,
- missingness counts / flags,
- lightweight context variables (for example `admission_type`, `first_careunit`).

### 4.3 Audit-only / lineage columns
These are retained in the table for validation, debugging, and traceability, but should generally be dropped before fitting the final model.

Examples:
- `stay_id`
- `subject_id`
- `hadm_id`
- `intime`
- `outtime`
- `los_days`
- any raw identifiers not meant as predictors

This split helps the table remain auditable without encouraging leakage or identifier-based fitting.

---

## 5) Type expectations

Because the source system was loaded quickly as text, formatting includes establishing clear downstream type expectations.

### 5.1 Key identifiers
Expected as integer-like fields:
- `stay_id`
- `hadm_id`
- `subject_id`

### 5.2 Timestamps
Expected as datetime/timestamp-like fields:
- `intime`
- `outtime`

### 5.3 Numeric predictors
Expected as numeric:
- vital summaries
- event counts
- missingness counts
- LOS-derived audit measures

### 5.4 Categorical predictors
Expected as categorical/string:
- `admission_type`
- `first_careunit`
- `last_careunit`

These should later be encoded inside the modeling pipeline rather than manually one-hot encoded in the raw export.

---

## 6) Missingness conventions

### 6.1 Preserve missing values in the prepared dataset
The exported dataset is not meant to hide missingness by aggressive pre-imputation.

### 6.2 Make missingness explicit
Where possible, missingness is already represented through:

- presence flags,
- missing-core-vitals counts,
- event-density features.

### 6.3 Defer learned imputation to the model pipeline
If imputation is used, it should be fit on training data only, not on the full dataset before splitting.

This is a key methodological rule for Assignment 2.

---

## 7) Formatting choices made in v1

### 7.1 Keep auditability in the exported table
The dataset retains enough lineage fields to make debugging and report validation easier.

### 7.2 Do not over-format too early
The CSV is not treated as a fully “final ML matrix” with all preprocessing baked in. It is a prepared analytical dataset that still expects modeling-pipeline steps later.

### 7.3 Keep versioned naming explicit
Versioned names reduce confusion and protect the report from notebook drift.

Examples:
- `derived.vitals_24h_by_stay_v1`
- `derived.icu_stay_modeling_24h_v1`
- `icu_stay_modeling_24h_v1.csv`

---

## 8) Safe handoff into modeling

The correct modeling handoff for v1 is:

1. load the exported prepared dataset
2. separate target, predictors, and audit-only fields
3. perform train / validation / test splitting
4. fit any learned preprocessing on training data only
5. evaluate on held-out data

This matters because formatting choices should support valid modeling, not accidentally bake in leakage.

---

## 9) Related artifact support

Related outputs already in the repo include:
- `outputs/tables/icu_stay_modeling_24h_v1_schema.csv`
- model metric tables
- coefficients / importance outputs
- held-out prediction tables

These help keep the final report tied to stable exported artifacts.

---

## 10) Bottom line

The v1 formatting strategy is designed to make the prepared dataset usable, auditable, and safe for downstream modeling. The exported table is intentionally not the final fully preprocessed machine-learning matrix. Instead, it is a stable stay-level analytical dataset with explicit column roles and enough lineage to support both the Assignment 2 report and the final modeling workflow cleanly.
