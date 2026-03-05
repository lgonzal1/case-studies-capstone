# 03 — Construct Data (Feature Engineering Spec) — v1

**Project:** ICU Patient Care Analysis (MIMIC-IV Clinical Database Demo)  
**Phase:** CRISP-DM — Data Preparation (Task 3: Construct Data)  
**Last updated:** 2026-03-04

---

## 1) Purpose

This document specifies the *derived attributes* created for the v1 modeling dataset. It exists so that:
- the feature logic is transparent and reproducible,
- leakage controls are explicit,
- future iterations (v2/v3) can extend features without breaking lineage.

**Core principle:** predictors must reflect information plausibly available early in the ICU stay.  
Therefore, v1 features are engineered using a fixed **0–24 hour window from ICU `intime`**.

---

## 2) Inputs and grain

### 2.1 Source tables
- `icu.icustays`  
  Used for stay anchors and timestamps (`stay_id`, `intime`).

- `icu.chartevents`  
  Used for physiologic measurements (`stay_id`, `itemid`, `charttime`, `valuenum`).

- (Optional lookup / documentation only) `icu.d_items`  
  Used for human-readable item labels when validating itemid choices.

### 2.2 Output grain
All constructed features are aggregated to **ICU stay grain**: one row per `stay_id`.

---

## 3) Leakage control (timing rules)

### 3.1 Prediction window
The feature extraction window is defined as:

- **Start:** `charttime >= icu.icustays.intime`
- **End:** `charttime < icu.icustays.intime + interval '24 hour'`

This is enforced at query time; source tables are not modified.

### 3.2 Why this matters
Many plausible ICU predictors become invalid if they incorporate future information.  
Example: full-stay event counts are partially determined by how long the patient stayed (future), so they leak outcome-related information into predictors. Restricting to an early window prevents this.

---

## 4) Itemid mappings (what counts as each vital)

v1 uses a conservative core-vitals set based on common MIMIC itemids. Multiple itemids are grouped where the same physiologic concept is charted in different ways (e.g., invasive vs non-invasive BP).

> **Important note:** charting conventions vary by unit and workflow. These mappings are intended to be clinically reasonable and stable in the demo cohort. They can be refined later if unit-specific inconsistencies emerge.

### 4.1 Core vitals and itemids

| Vital concept | Variable name | ItemIDs included | Notes |
|---|---|---|---|
| Heart Rate | `HR` | 220045 | Standard HR item |
| Respiratory Rate | `RR` | 220210, 224688, 224689, 224690 | Multiple RR representations |
| Oxygen Saturation | `SpO2` | 220277 | SpO2 |
| Temperature | `Temp` | 223762, 223761 | Temp variants |
| Systolic BP | `SBP` | 220179, 220050, 224167, 227243 | NIBP + arterial/manual variants |
| Diastolic BP | `DBP` | 220180, 220051, 224643, 227242 | NIBP + arterial/manual variants |
| Mean Arterial Pressure | `MAP` | 220181, 220052 | MAP variants |

---

## 5) Constructed feature groups

The v1 feature set has three categories:
1) **Measurement density** (how much was recorded early)
2) **Physiologic summaries** (what the vitals looked like in first 24h)
3) **Missingness indicators** (explicit signal about absent measurements)

All features are built by aggregating `icu.chartevents.valuenum` within the early window.

---

## 6) Measurement density features

### 6.1 Definitions

- `n_chartevents_6h`  
  Count of all `icu.chartevents` rows for the stay where:  
  `intime <= charttime < intime + 6 hours`

- `n_chartevents_24h`  
  Count of all `icu.chartevents` rows for the stay where:  
  `intime <= charttime < intime + 24 hours`

### 6.2 Rationale
In ICU data, measurement frequency is not random:
- higher acuity → more frequent charting,
- workflow differences → more/less recorded data,
- documentation practices can masquerade as physiology.

Rather than pretend this doesn’t exist, v1 captures measurement density explicitly so it can be modeled or at least interpreted.

---

## 7) Physiologic summary features (per vital, within 0–24h)

For each vital concept `X ∈ {HR, RR, SpO2, Temp, SBP, DBP, MAP}`, we compute:

### 7.1 Observation count
- `x_n` = count of observations in window  
  (`COUNT(*)` after filtering to that vital’s itemids and `valuenum IS NOT NULL`)

### 7.2 Simple statistics
- `x_min` = minimum observed value  
- `x_max` = maximum observed value  
- `x_mean` = average observed value

### 7.3 First/last value in window
- `x_first` = value with earliest `charttime` in the window  
- `x_last`  = value with latest `charttime` in the window

**Implementation detail:** `first` and `last` are taken using ordered aggregation on `charttime` (not by row order).

### 7.4 Why these summaries
They are:
- interpretable to clinicians and stakeholders,
- stable in small sample sizes,
- a reasonable early-window representation without excessive feature engineering.

---

## 8) Missingness indicators (explicit, not implied)

To avoid treating “no data” as “normal physiology,” v1 creates explicit missingness flags.

### 8.1 Presence flags
Each is 1 if at least one observation exists in 0–24h, else 0:

- `has_hr_24h`
- `has_rr_24h`
- `has_spo2_24h`
- `has_temp_24h`
- `has_map_24h`

### 8.2 Missing-core-vitals count
- `missing_core_vitals_24h_count`  
  Sum of missing indicators across the core set {HR, RR, SpO2, Temp, MAP}.

### 8.3 Rationale
Missingness can encode workflow/acuity and should be modeled or at least made visible. This feature lets later steps quantify how much of the “signal” is actually absence of measurement.

---

## 9) Output table

### 9.1 Produced table
- `derived.vitals_24h_by_stay_v1`

### 9.2 One-row-per-stay contract
- Primary key: `stay_id`
- Expectation: exactly one row per stay in cohort.

### 9.3 Downstream usage
This table feeds the modeling integration step (`08_build_modeling_table_icu_stay_24h.sql`) to create:
- `derived.icu_stay_modeling_24h_v1`

---

## 10) Data quality / limitations (v1)

### 10.1 Physiologic plausibility checks
v1 does **not** clip or winsorize values. It uses raw `valuenum` within the window.

**Why:** avoid introducing hidden clinical assumptions in v1.  
**Risk:** outliers may exist due to documentation errors or device issues.

**Planned v2:** add light plausibility rules (or outlier flags) per vital.

### 10.2 Unit inconsistencies
Different temperature units or BP charting conventions can exist across units. v1 assumes itemids selected correspond to consistent meaning. If unit conversion issues are observed, handling will be documented in a later revision.

### 10.3 ED/pre-ICU charting artifacts
Some charttimes can occur before ICU `intime` due to ED charting or transfer artifacts. v1 mitigates this by enforcing `charttime >= intime`.

---

## 11) Traceability (how to reproduce)

### Script of record
- `data/sql/07_construct_vitals_24h_features.sql`

### Repro command (concept)
Run script 07, then validate:
- row count = number of stays
- no duplicate stay_id
- expected coverage rates for core vitals

---

## 12) Planned changes (v2 roadmap)
- Add a small, high-value lab panel in 0–24h (coverage-gated).
- Add explicit outlier flags (not automatic deletion) for vitals.
- Consider splitting BP by invasive vs non-invasive if it improves interpretability and stability.

