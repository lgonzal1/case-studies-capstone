# Process Diary

## 2026-01-26  Entry 1 — Module 1 & 2 (Project Foundation + Data Discovery)

### What I completed
- Reviewed course structure, grading, and the three major assignments aligned to CRISP-DM.
- Reviewed CRISP-DM phases and the “hierarchical structure” concept (phases → tasks → specialized tasks → process instance).
- Chose a project option: **ICU Patient Care Analysis (MIMIC-IV demo)**.
- Set up repository structure to support “show your work” requirements.
- Skimmed dataset documentation and confirmed key tables needed for analysis:
  - patients, admissions, icustays, transfers
  - labevents + d_labitems, chartevents + d_items
  - diagnoses_icd + d_icd_diagnoses
  - inputevents, procedureevents

### Key takeaways
- CRISP-DM is iterative: it’s normal to move backward when data quality issues or new questions appear.
- Documentation is not extra — it’s a deliverable that supports alignment and reproducibility.
- In real-world analytics, wording and metric selection can drive politics and incentives; accuracy and framing matter.
- MIMIC’s deidentification (date shifting) preserves **durations/intervals** within a patient encounter but limits “true calendar time” analyses (e.g., real demand curves across patients).

### Decisions made
- **Project selection:** MIMIC-IV ICU Patient Care Analysis.
- **Initial framing:** lean toward a **QI-style** narrative (operational + clinical relevance).
- **Keep options open:** not committing yet to Kaplan–Meier or any single method until EDA confirms feasibility.
- **Repository choice:** keep raw data out of Git; document how to obtain data locally; commit scaffold + notes early.

### Open questions
- What is the best **unit of analysis** given sample size and table structure?
  - ICU stay-level (stay_id) vs admission-level (hadm_id) vs patient-level (subject_id)
- Which **primary outcome(s)** are strongest for a capstone-grade story with this dataset?
  - ICU LOS, in-hospital mortality, ICU bounceback, hospital readmission
- How complete are ED timestamps (edregtime/edouttime) for flow metrics?
- What is a defensible “early window” for feature extraction (6h vs 24h) without leakage?
- How should ICU stays be grouped into high-level pathways (cardiac/neuro/trauma/sepsis/etc.) without over-segmenting?

### Next steps
- Do a lightweight EDA pass focused on feasibility:
  - counts per key entity (patients/admissions/stays)
  - missingness and timestamp availability
  - distribution checks for LOS and outcome flags
- Draft a short “analysis plan” for Assignment 1:
  - stakeholder questions → measurable objectives → candidate outcomes → candidate predictors
- Create a first-pass mapping approach for ICU pathway grouping (diagnoses-based, upgraded later with interventions).
- Commit repo scaffold + Module 1 notes + Process Diary entry 1.

## 2026-01-31  Entry 2 — Module 2 (Business Understanding Deep Dive)

### What I completed
- Reviewed CRISP-DM Business Understanding tasks: determine business objectives → assess situation → define data mining goals → produce a project plan.
- Drafted an initial QI/operations-flavored business objective and sketched what “success” should look like for a class project (reproducible + defensible, not fake ROI claims).
- Surfaced early assumptions/constraints that shape scope: small N (demo cohort), cohort heterogeneity, missingness risk, and date-shift reality (intervals valid, calendar time not).
- Started a “translation layer” from stakeholder questions to technical work (e.g., defining outcomes, defining cohort groupings, and enforcing an early-window cutoff to avoid leakage).
- Updated my project planning artifacts (tracker/diary/decision log) so my scope and uncertainties are explicit going into Module 3.

### Key takeaways
- “Technical success” ≠ “business success.” Metrics must map to a decision or action.
- Assumptions/risks aren’t bureaucracy — they prevent misleading interpretations and bad incentives.
- Iteration is expected; project plans need explicit review/re-scope triggers.

### Decisions made
- Primary framing: QI-style narrative (actionable, operationally relevant).
- Default unit of analysis (tentative): ICU stay-level, pending EDA confirmation.
- Commit to defining an “early window” for features to avoid leakage (tentative: first 6–24h).

### Open questions
- Exact primary endpoint(s): ICU LOS vs mortality vs prolonged LOS vs utilization proxies.
- Best approach to “pathway grouping” (diagnosis-based vs intervention-based vs clustering).
- What’s the most defensible minimal feature set for small N?
- How sparse are event tables in the demo subset, and is missingness systematic (measurement bias)?

### Next steps
- Start Module 3 with a 1-page problem framing + stakeholder decision statement.
- Run a quick table inventory + key counts to confirm grain/joins and feasibility.
- Draft Background + Business Objectives + Success Criteria sections in a first-pass report outline.

## Entry — 2026-02-03 (Data Understanding: Data Inventory + Data Description profiling)

### What I did
- Loaded the MIMIC-IV demo CSV bundle into a local PostgreSQL database (`mimic_demo`) using `hosp` and `icu` schemas.
- Ran initial profiling queries to capture:
  - Database size footprint
  - Row counts for key tables
  - Cardinalities (distinct `subject_id`, `hadm_id`, `stay_id`)
  - Basic temporal coverage for ICU stays (`intime`/`outtime`)
  - Distribution summaries for admissions-per-patient and charted-events-per-stay
  - ICU LOS summary statistics
- Captured file provenance details:
  - Local file inventory with upstream modified timestamps (all clinical CSVs: 2023-01-09 08:43)
  - SHA-256 checksums (including a locally generated manifest)

### Key outputs captured
- DB footprint: ~185 MB (`pg_database_size('mimic_demo')`).
- Core table sizes: patients (100), admissions (275), icustays (140), diagnoses_icd (4,506), labevents (107,727), chartevents (668,862).
- ICU timestamp span (date-shifted): 2110-04-11 15:52:22 to 2201-12-13 18:29:00.
- ICU LOS (outtime - intime): min 00:34:10; median 2 days 03:43:20; mean 3 days 16:18:18; p90 8 days 20:39:08; max 20 days 12:41:18.

### Notes / gotchas
- The initial Postgres load preserved raw values (schema-on-read). Some identifier fields can contain empty strings, so profiling SQL used `NULLIF(col,'')`.

### Where this feeds the report
- Updated the **Data Inventory** table with measured row counts and scope notes.
- Completed **Data Description** Steps 1–4: key variables dictionary, relationships/join routes, temporal constraint, and volume/scale narrative.
