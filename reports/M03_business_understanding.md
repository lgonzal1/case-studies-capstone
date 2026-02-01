# Module 3 — Business Understanding Draft (MIMIC-IV Demo ICU Patient Care Analysis)

## 1) Background / Context (project framing)

I am completing a capstone-style case study using the **ICU Patient Care Analysis** option on the **MIMIC-IV Clinical Database Demo** (open-access subset; N≈100 ICU patients). The dataset captures realistic EHR complexity (ICU stays, transfers, vitals, labs, diagnoses, inputs, procedures), but the demo subset is intentionally small and may be sparse for some event tables.

This project is framed with a **quality-improvement (QI)-style** narrative: the goal is to define defensible ICU operational/outcome metrics and explore which *patient subgroups and early clinical signals* are associated with disproportionate resource utilization and worse downstream outcomes (especially **hospital readmission**). The analysis is descriptive and hypothesis-generating (not causal inference).

**Important dataset constraint:** dates are **patient-shifted** for de-identification. This preserves within-encounter **durations/intervals** for each patient, but limits cross-patient “true calendar time” analyses (e.g., real-world demand curves by day-of-week across the cohort).  
[Ref A: MIMIC-IV documentation / date shifting]

### Tables already identified as in-scope (current shortlist)
Hospital / core:
- admissions

ICU / flow:
- icustays
- transfers

Clinical events:
- labevents + d_labitems
- chartevents + d_items
- diagnoses_icd + d_icd_diagnoses
- inputevents
- procedureevents

### Key outcomes I plan to evaluate (initial shortlist)
- **ICU length of stay (ICU LOS):** ICU admit → ICU discharge (stay-level)
- **Prolonged ICU stay:** threshold-based indicator + sensitivity analysis (see Section 6)
- **Hospital readmission:** re-hospitalization within a defined window after discharge (see Section 6)
- Optional if feasible (demo-dependent): in-hospital mortality, transfers/ICU returns, procedure-dependent waits

> Note: Early EDA suggests *non-trivial readmission frequency* even with only ~100 patients, making it a viable outcome for subgroup comparisons (with appropriate caution on small N).

---

## 2) Business Objectives & Success Criteria (QI-style)

### 2.1 Primary business objective (decision-support framing)
Identify which ICU patient subgroups and early clinical signals are associated with:
1) **disproportionately long ICU stays** (including “prolonged ICU stay”), and  
2) **higher risk of hospital readmission**,  
in order to generate operationally-relevant hypotheses (e.g., “which cohorts are slower and why”) that an ICU QI team could investigate in a real setting.

This is a demo dataset, so the deliverable is best framed as:
- defensible **metric definitions** + cohort logic,
- clear **descriptive findings** + subgroup comparisons,
- and (if feasible) simple, interpretable **predictive prototypes** using early-window features (no leakage).

### 2.2 Secondary objectives
- **Define ICU episodes cleanly** using timestamps and transfers (ICU admit → ICU discharge; handling multiple ICU stays per hospital admission).
- **Subgroup / pathway analysis:** test whether outcomes differ across ICU subtypes/cohorts (initial buckets):
  - trauma, neuro, cardiac, sepsis/medical, other
- **Explain the “why” operationally (hypothesis list):** for subgroups with longer stays or more readmissions, explore plausible drivers:
  - procedure waits, ventilation/weaning time, lab-dependent delays (e.g., cultures), high measurement intensity as severity proxy, etc.
- **Validate feasibility:** quantify missingness/sparsity by table and feature family so the analysis stays honest and right-sized.

### 2.3 Quantitative success criteria (class-appropriate)
- Cohort construction and joins are reproducible and validated at the correct grain (`stay_id`, `hadm_id`, `subject_id`).
- ICU LOS distributions are summarized overall and by cohort (with uncertainty shown where possible).
- Readmission rate is computed using a documented operational definition (e.g., 30-day) and reported overall + by cohort.
- Subgroup comparisons are presented with effect sizes and confidence intervals (not just p-values), with clear caveats about statistical power.

