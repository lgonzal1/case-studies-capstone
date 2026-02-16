# Case Studies in Data Science — Capstone (CRISP-DM)

This repository contains an end-to-end ICU case study for my University of Pittsburgh MDS capstone course, organized using the CRISP-DM lifecycle:

**Business Understanding → Data Understanding → Data Preparation → Modeling → Evaluation → Deployment**

**Portfolio note:** This project uses the **MIMIC-IV Clinical Database Demo** (de-identified, public), and contains **no PHI / HIPAA-regulated data**.

## Start here
- **Assignment 1 (M5)** report materials: `reports/assignment_1/`
  - LaTeX source: `reports/assignment_1/main.tex`
  - Bibliography: `reports/assignment_1/ref.bib`
  - Figures: `reports/assignment_1/figures/`
- Course milestone reports (working markdown):
  - `reports/M03_business_understanding.md`
  - `reports/M05_assignment1.md`
  - `reports/M09_assignment2.md`
  - `reports/M13_assignment3.md`

## Repository structure (high level)
- `data/raw/` — source dataset (kept in-place; may be excluded from Git depending on distribution/license constraints)
- `data/interim/` — intermediate extracts / staging outputs
- `data/processed/` — modeling-ready datasets (e.g., `icu_stay_level_features.csv`)
- `data/sql/` — reproducible SQL used for inventory, constraints, quality checks, and feature extraction
- `notebooks/` — EDA / analysis notebooks
- `outputs/` — generated figures/tables/models intended for reuse across reports
- `docs/` — process artifacts (tracker, diary, decision log, assumptions/risks, AI use)

## Data source
This project uses the MIMIC-IV Clinical Database Demo (v2.2) dataset layout as provided under:
`data/raw/ICU Patients/data/raw/` (hosp + icu modules).

Notes:
- Timestamps are **date-shifted** for de-identification (intervals within an encounter are preserved).
- The demo cohort is **small by design** (100 patients), so some outcomes and subgroup analyses require feasibility gates.

## How to run (local)
### Using uv (recommended)
```bash
uv sync
uv run jupyter lab

