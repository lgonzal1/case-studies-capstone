"""Final Model Comparison — Early Prediction of Prolonged ICU Stay (v1.1)

Companion script for the official final modeling run.
Run from ./notebooks so relative paths resolve correctly.
"""

# # Final Model Comparison — Early Prediction of Prolonged ICU Stay (v1.1)
#
# **Project:** ICU Patient Care Analysis (MIMIC-IV Clinical Database Demo)  
# **Phase:** Assignment 2 — Final Modeling Run (v1.1 refresh)  
# **Author:** Luis Gonzalez  
# **Run location:** `./notebooks`  
# **Last updated:** 2026-03-22
#
# ## Purpose
#
# This notebook is the **official final modeling run** for the v1.1 dataset refresh. It replaces the earlier prototype-style run with a cleaner and more focused comparison that matches the locked modeling strategy.
#
# The comparison in this notebook is intentionally small:
#
# - majority-class baseline
# - logistic regression
# - random forest
#
# That is enough for this capstone. The goal is not to build the fanciest model possible. The goal is to run a fair comparison, keep leakage under control, and generate outputs that are clear enough to defend in the report.
#
# ## What changed from the earlier final-run notebook
#
# This v1.1 notebook reflects two practical lessons from the earlier run:
#
# 1. The first model leaned heavily on charting-intensity features, so the prepared dataset was refreshed with:
#    - grouped context features
#    - a small early lab panel
#
# 2. The earlier held-out comparison produced zero positive predictions at the default threshold, so this notebook now does **threshold tuning on training data only**.  
#    That keeps the held-out test honest while giving the classifier a more realistic decision rule.
#
# ## What this notebook produces
#
# If the notebook runs successfully, it should create artifacts under `../outputs/` including:
#
# ### Tables
# - `model_v1_1_split_manifest.csv`
# - `model_v1_1_search_results_logreg.csv`
# - `model_v1_1_search_results_rf.csv`
# - `model_v1_1_cv_metrics_by_fold.csv`
# - `model_v1_1_cv_metrics_summary.csv`
# - `model_v1_1_threshold_search_logreg.csv`
# - `model_v1_1_threshold_search_rf.csv`
# - `model_v1_1_thresholds_selected.csv`
# - `model_v1_1_test_metrics.csv`
# - `model_v1_1_model_comparison.csv`
# - `model_v1_1_test_predictions.csv`
# - `model_v1_1_logreg_coefficients.csv`
# - `model_v1_1_rf_feature_importance.csv`
#
# ### Figures
# - `model_v1_1_roc_curve_comparison.png`
# - `model_v1_1_precision_recall_curve_comparison.png`
# - `model_v1_1_confusion_matrix_logreg.png`
# - `model_v1_1_confusion_matrix_rf.png`
# - `model_v1_1_logreg_coefficients.png`
# - `model_v1_1_rf_feature_importance.png`
#
# ### Models
# - `model_v1_1_logreg.joblib`
# - `model_v1_1_random_forest.joblib`
#
# ## Notes
#
# - This notebook assumes it is being run from the `./notebooks` directory.
# - It assumes the refreshed prepared dataset already exists at `../data/processed/icu_stay_modeling_24h_v1_1.csv`.
# - It keeps related records together at the **subject level** during splitting.
# - Held-out test results are the official results for the final comparison.
# - Cross-validation and threshold tuning are done using training data only.

# ## 1) Setup

from pathlib import Path
import inspect
import warnings

import joblib
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd

from sklearn.base import clone
from sklearn.compose import ColumnTransformer
from sklearn.dummy import DummyClassifier
from sklearn.impute import SimpleImputer
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import (
    accuracy_score,
    average_precision_score,
    brier_score_loss,
    confusion_matrix,
    ConfusionMatrixDisplay,
    f1_score,
    precision_recall_curve,
    precision_score,
    recall_score,
    roc_auc_score,
    roc_curve,
)
from sklearn.model_selection import (
    GridSearchCV,
    GroupKFold,
    GroupShuffleSplit,
    cross_validate,
    cross_val_predict,
)
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import OneHotEncoder, StandardScaler
from sklearn.ensemble import RandomForestClassifier

