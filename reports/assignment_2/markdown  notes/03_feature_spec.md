# 03 — Feature Specification (CRISP-DM Data Preparation)

**Project:** ICU Patient Care Analysis (MIMIC-IV Clinical Database Demo)  
**Phase:** CRISP-DM — Data Preparation (Task 3: Construct Data)  
**Last updated:** 2026-03-22

---

## 1) Purpose

This document records the v1 feature engineering strategy for the ICU stay modeling dataset. Its goal is to explain:

- which predictors were constructed,
- how they were derived,
- why they are appropriate for early prediction,
- what was intentionally deferred to later versions.

The emphasis in v1 is interpretability, leakage control, and stable feature construction on a small demo cohort.

---

## 2) Feature engineering design principles

The v1 feature set was built using five rules:

1. **Stay-level grain only**  
   Every feature must resolve cleanly to one row per `stay_id`.

2. **Prediction-time realism**  
   Predictors must come only from the first 24 hours after ICU admission.

3. **Interpretability over complexity**  
   Simple summaries are preferred to opaque or fragile transformations.

4. **Missingness is signal, not just nuisance**  
   Lack of measurement is made explicit rather than silently ignored.

5. **Feasibility first**  
   Use the highest-coverage feature families first, then expand later if justified.

---

## 3) Source data used for feature construction

The v1 feature set is built primarily from:

- `icu.icustays` — anchor timing and stay context
- `icu.chartevents` — early-window measurement data
- `hosp.admissions` — lightweight admission context

The main constructed feature table is:

- `derived.vitals_24h_by_stay_v1`

This table is then joined into the final modeling table.

---

## 4) Prediction window and leakage rule

All event-derived predictors are restricted to:

- `charttime >= intime`
- `charttime < intime + interval '24 hour'`

This is a hard boundary. Features using full-stay information, late-stay accumulation, or post-window treatment history are intentionally excluded from v1.

---

## 5) Outcome variable

### 5.1 Target
The current v1 target is:

- `prolonged_los_8d = 1` if ICU LOS >= 8 days, else 0

### 5.2 Rationale
A prolonged-stay classification target is easier to explain in an operations / QI framing than a purely continuous LOS model, especially given the small demo cohort.

---

## 6) Feature families in v1

### 6.1 Early physiologic summary features
Core vital concepts were mapped from `chartevents` item IDs and summarized within the 24-hour window.

The v1 core set includes:

- Heart rate (HR)
- Respiratory rate (RR)
- SpO2
- Temperature
- Mean arterial pressure (MAP)

For each concept, the following summaries are generated where feasible:

- `first`
- `mean`
- `min`
- `max`
- `last`

Examples:
- `hr_first_24h`
- `hr_mean_24h`
- `hr_min_24h`
- `hr_max_24h`
- `hr_last_24h`

### 6.2 Measurement-density features
These features summarize how much charting occurred early in the stay.

- `n_chartevents_6h`
- `n_chartevents_24h`

**Why they matter:** measurement frequency can reflect acuity, workflow intensity, or attention burden.

### 6.3 Missingness indicators
Instead of treating “not measured” as if it were physiologically normal, the v1 design makes missingness explicit.

Presence flags for core vitals:
- `has_hr_24h`
- `has_rr_24h`
- `has_spo2_24h`
- `has_temp_24h`
- `has_map_24h`

Aggregate missingness feature:
- `missing_core_vitals_24h_count`

### 6.4 Lightweight context features
Small, stable context fields are retained because they may improve baseline signal without adding major integration risk.

Included context variables:
- `first_careunit`
- `last_careunit`
- `admission_type`

---

## 7) Construction logic

### 7.1 Map raw chart items to concepts
Relevant `chartevents.itemid` values are grouped into a small set of clinically meaningful vital concepts.

### 7.2 Filter to early window
Only events in the 0–24 hour window from ICU admission are eligible.

### 7.3 Aggregate to stay level
For each concept and `stay_id`, values are summarized into first/mean/min/max/last statistics.

### 7.4 Compute density and missingness
Counts and flags are generated after the event filtering step, so they describe the same prediction window as the physiologic summaries.

### 7.5 Preserve one-row-per-stay contract
All constructed features must reduce to exactly one record per `stay_id` in the output table.

---

## 8) Why these features were chosen

The v1 feature set is intentionally conservative.

### Strengths
- easy to explain,
- clinically legible,
- robust to small sample sizes,
- aligned with prediction-time availability,
- supports a clear baseline modeling story.

### Why not more features yet
More complex feature families were deferred because they would add integration burden, sparsity, or leakage risk without clearly improving the first-pass assignment deliverable.

Deferred for later versions:
- labs,
- diagnosis-derived features,
- medication/procedure features,
- text data,
- aggressive nonlinear transformations.

---

## 9) Quality notes / limitations

### 9.1 Outliers not aggressively clipped
v1 uses raw measured values within the early window.

**Reason:** avoid embedding hidden clinical assumptions without documenting them carefully.

**Future option:** add explicit plausibility flags rather than silent winsorization.

### 9.2 Missingness is meaningful but imperfect
A missingness flag can reflect both workflow and physiology. It is useful, but it should not be interpreted as purely clinical signal.

### 9.3 Unit consistency assumptions
The selected vital mappings assume item IDs represent comparable concepts. If unit conversion or concept heterogeneity becomes a problem, that should be handled explicitly in a later revision.

---

## 10) Output artifact

### Constructed table
- `derived.vitals_24h_by_stay_v1`

### Downstream consumer
- `derived.icu_stay_modeling_24h_v1`

### Expected row contract
- one row per `stay_id`

---

## 11) Traceability

### Script of record
- `data/sql/07_construct_vitals_24h_features.sql`

### Related artifacts
- `data/processed/icu_stay_modeling_24h_v1.csv`
- `outputs/tables/icu_stay_modeling_24h_v1_schema.csv`

---

## 12) Bottom line

The v1 feature engineering strategy is built around a simple idea: represent each ICU stay using early, interpretable, leakage-safe summaries of core physiology and measurement process. That is enough to support a credible baseline modeling exercise for Assignment 2 without pretending the demo dataset can sustain an exhaustive ICU feature stack.
