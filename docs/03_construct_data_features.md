# 03 — Construct Data (Feature Engineering Spec)

**Project:** ICU Patient Care Analysis (MIMIC-IV Clinical Database Demo)  
**Phase:** CRISP-DM — Data Preparation (Task 3: Construct Data)  
**Last updated:** 2026-03-22

---

## 1) Purpose

This document specifies the derived attributes created for the modeling dataset. It exists so that:
- the feature logic is transparent and reproducible
- leakage controls are explicit
- later iterations can extend features without breaking lineage

The core rule stays the same across v1 and v1.1: predictors should reflect information plausibly available early in the ICU stay.

For that reason, all features in this project are built using a fixed **0–24 hour window from ICU `intime`**.

This file started as the v1 feature spec and now includes the targeted v1.1 refresh that was added later in Assignment 2.

---

## 2) Inputs and grain

### 2.1 Source tables
The feature construction pipeline uses the following sources:

- `icu.icustays`  
  Used for stay anchors, timestamps, ICU context, and the stay-level modeling grain.

- `icu.chartevents`  
  Used for early physiologic measurements and measurement-density features.

- `hosp.admissions`  
  Used for admission context and grouped `admission_type`.

- `hosp.labevents`  
  Used for the small early lab panel added in v1.1.

- `icu.d_items` and `hosp.d_labitems`  
  Used as lookup tables when validating item IDs and concept mappings.

### 2.2 Output grain
All constructed features are aggregated to **ICU stay grain**: one row per `stay_id`.

That is the core rule for this whole project. Raw event tables are never joined directly into the final modeling table.

---

## 3) Leakage control (timing rules)

### 3.1 Prediction window
The feature extraction window is defined as:

- **Start:** event time >= `icu.icustays.intime`
- **End:** event time < `icu.icustays.intime + interval '24 hour'`

For `chartevents`, that means:
- `charttime >= intime`
- `charttime < intime + interval '24 hour'`

For `labevents`, the same logic is applied using the lab event timestamp.

### 3.2 Why this matters
A lot of ICU variables become invalid predictors if they quietly pull in future information.

Example:
- full-stay event counts are partly determined by how long the patient stayed
- late labs can reflect treatment and downstream trajectory
- raw hindsight-ish context can leak how the stay unfolded

Restricting everything to an early window is the main leakage-control rule in this project.

---

## 4) Feature construction strategy

The final feature set ended up with four broad groups:

1. **Measurement density**
2. **Physiologic summary features**
3. **Missingness indicators**
4. **Grouped context and early lab features**

That is still a fairly small feature set by design. The goal here was not to throw every possible ICU variable into the model. The goal was to build something defensible, reproducible, and easy enough to explain.

---

## 5) v1 core vital-sign features

The original v1 feature set was built from early-window vital signs in `icu.chartevents`.

### 5.1 Vital concepts and item IDs
v1 used a conservative core-vitals set based on common MIMIC item IDs. Multiple item IDs were grouped when the same physiologic concept could be charted in more than one way.

| Vital concept | Variable name | ItemIDs included | Notes |
|---|---|---|---|
| Heart Rate | `HR` | 220045 | Standard HR item |
| Respiratory Rate | `RR` | 220210, 224688, 224689, 224690 | Multiple RR representations |
| Oxygen Saturation | `SpO2` | 220277 | SpO2 |
| Temperature | `Temp` | 223762, 223761 | Temp variants |
| Systolic BP | `SBP` | 220179, 220050, 224167, 227243 | NIBP + arterial/manual variants |
| Diastolic BP | `DBP` | 220180, 220051, 224643, 227242 | NIBP + arterial/manual variants |
| Mean Arterial Pressure | `MAP` | 220181, 220052 | MAP variants |

### 5.2 Measurement density features
The v1 dataset included explicit measurement-density features:

- `n_chartevents_6h`
- `n_chartevents_24h`

These were kept on purpose. In ICU data, how often something gets measured is part of the real signal, even if it reflects workflow and acuity as much as physiology.

### 5.3 Physiologic summary features
For each vital concept in the early window, the project computed summary features such as:

- count
- min
- max
- mean
- first
- last

These were chosen because they are:
- easy to explain
- stable in a small cohort
- more defensible than overengineered time-series features for a capstone like this

### 5.4 Missingness indicators
The v1 dataset also included explicit missingness features rather than pretending missingness was harmless:

- `has_hr_24h`
- `has_rr_24h`
- `has_spo2_24h`
- `has_temp_24h`
- `has_map_24h`
- `missing_core_vitals_24h_count`

That made the dataset more honest and gave the model a way to learn from systematic absence of measurement if it was present.

---

## 6) v1.1 grouped context features

After the first final-model pass, we stepped back and did a targeted feature audit. That led to a small v1.1 refresh rather than a full rebuild.

One part of that refresh was grouped context features.