warnings.filterwarnings("ignore", category=UserWarning)
plt.rcParams["figure.figsize"] = (8, 5)
plt.rcParams["axes.grid"] = True
RANDOM_STATE = 42



# ## 2) Paths and output locations

DATA_PATH = Path("../data/processed/icu_stay_modeling_24h_v1_1.csv")

OUTPUTS_DIR = Path("../outputs")
TABLES_DIR = OUTPUTS_DIR / "tables"
FIGURES_DIR = OUTPUTS_DIR / "figures"
MODELS_DIR = OUTPUTS_DIR / "models"

for p in [TABLES_DIR, FIGURES_DIR, MODELS_DIR]:
    p.mkdir(parents=True, exist_ok=True)

print("Data path:", DATA_PATH.resolve())
print("Tables dir:", TABLES_DIR.resolve())
print("Figures dir:", FIGURES_DIR.resolve())
print("Models dir:", MODELS_DIR.resolve())



# ## 3) Load data and run basic integrity checks

df = pd.read_csv(DATA_PATH)

print("Shape:", df.shape)
print("\nColumns:")
print(df.columns.tolist())

assert "stay_id" in df.columns, "stay_id is missing"
assert "subject_id" in df.columns, "subject_id is missing"
assert "prolonged_los_8d" in df.columns, "target column prolonged_los_8d is missing"

assert df["stay_id"].notna().all(), "stay_id has nulls"
assert df["stay_id"].nunique() == len(df), "duplicate stay_id rows detected"
assert set(df["prolonged_los_8d"].dropna().unique()).issubset({0, 1}), "target must be 0/1"

print("\nTarget prevalence:")
print(df["prolonged_los_8d"].value_counts(dropna=False).sort_index())
print(df["prolonged_los_8d"].value_counts(normalize=True).sort_index().round(4))

stays_per_subject = df.groupby("subject_id")["stay_id"].nunique().sort_values(ascending=False)
repeat_subjects = stays_per_subject[stays_per_subject > 1]

print("\nSubjects with repeated ICU stays:", repeat_subjects.shape[0])
print("Max stays for a single subject:", int(stays_per_subject.max()))
repeat_subjects.head(10)



# ## 4) Define target, predictors, and audit-only fields
#
# The refreshed dataset keeps some raw context and lineage fields for auditability, but they should not all be used as predictors.
#
# For v1.1:
# - grouped context fields stay in as predictors
# - raw context fields stay in the table for auditability only
# - `last_careunit` stays out of the predictor set because it is too close to hindsight

TARGET = "prolonged_los_8d"

AUDIT_ONLY_COLS = [
    "subject_id",
    "hadm_id",
    "stay_id",
    "intime",
    "outtime",
    "los_days",
    "last_careunit",
    "first_careunit",
    "admission_type",
]

existing_audit_cols = [c for c in AUDIT_ONLY_COLS if c in df.columns]

X = df.drop(columns=[TARGET] + existing_audit_cols, errors="ignore").copy()
y = df[TARGET].astype(int).copy()
groups = df["subject_id"].astype(int).copy()

print("Predictor matrix shape:", X.shape)
print("Audit-only columns dropped:", existing_audit_cols)
print("\nPredictor columns:")
print(X.columns.tolist())



# ## 5) Helper functions

def make_onehot_encoder():
    params = {"handle_unknown": "ignore"}
    sig = inspect.signature(OneHotEncoder)
    if "sparse_output" in sig.parameters:
        params["sparse_output"] = False
    else:
        params["sparse"] = False
    return OneHotEncoder(**params)


def build_preprocessor(X_frame: pd.DataFrame):
    cat_cols = [
        c for c in X_frame.columns
        if pd.api.types.is_object_dtype(X_frame[c]) or pd.api.types.is_categorical_dtype(X_frame[c])
    ]
    num_cols = [c for c in X_frame.columns if c not in cat_cols]

    numeric_pipe = Pipeline(steps=[
        ("impute", SimpleImputer(strategy="median")),
        ("scale", StandardScaler()),
    ])

    categorical_pipe = Pipeline(steps=[
        ("impute", SimpleImputer(strategy="most_frequent")),
        ("onehot", make_onehot_encoder()),
    ])

    preprocess = ColumnTransformer(
        transformers=[
            ("num", numeric_pipe, num_cols),
            ("cat", categorical_pipe, cat_cols),
        ],
        remainder="drop",
    )
    return preprocess, num_cols, cat_cols


