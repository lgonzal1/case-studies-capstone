# Decisions Log

Purpose: Record key project decisions (what, why, tradeoffs) so future-me (and graders) can trace scope, assumptions, and reasoning.

---

## D001 — Project selection: ICU Patient Care Analysis (MIMIC-IV Demo)
- **Decision:** Use the ICU Patient Care Analysis dataset (MIMIC-IV Clinical Database Demo) as the course case study.
- **Date:** 2026-01-26
- **Options considered:**
  - COVID Drivers: Pennsylvania Traffic Safety
  - Consumer Product Safety Analysis
  - POGOH Bike Share Growth Analysis
  - BYOD (not pursued)
- **Rationale:**
  - Closest alignment to my professional domain (healthcare operations + QI analytics)
  - Realistic clinical complexity (linked tables, missingness, irregular measurements) without “data archaeology” overhead
  - Strong documentation and stable schemas support reproducibility and CRISP-DM deliverables
  - Portfolio-safe (no HIPAA/EHR exposure)
- **Tradeoffs / risks:**
  - Small sample size (~100 patients) limits complex modeling and generalization
  - Some outcomes/questions (e.g., throughput demand curves) may be infeasible due to limited coverage and missing timestamp patterns
  - De-identified date shifting preserves within-patient intervals but limits true calendar-time analyses across patients
- **What would change my mind:**
  - The demo subset is too sparse for a rigorous, defensible analysis (e.g., key tables mostly empty, outcomes too rare, or timestamps too incomplete)
  - The project cannot produce practical, evidence-based insights consistent with the course success criteria

---

## D002 — Analysis posture: QI-style framing (operations + clinical relevance)
- **Decision:** Frame the work as a quality-improvement oriented analysis (actionable insights + operational relevance), not purely academic modeling.
- **Date:** 2026-01-26
- **Options considered:**
  - Pure prediction-first approach (maximize model performance)
  - Descriptive clinical epidemiology-style report
  - QI/ops style: combine descriptive + interpretable models + practical recommendations
- **Rationale:**
  - Matches stakeholder needs in the provided context (medical director + hospital admin)
  - Matches how decisions are actually made in hospitals (interpretation + process improvement, not just “best AUC”)
- **Tradeoffs / risks:**
  - Risk of over-claiming causal impact from observational data (must be explicit about limitations)
  - QI framing requires careful language to avoid “perverse incentives” and political misinterpretation
- **What would change my mind:**
  - If EDA shows outcome/predictor structure supports a clearer predictive task that is easier to validate and explain

---

## D003 — Unit of analysis: keep options open until EDA confirms feasibility
- **Decision:** Do not lock the unit of analysis yet; shortlist:
  - ICU stay-level (`stay_id`)
  - Hospital admission-level (`hadm_id`)
  - Patient-level (`subject_id`)
- **Date:** 2026-01-26
- **Rationale:**
  - Different questions map naturally to different grains (LOS and interventions at ICU-stay level; comorbidity/history at admission/patient level)
  - Small N means the “right” grain may be dictated by event availability and missingness
- **Tradeoffs / risks:**
  - Delays committing to a single modeling target until data feasibility is established
- **What would change my mind:**
  - Clear EDA signal that one grain has adequate coverage and produces a cleaner, defensible outcome definition

---

## D004 — Repository hygiene: keep raw data out of Git
- **Decision:** Do not commit raw MIMIC files to Git; document how to obtain and place them locally.
- **Date:** 2026-01-26
- **Rationale:**
  - Avoid accidental exposure, reduce repo bloat, and keep workflows reproducible
  - Align with common DS best practices (raw data is read-only and typically excluded from version control)
- **Tradeoffs / risks:**
  - Requires setup steps for anyone reproducing the work
- **What would change my mind:**
  - Only if course instructions explicitly require bundling datasets in the submission ZIP (then include in ZIP but still not in Git)

---
## D005 — Stakeholder framing and decision focus: throughput/resource utilization lens
- **Decision:** Frame the project around an ICU Director–driven QI/ops question: **which ICU patient subtypes consume disproportionate resources, and what early factors predict that pattern?**
- **Date:** 2026-02-01
- **Primary stakeholder / judge of success**: ICU Medical Director (exec leadership is a secondary audience, but ICU Director is the primary evaluator)
- Other Options considered:
  - Pure clinical description (epidemiology-style summary)
 - Prediction-only (optimize model performance)
 - Cohort-first QI framing (subtypes → differences in utilization/outcomes → early predictors → interpretable levers)
