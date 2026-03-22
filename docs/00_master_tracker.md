# 00 — Master Tracker (Case Studies in Data Science)

## Current status (last updated: 2026-03-22)
- Today: **2026-03-22 (America/Chicago)**
- Current module: **M9 closeout → Assignment 2 report assembly**
- Current objective (1 sentence):
  Assemble the final Assignment 2 report PDF from frozen artifacts, complete final QA, and package the Show Your Work submission.

### Course progress (graded checkpoints)
- ✅ Assignment 0: Case Selection — **100%** (2026-01-20)
- ✅ Business Understanding Quiz — **100%** (2026-01-26)
- ✅ Module 3 Process Diary — **100%** (2026-02-02)
- ✅ Data Understanding Quiz — **100%** (2026-02-09)
- ✅ Assignment 1: Business & Data Understanding Report — **100%** (2026-02-16)
- ✅ Assignment 1: Show Your Work — submitted (2026-02-16)
- ✅ Data Preparation Quiz — **100%** (2026-02-23)
- ✅ Module 7 Process Diary — **submitted**
- ✅ Modules 6–9 assignment-context packets reviewed and consolidated
- ✅ Assignment 2 end-state clarified (report + separate Show Your Work package)

### Assignment 2 execution status
- ✅ Section 1 Data Preparation source artifacts drafted and aligned
- ✅ Modeling protocol locked
- ✅ Final experiment notebook/script created
- ✅ Initial final-model pass completed
- ✅ Methodology issue identified and corrected (threshold handling)
- ✅ Targeted v1.1 feature audit completed
- ✅ v1.1 feature refresh completed
- ✅ v1.1 modeling table rebuilt
- ✅ Final v1.1 comparison run completed
- ✅ Final metrics / plots / saved models frozen
- ✅ Final recommendation selected: **logistic regression**
- ✅ Section 2 source docs (`06`–`09`) drafted in final form
- ⏳ Final combined Assignment 2 report still needs assembly and PDF export
- ⏳ Final Show Your Work package still needs final QA and submission

- Risk level: **Low–Medium**
  - Low: methodology is locked; artifacts exist; recommendation is clear.
  - Medium: final submission still depends on clean report assembly, final QA, and packaging.

### Next 3 actions (highest ROI)
1) **Assemble the final Assignment 2 report** (Introduction + Section 1 + Section 2 + Conclusion) from frozen artifacts.
2) **Run final checklist / tracker / package QA** so the PDF and Show Your Work submission match the repository evidence exactly.
3) **Submit Assignment 2** and update this tracker to post-submission state.

---

## Course map (CRISP-DM alignment)
- Unit 1 (M1–M5): Business Understanding + Data Understanding → **Assignment 1 (DONE, 100%)**
- Unit 2 (M6–M9): Data Preparation + Modeling → **Assignment 2 (ACTIVE, FINAL ASSEMBLY)**
- Unit 3 (M10–M13): Evaluation + Deployment → **Assignment 3**
- M14: wrap-up / synthesis

---

## Module checklist (definition of done)

### M1 — Intro + CRISP-DM
- [x] Repo skeleton created
- [x] README has run instructions + repo map
- [x] Environment reproducible (uv or venv)
- [x] Tracker / diary / decision log created

### M2 — Business Understanding (Part 1)
- [x] Module content completed
- [x] Stakeholders + decisions drafted
- [x] Initial success criteria drafted
- [x] Assumptions / risks drafted

### M3 — Business Understanding (Part 2)
- [x] Background + constraints / risks refined
- [x] Data science goals + success criteria drafted
- [x] Project plan drafted
- [x] Module 3 process diary submitted (100%)

### M4 — Data Understanding (Part 1)
- [x] Load demo dataset into Postgres (local)
- [x] Confirm keys / grains / join routes (`subject_id` / `hadm_id` / `stay_id`)
- [x] ERD v1 exported
- [x] PK/FK constraints applied locally for guardrails / tooling
- [x] SQL artifacts saved in `data/sql/`