def make_group_holdout_split(X_frame, y_series, group_series, test_size=0.25, random_state=42):
    try:
        from sklearn.model_selection import StratifiedGroupKFold

        n_splits = int(round(1 / test_size))
        splitter = StratifiedGroupKFold(
            n_splits=n_splits,
            shuffle=True,
            random_state=random_state,
        )
        train_idx, test_idx = next(splitter.split(X_frame, y_series, group_series))
        strategy = f"StratifiedGroupKFold holdout (~{1/n_splits:.0%} test)"
    except Exception:
        splitter = GroupShuffleSplit(n_splits=1, test_size=test_size, random_state=random_state)
        train_idx, test_idx = next(splitter.split(X_frame, y_series, group_series))
        strategy = "GroupShuffleSplit holdout (fallback; not stratified)"
    return train_idx, test_idx, strategy


def make_group_cv(y_series, group_series, desired_splits=5, random_state=42):
    y_series = pd.Series(y_series)
    group_series = pd.Series(group_series)

    unique_groups = group_series.nunique()
    pos_groups = group_series[y_series == 1].nunique()
    neg_groups = group_series[y_series == 0].nunique()

    n_splits = min(desired_splits, unique_groups, pos_groups, neg_groups)
    if n_splits < 2:
        raise ValueError(
            f"Not enough groups to build a valid grouped CV splitter. "
            f"unique_groups={unique_groups}, pos_groups={pos_groups}, neg_groups={neg_groups}"
        )

    try:
        from sklearn.model_selection import StratifiedGroupKFold
        cv = StratifiedGroupKFold(
            n_splits=n_splits,
            shuffle=True,
            random_state=random_state,
        )
        cv_name = f"StratifiedGroupKFold ({n_splits} folds)"
    except Exception:
        cv = GroupKFold(n_splits=n_splits)
        cv_name = f"GroupKFold ({n_splits} folds fallback)"
    return cv, cv_name


def safe_metric(y_true, y_pred, y_prob):
    out = {
        "accuracy": accuracy_score(y_true, y_pred),
        "precision": precision_score(y_true, y_pred, zero_division=0),
        "recall": recall_score(y_true, y_pred, zero_division=0),
        "f1": f1_score(y_true, y_pred, zero_division=0),
    }

    try:
        out["roc_auc"] = roc_auc_score(y_true, y_prob)
    except Exception:
        out["roc_auc"] = np.nan

    try:
        out["pr_auc"] = average_precision_score(y_true, y_prob)
    except Exception:
        out["pr_auc"] = np.nan

    try:
        out["brier"] = brier_score_loss(y_true, y_prob)
    except Exception:
        out["brier"] = np.nan

    return out


def find_best_threshold(y_true, y_prob, model_name, thresholds=None):
    if thresholds is None:
        thresholds = np.round(np.arange(0.05, 0.951, 0.01), 2)

    rows = []
    for thr in thresholds:
        y_pred = (y_prob >= thr).astype(int)
        rows.append({
            "model": model_name,
            "threshold": thr,
            "accuracy": accuracy_score(y_true, y_pred),
            "precision": precision_score(y_true, y_pred, zero_division=0),
            "recall": recall_score(y_true, y_pred, zero_division=0),
            "f1": f1_score(y_true, y_pred, zero_division=0),
        })

    search_df = pd.DataFrame(rows).sort_values(
        ["f1", "recall", "precision", "threshold"],
        ascending=[False, False, False, True]
    ).reset_index(drop=True)

    best_threshold = float(search_df.loc[0, "threshold"])
    return best_threshold, search_df


def evaluate_estimator_with_threshold(name, estimator, threshold, X_train, y_train, X_test, y_test):
    fitted = clone(estimator)
    fitted.fit(X_train, y_train)

    y_prob = fitted.predict_proba(X_test)[:, 1]
    y_pred = (y_prob >= threshold).astype(int)

    metrics = safe_metric(y_test, y_pred, y_prob)
    metrics["model"] = name
    metrics["threshold"] = threshold

    pred_df = pd.DataFrame({
        "model": name,
        "y_true": y_test,
        "y_pred": y_pred,
        "y_prob": y_prob,
        "threshold_used": threshold,
    })

    return fitted, metrics, pred_df


