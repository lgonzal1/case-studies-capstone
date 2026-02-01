# 00 — Master Tracker (Case Studies in Data Science)

## Current status
- Current module: M3 (process diary submitted; moving into M4 next)
- Current objective (1 sentence):
  Lock a defensible QI-style story by finalizing unit-of-analysis + outcome definitions (readmission + prolonged ICU stay), then validate feasibility with a quick inventory pass before deeper modeling.
- Next deadline: 2026-02-09 M4 Data Understanding Quiz

- Risk level: Medium (mostly due to N≈100 + sparsity + subgroup sizes)
- Next 3 actions:
  1. Update repo artifacts: master tracker + decision log + assumptions/risks refresh (commit + push)
  2. Load MIMIC-IV demo tables into local Postgres for SQL-first exploration (rowcounts, keys, join routes)
  3. Feasibility pass + ERD: confirm readmission counts + prolonged ICU stay distribution; draft ER diagram to stabilize the “schema mental model”

---

## Course map (CRISP-DM alignment)
- Unit 1 (M1–M5): Business Understanding + Data Understanding → **Assignment 1** DUE 2026-02-16
- Unit 2 (M6–M9): Data Preparation + Modeling → **Assignment 2**
- Unit 3 (M10–M13): Evaluation + Deployment → **Assignment 3**
- M14: wrap-up / synthesis

---

## Module checklist (definition of done)

### M1 — Intro + CRISP-DM
- [x] Repo skeleton created
- [x] README has run instructions + repo map
- [x] Environment reproducible (uv or venv)
- [x] Tracker/diary/decision log created

### M2 — Business Understanding (Part 1)
- [x] Module content completed (videos/readings/quiz)
- [~] Stakeholders + decision(s) they need to make (drafted; tighten decision statements to 1–2)
- [~] Initial success criteria draft (business + technical) (drafted; refine thresholds + feasibility)
- [x] Add 3–5 assumptions/risks to docs (drafted; needs minor refresh)

### M3 — Business Understanding (Part 2)
- [x] Module overview complete
- [x] Background section reading complete
- [x] Constraints + risks refined (short + realistic)
- [ ] “Perverse incentives” check (what could be misinterpreted / gamed)
- [x] Data science goals + success criteria drafted
- [x] Project plan drafted
- [x] Module 3 process diary entry written + submitted


### M4 — Data Understanding (Part 1)
- [ ] Load demo dataset into Postgres (local)
- [ ] Confirm keys, grains, and join routes (subject_id / hadm_id / stay_id)
- [ ] Table inventory: rowcounts + coverage (events density, missingness patterns)
- [ ] ERD v1 drafted (dbdiagram.io or similar)

### M5 — Data Understanding (Part 2) + **Assignment 1 due**
- [ ] Assignment 1 report assembled (BU + DU sections)
- [ ] EDA artifacts included (figures/tables + data quality summary)
- [ ] Decision log + assumptions/risks updated and referenced in report

### M6 — Data Prep (Part 1)
### M7 — Data Prep (Part 2)
### M8 — Modeling (Part 1)
### M9 — Modeling (Part 2) + **Assignment 2 due**
### M10 — Evaluation (Part 1)
### M11 — Evaluation (Part 2)
### M12 — Deployment (Part 1)
### M13 — Deployment (Part 2) + **Assignment 3 due**
### M14 — Wrap-up

---

## Milestones (submission readiness checks)

### Assignment 1 — Business & Data Understanding (M5)
**Must have:**
- [ ] `reports/M05_assignment1.md` (or PDF)
- [ ] Notebooks: data inventory + EDA (or SQL-first equivalent with saved outputs)
- [ ] `docs/` updated: assumptions/risks + decisions + process diary entry
- [ ] Repo ZIP passes: “someone else can follow this”

### Assignment 2 — Data Prep & Modeling (M9)
**Must have:**
- [ ] `reports/M09_assignment2.md` (or PDF)
- [ ] Prepared dataset(s) in `data/processed/`
- [ ] Modeling notebooks + metrics artifacts
- [ ] Decisions logged (feature choices, model selection)

### Assignment 3 — Final Report + Slides (M13)
**Must have:**
- [ ] `reports/M13_assignment3.md` (or PDF)
- [ ] `reports/M13_exec_slides.pptx` (or PDF)
- [ ] Deployment + monitoring plan section
- [ ] Reflection + process diary entry 3
- [ ] Repo integrated and tidy

---

## Notes / parking lot

### Open questions (next to resolve)
- Unit of analysis:
  - ICU stay-level (`stay_id`) vs admission-level (`hadm_id`) vs patient-level (`subject_id`)
  - If “readmission” is a primary outcome, definition probably needs to be admission-level, then linked back to ICU exposure
- Outcomes feasibility with N≈100:
  - Hospital readmission / return visits: early EDA suggests this might actually have enough signal, but confirm counts formally
  - Prolonged ICU stay: pick a literature-backed threshold (likely varies by ICU type/condition), then sanity-check distribution in the demo cohort
- Cohort strategy:
  - ICU subtypes/pathways: cardiac, neuro, trauma, sepsis, other
  - Risk: over-segmentation → fallback to fewer buckets or pooled analysis with “reason codes”
- Early-window feature engineering (avoid leakage):
  - Candidate window: 6–24 hours after ICU admit
  - Feasibility depends on early labs/vitals density in demo tables
- Data completeness / measurement bias:
  - How sparse are `chartevents`, `labevents`, `inputevents`, `procedureevents`?
  - Is missingness systematic (sicker patients get measured more → bias)?
- Stakeholder decision clarity:
  - Tighten to 1–2 decisions (ex: “which sub-cohorts drive disproportionate ICU resource use?” and “what early signals predict prolonged stay/readmission risk?”)
- Workflow/tooling:
  - Postgres-first EDA for repeatability + cleaner joins
  - ERD is a requirement for staying sane once SQL exploration starts

### Things to look up later
- Literature thresholds for “prolonged ICU stay” (overall + condition-specific where relevant)
- ICD-based cohort mapping starter list (Cardiac/Neuro/Trauma/Sepsis/Other)
- Optional: sanity-check cohort definitions with a domain expert (if needed)