# 02 — Decision Log

**Project:** ICU Patient Care Analysis (MIMIC-IV Clinical Database Demo)  
**Purpose:** Track major project decisions, why they were made, tradeoffs accepted, and what would change the decision later.  
**Last updated:** 2026-03-22

---

## D001 — Use MIMIC-IV Clinical Database Demo as the project dataset
- **Date:** 2026-01-20
- **Decision:** Use the MIMIC-IV Clinical Database Demo subset for the capstone project rather than searching for a new dataset.
- **Rationale:**
  - The course emphasizes process and defensible methodology more than scale.
  - MIMIC-IV is widely used, clinically meaningful, and supports multiple data science problem types.
  - The demo version is small enough to work with quickly while still preserving realistic schema complexity.
- **Tradeoffs / risks:**
  - Very limited sample size.
  - Results will need to be framed conservatively.
- **Implications:**
  - The project should focus on methodological clarity and reproducibility rather than production-level performance.
- **What would change our mind:**
  - A dataset-level validity issue that made the demo cohort unusable for the chosen question.

---

## D002 — Frame the project around ICU prolonged length of stay
- **Date:** 2026-01-20
- **Decision:** Focus the project on predicting prolonged ICU length of stay rather than mortality, readmission, or another outcome.
- **Rationale:**
  - Prolonged ICU stay is operationally meaningful for capacity, bed utilization, and throughput.
  - It supports a clear quality-improvement framing instead of a purely academic one.
  - It is easier to explain to leadership than a more abstract score.
- **Tradeoffs / risks:**
  - Length of stay is influenced by both clinical severity and operational factors.
  - Any model will be associative, not causal.
- **Implications:**
  - The project should be written as an early operational risk-identification problem, not a causal inference project.
- **What would change our mind:**
  - Evidence that the chosen outcome was too unstable or not meaningful in the available cohort.

---

## D003 — Use ICU stay (`stay_id`) as the unit of analysis
- **Date:** 2026-01-21
- **Decision:** Use ICU stay as the modeling grain.
- **Rationale:**
  - ICU LOS is naturally defined at the stay level.
  - ICU `intime` gives a clean anchor for leakage-safe early windows.
  - `chartevents` links cleanly to `stay_id`.
- **Tradeoffs / risks:**
  - Some other useful sources are keyed at `hadm_id`, so extra integration work is needed.
- **Implications:**
  - All event tables must be reduced to one row per `stay_id` before joining into the final modeling table.
- **What would change our mind:**
  - Evidence that another grain was clearly better aligned to the outcome and source relationships.

---

## D004 — Treat ICU `intime` as the anchor for the prediction window
- **Date:** 2026-01-21
- **Decision:** Define the early prediction window relative to ICU `intime`.
- **Rationale:**
  - This is the cleanest point in the data to anchor the question.
  - It supports a stay-level, leakage-aware design.
- **Tradeoffs / risks:**
  - Some clinically useful information may exist before ICU arrival and not be captured.
- **Implications:**
  - Early-window features are defined relative to ICU admission, not the full hospital encounter.
- **What would change our mind:**
  - A strong reason to redefine the prediction question around admission-to-hospital rather than ICU entry.

---

## D005 — Restrict predictors to the first 24 hours after ICU admission
- **Date:** 2026-01-22
- **Decision:** Use a 0–24h feature window for predictors.
- **Rationale:**
  - This keeps the model grounded in an early-risk use case.
  - It is easier to defend than full-stay features.
  - It reduces the chance of post-outcome leakage.
- **Tradeoffs / risks:**
  - Some useful later information is intentionally left out.
- **Implications:**
  - Any feature not clearly available in the first 24 hours should be excluded from the predictor set.
- **What would change our mind:**
  - A different project framing that explicitly wanted later prediction timepoints.

---

## D006 — Start with early-window vitals from `icu.chartevents`
- **Date:** 2026-01-23
- **Decision:** Build the first-pass feature set from early-window vital signs in `icu.chartevents`.
- **Rationale:**
  - Core vitals are dense, clinically interpretable, and available early.
  - This creates a feasible baseline dataset without reopening the whole schema.
- **Tradeoffs / risks:**
  - Measurement behavior can reflect workflow and acuity, not just physiology.
- **Implications:**
  - Include both physiologic summaries and explicit density / missingness features.
- **What would change our mind:**
  - Evidence that chartevents-based features were too sparse or too unstable to support a usable model.

---

## D007 — Keep measurement density and missingness explicit
- **Date:** 2026-01-23
- **Decision:** Include `n_chartevents_6h`, `n_chartevents_24h`, and missing-core-vitals features instead of pretending missingness is ignorable.
- **Rationale:**
  - In ICU data, missingness is often systematic.
  - Measurement frequency is part of the operational story.