def save_figure(fig, path: Path):
    fig.tight_layout()
    fig.savefig(path, dpi=150, bbox_inches="tight")
    plt.close(fig)



# ## 6) Create the held-out split and save a split manifest

train_idx, test_idx, holdout_strategy = make_group_holdout_split(
    X_frame=X,
    y_series=y,
    group_series=groups,
    test_size=0.25,
    random_state=RANDOM_STATE,
)

X_train = X.iloc[train_idx].reset_index(drop=True)
X_test = X.iloc[test_idx].reset_index(drop=True)
y_train = y.iloc[train_idx].reset_index(drop=True)
y_test = y.iloc[test_idx].reset_index(drop=True)
groups_train = groups.iloc[train_idx].reset_index(drop=True)
groups_test = groups.iloc[test_idx].reset_index(drop=True)

print("Holdout strategy:", holdout_strategy)
print("Train shape:", X_train.shape)
print("Test shape:", X_test.shape)
print("\nTrain prevalence:", y_train.mean().round(4))
print("Test prevalence:", y_test.mean().round(4))
print("Unique train subjects:", groups_train.nunique())
print("Unique test subjects:", groups_test.nunique())
print("Subjects shared across train/test:", len(set(groups_train).intersection(set(groups_test))))

assert len(set(groups_train).intersection(set(groups_test))) == 0, "Subject leakage across train/test split"

split_manifest = df[["stay_id", "subject_id", TARGET]].copy()
split_manifest["split"] = "train"
split_manifest.loc[test_idx, "split"] = "test"
split_manifest.to_csv(TABLES_DIR / "model_v1_1_split_manifest.csv", index=False)

split_manifest.head()



# ## 7) Build preprocessing and grouped cross-validation objects

preprocess, num_cols, cat_cols = build_preprocessor(X_train)
cv, cv_name = make_group_cv(y_train, groups_train, desired_splits=5, random_state=RANDOM_STATE)

print("Grouped CV strategy:", cv_name)
print("\nNumeric columns:", num_cols)
print("\nCategorical columns:", cat_cols)



# ## 8) Define model pipelines and tuning grids
#
# The tuning stays modest on purpose. The goal is not a giant search. The goal is to give each model a fair shot and keep the final story clean.

logreg_pipe = Pipeline(steps=[
    ("preprocess", preprocess),
    ("model", LogisticRegression(max_iter=5000, solver="liblinear")),
])

rf_pipe = Pipeline(steps=[
    ("preprocess", preprocess),
    ("model", RandomForestClassifier(random_state=RANDOM_STATE, n_jobs=-1)),
])

logreg_param_grid = {
    "model__C": [0.1, 1.0, 10.0],
    "model__class_weight": [None, "balanced"],
}

rf_param_grid = {
    "model__n_estimators": [300, 500],
    "model__max_depth": [None, 5, 10],
    "model__min_samples_leaf": [1, 2, 5],
    "model__class_weight": [None, "balanced"],
}



# ## 9) Run model selection inside the training set only

search_scoring = {
    "accuracy": "accuracy",
    "precision": "precision",
    "recall": "recall",
    "f1": "f1",
    "roc_auc": "roc_auc",
}

logreg_search = GridSearchCV(
    estimator=logreg_pipe,
    param_grid=logreg_param_grid,
    scoring=search_scoring,
    refit="f1",
    cv=cv,
    n_jobs=-1,
    verbose=1,
)

rf_search = GridSearchCV(
    estimator=rf_pipe,
    param_grid=rf_param_grid,
    scoring=search_scoring,
    refit="f1",
    cv=cv,
    n_jobs=-1,
    verbose=1,
)

logreg_search.fit(X_train, y_train, groups=groups_train)
rf_search.fit(X_train, y_train, groups=groups_train)

print("Best logistic regression params:")
print(logreg_search.best_params_)
print("Best logistic regression CV F1:", round(logreg_search.best_score_, 4))

print("\nBest random forest params:")
print(rf_search.best_params_)
print("Best random forest CV F1:", round(rf_search.best_score_, 4))



