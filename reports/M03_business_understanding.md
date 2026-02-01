# Module 3 — Business Understanding Draft (MIMIC-IV Demo ICU Patient Care Analysis)

> **AI use note:** This draft was assembled with help from a generative AI assistant acting as a writing/organization aid (summarizing my notes, structuring outlines, and converting brainstormed bullets into a first draft). All project decisions, interpretations, and final wording are mine.

## 1) Background / Context (project framing)

I am completing a capstone-style case study using the **ICU Patient Care Analysis** option on the **MIMIC-IV Clinical Database Demo** (open-access subset; N≈100 ICU patients). The dataset represents realistic EHR complexity (ICU stays, transfers, vitals, labs, diagnoses, inputs, procedures), but the demo subset is small and may be sparse for some event tables.

This project is intentionally framed with a **QI-style** narrative: the goal is to describe and analyze ICU care patterns and outcomes in a way that resembles real operational/clinical analytics work (e.g., using interval-based timestamps, clarifying assumptions, and avoiding metric framing that creates misleading incentives).

**Important dataset constraint:** MIMIC dates are **patient-shifted** for de-identification. This preserves **durations/intervals** within a patient encounter, but it limits “true calendar time” analyses across patients (e.g., real-world demand curves by hour/day across the entire cohort).

### Tables already identified as in-scope (current shortlist)
Hospital / core:
- admissions
ICU / flow:
- icustays
- transfers
Clinical events:
- labevents + d_labitems
- chartevents + d_items
- diagnoses_icd + d_icd_diagnoses
- inputevents
- procedureevents

## 2) Business Objectives (QI-style)

### Primary business objective (draft)
Translate ICU care questions into measurable objectives that can support **quality improvement thinking**: identify patterns in ICU patient care and recovery that are associated with outcomes and resource utilization.

This is explicitly a **capstone / educational** analysis using a demo dataset, so the output is best framed as:
- evidence-based descriptive insights and
- defensible analytic prototypes (methods + definitions)
that could *inform* how a real ICU QI team might measure or investigate similar questions.

### Secondary objectives (draft)
- Establish a clear, reproducible definition of ICU episodes and timelines using timestamps (ICU admit → ICU discharge; transfers).
- Explore feasibility of outcome analyses given small N (e.g., LOS distributions; mortality counts if present; transfer patterns if supported).
- Explore high-level ICU “pathway” grouping as a first-pass mental model (to be verified later): **cardiac, neuro, trauma, sepsis, other**.

## 3) Business Success Criteria (what “good” looks like for this class project)

Because this is a demo dataset and not a live implementation, success is measured by producing a clear, defensible analytic narrative:

- A reproducible, well-documented analysis workflow (repo structure + notes + clear joins and grains).
- Feasibility decisions are explicit (what is analyzable vs what is not, and why).
- Outcomes and cohorts are defined in a way that is defensible for a QI-style story *without* overstating causality.
- Clear communication of limitations (small N, missingness, de-ID date shifting, measurement bias risk).
- Practical outputs suitable for a capstone submission: report sections, tables/figures, and documented decisions.

## 4) Stakeholders + Decisions (role-play, since this is a demo dataset)

Stakeholders for the narrative are framed as ICU/QI audiences who would plausibly use this style of analysis:

- ICU clinical leadership (protocol and pathway framing)
- ICU operations / bed management (resource utilization and flow)
- Hospital quality improvement team (measurement definitions, bias/assumption tracking)

**Decisions this analysis is meant to inform (draft):**
- What outcomes and operational metrics are most defensible to monitor given available data?
- How should ICU stays be grouped into coarse “pathways” without over-segmenting?
- What early-window signals are feasible to compute without leaking future information?

> [TODO] tighten to 1–2 “decision statements” once outcomes/unit-of-analysis are finalized.

---

# Task 2 — Assess Situation

## 5) Inventory of Resources

### Data resources (available locally)
- MIMIC-IV demo CSVs: admissions, icustays, transfers, and selected events/dim tables listed above.
- Documentation sources: MIMIC table documentation and definitions (including the note that LOINC mapping is maintained in a separate code repository rather than in-table).

### Compute / workflow resources
- Local repo with version control (GitHub) and a reproducible structure (“show your work”).
- Tooling under consideration: pandas-first EDA vs loading into Postgres for repeatable SQL EDA. (Decision not finalized yet.)

### People / domain resources
- I can sanity-check the cohort mental model with :contentReference[oaicite:0]{index=0} at :contentReference[oaicite:1]{index=1} as a reality-check (not as a data source).

## 6) Requirements, Assumptions, Constraints (draft)

### Requirements
- Keep work reproducible and well-documented for capstone grading.
- Keep raw data out of Git; document how it is obtained/placed locally.
- Use clear definitions for any metric that depends on timestamps or cohort mapping.

