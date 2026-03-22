# 08 — Model Evaluation and Comparison

**Project:** ICU Patient Care Analysis (MIMIC-IV Clinical Database Demo)  
**Phase:** CRISP-DM — Modeling (Assess Model)  
**Last updated:** 2026-03-22

---

## 1) Purpose

This document records how the final model set was evaluated and compared. The point here is to turn the raw output from the final model run into a comparison that is fair, readable, and defensible.

To ensure honesty:
- the models are evaluated on the same task
- the same dataset version is used for all of them
- the held-out test set stays held out
- the reported metrics actually fit the problem
- any tradeoff is explained plainly instead of hidden behind one headline number

This section answers the real question: given this dataset and this use case, which model actually makes the most sense?

---

## 2) What was compared

The final v1.1 comparison was:

- majority-class baseline
- logistic regression
- random forest

The baseline gave us a floor. Logistic regression was the main interpretable model. Random forest was the main nonlinear model. That was enough to show whether added complexity was buying anything meaningful.

We did not treat a third model as part of the official comparison.

---

## 3) Evaluation principles used

The final comparison followed a few simple rules.

### 3.1 Held-out test results were used for final reporting
The numbers in the final comparison table came from held-out evaluation data, not training performance and not tuning results.

### 3.2 More than one metric was used
Accuracy alone was not enough here because the positive class was limited. A model can look decent on accuracy without being very useful.

### 3.3 The models were compared on the same footing
The same:
- target
- predictor set
- split logic
- preprocessing rules
- thresholding logic
- evaluation framework

applied to every model in the final comparison.

### 3.4 The results were interpreted in context
With a small demo cohort, one number can swing a lot based on a tiny number of cases. So we treated the held-out thresholded results as important, but not as the only thing that mattered.

---

## 4) Evaluation workflow

The final evaluation workflow for this project was:

1. start from the refreshed v1.1 modeling dataset  
2. apply the locked subject-aware split design  
3. do model development and modest tuning using training data only  
4. keep related records together at the subject level during splitting  
5. choose final thresholds using training-only out-of-fold predictions  
6. evaluate final selected configurations on the held-out test set  
7. save the results as stable artifacts  
8. compare the models using one consistent metric panel and a clear narrative  

That gave us a comparison we could actually defend.

---

## 5) Metric set used in the final comparison

### 5.1 Official reported metrics
The final comparison reports:

- Accuracy
- Precision
- Recall
- F1-score
- ROC-AUC

### 5.2 Confusion matrices
Confusion matrices are included because they make the tradeoff concrete.

### 5.3 Primary ranking metric
The main metric used to rank the models is:

- **F1-score**

We used F1 as the main ranking metric because it balances precision and recall, which matters more here than raw accuracy.

### 5.4 Supporting metrics
We also kept:
- PR-AUC
- Brier score

as supporting diagnostics. They were helpful, especially because they made it easier to see that a model could still have ranking signal even when the thresholded classification result looked weak.

---

## 6) Final comparison results

### 6.1 Majority-class baseline
The majority baseline did what it was supposed to do: it showed the floor. It had the best raw accuracy simply because the positive class was rare, but it did not identify any positive cases in a useful way.

Held-out baseline performance:
- Threshold: not applicable
- Accuracy: **0.9474**
- Precision: **0.0000**
- Recall: **0.0000**
- F1: **0.0000**
- ROC-AUC: **0.5000**
- PR-AUC: **0.0526**
- Brier: **0.0526**

That is exactly why accuracy by itself was not enough here.

### 6.2 Logistic regression
Logistic regression ended up being the strongest model overall once we looked at the full picture.

Held-out logistic regression performance:
- Threshold: **0.52**
- Accuracy: **0.8947**
- Precision: **0.0000**
- Recall: **0.0000**
- F1: **0.0000**
- ROC-AUC: **0.8611**
- PR-AUC: **0.2262**
- Brier: **0.0703**

On the held-out confusion matrix, logistic regression was conservative:
- 34 true negatives
- 2 false positives
- 2 false negatives
- 0 true positives

So on this specific held-out split, it missed both positive cases. That matters. But the held-out test set only contained **2 positives**, which makes those thresholded metrics very unstable.

At the same time, logistic regression had the better discrimination metrics on the held-out test set and the more convincing pattern in cross-validation. Across grouped CV, it averaged:
- Accuracy: **0.8302**
- Precision: **0.5083**
- Recall: **0.4567**
- F1: **0.4111**
- ROC-AUC: **0.6977**
- PR-AUC: **0.4452**
- Brier: **0.1507**

That is why logistic regression still ended up being the stronger overall model.

### 6.3 Random forest
Random forest did catch one positive case on the held-out split:

Held-out random forest performance:
- Threshold: **0.18**
- Accuracy: **0.7368**
- Precision: **0.1000**
- Recall: **0.5000**
- F1: **0.1667**
- ROC-AUC: **0.5833**
- PR-AUC: **0.1025**
- Brier: **0.0634**

Its confusion matrix was:
- 27 true negatives
- 9 false positives
- 1 false negative
- 1 true positive