### M5 — Data Understanding (Part 2) + Assignment 1
- [x] Assignment 1 report submitted
- [x] Assignment 1 graded (**100%**)
- [x] Show-your-work artifacts submitted

### M6 — Data Preparation (Part 1)
- [x] Data Preparation quiz graded (**100%**)
- [x] Prepared dataset direction established (`stay_id` grain, 0–24h predictor window)
- [x] Early-window feature engineering pipeline exists (SQL scripts + derived tables)
- [x] Core “Select Data” and “Clean Data” material exists in project docs
- [x] Assignment 2 requirements / checklist / CRISP-DM outputs reviewed and mapped to project

### M7 — Data Preparation (Part 2) + Process Diary
- [x] Module 7 process diary submitted
- [x] `01_select_data_rationale.md` finalized for report use
- [x] `02_clean_data_report.md` finalized for report use
- [x] `03_feature_spec.md` finalized for report use
- [x] `04_integration_lineage.md` finalized for report use
- [x] `05_format_data_notes.md` finalized for report use
- [x] Section 1.1–1.4 prose aligned to split-aware / leakage-safe language
- [x] Final dataset contract clearly stated: target, predictors, audit-only fields, missingness representation, handoff assumptions

### M8 — Modeling (Part 1)
- [x] Modeling problem statement locked in one sentence
- [x] Target definition and threshold wording locked
- [x] Split / validation / tuning design locked before final experiments
- [x] Training-only preprocessing rule explicitly documented
- [x] Meaningful baseline chosen and justified
- [x] Candidate models chosen and justified
- [x] Modeling Strategy draft (Section 2.1) written from the locked design

### M9 — Modeling (Part 2) + Assignment 2
- [x] Baseline model run under final protocol
- [x] Candidate model set run under final protocol
- [x] Hyperparameter tuning documented cleanly
- [x] Held-out evaluation table frozen
- [x] Diagnostics / plots frozen
- [x] Model comparison and ranking logic documented
- [x] Recommended model selected and justified
- [x] Section 2.2–2.4 drafted from actual artifacts
- [ ] Assignment 2 report finalized and submitted (PDF)
- [ ] Assignment 2 Show Your Work package finalized and submitted

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
- [x] Prepared dataset(s) in `data/processed/` with a stable schema
- [x] Data preparation documentation finalized
- [x] Modeling notebook(s) + baseline + candidate comparisons finalized
- [x] Decisions logged in section docs / tracker / diary
- [x] Final metrics / plots / saved models frozen
- [ ] Report / writeup submitted (per course instructions)
- [ ] Show-your-work package submitted (ZIP / separate submission)

### Assignment 3 — Final Report + Slides (M13)
**Must have:**
- [ ] Final report (PDF)
- [ ] Slides deck (PPTX / PDF)
- [ ] Deployment + monitoring plan
- [ ] Reflection + process diary entry

---

## Assignment 2 execution roadmap (current state)

### Phase A — Lock the Data Preparation documentation layer
**Status:** done

**What got finished:**
- Section 1 source docs stabilized
- v1 scope and exclusions stated clearly
- leakage rule and dataset contract documented
- integration / formatting story aligned to the actual pipeline

**Tracker note:**
- “Section 1 source artifacts locked; scope, exclusions, leakage rule, and dataset contract frozen for Assignment 2 drafting.”

---

### Phase B — Freeze the final modeling protocol
**Status:** done

**What got locked:**
- binary classification framing
- prolonged LOS threshold
- subject-aware train/test split
- grouped cross-validation inside training only
- training-only preprocessing
- majority baseline + logistic regression + random forest
- multiple metrics beyond accuracy
- training-only threshold tuning before held-out evaluation

**Tracker note:**
- “Modeling protocol locked before final experiments: problem framing, target, split/tuning design, baseline, candidate models, metrics, thresholding, and preprocessing rule documented.”

---

### Phase C — Run / confirm the final experiment set
**Status:** done