### 6.1 Why grouped context was added
The raw context fields existed already, but they were either too sparse or too messy to use directly as clean modeling inputs in a small cohort.

So instead of pretending the raw fields were ideal, we grouped them into more stable categories.

### 6.2 Added grouped context features
The v1.1 refresh added:

- `admission_type_grp`
- `first_careunit_grp`

These are the intended context predictors in the final v1.1 modeling dataset.

The raw fields:
- `admission_type`
- `first_careunit`
- `last_careunit`

were retained for auditability, but they are not the preferred predictor layer.

### 6.3 Why this helped
This made the feature set easier to defend because:
- the categories were more stable
- the model did not have to learn from tiny sparse groups
- the context story became more operationally meaningful

---

## 7) v1.1 early lab features

The second part of the v1.1 refresh was a small 24-hour lab panel.

### 7.1 Why labs were added
In the first final-model pass, the model was leaning heavily on charting-intensity features. That is not automatically wrong, but it made the story thinner than we wanted.

The audit showed that a small number of early labs had strong enough coverage to justify adding them without turning the project into a huge feature expansion.

### 7.2 Lab concepts added
The final v1.1 lab panel was:

- creatinine
- WBC
- hemoglobin
- lactate

### 7.3 Construction logic
Labs were:
1. filtered to the same 0–24h window from ICU `intime`
2. mapped to a small concept panel
3. aggregated to one row per `stay_id`

### 7.4 Lab summary features added
For **creatinine**, **WBC**, and **hemoglobin**:
- `*_first_24h`
- `*_mean_24h`
- `has_*_24h`

For **lactate**:
- `lactate_first_24h`
- `lactate_max_24h`
- `has_lactate_24h`

### 7.5 Why this summary set was chosen
The audit showed that these labs were often repeated in the first 24 hours, so a single first value was not always enough. At the same time, there was no need to go overboard.

So the final choice was intentionally modest:
- first + mean for the more routine repeated labs
- first + max for lactate
- explicit presence flags for all of them

That gave the model a better feature mix without making the dataset much harder to explain.

---

## 8) Final derived tables used in feature construction

The final constructed-feature layer includes:

### 8.1 v1 vitals feature table
- `derived.vitals_24h_by_stay_v1`

This table contains the stay-level early-window vitals, density features, and missingness indicators.

### 8.2 v1.1 lab feature table
- `derived.labs_24h_by_stay_v1_1`

This table contains the small early lab panel summarized to stay level.

### 8.3 v1.1 grouped context table
- `derived.context_features_by_stay_v1_1`

This table contains the grouped context variables summarized at the stay level.

These are then joined into the final modeling table rather than rebuilding features directly inside the modeling notebook.

---

## 9) Output table and downstream use

### 9.1 Final modeling artifact
The final modeling artifact used in Assignment 2 is:

- `derived.icu_stay_modeling_24h_v1_1`

### 9.2 Export used for modeling
- `data/processed/icu_stay_modeling_24h_v1_1.csv`

### 9.3 One-row-per-stay contract
The final expectation remains:
- one row per `stay_id`
- no duplicate `stay_id` rows

That is the key integrity rule for downstream modeling.

---

## 10) Data quality / limitations

### 10.1 Raw values were not aggressively cleaned away
The project did not clip or winsorize numeric values in v1 or v1.1.

That was a deliberate choice. We did not want to quietly inject hidden clinical assumptions into the first serious pass of the project.

### 10.2 Measurement behavior is part of the signal
Features like `n_chartevents_24h` are meaningful, but they are not purely physiologic. They partly reflect acuity, workflow, and documentation intensity.

That is fine as long as the report is honest about it.

### 10.3 The lab panel is intentionally small
We did not try to build a giant lab feature set. The v1.1 refresh was targeted and coverage-driven.

### 10.4 Small cohort still limits what the feature set can do
The feature refresh improved the balance of the model inputs, but it did not change the fact that this is still a small demo cohort. Any interpretation still needs to stay conservative.

---

## 11) Traceability (how to reproduce)

### Scripts of record
- `data/sql/07_construct_vitals_24h_features.sql`
- `data/sql/10_assignment2_feature_audit_v1_1.sql`
- `data/sql/11_construct_labs_24h_features_v1_1.sql`
- `data/sql/12_build_modeling_table_icu_stay_24h_v1_1.sql`

### Repro flow
1. build stay-level vitals features  
2. run the targeted audit if needed  
3. build stay-level labs + grouped context features  
4. build the final v1.1 modeling table  
5. export the final CSV for modeling  

---

## 12) Bottom line

The final feature engineering strategy stayed pretty simple on purpose. We started with early-window vitals, density, and missingness features, then added a targeted v1.1 refresh with grouped context and a small lab panel when the first final-model pass showed the feature mix needed help.

That gave us a final dataset that was still easy to explain, still leakage-aware, and more balanced than the original v1 feature set.
