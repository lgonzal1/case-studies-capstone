# 09 — Model Selection and Recommendation

**Project:** ICU Patient Care Analysis (MIMIC-IV Clinical Database Demo)  
**Phase:** CRISP-DM — Modeling (Select Final Model / Recommendation)  
**Last updated:** 2026-03-22

---

## 1) Purpose

This document records the final model recommendation for Assignment 2. The goal here is to move from model comparison to a clear recommendation that makes sense for the project as a whole.

At this point, the question is not just which model posted the best number on one table. The question is which model makes the most sense once we look at:
- held-out performance
- cross-validation behavior
- interpretability
- operational usefulness
- the limits of the dataset

That is the standard we are using for the final recommendation.

---

## 2) Recommendation approach

The recommendation is based on the full comparison, not on one metric in isolation.

For this project, that means weighing:
- how the model performed on the held-out test set
- how stable the model looked in grouped cross-validation
- whether the model is easy enough to explain and defend
- whether the model fits the process-improvement framing of the project

That last point matters. This is not a leaderboard exercise. The end result should be something we could explain to an operational audience without overselling it.

---

## 3) Final recommendation

The recommended model for this project is **logistic regression**.

That recommendation is based on the full picture, not just one held-out thresholded result.

Random forest did end up with the better held-out F1 on this particular test split because it caught one of the two positive cases. That is worth acknowledging. But the held-out test set only had **2 positives**, which makes those thresholded metrics very unstable.

Once we step back and look at the full comparison, logistic regression has the stronger overall case:
- better held-out ROC-AUC
- better held-out PR-AUC
- much stronger grouped cross-validation F1
- much better interpretability
- a cleaner fit to the actual use case

For this project, that is enough to make logistic regression the better recommendation.

---

## 4) Why logistic regression is the better choice

### 4.1 Better overall evidence
On the held-out test set, logistic regression had:
- ROC-AUC = **0.8611**
- PR-AUC = **0.2262**

Random forest had:
- ROC-AUC = **0.5833**
- PR-AUC = **0.1025**

That matters because it shows logistic regression did a better job ranking cases overall, even if it missed the two positives at the selected threshold on this one split.

Grouped cross-validation points the same direction. Logistic regression averaged:
- Precision = **0.5083**
- Recall = **0.4567**
- F1 = **0.4111**

Random forest averaged:
- Precision = **0.2000**
- Recall = **0.0500**
- F1 = **0.0800**

That is a big enough gap that the overall recommendation should not be driven by one tiny held-out confusion matrix.

### 4.2 Easier to explain
Logistic regression is easier to explain to a nontechnical audience. That matters for this project.

If this were a real process-improvement setting, we would need to be able to explain:
- what the model is using
- why it is flagging certain cases
- what the important signals appear to be
- and what the limits are

Logistic regression makes that much easier than random forest.

### 4.3 Better fit for the project
This project is closer to a BI / operations case than a pure ML competition. In that setting, a model that is understandable and defensible is usually more useful than one that is a little more flexible but harder to interpret.

That is especially true here because the dataset is small and the test set is fragile. There is not enough evidence to justify taking the more complex path just because it happened to catch one positive case on one held-out split.

---

## 5) What random forest contributed

Random forest was still useful in this project.

It served as a fair nonlinear comparison model and gave us a way to test whether extra flexibility would meaningfully improve the result. It also confirmed that the v1.1 refresh added useful signal beyond simple chart-count behavior. In the importance output, early labs like lactate and hemoglobin showed up along with workflow-related features.

So random forest did add value to the analysis. It just did not add enough value to become the recommended final model.

That is still a successful result. A comparison model does not have to win in order to be useful.

---

## 6) Main limitation behind the recommendation

The biggest limitation is the size of the held-out test set.

There were only **2 positive cases** in the final held-out split. That means the thresholded classification metrics are very unstable. One case changes the story a lot.

Because of that, the recommendation should not be based only on held-out precision, recall, or F1. Those numbers still matter, but they need to be read alongside:
- grouped cross-validation performance
- ROC-AUC
- PR-AUC
- interpretability
- practical fit to the project

That is exactly why logistic regression remains the better recommendation here.

---

## 7) What the v1.1 refresh changed

The v1.1 refresh made the final recommendation easier to defend.

In the earlier pass, the model was leaning heavily on charting-intensity features. That is not necessarily wrong, but it made the story thinner than we wanted. The v1.1 refresh improved the feature mix by adding:
- grouped context variables
- a small early lab panel

That gave the model a more balanced set of signals. After the refresh, the outputs showed that early labs and grouped context features were contributing alongside workflow-intensity features.

So even though the final recommendation stayed with logistic regression, the refresh was still worth doing.

---

## 8) Practical recommendation

If this project were moving forward beyond the capstone, logistic regression is the model we would carry forward first.

That does not mean it is production-ready as-is. It means it is the best next-step model because it gives the strongest overall balance of:
- signal
- stability
- interpretability
- operational usefulness

The right next step would be to test it on a larger cohort before making any stronger claims.

---

## 9) Future work

The next reasonable steps are straightforward:

- test the same workflow on a larger cohort
- check whether the recommendation still holds with more positive cases in evaluation
- revisit threshold setting in a more use-case-specific way
- expand features carefully only if they add real value and stay defensible
- look at calibration more closely if the model is ever going to be used as a risk score instead of just a ranked flagging tool

The main point is not to jump straight to a fancier model. The main point is to strengthen the evidence around the simpler one first.

---

## 10) Final recommendation statement

Based on the full comparison, we recommend **logistic regression** as the final model for this project.

Random forest had the higher held-out F1 on this one split, but the held-out test set was too small to let that result carry the whole decision. Logistic regression had the stronger overall case once we considered discrimination, cross-validation performance, interpretability, and fit to the process-improvement context.

That makes logistic regression the better choice for this assignment and the more defensible choice for a practical operational use case.

---

## 11) Planned report contribution

This document feeds directly into **Section 2.4: Model Selection and Recommendation** of Assignment 2.

In the final report, this section should:
- state the recommended model clearly
- explain why it is being selected
- acknowledge the main limitation behind that choice
- and give a reasonable next step without turning the conclusion into a whole new project

---

## 12) Bottom line

The final recommendation is logistic regression. It gave the better overall balance of performance, interpretability, and practical fit for the problem we were actually trying to solve. That is enough to make it the right model to carry forward from this assignment.