- **Rationale:**
 - Mirrors how hospital analytics requests tend to show up in real life: operational pressure → identify the drivers → focus on actionable levers.
 - Encourages sub-cycle thinking (not treating utilization/LOS as one undifferentiated metric).
 - Supports a defensible narrative with small N: start with group differences and then test whether early indicators explain variability.
- **Tradeoffs / risks:**
  - **Small sample risk:** subtype counts may be too small for separate models; may require fewer buckets or pooled modeling with cohort indicators.
  - **Data feasibility risk:** “recidivism” / ICU return rates may be limited by the demo subset structure and event frequency.
  - **Causal overreach risk:**  stick to association and plausible mechanisms.
- **Decision statement (what this enables):**
  - Compare ICU subtypes (e.g., trauma/neuro/cardiac/sepsis/other) on resource utilization and related outcomes.
  - Identify early-encounter features (first-hours labs/vitals/interventions) that predict high utilization within/among cohorts.
- **What would change my mind:**
  - If cohort sizes or table coverage are too sparse, pivot to fewer cohorts (or a single pooled model with minimal stratification).
  - If “early window” data density is insufficient to avoid leakage, shift to a simpler descriptive + interpretable approach.

---
## D006 — Primary outcome: ICU LOS (hours), with prolonged LOS as secondary
- **Decision:** Use **ICU length of stay (LOS)** as the primary outcome, measured **ICU admit → ICU discharge** (hours). Use **prolonged ICU LOS** (e.g., high-percentile / threshold-based flag) as a secondary outcome.
- **Date:** 2026-02-01
- **Options considered (primary):**
  - ICU LOS (hours)
  - Prolonged ICU LOS flag
  - Vent duration / vent-days (if feasible)
- **Rationale:**
  - ICU LOS is the most direct, widely understood proxy for ICU resource utilization and throughput burden.
  - A prolonged LOS indicator provides a “QI-friendly” framing (“who becomes long-stay”) that is often more operationally actionable than only modeling a continuous outcome.
  - Works with a cohort-first approach: compare LOS distributions across cohorts, then explore early predictors.
- **Tradeoffs / risks:**
  - LOS is influenced by downstream constraints and clinical complexity; must avoid implying the ICU “controls” LOS end-to-end.
  - Prolonged LOS threshold choice can be arbitrary; must document how threshold is defined (e.g., percentile-based) and why.
  - Small N may limit stability of any predictive modeling; descriptive + interpretable approaches may be favored.
- **What would change my mind:**
  - If EDA shows LOS timestamps are unreliable/incomplete for too many stays.
  - If event counts for prolonged LOS are too small (e.g., very few “long-stay” cases) to support even simple modeling.

---
## D007 — Cohort strategy: hybrid ICD + interventions, using 3–4 buckets initially
- **Decision:** Define ICU subtypes using a **hybrid approach**: diagnoses (ICD-based) augmented with key **interventions** (e.g., vent/procedure proxies where available). Start with **3–4 coarse buckets** for the first pass to avoid over-segmentation.
- **Date:** 2026-02-01
- **Options considered:**
  - ICD-only cohorting (diagnosis-driven)
  - Hybrid cohorting (ICD + interventions)
  - Unsupervised clustering (phenotyping) as a later/optional refinement
- **Rationale:**
  - ICD alone may miss meaningful pathway differences driven by care processes (e.g., ventilation, procedure-timing, escalation patterns).
  - Hybrid definition better matches “real ICU mental models” (clinical + operational pathway signals).
  - 3–4 buckets is statistically safer with N≈100 and keeps the story interpretable for a QI audience.
- **Tradeoffs / risks:**
  - Hybrid definitions can become subjective; must document rules clearly and keep them simple.
  - Intervention data may be sparse; cohorting rules must degrade gracefully if a table is missing/empty.
  - Coarse buckets may hide important heterogeneity; acceptable early tradeoff for stability and clarity.
- **What would change my mind:**
  - If ICD or intervention fields are too incomplete to support consistent cohort assignment.
  - If EDA shows one bucket dominates or buckets collapse (e.g., too few cases), forcing fewer buckets or a pooled analysis with cohort indicators.

---
# D008 — Establish core entity grains and relationship constraints (MIMIC-IV Demo)