So if we looked only at held-out F1 on that one split, random forest would come out ahead. The problem is that this one result, by itself, is not strong enough to outweigh the rest of the evidence.

Across grouped CV, random forest averaged:
- Accuracy: **0.8742**
- Precision: **0.2000**
- Recall: **0.0500**
- F1: **0.0800**
- ROC-AUC: **0.7611**
- PR-AUC: **0.4263**
- Brier: **0.1139**

So random forest was not useless, but it did not show enough overall advantage to justify the extra complexity.

### 6.4 What the plots showed
The ROC and precision-recall curves told a clearer story than the confusion matrices alone:

- logistic regression had the stronger ROC-AUC
- logistic regression had the stronger average precision
- random forest was not useless, but it did not show enough overall advantage to justify the extra complexity

The coefficient and importance plots also showed that the v1.1 refresh helped. The model was no longer leaning only on charting-intensity features. Early labs and grouped context features were part of the signal too.

---

## 7) What mattered most in the comparison

### 7.1 The held-out test set was tiny
This is the single biggest caveat. The held-out test set had only 2 positive cases. That means thresholded metrics like precision, recall, and F1 are very unstable.

One caught case changes the whole story.

Because of that, we did not want to pretend the held-out confusion matrices alone settled the model choice.

### 7.2 Logistic regression had the better overall case
Even though random forest caught one positive on the held-out split, logistic regression still had the better overall case once we looked at:
- stronger discrimination
- stronger cross-validation performance
- better interpretability
- better fit to the actual project use case

### 7.3 Random forest was still useful as a comparison model
We would not call random forest a failure. It was useful because it tested whether a more flexible model added enough to justify itself. In the end, we do not think it did.

---

## 8) Final comparison table

| Model | Threshold | Accuracy | Precision | Recall | F1 | ROC-AUC | Notes |
|------|-----------:|---------:|----------:|-------:|---:|--------:|-------|
| Majority baseline | — | 0.9474 | 0.0000 | 0.0000 | 0.0000 | 0.5000 | high accuracy only because positives are rare |
| Logistic regression | 0.52 | 0.8947 | 0.0000 | 0.0000 | 0.0000 | 0.8611 | strongest overall recommendation |
| Random forest | 0.18 | 0.7368 | 0.1000 | 0.5000 | 0.1667 | 0.5833 | caught one positive, but not enough to justify extra complexity |

That is enough for the report. The point is to be clear, not flashy.

---

## 9) Diagnostics included

The final comparison uses a small set of diagnostics that actually help explain model behavior:

- confusion matrix for logistic regression
- confusion matrix for random forest
- ROC curve comparison
- precision-recall curve comparison
- logistic regression coefficient output
- random forest feature importance output

That is enough to support the report without making it bloated.

---

## 10) Robustness and caveats

The final comparison needs to be honest about the limits of the dataset and the workflow.

The main caveats are:

- small cohort size
- very limited positive class
- only 2 positive cases in the held-out test set
- thresholded metrics are unstable because of that
- the results come from the demo dataset, not the full MIMIC-IV database
- the v1.1 refresh improved the feature mix, but it did not change the fact that this is still a small first-pass study

These are not excuses. They are part of a believable interpretation of the results.

---

## 11) Final comparison narrative

### Majority-class baseline summary
The majority baseline confirmed that raw accuracy was not enough. It looked fine on accuracy because the positive class was rare, but it did not identify positives in a useful way.

### Logistic regression summary
Logistic regression was the strongest overall model. It had the better discrimination metrics, the better cross-validation profile, and the cleaner interpretation. Even though it missed both positive cases on the held-out split, we do not think that one split overturns the stronger overall evidence in its favor.

### Random forest summary
Random forest was useful as a comparison model and did catch one positive case on the held-out split, but it came with many more false positives and weaker overall discrimination. We do not think it earned enough to justify the extra complexity.

### Overall comparison takeaway
The final comparison suggests that the simpler model is still the better choice. Logistic regression gave the strongest overall balance of signal, interpretability, and operational usefulness. Random forest was a fair test, but not a compelling enough improvement.

---

## 12) Artifacts created

By the end of the evaluation phase, the repo contained stable outputs such as:

### In `outputs/tables/`
- final CV metrics by fold
- final CV summary metrics
- held-out test metrics
- final comparison table
- held-out predictions
- logistic regression coefficients
- random forest feature importances
- threshold search outputs

### In `outputs/figures/`
- ROC curve comparison
- precision-recall curve comparison
- confusion matrix plots
- coefficient / importance plots used in the report

### In `outputs/models/`
- saved logistic regression model
- saved random forest model

At that point, the comparison was complete enough to support the final recommendation.

---

## 13) Planned report contribution

This document feeds directly into **Section 2.3: Model Evaluation and Comparison** of Assignment 2.

In the final report, this section should:
- present held-out results
- compare the models fairly
- explain the main tradeoffs
- connect the results back to the actual prolonged-LOS use case

---

## 14) Bottom line

This comparison was supposed to answer a practical question, not just a statistical one. At the end of the process, we do not think the more flexible model earned enough to outweigh the simpler one. Logistic regression gave the better overall balance of evidence, interpretability, and operational fit, and that is what matters most for this project.
