/*
relationship_constraints_pk_fk.sql

Purpose
- Adds "real" relational constraints (PK/FK/UNIQUE) for the MIMIC-IV Demo subset
  loaded into local PostgreSQL (mimic_demo).
- This is intended to:
    (1) enforce join correctness (prevent silent join errors), and
    (2) enable DBeaver to auto-draw an accurate ERD.

Assumptions
- Tables live in schemas: hosp, icu.
- Columns  loaded as TEXT; this script normalizes empty strings ("")
  to NULL for key columns.

*/

-- ============================================================================
-- A) Normalize empty-string keys to NULL
-- ============================================================================

-- Anchor keys
UPDATE hosp.patients   SET subject_id = NULLIF(subject_id, '');
UPDATE hosp.admissions SET subject_id = NULLIF(subject_id, ''),
                          hadm_id    = NULLIF(hadm_id, '');
UPDATE icu.icustays    SET subject_id = NULLIF(subject_id, ''),
                          hadm_id    = NULLIF(hadm_id, ''),
                          stay_id    = NULLIF(stay_id, '');

-- Fact/event tables used in the ERD
UPDATE icu.chartevents SET subject_id = NULLIF(subject_id, ''),
                          hadm_id    = NULLIF(hadm_id, ''),
                          stay_id    = NULLIF(stay_id, ''),
                          itemid     = NULLIF(itemid, '');

UPDATE hosp.labevents  SET subject_id  = NULLIF(subject_id, ''),
                          hadm_id     = NULLIF(hadm_id, ''),
                          itemid      = NULLIF(itemid, ''),
                          labevent_id = NULLIF(labevent_id, '');

UPDATE hosp.diagnoses_icd SET subject_id  = NULLIF(subject_id, ''),
                             hadm_id     = NULLIF(hadm_id, ''),
                             seq_num    = NULLIF(seq_num, ''),
                             icd_code   = NULLIF(icd_code, ''),
                             icd_version= NULLIF(icd_version, '');

-- Dictionary tables
UPDATE hosp.d_labitems SET itemid = NULLIF(itemid, '');
UPDATE icu.d_items     SET itemid = NULLIF(itemid, '');
UPDATE hosp.d_icd_diagnoses  SET icd_code = NULLIF(icd_code, ''), icd_version = NULLIF(icd_version, '');
UPDATE hosp.d_icd_procedures SET icd_code = NULLIF(icd_code, ''), icd_version = NULLIF(icd_version, '');

-- ============================================================================
-- B) Indexes to support constraints + interactive joins
-- ============================================================================

-- FK columns should be indexed (Postgres does NOT auto-index FKs)
CREATE INDEX IF NOT EXISTS idx_hosp_admissions_subject_id ON hosp.admissions(subject_id);
CREATE INDEX IF NOT EXISTS idx_icu_icustays_subject_id     ON icu.icustays(subject_id);
CREATE INDEX IF NOT EXISTS idx_icu_icustays_hadm_id        ON icu.icustays(hadm_id);

CREATE INDEX IF NOT EXISTS idx_icu_chartevents_stay_id     ON icu.chartevents(stay_id);
CREATE INDEX IF NOT EXISTS idx_icu_chartevents_itemid      ON icu.chartevents(itemid);
CREATE INDEX IF NOT EXISTS idx_hosp_labevents_hadm_id      ON hosp.labevents(hadm_id);
CREATE INDEX IF NOT EXISTS idx_hosp_labevents_itemid       ON hosp.labevents(itemid);
CREATE INDEX IF NOT EXISTS idx_hosp_diagnoses_icd_hadm_id  ON hosp.diagnoses_icd(hadm_id);

-- Dictionary lookups
CREATE INDEX IF NOT EXISTS idx_hosp_d_labitems_itemid      ON hosp.d_labitems(itemid);
CREATE INDEX IF NOT EXISTS idx_icu_d_items_itemid          ON icu.d_items(itemid);

-- ============================================================================
-- C) Primary keys / unique keys (anchors first)
-- ============================================================================

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'pk_hosp_patients'
  ) THEN
    ALTER TABLE hosp.patients
      ADD CONSTRAINT pk_hosp_patients PRIMARY KEY (subject_id);
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'pk_hosp_admissions'
  ) THEN
    ALTER TABLE hosp.admissions
      ADD CONSTRAINT pk_hosp_admissions PRIMARY KEY (hadm_id);
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'pk_icu_icustays'
  ) THEN
    ALTER TABLE icu.icustays
      ADD CONSTRAINT pk_icu_icustays PRIMARY KEY (stay_id);
  END IF;
END $$;

-- Optional: use a PRIMARY KEY for labevents if it is truly unique.
-- If this fails, switch it to a UNIQUE constraint instead.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'pk_hosp_labevents'
  ) THEN
    ALTER TABLE hosp.labevents
      ADD CONSTRAINT pk_hosp_labevents PRIMARY KEY (labevent_id);
  END IF;
EXCEPTION WHEN others THEN
  RAISE NOTICE 'Skipping pk_hosp_labevents (labevent_id) due to: %', SQLERRM;
END $$;

-- Diagnoses: keep as UNIQUE (safer if any component can be NULL)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'uq_hosp_diagnoses_icd_comp'
  ) THEN
    ALTER TABLE hosp.diagnoses_icd
      ADD CONSTRAINT uq_hosp_diagnoses_icd_comp
      UNIQUE (hadm_id, seq_num, icd_code, icd_version);
  END IF;