- **Tradeoffs / risks:**
  - These features can reflect workflow intensity rather than underlying physiology.
- **Implications:**
  - The report should acknowledge that some signal may come from measurement behavior, not just patient state.
- **What would change our mind:**
  - Evidence that these features were overwhelming the model in a way that made the final result unusable.

---

## D008 — Keep source tables raw-ish; build prepared tables under `derived`
- **Date:** 2026-01-24
- **Decision:** Do not mutate source schemas for convenience. Build cleaned / constructed artifacts in a separate `derived` schema.
- **Rationale:**
  - Preserves provenance.
  - Makes lineage and rebuilds easier to explain.
- **Tradeoffs / risks:**
  - Requires more explicit casting / cleaning logic in SQL.
- **Implications:**
  - Versioned derived tables become the source of truth for modeling.
- **What would change our mind:**
  - A typed re-ingestion plan that replaced the current quick-load setup.

---

## D009 — Use one-row-per-stay derived tables as the integration pattern
- **Date:** 2026-01-24
- **Decision:** Aggregate event tables to stay level first, then join them into the final modeling table.
- **Rationale:**
  - Prevents join explosions.
  - Keeps the row contract simple and testable.
- **Tradeoffs / risks:**
  - Requires deliberate feature construction instead of quick direct joins.
- **Implications:**
  - Event tables are never joined directly into the modeling table.
- **What would change our mind:**
  - Nothing likely; this is a core design rule for the project.

---

## D010 — Keep the initial model set small
- **Date:** 2026-02-01
- **Decision:** Plan to compare a meaningful baseline, logistic regression, and one flexible nonlinear model rather than a larger algorithm sweep.
- **Rationale:**
  - The assignment rewards a defensible workflow, not algorithm shopping.
  - The dataset is too small to justify a zoo of models.
- **Tradeoffs / risks:**
  - Some potentially useful model families are left unexplored.
- **Implications:**
  - Model comparison should stay disciplined and easy to explain.
- **What would change our mind:**
  - Evidence that the chosen model set was clearly insufficient to answer the project question.

---

## D011 — Keep preprocessing inside the modeling pipeline
- **Date:** 2026-02-05
- **Decision:** Fit imputation, scaling, and encoding steps on training data only inside the modeling workflow.
- **Rationale:**
  - Prevents leakage.
  - Matches good modeling practice and course expectations.
- **Tradeoffs / risks:**
  - Slightly more setup in notebooks / scripts.
- **Implications:**
  - The CSV export is a prepared analytical dataset, not a fully preprocessed ML matrix.
- **What would change our mind:**
  - Nothing likely; this is a methodological guardrail.

---

## D012 — Keep audit-only columns in the prepared dataset
- **Date:** 2026-02-05
- **Decision:** Retain identifiers, timings, and raw LOS fields in the prepared table for auditability, but drop them before training.
- **Rationale:**
  - Makes debugging, validation, and report QA easier.
- **Tradeoffs / risks:**
  - Requires discipline so those fields are not accidentally used as predictors.
- **Implications:**
  - The modeling notebook must explicitly separate predictors from audit-only fields.
- **What would change our mind:**
  - A simpler workflow that still preserved traceability equally well.

---

## D013 — Use a baseline before interpreting any model as useful
- **Date:** 2026-02-06
- **Decision:** Include a majority-class baseline in the final comparison.
- **Rationale:**
  - Prevents overclaiming.
  - Makes it obvious why raw accuracy is not enough.
- **Tradeoffs / risks:**
  - None worth noting; this is basic discipline.
- **Implications:**
  - The final comparison must show the baseline explicitly.
- **What would change our mind:**
  - Nothing likely.

---

## D014 — Use grouped patient-aware splitting if repeated patients exist
- **Date:** 2026-02-10
- **Decision:** Keep related records together at the subject level during final train/test splitting and grouped CV if repeated stays exist.
- **Rationale:**
  - Prevents the same patient from leaking across train and evaluation.
  - Better matches how real hospital BI work should be handled.
- **Tradeoffs / risks:**
  - Makes splitting slightly more complicated.
- **Implications:**
  - `subject_id` must be retained for grouping even if dropped from predictors.
- **What would change our mind:**
  - Evidence that repeated patients were not materially present in the cohort.

---

## D015 — Materialize reproducible derived tables in `derived` schema + normalize key types to INT
- **Date:** 2026-02-22
- **Decision:** Materialize feature and modeling datasets as versioned tables in a dedicated schema:
  - `derived.vitals_24h_by_stay_v1`
  - `derived.icu_stay_modeling_24h_v1`

  Normalize key fields to INT in derived tables due to text-loaded source tables.