**What happened:**
- initial final-model run completed
- methodology issue surfaced and was corrected rather than handwaved away
- targeted feature audit completed
- v1.1 feature refresh completed
- v1.1 modeling table rebuilt
- final v1.1 comparison notebook/script run successfully
- metrics / plots / predictions / saved models frozen for report use

**Tracker note:**
- “Final v1.1 experiment set complete; baseline and candidate models run under locked protocol; metrics/artifacts frozen for report use.”

---

### Phase D — Freeze evaluation + recommendation
**Status:** done in source-doc form

**What got finished:**
- final comparison table frozen
- model tradeoffs interpreted
- recommendation selected based on evidence, interpretability, and project fit
- caveats documented explicitly
- no unresolved leakage concern left hanging

**Recommendation:**
- **Logistic regression**

**Tracker note:**
- “Held-out comparison finalized; recommendation chosen based on evidence, tradeoffs, and project fit rather than headline score alone.”

---

### Phase E — Draft and finalize Assignment 2 report
**Status:** active now

**Still needs to happen:**
- finalize Introduction
- assemble Section 1 from `01–05`
- assemble Section 2 from `06–09`
- finalize Conclusion
- place figures/tables where they belong
- make the whole report read like one report instead of separate notes
- export final PDF

**Tracker note to add when done:**
- “Assignment 2 report assembled from frozen artifacts; final QA pass completed; PDF ready for submission.”

---

### Phase F — Submit and close Assignment 2
**Status:** not done

**Still needs to happen:**
- report PDF submitted
- Show Your Work ZIP submitted
- final tracker / diary / decision log sync pass
- post-submission state recorded
- transition note added for M10 / Assignment 3

**Tracker note to add when done:**
- “Assignment 2 fully submitted: PDF report + Show Your Work package. Transition ready for M10 Evaluation.”

---

## Notes / parking lot (updated)

### What’s already solid (do not reopen unless necessary)
- Grain: ICU stay (`stay_id`) is the modeling unit
- Predictor timing: early-window restriction (0–24h from ICU `intime`) is the main leakage control rule
- Prepared dataset exists in a stable v1.1 form
- Repo structure supports Assignment 2 artifact separation:
  - `data/processed/` for prepared datasets
  - `notebooks/` for analysis/modeling notebooks
  - `outputs/models/`, `outputs/tables/`, `outputs/figures/` for saved evidence
  - `reports/assignment_2/` for section-source prose
- Assignment 2 context has been fully reviewed and consolidated
- Final model recommendation is locked

### Current focus (right now)
- Final report assembly
- Final checklist / QA pass
- Final Show Your Work packaging
- Submission closeout

### Open questions (only if time allows)
- Final wording polish in Introduction / Conclusion
- Final figure placement in the report
- Whether the tracker or diary needs one more brief post-submission note before moving to M10

### Explicit “do not drift” rules for Assignment 2
- Do not reopen the unit of analysis.
- Do not add more models just to look sophisticated.
- Do not rerun the workflow unless a real submission-level defect is found.
- Do not let the report imply a different methodology than the one actually used.
- Do not optimize for novelty over defensibility.

---

## Assignment 2 finish-line state (target state for this file)

When Assignment 2 is fully complete, this tracker should say:

- Current module: **M10**
- Current objective:
  Transition from Assignment 2 into Evaluation planning for Assignment 3.
- Risk level: **Low**
- Assignment 2 milestone:
  - [x] Prepared dataset(s) in `data/processed/` with stable schema
  - [x] Data preparation documentation finalized
  - [x] Modeling notebook(s) + baseline + candidate comparisons finalized
  - [x] Decisions logged
  - [x] Model artifacts saved (metrics, plots, fitted models, predictions)
  - [x] Report submitted
  - [x] Show Your Work submitted
- Notes:
  - Assignment 2 completed with a stable ICU stay-level prolonged-LOS modeling workflow
  - Report and repository aligned to course structure and checklist
  - Ready to move into Evaluation / Assignment 3
