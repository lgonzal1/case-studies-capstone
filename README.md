# Case Studies in Data Science — Capstone (CRISP-DM)

This repository contains an end-to-end ICU case study for my University of Pittsburgh MDS capstone course, organized using the CRISP-DM lifecycle:

**Business Understanding → Data Understanding → Data Preparation → Modeling → Evaluation → Deployment**

**Portfolio note:** This project uses the **MIMIC-IV Clinical Database Demo** (de-identified, public) and contains **no PHI / HIPAA-regulated data**.

## Project summary

The project is framed as an early risk-identification problem:

> Can information available within the first 24 hours of ICU admission be used to identify stays that are more likely to become prolonged ICU stays?

The current final Assignment 2 workflow uses:

- **Unit of analysis:** ICU stay (`stay_id`)
- **Prediction window:** first 24 hours after ICU admission
- **Outcome:** `prolonged_los_8d = 1` if ICU LOS >= 8 days
- **Final prepared dataset:** `data/processed/icu_stay_modeling_24h_v1_1.csv`
- **Final recommended model:** logistic regression
- **Comparison models:** majority-class baseline, logistic regression, random forest

This repository includes both the broader course project history and the final Assignment 2 artifacts used in the technical report and Show Your Work submission.

---

## Start here

### Final Assignment 2 report materials
- `reports/assignment_2/`
  - LaTeX source: `reports/assignment_2/main.tex`
  - Bibliography: `reports/assignment_2/ref.bib`
  - Figures used in report: `reports/assignment_2/figures/`

### Assignment 2 source docs
- `reports/assignment_2/01_select_data_rationale.md`
- `reports/assignment_2/02_clean_data_report.md`
- `reports/assignment_2/03_feature_spec.md`
- `reports/assignment_2/04_integration_lineage.md`
- `reports/assignment_2/05_format_data_notes.md`
- `reports/assignment_2/06_modeling_strategy.md`
- `reports/assignment_2/07_model_development.md`
- `reports/assignment_2/08_model_evaluation_comparison.md`
- `reports/assignment_2/09_model_selection_recommendation.md`

### Assignment 1 report materials
- `reports/assignment_1/`
  - LaTeX source: `reports/assignment_1/main.tex`
  - Bibliography: `reports/assignment_1/ref.bib`
  - Figures: `reports/assignment_1/figures/`

### Course milestone notes
- `reports/M03_business_understanding.md`
- `reports/M05_assignment1.md`
- `reports/M09_assignment2.md`
- `reports/M13_assignment3.md`

---

## Repository structure (high level)

- `data/raw/` — source dataset (kept in-place; may be excluded from Git depending on license/distribution constraints)
- `data/interim/` — intermediate extracts / staging outputs
- `data/processed/` — final modeling-ready datasets
- `data/sql/` — reproducible SQL for inventory, QA, feature construction, and modeling table builds
- `notebooks/` — EDA and modeling notebooks
- `outputs/` — generated figures, tables, and saved models
- `docs/` — project-wide process artifacts (tracker, diary, decision log, dataset notes, AI use)
- `reports/` — assignment reports and course milestone writeups
- `scripts/` — replay / utility scripts for rebuilding final artifacts

---

## Final Assignment 2 artifacts

### Final prepared dataset
- `data/processed/icu_stay_modeling_24h_v1_1.csv`

### Final dataset documentation
- `outputs/tables/icu_stay_modeling_24h_v1_1_schema.csv`

### Final model artifacts
- `outputs/models/` — saved final models
- `outputs/tables/model_v1_1_*` — metrics, predictions, coefficients, feature importances, threshold outputs, and search summaries
- `outputs/figures/model_v1_1_*` — ROC / PR curves, confusion matrices, coefficient plot, feature importance plot

### Final report-facing figures
- `reports/assignment_2/figures/`

---

## Data source

This project uses the **MIMIC-IV Clinical Database Demo (v2.2)** dataset layout as provided under:

`data/raw/ICU Patients/data/raw/`

This includes the `hosp` and `icu` modules used for the project workflow.

### Notes
- timestamps are **date-shifted** for de-identification, while intervals within encounters are preserved
- the demo cohort is **small by design**, so model performance should be interpreted as proof of concept rather than production validation
- the small cohort size is one reason the project emphasizes reproducibility, interpretability, and careful leakage control over headline performance

---

## Final Assignment 2 workflow

The final Assignment 2 workflow uses a small number of versioned, reproducible steps.

### Data preparation
The final prepared dataset is built from:

- early-window stay-level vitals features
- grouped context variables
- a small early lab panel
- a final stay-level modeling table

#### Main SQL scripts of record
- `data/sql/07_construct_vitals_24h_features.sql`
- `data/sql/10_assignment2_feature_audit_v1_1.sql`
- `data/sql/11_construct_labs_24h_features_v1_1.sql`
- `data/sql/12_build_modeling_table_icu_stay_24h_v1_1.sql`

#### Replay script
- `scripts/run_v1_1_pipeline.sh`

### Modeling
The final model comparison is based on:

- majority-class baseline
- logistic regression
- random forest

The final comparison is run on the `v1_1` dataset and uses:
- subject-aware splitting
- grouped cross-validation inside training
- training-only preprocessing
- training-only threshold tuning
- held-out test evaluation

#### Final modeling notebook / script
- `notebooks/10_final_model_comparison_v1_1.ipynb`
- `notebooks/10_final_model_comparison_v1_1.py`

---

## How to run (local)

### Python environment
Using `uv` (recommended):

```bash
uv sync
uv run jupyter lab
```

If using another environment manager, install the dependencies from `pyproject.toml`.

---

## Rebuild the final Assignment 2 prepared dataset

Set your Postgres connection first:

```bash
export PGURI='host=localhost port=5432 dbname=mimic_demo user=mimic_reader'
```

Then run:

```bash
./scripts/run_v1_1_pipeline.sh
```

This rebuilds the final Assignment 2 data preparation pipeline and exports:

- `data/processed/icu_stay_modeling_24h_v1_1.csv`
- `outputs/tables/icu_stay_modeling_24h_v1_1_schema.csv`

---

## Run the final Assignment 2 model comparison

After the final prepared dataset exists, run the final comparison notebook or script:

```bash
jupyter lab notebooks/10_final_model_comparison_v1_1.ipynb
```

or execute the script version if preferred.

This produces the final saved models, metrics, predictions, and diagnostic figures under `outputs/`.

---

## Notes on historical vs final artifacts

This repository contains both:
- earlier exploratory / Assignment 1 artifacts
- final Assignment 2 artifacts

For Assignment 2 grading and reproduction, the main source of truth is the **v1.1 workflow**:
- final dataset: `icu_stay_modeling_24h_v1_1.csv`
- final outputs: `model_v1_1_*`
- final report: `reports/assignment_2/`

Earlier artifacts are preserved for project continuity and documentation, but they are not the final Assignment 2 evidence set unless explicitly referenced.

---

## Reproducibility and intent

This project is intended to show:
- disciplined data preparation
- leakage-aware modeling
- reproducible analytical workflow
- interpretable proof-of-concept modeling in a realistic healthcare data setting

It is **not** intended to claim production readiness from a demo cohort alone. The final Assignment 2 result should be interpreted as a feasible early operational modeling workflow and a reproducible capstone proof of concept.