END $$;

-- Dictionaries (composite uniqueness by code + version)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'pk_hosp_d_labitems'
  ) THEN
    ALTER TABLE hosp.d_labitems
      ADD CONSTRAINT pk_hosp_d_labitems PRIMARY KEY (itemid);
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'pk_icu_d_items'
  ) THEN
    ALTER TABLE icu.d_items
      ADD CONSTRAINT pk_icu_d_items PRIMARY KEY (itemid);
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'pk_hosp_d_icd_diagnoses'
  ) THEN
    ALTER TABLE hosp.d_icd_diagnoses
      ADD CONSTRAINT pk_hosp_d_icd_diagnoses PRIMARY KEY (icd_code, icd_version);
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'pk_hosp_d_icd_procedures'
  ) THEN
    ALTER TABLE hosp.d_icd_procedures
      ADD CONSTRAINT pk_hosp_d_icd_procedures PRIMARY KEY (icd_code, icd_version);
  END IF;
END $$;

-- ============================================================================
-- D) Foreign keys (add NOT VALID, then VALIDATE)
-- ============================================================================

-- admissions.subject_id -> patients.subject_id
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_admissions_subject') THEN
    ALTER TABLE hosp.admissions
      ADD CONSTRAINT fk_admissions_subject
      FOREIGN KEY (subject_id) REFERENCES hosp.patients(subject_id)
      NOT VALID;
  END IF;
END $$;

-- icustays.hadm_id -> admissions.hadm_id
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_icustays_hadm') THEN
    ALTER TABLE icu.icustays
      ADD CONSTRAINT fk_icustays_hadm
      FOREIGN KEY (hadm_id) REFERENCES hosp.admissions(hadm_id)
      NOT VALID;
  END IF;
END $$;

-- icustays.subject_id -> patients.subject_id
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_icustays_subject') THEN
    ALTER TABLE icu.icustays
      ADD CONSTRAINT fk_icustays_subject
      FOREIGN KEY (subject_id) REFERENCES hosp.patients(subject_id)
      NOT VALID;
  END IF;
END $$;

-- chartevents.stay_id -> icustays.stay_id
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_chartevents_stay') THEN
    ALTER TABLE icu.chartevents
      ADD CONSTRAINT fk_chartevents_stay
      FOREIGN KEY (stay_id) REFERENCES icu.icustays(stay_id)
      NOT VALID;
  END IF;
END $$;

-- chartevents.itemid -> d_items.itemid
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_chartevents_item') THEN
    ALTER TABLE icu.chartevents
      ADD CONSTRAINT fk_chartevents_item
      FOREIGN KEY (itemid) REFERENCES icu.d_items(itemid)
      NOT VALID;
  END IF;
END $$;

-- labevents.hadm_id -> admissions.hadm_id
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_labevents_hadm') THEN
    ALTER TABLE hosp.labevents
      ADD CONSTRAINT fk_labevents_hadm
      FOREIGN KEY (hadm_id) REFERENCES hosp.admissions(hadm_id)
      NOT VALID;
  END IF;
END $$;

-- labevents.itemid -> d_labitems.itemid
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_labevents_item') THEN
    ALTER TABLE hosp.labevents
      ADD CONSTRAINT fk_labevents_item
      FOREIGN KEY (itemid) REFERENCES hosp.d_labitems(itemid)
      NOT VALID;
  END IF;
END $$;

-- diagnoses_icd.hadm_id -> admissions.hadm_id
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_dx_hadm') THEN
    ALTER TABLE hosp.diagnoses_icd
      ADD CONSTRAINT fk_dx_hadm
      FOREIGN KEY (hadm_id) REFERENCES hosp.admissions(hadm_id)
      NOT VALID;
  END IF;
END $$;

-- diagnoses_icd.(icd_code, icd_version) -> d_icd_diagnoses
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_dx_icd_dict') THEN
    ALTER TABLE hosp.diagnoses_icd
      ADD CONSTRAINT fk_dx_icd_dict
      FOREIGN KEY (icd_code, icd_version) REFERENCES hosp.d_icd_diagnoses(icd_code, icd_version)
      NOT VALID;
  END IF;
END $$;

-- --------------------------------------------------------------------------
-- Validate constraints 
-- --------------------------------------------------------------------------

ALTER TABLE hosp.admissions     VALIDATE CONSTRAINT fk_admissions_subject;
ALTER TABLE icu.icustays        VALIDATE CONSTRAINT fk_icustays_hadm;
ALTER TABLE icu.icustays        VALIDATE CONSTRAINT fk_icustays_subject;
ALTER TABLE icu.chartevents     VALIDATE CONSTRAINT fk_chartevents_stay;
ALTER TABLE icu.chartevents     VALIDATE CONSTRAINT fk_chartevents_item;
ALTER TABLE hosp.labevents      VALIDATE CONSTRAINT fk_labevents_hadm;
ALTER TABLE hosp.labevents      VALIDATE CONSTRAINT fk_labevents_item;
ALTER TABLE hosp.diagnoses_icd  VALIDATE CONSTRAINT fk_dx_hadm;
ALTER TABLE hosp.diagnoses_icd  VALIDATE CONSTRAINT fk_dx_icd_dict;

-- End of script