### Constraints
- Small dataset: demo cohort is ~100 ICU patients, limiting robust modeling and subgroup analysis.
- De-identification: shifted dates preserve within-encounter intervals but limit real “calendar-time” demand analysis.
- Table sparsity/missingness likely varies across labevents/chartevents/inputevents/procedureevents.

### Assumptions (explicit, draft)
- Timestamp sequences within a stay are meaningful for interval-based analysis (durations).
- Cohort grouping using ICD codes is a reasonable first-pass approach (to validate/adjust later).
- “Early window” feature extraction (e.g., 6h/12h/24h from ICU admit) can be done without leakage if event timestamps are sufficiently dense.

## 7) Risks + Contingencies (draft)

- **Risk: too few cases per cohort** (cardiac/neuro/trauma/sepsis/other) → contingency: reduce to fewer buckets or analyze overall cohort only.
- **Risk: event-table sparsity / missingness** blocks key features → contingency: pivot to higher-level features (diagnoses, basic demographics, LOS/transfer patterns).
- **Risk: measurement bias** (sicker patients have more labs/vitals → missingness is not random) → contingency: acknowledge bias, consider simple sensitivity checks (e.g., measurement count as proxy).
- **Risk: leakage** from using data too late in the stay → contingency: enforce an “early window” cutoff and document it.
- **Risk: throughput/demand curves not valid** due to date shifting + incomplete coverage → contingency: avoid cross-patient “real-time demand” claims; focus on within-stay timelines and distributions.

## 8) Terminology (starter list)
- **Unit of analysis:** ICU stay (`stay_id`) vs hospital admission (`hadm_id`) vs patient (`subject_id`) — not finalized.
- **Outcome:** ICU LOS, hospital LOS, in-hospital mortality, transfer patterns/bounceback — feasibility TBD.
- **Early window:** first 6h / 12h / 24h after ICU admission (candidate cutoffs).
- **Cohort / pathway:** coarse grouping of ICU stays into cardiac/neuro/trauma/sepsis/other (first-pass mental model).

## 9) Costs / Benefits (class framing)
- “Costs”: time spent on data inventory, cleaning, and documentation; scope control due to small N and missingness.
- “Benefits”: a portfolio-safe, realistic healthcare analytics project demonstrating CRISP-DM thinking, explicit assumptions, and reproducible workflow.

---

# Task 3 — Determine Data Mining Goals (technical translation)

## 10) Data Mining Goals (draft)
Given the chosen unit of analysis and outcomes, the technical goals are to:

- Build a reliable ICU-stay timeline dataset from admissions + icustays + transfers (and selectively enrich with event data where feasible).
- Quantify and visualize outcome distributions (LOS; mortality if feasible) and examine whether outcomes differ meaningfully by cohort/pathway grouping.
- Prototype “early window” features (using events within a cutoff window after ICU admit) to support later modeling **without leakage**.

> [TODO] finalize: primary outcome + unit of analysis before locking these goals.

## 11) Data Mining Success Criteria (draft)
- Reproducible cohort construction and join logic (documented keys + grain).
- Clear missingness/coverage summary for event tables used in features.
- If modeling is attempted: performance evaluation is honest and right-sized for N≈100 (likely simple baselines + interpretability).

---

# Task 4 — Produce Project Plan (high-level)

## 12) Project Plan (draft)
**M3 (now):** finalize business framing + stakeholders/decisions + assumptions/risks + draft goals + project plan  
**M4–M5:** data inventory + missingness; confirm feasible unit-of-analysis and outcomes; EDA supporting Assignment 1  
**M6–M9:** data prep + baseline models (if feasible); otherwise strong descriptive/evaluation approach  
**M10–M13:** evaluation narrative + limitations + “deployment” story (how this would be used in a real setting)  
**M14:** wrap-up reflection and portfolio polish

---

## Notes / Parking Lot (from earlier brainstorm)
- Open questions:
  - Best unit of analysis: `stay_id` vs `hadm_id` vs `subject_id`
  - Which primary outcomes are feasible with N≈100 (LOS vs mortality vs transfers/bounceback)?
  - Cohort strategy: ICD-only vs hybrid (ICD + procedures + meds/labs); how many buckets can we support? email Dr. Gibney (UCI)
  - Defensible early feature window: 6h vs 12h vs 24h (depends on timestamp density)
  - How sparse are `chartevents`, `labevents`, `inputevents`, `procedureevents` in the demo subset?
  - Stakeholder decision clarity: what exact decision(s) should the analysis inform?
  - Workflow/tooling: Postgres-first for repeatable SQL EDA vs pandas-first until inventory is complete

- Things to look up later:
  - ICD10 codes for ICU cohorts (Cardiac, Neuro, Trauma, Sepsis, Other)
  - Verify cohort mental model