### 2.4 Qualitative success criteria
- Clear, defensible definitions that avoid incentive-toxic metrics (explicit assumptions and edge cases).
- Transparent discussion of bias risks (measurement intensity, missing-not-at-random, severity confounding).
- A narrative that would make sense to an ICU leader: what is different across cohorts, what might drive it, and what would be worth investigating operationally.

---

## 3) Stakeholders + “Decisions this informs” (role-play, demo dataset)

### Primary stakeholder
- **ICU Director** (most directly accountable for ICU throughput/outcomes and likely to care about prolonged stays and readmissions)

### Secondary stakeholders
- ICU operations / bed management (capacity, flow)
- Hospital QI leadership (metrics, fairness, definitional defensibility)
- CMO/executive leadership (high-level outcomes, but less detail than ICU Director)

### Decisions this analysis is meant to inform (tightened)
1) **Where to focus QI effort:** which ICU cohorts show the largest burden of prolonged LOS and/or readmission?
2) **What to measure early:** which *early-window* indicators are feasible and potentially predictive of disproportionate resource use or readmission (without leaking future information)?

---

# Task 2 — Assess Situation (CRISP-DM)

## 4) Inventory of Resources
### Data resources
- MIMIC-IV demo tables listed above, plus table dictionaries (`d_*` tables) where available.
- MIMIC documentation for table meanings, key fields, and de-identification constraints.  
[Ref A]

### Compute / workflow resources
- Local repo with version control and a reproducible structure (“show your work”).
- Tooling: pandas-first EDA vs Postgres-first repeatable SQL (decision still open; either is acceptable if documented).

### Domain resources
- ICU QI framing is based on general operational logic; thresholds/definitions will be supported with literature citations rather than personal opinion.  
[Ref B/C/D]

---

## 5) Requirements, Assumptions, Constraints

### Requirements
- Reproducible workflow; raw data not committed to Git; clear “how to run” notes.
- Explicit definitions for any metric dependent on timestamps, cohort mapping, or windows.
- Avoid causal claims; keep inference aligned to what the demo dataset can support.

### Constraints
- Small dataset (N≈100 ICU patients) → limited power for fine-grained subgroup modeling.
- De-identification date shifting → good for within-patient durations; weaker for cross-patient calendar-time utilization claims.
- Potential sparsity in event tables (chartevents/labevents/inputevents/procedureevents), varying by patient and cohort.

### Assumptions (explicit)
- Within-patient timestamp ordering is meaningful enough for interval-based features (durations, early windows).
- Cohort grouping using diagnoses (and possibly procedures) is “good enough” for a first-pass pathway model, but must be validated.
- Measurement frequency is not random; high measurement can proxy severity and may confound associations.

---

## 6) Operational Definitions (outcomes + key terms)

### 6.1 Unit of analysis (candidate)
- Primary: **ICU stay** (`stay_id`) for ICU LOS and early-window features
- Linking: **hospital admission** (`hadm_id`) for readmission logic and discharge timing
- Patient-level: `subject_id` to connect multiple admissions and multiple ICU stays

> [TODO] Finalize which unit drives each section: ICU LOS (stay-level), readmission (admission-level), subgroup (stay-level or admission-level depending on cohort definition).

### 6.2 Hospital readmission (explicit)
**Hospital readmission** will be defined as a *subsequent hospital admission* for the same patient (`subject_id`) that occurs within **X days** after discharge of an index admission (`hadm_id`).  
- Default window: **30-day readmission** (common operational standard)  
- Sensitivity: 7/14/30 days if small-N instability suggests it

Implementation approach:
- Sort admissions by (`subject_id`, `admittime`)
- For each index discharge time, flag whether the next `admittime` occurs within the window
- Report overall rate + cohort-stratified rates

[Ref E: readmission within 30 days is a common operational definition; Ref A/F: admissions fields]

> [TODO] Decide whether to exclude planned readmissions (likely not feasible in demo) and how to treat transfers vs true discharge/re-admit.

### 6.3 Prolonged ICU stay (threshold + sensitivity plan)
“Prolonged ICU stay” does not have a single universal threshold in the literature; definitions vary by population and study design. The plan is:

**Primary operational definition (baseline):**
- Prolonged ICU stay = **ICU LOS ≥ 14 days** (initial working threshold)