# ## 10) Save model-search results

logreg_search_results = pd.DataFrame(logreg_search.cv_results_).sort_values("rank_test_f1")
rf_search_results = pd.DataFrame(rf_search.cv_results_).sort_values("rank_test_f1")

logreg_search_results.to_csv(TABLES_DIR / "model_v1_1_search_results_logreg.csv", index=False)
rf_search_results.to_csv(TABLES_DIR / "model_v1_1_search_results_rf.csv", index=False)

display_cols_logreg = [
    "rank_test_f1",
    "mean_test_accuracy",
    "mean_test_precision",
    "mean_test_recall",
    "mean_test_f1",
    "mean_test_roc_auc",
    "param_model__C",
    "param_model__class_weight",
]
display_cols_rf = [
    "rank_test_f1",
    "mean_test_accuracy",
    "mean_test_precision",
    "mean_test_recall",
    "mean_test_f1",
    "mean_test_roc_auc",
    "param_model__n_estimators",
    "param_model__max_depth",
    "param_model__min_samples_leaf",
    "param_model__class_weight",
]

print("Top logistic regression search results:")
display(logreg_search_results[display_cols_logreg].head())

print("Top random forest search results:")
display(rf_search_results[display_cols_rf].head())



# ## 11) Save grouped cross-validation metrics for the chosen configurations

cv_scoring = {
    "accuracy": "accuracy",
    "precision": "precision",
    "recall": "recall",
    "f1": "f1",
    "roc_auc": "roc_auc",
    "pr_auc": "average_precision",
    "brier": "neg_brier_score",
}

best_logreg = logreg_search.best_estimator_
best_rf = rf_search.best_estimator_

cv_results = []

for model_name, estimator in [
    ("Logistic regression", best_logreg),
    ("Random forest", best_rf),
]:
    scores = cross_validate(
        estimator,
        X_train,
        y_train,
        cv=cv,
        groups=groups_train,
        scoring=cv_scoring,
        return_train_score=False,
        error_score="raise",
        n_jobs=-1,
    )

    n_folds = len(scores["test_f1"])
    for fold in range(n_folds):
        cv_results.append({
            "model": model_name,
            "fold": fold + 1,
            "accuracy": scores["test_accuracy"][fold],
            "precision": scores["test_precision"][fold],
            "recall": scores["test_recall"][fold],
            "f1": scores["test_f1"][fold],
            "roc_auc": scores["test_roc_auc"][fold],
            "pr_auc": scores["test_pr_auc"][fold],
            "brier": -scores["test_brier"][fold],
        })

cv_metrics_by_fold = pd.DataFrame(cv_results)
cv_metrics_summary = (
    cv_metrics_by_fold
    .groupby("model")[["accuracy", "precision", "recall", "f1", "roc_auc", "pr_auc", "brier"]]
    .agg(["mean", "std", "min", "max"])
)

cv_metrics_by_fold.to_csv(TABLES_DIR / "model_v1_1_cv_metrics_by_fold.csv", index=False)
cv_metrics_summary.to_csv(TABLES_DIR / "model_v1_1_cv_metrics_summary.csv")

cv_metrics_summary



# ## 12) Threshold tuning on training data only
#
# The earlier run showed that using the default 0.5 threshold produced zero positive predictions on the held-out test set.  
# That does not mean the model had no signal. It means the default threshold was too conservative for this class balance.
#
# So in v1.1:
# - I keep the held-out test untouched
# - I tune the classification threshold using **training-only out-of-fold probabilities**
# - then I carry that fixed threshold into the held-out test evaluation

logreg_oof_prob = cross_val_predict(
    best_logreg,
    X_train,
    y_train,
    cv=cv,
    groups=groups_train,
    method="predict_proba",
    n_jobs=-1,
)[:, 1]

rf_oof_prob = cross_val_predict(
    best_rf,
    X_train,
    y_train,
    cv=cv,
    groups=groups_train,
    method="predict_proba",
    n_jobs=-1,
)[:, 1]

logreg_threshold, logreg_threshold_search = find_best_threshold(
    y_true=y_train,
    y_prob=logreg_oof_prob,
    model_name="Logistic regression",
)

rf_threshold, rf_threshold_search = find_best_threshold(
    y_true=y_train,
    y_prob=rf_oof_prob,
    model_name="Random forest",
)

