# 00 — Master Tracker (Case Studies in Data Science)

## Current status (last updated: 2026-03-04)
- Today: **2026-03-04 (America/Chicago)**
- Current module: **M7 (Data Preparation — Part 2)**
- Current objective (1 sentence):
  Complete the Module 7 process diary and finalize a reproducible Data Preparation workflow (select → clean → construct → integrate → format) to support Assignment 2 modeling.

### Course progress (graded checkpoints)
- ✅ Assignment 0: Case Selection — **100%** (2026-01-20)
- ✅ Business Understanding Quiz — **100%** (2026-01-26)
- ✅ Module 3 Process Diary — **100%** (2026-02-02)
- ✅ Data Understanding Quiz — **100%** (2026-02-09)
- ✅ Assignment 1: Business & Data Understanding Report — **100%** (2026-02-16)
- ✅ Assignment 1: Show Your Work — submitted (2026-02-16)
- ✅ Data Preparation Quiz — **100%** (2026-02-23)
- ⚠️ Module 7 Process Diary — **due/overdue; in progress today**

- Risk level: **Low–Medium**
  - Low: You already have reproducible SQL artifacts and a prepared dataset path.
  - Medium: Process diary is overdue + you want to keep documentation tight and consistent for grading.

### Next 3 actions (highest ROI)
1) **Submit Module 7 process diary** (tight narrative: what you did, what you learned, what’s next, blockers).
2) **Write Data Prep documentation artifacts** (brief but concrete): selection rationale + cleaning decisions + constructed feature definitions.
3) **Lock “v1” prepared dataset + schema description** (so M8/M9 modeling isn’t fighting moving targets).

---

## Course map (CRISP-DM alignment)
- Unit 1 (M1–M5): Business Understanding + Data Understanding → **Assignment 1 (DONE, 100%)**
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
- [x] Module content completed
- [x] Stakeholders + decisions drafted
- [x] Initial success criteria drafted
- [x] Assumptions/risks drafted

### M3 — Business Understanding (Part 2)
- [x] Background + constraints/risks refined
- [x] Data science goals + success criteria drafted
- [x] Project plan drafted
- [x] Module 3 process diary submitted (100%)

### M4 — Data Understanding (Part 1)
- [x] Load demo dataset into Postgres (local)
- [x] Confirm keys/grains/join routes (subject_id / hadm_id / stay_id)
- [x] ERD v1 exported
- [x] PK/FK constraints applied locally for guardrails/tooling
- [x] SQL artifacts saved in `data/sql/` (01/02/03…)

### M5 — Data Understanding (Part 2) + Assignment 1
- [x] Assignment 1 report submitted
- [x] Assignment 1 graded (100%)
- [x] Show-your-work artifacts submitted

### M6 — Data Preparation (Part 1)
- [x] Data Preparation quiz graded (100%)
- [x] Prepared dataset direction established (stay_id grain, 0–24h window)
- [x] Early-window feature engineering pipeline exists (SQL scripts + derived tables)
- [~] Documentation for “Select Data” + “Clean Data” (exists in pieces; consolidate)

### M7 — Data Preparation (Part 2) + Process Diary
- [ ] Module 7 process diary submitted (overdue)
- [ ] “Construct Data” documentation: feature definitions + leakage rule + missingness strategy
- [ ] “Integrate Data” documentation: join keys, grain, and integration logic
- [ ] “Format Data” decision: modeling-ready table spec (columns, types, encoding, missing handling)

### M8 — Modeling (Part 1)
### M9 — Modeling (Part 2) + Assignment 2
### M10 — Evaluation (Part 1)
### M11 — Evaluation (Part 2)
### M12 — Deployment (Part 1)
### M13 — Deployment (Part 2) + Assignment 3
### M14 — Wrap-up

---

## Milestones (submission readiness checks)

### Assignment 1 — Business & Data Understanding (M5)
- [x] Submitted
- [x] Graded **100%**
- [x] Show-your-work submitted

### Assignment 2 — Data Preparation & Modeling (M9)
**Must have:**
- [ ] Prepared dataset(s) in `data/processed/` with a stable schema (v1)
- [ ] Data preparation documentation (selection + cleaning + feature construction + integration + formatting)
- [ ] Modeling notebook(s) + baseline metrics
- [ ] Decisions logged (feature choices, model selection, evaluation approach)
- [ ] Report/Writeup submitted (per course instructions)

### Assignment 3 — Final Report + Slides (M13)
**Must have:**
- [ ] Final report (PDF)
- [ ] Slides deck (PPTX/PDF)
- [ ] Deployment + monitoring plan
- [ ] Reflection + process diary entry

---

## Notes / parking lot (updated)

### What’s already solid (don’t reopen unless necessary)
- Grain: ICU stay (`stay_id`) is the primary modeling unit (for current pipeline).
- Predictor timing: early-window restriction (0–24h from ICU `intime`) prevents leakage.
- Prepared dataset exists as a stable “v1” artifact (CSV + derived table).

### Current focus for M7 (Data Preparation documentation)
- Select Data:
  - What tables/fields are included for v1 modeling and why (and what is excluded).
- Clean Data:
  - Type normalization strategy (text-ingest → derived casts), timestamp sanity checks, missingness handling.
- Construct Data:
  - How vitals features are constructed (min/max/mean/first/last), missingness indicators, measurement-density features.
- Integrate Data:
  - How admissions context joins to icustays; how chartevents aggregates to stay grain.
- Format Data:
  - Final modeling table layout, column list, outcome definition, encoding and missing handling.

### Open questions (only if time allows)
- Sensitivity check on prolonged LOS threshold (optional; only if it affects modeling credibility).
- Whether to pursue readmission/return-risk as a secondary outcome later (likely hadm_id grain).