**Cohort-aware sensitivity analysis:**
- Trauma/general ICU-like cohorts: test **≥ 7 days** as an alternate threshold
- Neuro/ICH-like cohorts: test **≥ 10 days** as an alternate threshold
- Also test **≥ 14 days** across all cohorts for consistency and comparability

Rationale:
- Studies commonly use thresholds in the **~7–14 day** range, and some context-specific definitions use **~8 days (trauma)** or **~10 days (ICH)**.  
[Ref B/C/D]

> [TODO] Add 1–2 strong citations per cohort threshold and decide whether the “main” threshold should be 14 days overall or cohort-specific.  
> [TODO] Decide whether to include a “very long stay” category (e.g., ≥ 21 or ≥ 28 days) if the demo cohort contains outliers.

---

## 7) Risks + Contingencies
- **Risk: too few cases per subgroup** → collapse buckets (e.g., neuro vs non-neuro) or focus on descriptive stats only.
- **Risk: event-table sparsity** blocks early-window features → fallback to diagnoses/procedures + basic timing features.
- **Risk: measurement bias** (sicker patients have more data) → explicitly report measurement counts; use as covariate or caveat.
- **Risk: leakage** from late-stay signals → enforce hard early-window cutoff (6h/12h/24h from ICU admit) and document.
- **Risk: ambiguous readmissions** (planned vs unplanned) → acknowledge limitation; keep framing as “observed readmission” rather than preventable readmission.

---

# Task 3 — Determine Data Mining Goals (technical translation)

## 8) Data Mining Goals (draft)
Given the unit of analysis and definitions above:

1) Build a reliable ICU stay timeline dataset from admissions + icustays + transfers (correct grain; documented joins).  
2) Quantify outcome distributions:
   - ICU LOS overall + by cohort
   - prolonged ICU LOS indicator (with sensitivity thresholds)
   - hospital readmission rates (default 30-day) overall + by cohort
3) Prototype **early-window** features (6/12/24h post-ICU admit) and test whether they are associated with:
   - prolonged ICU stay
   - hospital readmission

### Data Mining Success Criteria (draft)
- Cohort logic is reproducible and validated.
- Missingness and coverage are summarized for all tables used.
- If modeling is attempted: use simple, interpretable baselines (logistic regression / regularized models), report uncertainty, and treat as exploratory due to N≈100.

---

# Task 4 — Produce Project Plan (high-level)

## 9) Project Plan (draft)
**Module 3 (now):** finalize stakeholders/decisions, operational definitions (readmission + prolonged stay), and assumptions/risks; draft DS goals + plan  
**Module 4–5:** data inventory + missingness; finalize cohort buckets; finalize outcome definitions and unit-of-analysis mapping  
**Module 6–9:** data prep + descriptive subgroup comparisons; attempt simple early-window models if feasible  
**Module 10–13:** evaluation narrative + limitations + “deployment” story (how ICU Director/QI would use this in real practice)  
**Module 14:** final polish, reflection, and portfolio packaging

---

## Notes / What still needs refinement (explicit TODOs)
1) Confirm readmission window (30-day default) and edge cases:
   - planned vs unplanned readmissions (likely not separable)
   - transfers vs discharge/re-admit logic
2) Lock “prolonged ICU stay” threshold strategy:
   - single global threshold vs cohort-specific definitions
   - whether to add “very long stay” category
3) Finalize cohort/pathway mapping:
   - ICD-only vs ICD + procedure signals
   - how many buckets the demo cohort can support without nonsense comparisons
4) Choose workflow:
   - pandas-first vs Postgres-first EDA (either is fine; document rationale)
5) Decide which “why” hypotheses are testable with this demo subset:
   - procedure wait proxies, ventilation proxies, culture/lab delay proxies, etc.


Review
https://www.physionet.org/content/mimiciv/2.0/?utm_source=chatgpt.com
https://www.ejgm.co.uk/download/characteristics-and-outcomes-of-patients-withprolonged-stays-in-an-intensive-care-unit-7323.pdf
https://www.frontiersin.org/journals/medicine/articles/10.3389/fmed.2024.1358205/full
https://eventstreamml.readthedocs.io/en/dev/MIMIC_IV_tutorial/