logreg_threshold_search.to_csv(TABLES_DIR / "model_v1_1_threshold_search_logreg.csv", index=False)
rf_threshold_search.to_csv(TABLES_DIR / "model_v1_1_threshold_search_rf.csv", index=False)

thresholds_selected = pd.DataFrame([
    {"model": "Logistic regression", "selected_threshold": logreg_threshold},
    {"model": "Random forest", "selected_threshold": rf_threshold},
])
thresholds_selected.to_csv(TABLES_DIR / "model_v1_1_thresholds_selected.csv", index=False)

print("Selected thresholds:")
display(thresholds_selected)

print("Top logistic threshold candidates:")
display(logreg_threshold_search.head(10))

print("Top random forest threshold candidates:")
display(rf_threshold_search.head(10))



# ## 13) Fit final models on training data and evaluate on held-out test data

baseline_clf = DummyClassifier(strategy="most_frequent")
baseline_clf.fit(X_train, y_train)

baseline_pred = baseline_clf.predict(X_test)
baseline_prob = baseline_clf.predict_proba(X_test)[:, 1]
baseline_metrics = safe_metric(y_test, baseline_pred, baseline_prob)
baseline_metrics["model"] = "Majority baseline"
baseline_metrics["threshold"] = np.nan

fitted_logreg, logreg_metrics, logreg_pred_df = evaluate_estimator_with_threshold(
    name="Logistic regression",
    estimator=best_logreg,
    threshold=logreg_threshold,
    X_train=X_train,
    y_train=y_train,
    X_test=X_test,
    y_test=y_test,
)

fitted_rf, rf_metrics, rf_pred_df = evaluate_estimator_with_threshold(
    name="Random forest",
    estimator=best_rf,
    threshold=rf_threshold,
    X_train=X_train,
    y_train=y_train,
    X_test=X_test,
    y_test=y_test,
)

test_metrics = pd.DataFrame([baseline_metrics, logreg_metrics, rf_metrics])
test_metrics = test_metrics[
    ["model", "threshold", "accuracy", "precision", "recall", "f1", "roc_auc", "pr_auc", "brier"]
].sort_values("f1", ascending=False)

test_metrics.to_csv(TABLES_DIR / "model_v1_1_test_metrics.csv", index=False)
test_metrics.to_csv(TABLES_DIR / "model_v1_1_model_comparison.csv", index=False)

test_metrics



# ## 14) Save held-out predictions and model files

predictions = df.iloc[test_idx][["stay_id", "subject_id", TARGET]].copy().reset_index(drop=True)
predictions = predictions.rename(columns={TARGET: "y_true"})

predictions["pred_majority_baseline"] = baseline_pred
predictions["prob_majority_baseline"] = baseline_prob

predictions["pred_logreg"] = logreg_pred_df["y_pred"].values
predictions["prob_logreg"] = logreg_pred_df["y_prob"].values
predictions["threshold_logreg"] = logreg_threshold

predictions["pred_random_forest"] = rf_pred_df["y_pred"].values
predictions["prob_random_forest"] = rf_pred_df["y_prob"].values
predictions["threshold_random_forest"] = rf_threshold

predictions.to_csv(TABLES_DIR / "model_v1_1_test_predictions.csv", index=False)

joblib.dump(fitted_logreg, MODELS_DIR / "model_v1_1_logreg.joblib")
joblib.dump(fitted_rf, MODELS_DIR / "model_v1_1_random_forest.joblib")

predictions.head()



# ## 15) ROC and precision-recall curves

fig, ax = plt.subplots()
for label, probs in [
    ("Logistic regression", logreg_pred_df["y_prob"].values),
    ("Random forest", rf_pred_df["y_prob"].values),
]:
    fpr, tpr, _ = roc_curve(y_test, probs)
    roc_auc = roc_auc_score(y_test, probs)
    ax.plot(fpr, tpr, label=f"{label} (AUC={roc_auc:.3f})")

ax.plot([0, 1], [0, 1], linestyle="--")
ax.set_xlabel("False Positive Rate")
ax.set_ylabel("True Positive Rate")
ax.set_title("Held-out ROC Curve Comparison (v1.1)")
ax.legend(loc="lower right")
save_figure(fig, FIGURES_DIR / "model_v1_1_roc_curve_comparison.png")

