## 2026-03-22  Entry 10 — Assignment 2 Execution Closeout (Protocol Lock → v1.1 Rerun → Final Recommendation)

### What I completed
- Moved the project from “almost ready” into actual Assignment 2 execution.
- Locked the final modeling protocol in writing before treating any more results as final.
- Built a clean final comparison notebook/script rather than overloading the earlier prototype notebook.
- Ran the first final-model pass and reviewed the outputs closely enough to catch a real methodology issue instead of just explaining it away.
- Identified that the default classification threshold was too conservative for the held-out split and handled that explicitly by moving threshold selection into the training-only part of the workflow.
- Stepped back and did a targeted feature audit instead of forcing the first pass to be “good enough.”
- Used that audit to justify a small v1.1 feature refresh:
  - grouped `admission_type`
  - grouped `first_careunit`
  - small early lab panel
- Wrote new SQL to build the v1.1 lab/context features and rebuilt the modeling table.
- Reran the final comparison on the refreshed v1.1 dataset.
- Reviewed the final v1.1 metrics, curves, confusion matrices, coefficients, and feature importances.
- Finalized the model recommendation and updated the Section 2 source docs around the actual evidence rather than around placeholders.

### Key takeaways
- The biggest issue in the first final-model pass was not that the model had no signal. The issue was that the default threshold made the held-out classification result look worse than the ranking signal actually was.
- Threshold selection is part of the modeling workflow, not some sacred default that should never be touched.
- The small v1.1 feature refresh was worth doing. It did not make the project bigger than it needed to be, but it did make the model story more believable.
- `n_chartevents_24h` still matters a lot, which is not surprising in an ICU workflow. The difference after the refresh is that the model is no longer leaning on that feature alone. Early labs and grouped context features now show up too.
- The held-out test split is tiny, so one positive case changes the whole F1 story. That means the final recommendation has to come from the full picture, not just one held-out confusion matrix.

### Decisions made
- Kept the project framed as a binary early-risk classification problem for prolonged ICU LOS.
- Kept the 8-day threshold because it was a pragmatic, literature-informed operational cutoff, even though in a real hospital setting that kind of threshold would still need stakeholder confirmation.
- Treated majority baseline + logistic regression + random forest as the final model set.
- Treated training-only threshold tuning as part of the final locked workflow.
- Carried forward the v1.1 dataset as the final prepared dataset for Assignment 2.
- Selected **logistic regression** as the recommended model.

### Why logistic regression was selected
- It had the stronger overall case once we looked at held-out discrimination, grouped cross-validation performance, interpretability, and practical fit.
- Random forest did catch one positive case on the held-out split, so it did better on held-out F1 for that one tiny split.
- That held-out test set only had 2 positive cases, so we did not let that one result drive the whole recommendation.
- Logistic regression had much stronger ROC-AUC and PR-AUC on the held-out set and much stronger F1 in grouped cross-validation.
- For a project framed like BI / process improvement, that is enough to make the simpler model the better recommendation.

### Open questions
- Final report assembly still needs to happen.
- Introduction and Conclusion still need to be finalized in report form.
- Final packaging for the Show Your Work submission still needs one more QA pass before submission.

### Next steps
- Assemble the final Assignment 2 report from the frozen section docs and artifacts.
- Update the tracker and checklist one last time before submission.
- Finalize the PDF report.
- Finalize the Show Your Work package.
- Submit Assignment 2 and then transition into M10 / Assignment 3.
