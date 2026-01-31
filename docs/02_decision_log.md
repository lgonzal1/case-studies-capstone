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