fig, ax = plt.subplots()
prevalence = y_test.mean()
for label, probs in [
    ("Logistic regression", logreg_pred_df["y_prob"].values),
    ("Random forest", rf_pred_df["y_prob"].values),
]:
    precision, recall, _ = precision_recall_curve(y_test, probs)
    ap = average_precision_score(y_test, probs)
    ax.plot(recall, precision, label=f"{label} (AP={ap:.3f})")

ax.axhline(prevalence, linestyle="--", label=f"Prevalence={prevalence:.3f}")
ax.set_xlabel("Recall")
ax.set_ylabel("Precision")
ax.set_title("Held-out Precision-Recall Curve Comparison (v1.1)")
ax.legend(loc="best")
save_figure(fig, FIGURES_DIR / "model_v1_1_precision_recall_curve_comparison.png")



# ## 16) Confusion matrices

for label, preds, filename in [
    ("Logistic regression", logreg_pred_df["y_pred"].values, "model_v1_1_confusion_matrix_logreg.png"),
    ("Random forest", rf_pred_df["y_pred"].values, "model_v1_1_confusion_matrix_rf.png"),
]:
    fig, ax = plt.subplots()
    cm = confusion_matrix(y_test, preds)
    disp = ConfusionMatrixDisplay(confusion_matrix=cm)
    disp.plot(ax=ax, colorbar=False)
    ax.set_title(f"Held-out Confusion Matrix — {label} (v1.1)")
    save_figure(fig, FIGURES_DIR / filename)



# ## 17) Logistic regression coefficients

feature_names_logreg = fitted_logreg.named_steps["preprocess"].get_feature_names_out()
logreg_coefs = fitted_logreg.named_steps["model"].coef_.ravel()

logreg_coef_df = pd.DataFrame({
    "feature": feature_names_logreg,
    "coef": logreg_coefs,
})
logreg_coef_df["abs_coef"] = logreg_coef_df["coef"].abs()
logreg_coef_df = logreg_coef_df.sort_values("abs_coef", ascending=False)

logreg_coef_df.to_csv(TABLES_DIR / "model_v1_1_logreg_coefficients.csv", index=False)

plot_df = pd.concat([
    logreg_coef_df.sort_values("coef", ascending=False).head(10),
    logreg_coef_df.sort_values("coef", ascending=True).head(10),
]).drop_duplicates()

fig, ax = plt.subplots(figsize=(9, 7))
plot_df = plot_df.sort_values("coef")
ax.barh(plot_df["feature"], plot_df["coef"])
ax.set_title("Logistic Regression Coefficients (Top Positive / Negative) — v1.1")
ax.set_xlabel("Coefficient")
save_figure(fig, FIGURES_DIR / "model_v1_1_logreg_coefficients.png")

logreg_coef_df.head(15)



# ## 18) Random forest feature importance

feature_names_rf = fitted_rf.named_steps["preprocess"].get_feature_names_out()
rf_importances = fitted_rf.named_steps["model"].feature_importances_

rf_importance_df = pd.DataFrame({
    "feature": feature_names_rf,
    "importance": rf_importances,
}).sort_values("importance", ascending=False)

rf_importance_df.to_csv(TABLES_DIR / "model_v1_1_rf_feature_importance.csv", index=False)

plot_df = rf_importance_df.head(20).sort_values("importance")
fig, ax = plt.subplots(figsize=(9, 7))
ax.barh(plot_df["feature"], plot_df["importance"])
ax.set_title("Random Forest Feature Importance (Top 20) — v1.1")
ax.set_xlabel("Importance")
save_figure(fig, FIGURES_DIR / "model_v1_1_rf_feature_importance.png")

rf_importance_df.head(20)



# ## 19) Final artifact check
#
# If everything above ran successfully, the main Phase C artifacts for the v1.1 rerun should now exist under `../outputs/`.
#
# At that point, the next work shifts to:
#
# 1. updating `08_model_evaluation_comparison.md` with actual frozen results  
# 2. updating `09_model_selection_recommendation.md`  
# 3. assembling the final Assignment 2 report around the v1.1 artifact set