- **Rationale:**
  - Reproducibility: running the SQL pipeline produces the same artifacts deterministically.
  - Auditability: derived tables provide a stable reference for figures/tables in the report and reduce notebook drift.
  - Practical constraint: source tables were ingested as TEXT for speed; casting/normalization prevents join errors.
- **Tradeoffs / risks:**
  - Derived tables can go stale if scripts change but tables are not rebuilt.
  - Type casting can mask upstream ingestion issues if it is not documented clearly.
- **Implications:**
  - Rebuild order matters and must be documented.
  - Export artifact for downstream work: `data/processed/icu_stay_modeling_24h_v1.csv`
- **What would change our mind:**
  - A typed ingestion rebuild that replaced the current quick-load design.

---

## D016 — Define prolonged ICU stay as LOS ≥ 8 days
- **Date:** 2026-02-25
- **Decision:** Define prolonged ICU length of stay as **ICU LOS ≥ 8 days**.
- **Rationale:**
  - A binary prolonged-stay outcome is operationally interpretable for ICU leadership.
  - The literature review supported a one-week style threshold as a practical operational cutoff.
  - The demo cohort supported this definition with workable prevalence (**16/140 = 11.4%**).
- **Tradeoffs / risks:**
  - Thresholds vary across clinical literature and local practice.
  - This is a pragmatic operational threshold, not a universal clinical law.
- **Implications:**
  - The model is framed as early classification, not exact LOS prediction.
- **What would change our mind:**
  - Strong stakeholder input in a real hospital setting that defined prolonged stay differently, or clear instability in this cohort.

---

## D017 — Keep the initial Assignment 2 data scope stable unless a real methodology defect is found
- **Date:** 2026-02-27
- **Decision:** Treat the original v1 stay-level prepared dataset and Section 1 artifact set as the authoritative basis for Assignment 2 unless a genuine methodological problem is discovered.
- **Rationale:**
  - The project already had a stable grain, a documented leakage rule, a derived modeling table, and draft documentation covering selection, cleaning, construction, integration, and formatting.
  - At that stage, the highest-value work was alignment and defensibility, not scope expansion.
- **Tradeoffs / risks:**
  - A stable v1 scope leaves potentially useful sources on the table.
- **Implications:**
  - New feature families should only be added if they solve a clearly documented problem, not just to make the project look fancier.
- **What would change our mind:**
  - Evidence of leakage, broken split logic, grain corruption, or another issue that materially threatened validity.

---

## D018 — Treat Assignment 2 as a binary early-risk classification problem
- **Date:** 2026-02-27
- **Decision:** Frame Assignment 2 as binary classification: predict whether an ICU stay will become a prolonged ICU stay using information available in the first 24 hours after ICU admission.
- **Rationale:**
  - Easier to explain than continuous LOS modeling.
  - Better fit to an operational risk-identification use case.
- **Tradeoffs / risks:**
  - Thresholding loses some information compared with continuous prediction.
- **Implications:**
  - The report should stay focused on early risk flagging, not exact LOS estimation.
- **What would change our mind:**
  - A future project with enough data and stakeholder need for a regression-style outcome.

---

## D019 — Freeze the final model set at baseline + logistic regression + random forest
- **Date:** 2026-03-21
- **Decision:** Use the following as the official final comparison set:
  - majority-class baseline
  - logistic regression
  - random forest
- **Rationale:**
  - This is enough to answer the assignment question cleanly.
  - Logistic regression gives the interpretable benchmark.
  - Random forest provides a fair nonlinear comparison.
- **Tradeoffs / risks:**
  - More complex models are intentionally left out.
- **Implications:**
  - The report should explain that the portfolio was intentionally small and practical.
- **What would change our mind:**
  - Strong evidence that the chosen set was not enough to answer the question.

---

## D020 — Treat the first final-model run as a real checkpoint, not something to handwave
- **Date:** 2026-03-22
- **Decision:** When the first final-model pass produced zero positive predictions at the default threshold, treat that as a methodological issue to investigate rather than just a caveat to write around.
- **Rationale:**
  - The point of the capstone is not just to produce output. It is to show disciplined method.
  - A model can have ranking signal and still look useless at an unhelpful threshold.
- **Tradeoffs / risks:**
  - This added work late in the assignment.
- **Implications:**
  - The workflow needed one more corrective pass before freezing results.
- **What would change our mind:**
  - Nothing likely; this was the right call once the issue surfaced.

---

