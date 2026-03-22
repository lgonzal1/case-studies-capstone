# 07 — Model Development

**Project:** ICU Patient Care Analysis (MIMIC-IV Clinical Database Demo)  
**Phase:** CRISP-DM — Modeling (Build Model)  
**Last updated:** 2026-03-22

---

## 1) Purpose

This document records how the final model set for Assignment 2 was developed. By this point, the strategy had already been narrowed and locked in `06_modeling_strategy.md`. The job here was to execute that plan in a controlled way and document what was actually done.

For this project, we were not trying to run a big model search. We were trying to build a fair comparison that we could explain clearly and defend without a lot of hand waving. Since the project is framed more like an operations / quality-improvement case than a machine learning competition, we cared more about whether the modeling workflow was sound and usable than about chasing a slightly better score with something more complicated.

This section documents:
- the baseline used
- the models that were actually trained
- how preprocessing was handled
- how tuning was handled
- what issues came up during training
- what each model added to the final comparison

---

## 2) Development approach

The development approach for this project stayed intentionally simple.

The final official comparison was:

- majority-class baseline
- logistic regression
- random forest

That was enough for Assignment 2. It gave us:
- a floor
- a simple interpretable model
- a more flexible nonlinear model

That is a clean comparison and it is enough to answer the real question here: does a more complex model add enough value to justify the extra complexity?

We did not treat anything beyond that as part of the required final model set.

---

## 3) Inputs used for model development

### 3.1 Prepared dataset
The final modeling input for the rerun was:

- `data/processed/icu_stay_modeling_24h_v1_1.csv`

We started with the original v1 modeling dataset, but after reviewing the first final-model pass, we did a small v1.1 feature refresh. That refresh added:
- grouped context variables
- a small early lab panel

The point of that update was not to reopen the whole project. It was to improve the feature mix enough to give the model a fairer shot.

### 3.2 Upstream documentation
This modeling work depends on the prepared dataset and the Section 1 artifacts already completed:

- `01_select_data_rationale.md`
- `02_clean_data_report.md`
- `03_feature_spec.md`
- `04_integration_lineage.md`
- `05_format_data_notes.md`

### 3.3 Audit-only fields
The modeling table includes some fields that are useful for traceability and QA but should not be used as predictors.

Examples include:
- `stay_id`
- `subject_id`
- `hadm_id`
- timestamps
- raw LOS audit fields
- raw context fields that are being kept for auditability rather than modeling

These fields were separated out before model fitting.

---

## 4) Baseline development

### 4.1 Majority-class baseline
The first benchmark in the workflow was the majority-class baseline.

Its purpose was simple: show what happens if the model predicts the most common class every time. That gave us a floor for the rest of the comparison.

### 4.2 Why the baseline mattered
Without a baseline, it is too easy to make a more complex model sound impressive just because it produces numbers. That matters even more here because the dataset is small enough that modest-looking improvements may not really mean much.

### 4.3 Baseline result summary
The majority-class baseline did exactly what it was supposed to do: it gave a clear floor. It also showed why raw accuracy alone was not enough in this problem. The baseline reached **0.9474** accuracy on the held-out set simply because the positive class was rare, but it had **0.0000 precision**, **0.0000 recall**, and **0.0000 F1**. That made it a useful floor, not a useful model.

---

## 5) Logistic regression development

### 5.1 Role in the comparison
Logistic regression was the main interpretable benchmark.

This is the model we would be most comfortable explaining to a non-ML audience in an operational setting. If it performed reasonably well, that was a strong result because it meant the signal was being picked up by something simple and understandable.

### 5.2 Why it belonged
- easy to explain
- stable on structured tabular data
- supports coefficient-based interpretation
- fits the overall process-improvement mindset of the project

### 5.3 What was actually done
For the final run, logistic regression was developed inside a pipeline that handled:
- imputation
- scaling for numeric variables
- one-hot encoding for categorical variables

Its hyperparameters were tuned using grouped cross-validation on the training data only. We also treated the classification threshold as part of the development process, rather than assuming the library default `0.5` threshold was the right choice.

That threshold step ended up mattering. In the earlier pass, the default threshold was too conservative and produced no positive predictions on the held-out split. The v1.1 workflow fixed that by tuning the threshold using training-only out-of-fold predictions.

### Logistic regression summary
- Final version used: logistic regression pipeline with grouped cross-validation and training-only threshold tuning
- Key settings: `C = 1.0`, `class_weight = None`
- Selected threshold: `0.52`
- Preprocessing used: median imputation + scaling for numeric features, most-frequent imputation + one-hot encoding for categorical features
- Training notes: logistic regression remained the strongest overall model once we looked at discrimination, cross-validation behavior, and interpretability together

### Logistic regression training performance
Across grouped cross-validation, logistic regression averaged:
- Accuracy: **0.8302**
- Precision: **0.5083**
- Recall: **0.4567**
- F1: **0.4111**
- ROC-AUC: **0.6977**
- PR-AUC: **0.4452**
- Brier: **0.1507**

That profile was much more balanced than random forest.

---

