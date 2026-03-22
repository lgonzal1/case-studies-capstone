# 06 — Modeling Strategy

**Project:** ICU Patient Care Analysis (MIMIC-IV Clinical Database Demo)  
**Phase:** CRISP-DM — Modeling (Technique Selection / Test Design)  
**Last updated:** 2026-03-22

---

## 1) Purpose

This document lays out the modeling strategy for Assignment 2. The goal here is to lock in the problem definition, target, predictor scope, model set, evaluation metrics, and validation approach before treating any results as final.

The goal is to build a workflow that is methodologically clean, easy to explain, and realistic for a process-improvement style use case. This project prioritizes operations and quality improvement, so we care more about whether the model is understandable and defensible than about squeezing out a tiny gain with something more complex.

After an initial model pass, we made a small v1.1 refresh to the prepared dataset. That did not change the basic problem. It just gave the model a better feature mix by adding grouped context variables and a small early lab panel.

---

## 2) Problem framing

For this project, we are treating the task as a **binary classification** problem:

> Predict whether an ICU stay will become a prolonged ICU stay using information available within the first 24 hours after ICU admission.

This still fits the structure of the prepared dataset, which is built at the ICU-stay level (`stay_id`) and uses predictors derived from the first 24 hours after ICU `intime`.

We considered whether it would make more sense to model ICU LOS directly as a continuous outcome, but for this assignment the binary framing is the better choice. It is easier to explain, easier to connect to an operational question, and more realistic for a first-pass model on the demo dataset.

---

## 3) Target definition

The target remains:

- `prolonged_los_8d = 1` if ICU LOS >= 8 days
- `prolonged_los_8d = 0` otherwise

We kept the same 8-day threshold across the v1 and v1.1 passes. That number was not random. It was a pragmatic cutoff supported by the literature review and by the earlier framing of this project, where the goal was to separate more routine ICU stays from the longer, more resource-intensive stays in a way that is still easy to explain.

That said, a threshold like this is still ultimately an operational decision, not just a modeling decision. In a real hospital setting, we would bring a cutoff like 8 days to leadership as a defensible starting point, then confirm whether that lines up with how they define the problem. That stakeholder step is part of CRISP-DM, even if it is hard to simulate cleanly in a capstone built on demo data.

For this project, that tradeoff is still worth it. We do not need to predict the exact LOS with precision. We need a modeling setup that can ask whether early-stay data contains useful signal for identifying patients who are more likely to end up in the more resource-intensive group.

---

## 4) Predictor scope

The official predictor set is limited to information available within the first 24 hours of the ICU stay.

That includes:

- early physiologic summary features from `chartevents`
- measurement-density features
- missingness indicators
- grouped context variables that are safe to treat as known at or near ICU admission
- a small early lab panel

For the grouped context variables, the intended predictors are:

- `admission_type_grp`
- `first_careunit_grp`

We are keeping the raw versions of those fields in the table for auditability, but the grouped versions are cleaner and more stable for this dataset.

We are also not treating `last_careunit` as a predictor. It can stay in the dataset for auditability and debugging, but not for model fitting. The reason is simple: `last_careunit` is too close to hindsight.

The early lab panel added in v1.1 is intentionally small:

- creatinine
- WBC
- hemoglobin
- lactate

These were added because they had reasonable 24-hour coverage and gave the model a better mix of operational and clinical signal. We did not want the model leaning almost entirely on charting-intensity features if a small, defensible feature refresh could improve that.

We are still not including:

- diagnosis-derived features
- medication or procedure features
- text features
- anything from later in the stay
- anything that depends on full-stay hindsight

The rule is still straightforward: if we cannot defend that the information would be available within the first 24 hours of the ICU stay, it does not belong in the model.

---

## 5) Model portfolio

We are keeping the model portfolio small on purpose.

### 5.1 Baseline floor
We include a **majority-class baseline** as the minimum benchmark.

That gives us a simple reference point for what happens if the model does nothing except predict the most common class.

### 5.2 Main simple benchmark
We use **logistic regression** as the main interpretable model.

This is the kind of model that makes sense for a project like this. It is simple, stable, familiar, and easy to explain. If it performs reasonably well, that is a strong outcome because it means the signal is being captured by something simple and understandable.

### 5.3 Main nonlinear comparison model
We use **random forest** as the main flexible nonlinear model.

This gives us a useful contrast with logistic regression. It can pick up interactions and nonlinear behavior without a lot of extra feature engineering, but it is still easier to justify and discuss than a more complex boosting setup.

