# Case Studies in Data Science — Capstone (CRISP-DM)

This repository contains a single end-to-end case study for my University of Pittsburgh MDS capstone course.
Work is organized using the CRISP-DM lifecycle: Business Understanding → Data Understanding → Data Preparation → Modeling → Evaluation → Deployment.

**Portfolio note:** This project uses non-sensitive coursework data (no PHI/EHR/HIPAA data).

## Start here
- Assignment 1 report (M5): `reports/M05_assignment1.md` (exported PDF later)
- Assignment 2 report (M9): `reports/M09_assignment2.md`
- Assignment 3 final report + slides (M13): `reports/M13_assignment3.md`

## Repository structure
- `data/raw/` — provided dataset (unchanged; may not be committed to Git)
- `data/processed/` — modeling-ready datasets created during prep
- `notebooks/` — analysis notebooks (numbered in workflow order)
- `outputs/` — figures/tables/models referenced in reports
- `docs/` — scope, decisions, assumptions/risks, process diary
- `reports/` — written reports aligned to course assignments

## How to run
### Using uv (recommended)
- `uv sync`
- `uv run jupyter lab`

### Using venv + pip (fallback)
- `python3 -m venv .venv && source .venv/bin/activate`
- `pip install -r requirements.txt`
- `jupyter lab`

## Data note
The dataset may be provided through coursework and may not be licensed for public redistribution.
Raw data is kept in `data/raw/` and may be excluded from Git. If needed for course submission, it will be included in the submission ZIP.
