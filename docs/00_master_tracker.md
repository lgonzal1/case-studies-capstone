# 00 — Master Tracker (Case Studies in Data Science)

## Current status
- Current module: M3
- Current objective (1 sentence):
  Translate the ICU Patient Care Analysis context into a crisp QI-style problem statement, with measurable business + technical success criteria, and explicit assumptions/risks.
- Next deadline: 2026-02-02 (Module 03 Process Diary, 10:59 PM CST)
- Risk level: Medium
- Next 3 actions:
  1. M3 writing: draft Background + Business Objectives/Success Criteria (drop into `reports/M05_assignment1_draft.md`)
  2. M3 writing: draft Data Science Goals/Success Criteria + “Assessment of Responsibility” (ethics/limitations)
  3. Update `docs/assumptions_risks.md` (3–5 bullets) + add “perverse incentives” note

---

## Course map (CRISP-DM alignment)
- Unit 1 (M1–M5): Business Understanding + Data Understanding → **Assignment 1**
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
- [ ] Stakeholders + decision(s) they need to make (even if fictional)
- [ ] Initial success criteria draft (business + technical)
- [ ] Add 3–5 assumptions/risks to docs

### M3 — Business Understanding (Part 2)
- [x] Module overview complete
- [x] Background section reading complete
- [ ] Constraints + risks refined (short + realistic)
- [ ] “Perverse incentives” check (what could be misinterpreted / gamed)
- [ ] Data science goals + success criteria drafted
- [ ] Project plan drafted (high level is fine)
- [ ] Module 3 process diary entry written

### M4 — Data Understanding (Part 1)


### M5 — Data Understanding (Part 2) + **Assignment 1 due**

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
- [ ] Notebooks: data inventory + EDA
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
- Open questions:
  - What is the best unit of analysis for this dataset?
    - ICU stay-level (`stay_id`) vs admission-level (`hadm_id`) vs patient-level (`subject_id`)
    - How many patients have multiple ICU stays or multiple admissions (i.e., is “recidivism” even measurable in the demo subset)?
  - Which primary outcome(s) are feasible and tell a defensible QI-style story with N≈100?
    - ICU LOS vs hospital LOS
    - In-hospital mortality (is event count sufficient?)
    - ICU transfer patterns / stepdown / ICU bounceback (if supported)
    - Readmission/return visits (likely limited — confirm)
  - Cohort strategy: what’s the most defensible way to group ICU stays into high-level pathways without over-segmenting?
    - ICD-based cohorts (cardiac/neuro/trauma/sepsis/other) vs care-unit-based vs hybrid (ICD + procedures + meds/labs)
    - Do we have enough cases per cohort to model separately, or do we need fewer buckets?
  - What is a defensible “early window” for feature extraction that avoids leakage?
    - 6h vs 12h vs 24h from ICU admit (confirm timestamp density supports this)
  - Data completeness check:
    - How sparse are `chartevents`, `labevents`, `inputevents`, `procedureevents` in the demo subset?
    - Is missingness systematic (sicker patients measured more often → bias)?
  - Stakeholder decision clarity:
    - What exact decision(s) should this analysis inform (protocol changes, resource allocation, early risk flagging, etc.)?
    - What “success” looks like in measurable-ish terms for a class project (since real deployment impact isn’t measurable here)
  - Workflow/tooling:
    - Load into Postgres now for repeatable SQL EDA vs stay Python/pandas-first until inventory is done
    - If Postgres: do we need a lightweight ERD/db diagram to document joins and grains?
- Things to look up later:
  - ICD10 codes for specific ICU cohorts (Cardiac, Neuro, Trauma, Sepsis, Other)
    - Verify with Dr. Gibney (UCI Health) whether this cohort mental model is “good enough” for a capstone framing