### 5.4 What we are not requiring
We are still **not** treating gradient boosting / XGBoost as part of the required model set.

That is a deliberate choice. For this assignment, we would rather compare a simple interpretable model and a reasonable nonlinear model cleanly than add a third model just because it is common in tabular ML work.

### 5.5 Model selection philosophy
Our bias here is simple: if the simpler model performs credibly and is close to the more complex one, we would rather recommend the simpler model.

That fits the operational framing better. In process improvement, “good enough, understandable, and usable” is often more valuable than “slightly better on paper but harder to trust and explain.”

---

## 6) Evaluation metrics

Because the positive class is limited, we are not going to rely on accuracy alone.

The main metrics we report are:

- Precision
- Recall
- F1-score
- ROC-AUC
- Confusion matrix

We still report **accuracy**, but only as a secondary descriptive metric.

### Primary ranking metric
The main metric we use for model ranking is **F1-score**.

That is still the best single summary metric for this setup because it balances precision and recall. In this project, we care about both:
- we do not want to miss too many prolonged stays
- but we also do not want a model that throws too many false alarms to be considered good just because it catches more positives

We also keep:
- **PR-AUC**
- **Brier score**

as supporting metrics. They are useful, but they are not the headline comparison metrics for the report.

---

## 7) Validation and split design

The evaluation design needs to preserve a real held-out test set and keep leakage under control.

The protocol is:

1. Start from the prepared modeling dataset.
2. Separate the target, predictors, and audit-only fields.
3. Use a **75/25 train/test split**.
4. Keep related records together at the **subject level** when splitting, so the same patient does not leak across training and evaluation.
5. Use **5-fold cross-validation within the training set only** for model development and modest tuning.
6. Fit learned preprocessing steps on training data only.
7. Tune the final decision threshold using **training-only out-of-fold predictions**.
8. Evaluate the final chosen model configurations on the held-out test set once.

That last point is the main update from the earlier version. In the first final-model pass, the default `0.5` threshold turned out to be too conservative for the held-out split. Rather than pretend that default threshold was sacred, we treated threshold choice like part of the actual modeling workflow and tuned it using training data only. That is a more realistic way to handle a classifier in practice, and it keeps the held-out test honest.

### Preprocessing rule
Any preprocessing step that learns from the data belongs inside the modeling workflow, not in the global data-prep layer. That includes things like:
- imputation
- scaling
- encoding logic

We do not want the report to imply that we cleaned the full dataset once and then harmlessly modeled it afterward if, in reality, the preprocessing should have been fit only on training data.

### Guardrails
To keep this clean:
- we do not tune on the held-out test set
- we do not fit imputers or scalers on the full dataset before splitting
- we do not use identifiers or obviously post-hoc variables as predictors
- we do not treat exploratory notebook output as final evidence

---

## 8) Practical constraints

This project uses the MIMIC-IV demo dataset, not the full MIMIC-IV database. That matters.

The cohort is small, which means:
- performance estimates may move around more than we would like
- very complex models are harder to justify
- tiny numeric differences between models may not mean much

Because of that, a restrained strategy is still the right strategy. If this were a real process-improvement project, we would much rather hand operations a simple model that makes sense than a more complicated one that is theoretically stronger but harder to trust.

That is still the guiding idea here: keep it meat and potatoes. Something useful, understandable, and believable beats something fancy that mainly exists to impress other modelers.

---

## 9) What counts as success here

For this modeling phase, success means:

- we have a clearly documented majority-class floor
- we have a fair comparison between logistic regression and random forest
- the evaluation is leakage-safe
- the metric panel fits the class balance
- the final recommendation makes sense for the project, not just for the score table

We do not need a flashy result. We need one we can defend.

---

## 10) Planned report contribution

This document feeds directly into **Section 2.1: Modeling Strategy** of Assignment 2.

In the final report, this section should explain:

- why we framed the problem as early prolonged-LOS classification
- why we kept the predictor set narrow but allowed a small v1.1 refresh
- why we chose a small model set
- why F1 is the main ranking metric
- why the validation design includes training-only threshold tuning before the held-out test

---

## 11) Bottom line

The modeling strategy is still deliberately simple and practical. We are using a stay-level early-risk classification setup, a narrow and defensible predictor set, a small model portfolio, and a held-out evaluation design that keeps leakage in check.

The v1.1 refresh did not change the basic strategy. It just gave the model a better mix of early signals and made the final comparison more believable.