## D021 — Tune classification thresholds using training-only out-of-fold predictions
- **Date:** 2026-03-22
- **Decision:** Treat threshold choice as part of the modeling workflow and tune the final threshold using training-only out-of-fold predictions.
- **Rationale:**
  - The default `0.5` threshold was too conservative for the held-out split.
  - Threshold choice is operational, not sacred.
  - Training-only threshold tuning keeps the held-out test honest.
- **Tradeoffs / risks:**
  - Adds one more modeling step to explain.
- **Implications:**
  - Final selected thresholds became part of the frozen workflow.
  - Logistic regression threshold: **0.52**
  - Random forest threshold: **0.18**
- **What would change our mind:**
  - A different use case where thresholding was determined externally by stakeholders before modeling.

---

## D022 — Run a targeted feature audit instead of pretending v1 was final
- **Date:** 2026-03-22
- **Decision:** Step back and audit the existing features before rerunning the final comparison.
- **Rationale:**
  - `n_chartevents_24h` was dominating the model story.
  - That was not necessarily wrong, but it meant the feature mix needed a closer look.
- **Tradeoffs / risks:**
  - Added one more iteration late in the process.
- **Implications:**
  - A targeted audit script was created and used to decide whether a small refresh was justified.
- **What would change our mind:**
  - Audit results showing that no small refresh would meaningfully improve the feature mix.

---

## D023 — Approve a targeted v1.1 feature refresh
- **Date:** 2026-03-22
- **Decision:** Approve a small v1.1 refresh rather than a full project rebuild.
- **What was added:**
  - grouped `admission_type`
  - grouped `first_careunit`
  - a small early lab panel:
    - creatinine
    - WBC
    - hemoglobin
    - lactate
- **Rationale:**
  - The audit showed these additions were feasible and well-covered enough to justify.
  - The refresh improved the feature mix without blowing up scope.
- **Tradeoffs / risks:**
  - More SQL and another modeling rerun.
- **Implications:**
  - New derived artifacts were needed:
    - `derived.labs_24h_by_stay_v1_1`
    - `derived.context_features_by_stay_v1_1`
    - `derived.icu_stay_modeling_24h_v1_1`
    - `data/processed/icu_stay_modeling_24h_v1_1.csv`
- **What would change our mind:**
  - Evidence that the added features were too sparse or too unstable to help.

---

## D024 — Keep grouped context as the intended predictor layer in v1.1
- **Date:** 2026-03-22
- **Decision:** Keep raw `admission_type` and `first_careunit` in the table for auditability, but use grouped versions as the intended modeling predictors.
- **Rationale:**
  - Grouped versions are more stable in a small cohort.
  - Raw versions are still useful for debugging and lineage.
- **Tradeoffs / risks:**
  - Slightly more documentation burden because both raw and grouped fields exist.
- **Implications:**
  - Raw context fields become audit-only.
  - Grouped context fields become the preferred predictors.
- **What would change our mind:**
  - A much larger cohort where the raw categories were stable enough to keep.

---

## D025 — Freeze the final prepared dataset at v1.1
- **Date:** 2026-03-22
- **Decision:** Use `icu_stay_modeling_24h_v1_1.csv` as the final Assignment 2 modeling dataset.
- **Rationale:**
  - It reflects the targeted refresh and corrected workflow.
  - It gives a more balanced feature mix than v1.
- **Tradeoffs / risks:**
  - Requires keeping v1 and v1.1 lineage clear.
- **Implications:**
  - Final notebooks and report text should refer to v1.1 as the final prepared dataset.
- **What would change our mind:**
  - Discovery of a submission-level defect in the v1.1 rebuild.

---

## D026 — Recommend logistic regression as the final model
- **Date:** 2026-03-22
- **Decision:** Recommend **logistic regression** as the final model for Assignment 2.
- **Rationale:**
  - Logistic regression had the stronger overall case once we looked at:
    - held-out discrimination
    - grouped cross-validation performance
    - interpretability
    - operational fit
  - Random forest did catch one positive case on the held-out split, but that split contained only 2 positives, so the thresholded metrics were too unstable to drive the whole recommendation.
- **Tradeoffs / risks:**
  - Random forest had the higher held-out F1 on that one split.
- **Implications:**
  - The final recommendation should be based on the full picture, not on one fragile metric.
  - The report should state clearly why the simpler model still wins overall.
- **What would change our mind:**
  - A larger evaluation cohort showing that the random forest advantage was stable and meaningful enough to outweigh the interpretability gap.

---

## Bottom line

The project started with a simple, leakage-aware baseline and stayed disciplined all the way through Assignment 2. Where real issues surfaced, they were handled directly instead of being explained away. The final state of the project is a stable v1.1 stay-level modeling workflow with a clear recommendation: carry forward logistic regression.