**Date:** 2026-02-15  \
**Decision:** Treat \`hosp.patients\` (\`subject_id\`), \`hosp.admissions\` (\`hadm_id\`), and \`icu.icustays\` (\`stay_id\`) as the three anchor entities, and enforce their relationships with explicit PK/FK constraints after normalizing empty strings to NULL.

**Rationale:** Empirical validation confirmed unique candidate primary keys (no duplicates) and zero orphan rows along the primary join paths. Adding constraints will (1) prevent accidental join-induced duplication during analysis and (2) allow DBeaver to generate a correct ERD automatically.

**Implications:** Event tables (e.g., \`icu.chartevents\`, \`hosp.labevents\`, \`hosp.diagnoses_icd\`) will remain one-to-many relative to the anchors and should be aggregated or filtered (e.g., early-window) before modeling.

**Status:** Approved (to implement in SQL after review).

---
## D009 — Use numbered SQL scripts for reproducible execution order
- **Date:** 2026-02-15
- **Decision:** Store SQL exploration artifacts under `data/sql/` with a numeric prefix (01/02/03/...) to reflect the order they are intended to be run.
- **Rationale:** Keeps the workflow understandable as the number of queries grows and makes it easier for a reviewer to replay the work end-to-end.
- **Implications:** Requires renaming files rather than 'latest.sql'; commit history preserves change tracking.

--- 
## D010 — Constrain the initial ERD to a core subset of tables
- **Date:** 2026-02-15
- **Decision:** Build the first ERD around core entities and high-value event tables used for early feature engineering: `patients`, `admissions`, `icustays`, `chartevents`, `labevents`, `diagnoses_icd`, plus lookup tables (`d_items`, `d_labitems`, `d_icd_diagnoses`).
- **Rationale:** Full MIMIC-IV schemas are too large for a readable diagram; a focused ERD supports clearer unit-of-analysis decisions and faster EDA iteration.
- **Implications:** Additional tables can be added later as needed (e.g., meds, microbiology).

---
## D011 — Add PK/FK constraints to the local Postgres demo schema
- **Date:** 2026-02-15
- **Decision:** Apply explicit primary key and foreign key constraints in the local database based on relationship validation queries.
- **Rationale:** Constraints provide hard rails for join correctness, enable ERD tooling (DBeaver), and reduce accidental duplicate joins during analysis.
- **Implications:** Constraints reflect demo-extract consistency and may need adjustment if/when switching to the full dataset.

---
## D012 — Place the ERD in the report appendix and reference it from Data Description
- **Date:** 2026-02-15
- **Decision:** Embed the ERD as Appendix A and reference it from the Data Description/Relationships narrative.
- **Rationale:** The ERD is useful for transparency and reviewer context but too detailed to live in the main flow of the report.
- **Implications:** Keep the figure export stable (file name + path) and update the appendix if the core table set changes.


--- 
## D013 — Lock modeling grain for initial pipeline: ICU sta(`stay_id`)
- **Date:** 2026-02-22
- **Decision:** For the initial modeling pipeline and Assignment 1 Data Understanding outputs, treat the ICU stay (stay_id) as the primary unit of analysis.
- **Rationale:**
  - The core operational question (resource use / ICU LOS) is most naturally defined at the ICU-stay level.
  - Empirical validation: `icu.icustays` contains complete `intime/outtime/los` with no negative LOS records (per integrity checks), and `stay_id` is unique for the demo cohort.
  - Enables an “early window” predictor strategy anchored to intime, which is necessary for leakage control.

- **Tradeoffs / risks:**
  - Some outcomes (e.g., readmission/return risk) may map more cleanly to admission (`hadm_id`) or patient (`subject_id`) and may remain secondary/optional.
  - ICU stays can be influenced by downstream system constraints (stepdown/ward capacity), so interpretations must avoid implying the ICU fully controls LOS.

- **Implications:**
  - All event tables must be aggregated or windowed to stay_id before modeling.
  - The derived dataset will be one-row-per-stay and exported as a modeling matrix.
  
## D014 — Enforce an explicit anti-leakage rule: predictors limited to first 24h from ICU intime

- **Date:** 2026-02-22
- **Decision**: Define the predictor window as [ICU intime, ICU intime + 24 hours) and restrict all constructed predictors to this window.
- **Rationale**:
  - Goal is early risk stratification, so predictors must reflect what is plausibly available at/near a fixed prediction time.
  - Prevents “full-stay leakage” (longer stays inherently accumulate more charting/labs; using full-stay counts would indirectly encode LOS).
  - The demo dataset supports this choice empirically: core vitals have high presence within 24 hours (mid-90s to ~100% coverage for key items in the data quality outputs).

- **Tradeoffs / risks:
  - Some clinically useful predictors may not appear in the first 24 hours for all patients, which can increase missingness.
  - Clinical charting time may reflect workflow (ED vs ICU documentation), so strict windowing can exclude some values that are clinically “known” but documented earlier.

- **Implications**:
  - Feature scripts must explicitly filter by charttime >= intime AND charttime < intime + interval '24 hour'.
  - Missingness indicators are treated as first-class features rather than ignored.

## D015 — Materialize reproducible derived tables in `derived` schema + normalize key types to INT

- **Date**: 2026-02-22
- **Decision**: Materialize feature and modeling datasets as versioned tables in a dedicated schema:
  - `derived.vitals_24h_by_stay_v1`
  - `derived.icu_stay_modeling_24h_v1` and normalize key fields to INT in derived tables due to text-loaded source tables.

- **Rationale**:
  - Reproducibility: running 07 then 08 produces the same artifacts deterministically; tables can be validated and exported consistently.
  - Auditability: derived tables provide a stable reference for figures/tables in the report and reduce “notebook drift.”
  - Practical constraint: source tables were ingested as TEXT for speed; casting/normalization prevents join errors (observed text = integer join error during initial build).
  - Pipeline sanity checks succeeded: final modeling table has 140 rows / 140 distinct stays, and the prolonged LOS (>=8d) label yields 16 positives (11.4%).

- **Tradeoffs / risks**:
  - Derived tables can go stale if scripts change but tables are not rebuilt; requires discipline to rerun scripts after edits.
  - Type casting can mask upstream ingestion issues; mitigated by documenting the “quick ingest” choice and adding integrity checks.

- **Implications**:
  - Scripts include DROP TABLE IF EXISTS …; CREATE TABLE … AS …; so rebuilds are simple and explicit.
  - Use NULLIF(TRIM(x),'')::int for keys to avoid empty-string casting failures.
  - Export artifact for downstream work: data/processed/icu_stay_modeling_24h_v1.csv.
  
 ---
## D016 — Define “prolonged ICU stay” as LOS ≥ 8 days and build a leakage-safe 0–24h modeling table
- **Date:** 2026-02-25
- **Decision:** Define prolonged ICU length of stay as **ICU LOS ≥ 8 days** and create a **stay_id–grain early-window (0–24h) feature set** from `icu.chartevents`, producing:
  - `derived.vitals_24h_by_stay`
  - `derived.icu_stay_modeling_24h_v1`
  - `data/processed/icu_stay_modeling_24h_v1.csv`
- **Rationale:**
  - A binary “prolonged stay” outcome is operationally interpretable for ICU leadership (capacity / bed-days risk).
  - Literature commonly uses a **1-week threshold** operationally (≥7 days; i.e., **8+ days**) and explicitly discusses why this cut-off is defensible (clinical + methodological reasons, avoiding domination by short stays).
  - The demo cohort supports this definition with workable prevalence (**16/140 = 11.4%**), which is enough to proceed with simple modeling without collapsing into “too rare to analyze.”
- **Key source support:**
  - Frontiers in Medicine article (ICU LoS modeling) defines prolonged ICU stay using a **7-day cut-off (8+ days)** and explains why (short stays confounded by bed availability; skewed distribution issues). :contentReference[oaicite:0]{index=0}
- **Leakage control / constraints:**
  - Features are restricted to **0–24h after ICU `intime`** (and 0–6h counts as a secondary density signal).
  - This replaces any full-stay proxy features (e.g., total `n_chartevents` over the entire stay) that would leak future information.
- **Tradeoffs / risks:**
  - Thresholds vary across clinical literature and ICU populations; this choice is a pragmatic “common line” rather than a universal clinical standard.
  - Inference remains associative; model results should not be interpreted causally.
- **What would change my mind:**
  - If later sensitivity checks show the 8-day cutoff produces unstable results in this demo cohort, pivot to:
    - a percentile-based threshold (e.g., top decile of LOS), or
    - a different clinically common threshold (e.g., ≥14 days) *if* it still yields viable positive counts.
---