## 6) Random forest development

### 6.1 Role in the comparison
Random forest was the main nonlinear comparison model.

Its job was to answer a practical question: does a more flexible model pick up enough additional signal to justify the extra complexity?

### 6.2 Why it belonged
- captures nonlinearities and interactions without needing a lot of manual feature engineering
- gives a fair contrast to logistic regression
- is still easier to explain than something even more complex

### 6.3 What was actually done
For the final run, random forest was also developed using grouped cross-validation on the training data only. The tuning stayed modest, focusing on:
- number of trees
- depth limits
- minimum leaf size
- class weighting

Like logistic regression, random forest also used training-only threshold tuning before final held-out evaluation.

### Random forest summary
- Final version used: random forest pipeline with grouped cross-validation and training-only threshold tuning
- Key settings: `n_estimators = 300`, `max_depth = None`, `min_samples_leaf = 1`, `class_weight = None`
- Selected threshold: `0.18`
- Training notes: random forest was useful as a comparison model, but it did not outperform logistic regression consistently enough to justify recommending it over the simpler model

### Random forest training performance
Across grouped cross-validation, random forest averaged:
- Accuracy: **0.8742**
- Precision: **0.2000**
- Recall: **0.0500**
- F1: **0.0800**
- ROC-AUC: **0.7611**
- PR-AUC: **0.4263**
- Brier: **0.1139**

That profile is part of why we did not want to choose the model based only on one held-out confusion matrix.

---

## 7) Preprocessing inside the modeling workflow

Any preprocessing that learned from the data happened after splitting and was fit on training data only.

That included:
- imputation
- scaling
- categorical encoding
- threshold selection

This mattered because we did not want the final report to blur the line between global data preparation and model-specific preprocessing. If the model learned from the transformed data, then that transformation belonged inside the modeling workflow.

### What this meant in practice
The workflow looked like this:

1. load the prepared dataset  
2. separate target, predictors, and audit-only columns  
3. split train/test while keeping related records together at the subject level  
4. fit preprocessing on training data only  
5. run cross-validation inside training  
6. choose the final model configuration  
7. tune the classification threshold using training-only out-of-fold predictions  
8. evaluate once on the held-out test set  

---

## 8) Tuning approach

The tuning approach for this project stayed modest.

We did not need a huge search. We needed a small, reasonable set of settings that let us compare models fairly without turning this into a fishing expedition.

### What we did
- used a small parameter grid for each model
- evaluated those settings using grouped cross-validation on the training data only
- left the held-out test set untouched until the end

### What we avoided
- tuning against the test set
- trying a large pile of settings with no clear logic
- treating exploratory churn as if it were a coherent strategy

### Final tuning takeaway
The tuning was enough to make the comparison fair, but not so broad that it became the whole story. That was the right tradeoff for this project.

---

## 9) Training issues that came up

A few practical issues mattered during development.

### 9.1 Small sample size
The dataset is small, which means the results move around more than we would like. That is just part of working with the demo cohort.

### 9.2 Limited positive class
This affected both tuning and evaluation. It also made it obvious that accuracy by itself was not a useful summary metric.

### 9.3 Threshold sensitivity
This ended up being one of the biggest practical lessons from the project. The earlier final-model pass showed that the default threshold could make a model look useless even when it still had ranking signal. That is why the final v1.1 workflow included training-only threshold tuning.

### 9.4 Feature mix matters
The v1.1 refresh helped. It did not remove the importance of charting-intensity features, but it did give the model a more balanced mix of workflow, physiologic, lab, and grouped context signals.

The logistic regression coefficient output makes that pretty clear. `n_chartevents_24h` still matters, but so do grouped admission type, grouped careunit, lactate, and other early clinical variables. Random forest also picked up early lab signal, including lactate and hemoglobin, instead of behaving like a pure chart-count model.

### Most useful lesson from development
The biggest lesson was that in a project like this, a small and disciplined feature refresh plus a realistic thresholding step can matter more than swapping in a fancier model.

---

## 10) Artifacts created

By the end of model development, the repo contained:

### In `outputs/tables/`
- CV metrics by fold
- CV summary metrics
- held-out test metrics
- held-out predictions
- logistic regression coefficients
- random forest feature importances
- final model comparison table
- threshold search results and selected thresholds

### In `outputs/models/`
- saved logistic regression model
- saved random forest model

### In `outputs/figures/`
- ROC curve comparison
- precision-recall curve comparison
- confusion matrix plots
- coefficient / importance plots used in the report

At that point, model development was complete enough to move into final evaluation and recommendation.

---

## 11) Planned report contribution

This document feeds directly into **Section 2.2: Model Development** of Assignment 2.

In the final report, this section should explain:
- what the baseline was
- which models were actually trained
- how preprocessing and tuning were handled
- what practical issues came up
- what each model added to the final comparison

---

## 12) Bottom line

For this project, model development looked like a controlled comparison, not an uncontrolled search. We kept the model set small, kept preprocessing and tuning honest, refreshed the feature set in a targeted way, and built toward a final comparison that we could actually defend. 
