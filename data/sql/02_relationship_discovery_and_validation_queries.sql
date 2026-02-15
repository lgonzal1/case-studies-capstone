/*
SQL “relationship discovery + validation” queries

Takeaways:
- Candidate PK are valid, no duplciates
- Core FK paths have 0 orphans
- Cardinality

Note: labevents has 79307 with hadm_id out of 107727 total so a chunk of labs wont join at the admission level...should be ok?


*/

-- ============================================================================
-- Q1) Inventory: which tables share key-like columns?
-- ============================================================================
/*
{
 [
	{
		"column_name" : "subject_id",
		"appearances" : 25,
		"tables" : "hosp.admissions, hosp.diagnoses_icd, hosp.drgcodes, 
		            hosp.emar, hosp.emar_detail, hosp.hcpcsevents, 
		            hosp.labevents, hosp.microbiologyevents, 
		            hosp.omr, hosp.patients, hosp.pharmacy, 
		            hosp.poe, hosp.poe_detail, hosp.prescriptions, 
		            hosp.procedures_icd, hosp.services, hosp.transfers, 
		            icu.chartevents, icu.datetimeevents, icu.icustays, 
		            icu.ingredientevents, icu.inputevents, 
		            icu.outputevents, icu.procedureevents, 
		            mimic.demo_subject_id"
	},
	{
		"column_name" : "hadm_id",
		"appearances" : 20,
		"tables" : "hosp.admissions, hosp.diagnoses_icd, hosp.drgcodes, 
		            hosp.emar, hosp.hcpcsevents, hosp.labevents, 
		            hosp.microbiologyevents, hosp.pharmacy, hosp.poe, hosp.prescriptions, 
		            hosp.procedures_icd, hosp.services, hosp.transfers, icu.chartevents, 
		            icu.datetimeevents, icu.icustays, icu.ingredientevents, icu.inputevents, 
		            icu.outputevents, icu.procedureevents"
	},
	{
		"column_name" : "itemid",
		"appearances" : 9,
		"tables" : "hosp.d_labitems, hosp.labevents, icu.chartevents, icu.d_items, 
		            icu.datetimeevents, icu.ingredientevents, icu.inputevents, 
		            icu.outputevents, icu.procedureevents"
	},
	{
		"column_name" : "stay_id",
		"appearances" : 7,
		"tables" : "icu.chartevents, icu.datetimeevents, icu.icustays, 
		            icu.ingredientevents, icu.inputevents, icu.outputevents, 
		            icu.procedureevents"
	},
	{
		"column_name" : "icd_code",
		"appearances" : 4,
		"tables" : "hosp.d_icd_diagnoses, hosp.d_icd_procedures, hosp.diagnoses_icd, hosp.procedures_icd"
	},
	{
		"column_name" : "icd_version",
		"appearances" : 4,
		"tables" : "hosp.d_icd_diagnoses, hosp.d_icd_procedures, hosp.diagnoses_icd, hosp.procedures_icd"
	}
]}
*/


-- Find shared “key-ish” column names across hosp/icu/mimic
WITH cols AS (
  SELECT table_schema, table_name, column_name
  FROM information_schema.columns
  WHERE table_schema IN ('hosp','icu','mimic')
)
SELECT
  column_name,
  COUNT(*) AS appearances,
  STRING_AGG(table_schema || '.' || table_name, ', ' ORDER BY table_schema, table_name) AS tables
FROM cols
WHERE column_name IN ('subject_id','hadm_id','stay_id','itemid','icd_code','icd_version')
GROUP BY 1
ORDER BY appearances DESC, column_name;

-- ============================================================================
-- Candidate primary key checks (uniqueness + duplicates)
-- ============================================================================

-- Patients: subject_id should be unique
SELECT
  COUNT(*) AS total_rows,
  COUNT(DISTINCT NULLIF(subject_id,'')) AS distinct_subject_id
FROM hosp.patients;

/*
result 1:
total_rows|distinct_subject_id|
----------+-------------------+
       100|                100|
*/


SELECT subject_id, COUNT(*) AS n
FROM hosp.patients
GROUP BY 1
HAVING COUNT(*) > 1
ORDER BY n DESC;
/*     
result 2:
subject_id|n|
----------+-+
*/


-- Admissions: hadm_id should be unique
SELECT
  COUNT(*) AS total_rows,
  COUNT(DISTINCT NULLIF(hadm_id,'')) AS distinct_hadm_id
FROM hosp.admissions;

/*
result 3
total_rows|distinct_hadm_id|
----------+----------------+
       275|             275|
  */
  
  
  SELECT hadm_id, COUNT(*) AS n
FROM hosp.admissions
GROUP BY 1
HAVING COUNT(*) > 1
ORDER BY n DESC;

/*     
 result 4:
      hadm_id|n|
-------+-+
*/

-- ICU stays: stay_id should be unique
SELECT
  COUNT(*) AS total_rows,
  COUNT(DISTINCT NULLIF(stay_id,'')) AS distinct_stay_id
FROM icu.icustays;
/*
result 5:
total_rows|distinct_stay_id|
----------+----------------+
       140|             140|
       
  */
  
    SELECT stay_id, COUNT(*) AS n
FROM icu.icustays
GROUP BY 1
HAVING COUNT(*) > 1
ORDER BY n DESC;

/*   
result 6:
stay_id|n|
-------+-+
*/

-- Diagnoses: typical uniqueness is (hadm_id, seq_num, icd_code, icd_version)
SELECT
  COUNT(*) AS total_rows,
  COUNT(DISTINCT md5(concat_ws('|',
    NULLIF(hadm_id,''),
    NULLIF(seq_num,''),
    NULLIF(icd_code,''),
    NULLIF(icd_version,'')
  ))) AS distinct_rows_by_comp_key
FROM hosp.diagnoses_icd;
/*
result 7:
total_rows|distinct_rows_by_comp_key|
----------+-------------------------+
      4506|                     4506|

*/

-- ============================================================================
-- Foreign key “coverage” checks (orphans)
-- ============================================================================

-- admissions.subject_id -> patients.subject_id
SELECT
  COUNT(*) AS admissions_with_subject,
  SUM(CASE WHEN p.subject_id IS NULL THEN 1 ELSE 0 END) AS orphan_admissions
FROM hosp.admissions a
LEFT JOIN hosp.patients p
  ON p.subject_id = a.subject_id
WHERE NULLIF(a.subject_id,'') IS NOT NULL;

/*
admissions_with_subject|orphan_admissions|
-----------------------+-----------------+
                    275|                0|
*/

-- icustays.hadm_id -> admissions.hadm_id
SELECT
  COUNT(*) AS stays_with_hadm,
  SUM(CASE WHEN a.hadm_id IS NULL THEN 1 ELSE 0 END) AS orphan_stays
FROM icu.icustays s
LEFT JOIN hosp.admissions a
  ON a.hadm_id = s.hadm_id
WHERE NULLIF(s.hadm_id,'') IS NOT NULL;

/*
stays_with_hadm|orphan_stays|
---------------+------------+
            140|           0|
*/
            
-- chartevents.stay_id -> icustays.stay_id
SELECT
  COUNT(*) AS events_with_stay,
  SUM(CASE WHEN s.stay_id IS NULL THEN 1 ELSE 0 END) AS orphan_events
FROM icu.chartevents e
LEFT JOIN icu.icustays s
  ON s.stay_id = e.stay_id
WHERE NULLIF(e.stay_id,'') IS NOT NULL;

/*
events_with_stay|orphan_events|
----------------+-------------+
          668862|            0|
*/

 -- labevents.hadm_id -> admissions.hadm_id
SELECT
  COUNT(*) AS labs_with_hadm,
  SUM(CASE WHEN a.hadm_id IS NULL THEN 1 ELSE 0 END) AS orphan_labs
FROM hosp.labevents l
LEFT JOIN hosp.admissions a
  ON a.hadm_id = l.hadm_id
WHERE NULLIF(l.hadm_id,'') IS NOT NULL;

/*
labs_with_hadm|orphan_labs|
--------------+-----------+
         79307|          0|
*/ 


-- diagnoses_icd.hadm_id -> admissions.hadm_id
SELECT
  COUNT(*) AS dx_with_hadm,
  SUM(CASE WHEN a.hadm_id IS NULL THEN 1 ELSE 0 END) AS orphan_dx
FROM hosp.diagnoses_icd d
LEFT JOIN hosp.admissions a
  ON a.hadm_id = d.hadm_id
WHERE NULLIF(d.hadm_id,'') IS NOT NULL;

/*
dx_with_hadm|orphan_dx|
------------+---------+
        4506|        0|
*/


-- ============================================================================
-- Cardinality summaries (useful labels on ERD + narrative)
-- ============================================================================


-- admissions per patient (documentation, previously run)
WITH x AS (
  SELECT NULLIF(subject_id,'') AS subject_id, COUNT(*) AS n_adm
  FROM hosp.admissions
  WHERE NULLIF(subject_id,'') IS NOT NULL
  GROUP BY 1
)
SELECT
  COUNT(*) AS n_patients_with_adm,
  MIN(n_adm) AS min_adm,
  PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY n_adm) AS median_adm,
  MAX(n_adm) AS max_adm
FROM x;

/*
n_patients_with_adm|min_adm|median_adm|max_adm|
-------------------+-------+----------+-------+
                100|      1|       1.0|     20|
*/

-- ICU stays per admission
WITH x AS (
  SELECT NULLIF(hadm_id,'') AS hadm_id, COUNT(*) AS n_stays
  FROM icu.icustays
  WHERE NULLIF(hadm_id,'') IS NOT NULL
  GROUP BY 1
)
SELECT
  COUNT(*) AS n_adm_with_stays,
  MIN(n_stays) AS min_stays,
  PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY n_stays) AS median_stays,
  MAX(n_stays) AS max_stays
FROM x;
/*
n_adm_with_stays|min_stays|median_stays|max_stays|
----------------+---------+------------+---------+
             128|        1|         1.0|        4|
*/
-- chart events per stay (documentation, previously run)
WITH x AS (
  SELECT NULLIF(stay_id,'') AS stay_id, COUNT(*) AS n_ce
  FROM icu.chartevents
  WHERE NULLIF(stay_id,'') IS NOT NULL
  GROUP BY 1
)
SELECT
  COUNT(*) AS n_stays_with_ce,
  MIN(n_ce) AS min_ce,
  PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY n_ce) AS median_ce,
  MAX(n_ce) AS max_ce
FROM x;
/*
n_stays_with_ce|min_ce|median_ce|max_ce|
---------------+------+---------+------+
            140|    35|   2520.5| 37061|
*/
-- lab events per admission
WITH x AS (
  SELECT NULLIF(hadm_id,'') AS hadm_id, COUNT(*) AS n_lab
  FROM hosp.labevents
  WHERE NULLIF(hadm_id,'') IS NOT NULL
  GROUP BY 1
)
SELECT
  COUNT(*) AS n_adm_with_labs,
  MIN(n_lab) AS min_lab,
  PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY n_lab) AS median_lab,
  MAX(n_lab) AS max_lab
FROM x;
/*
n_adm_with_labs|min_lab|median_lab|max_lab|
---------------+-------+----------+-------+
            252|      8|     178.0|   2538|
*/
-- diagnoses per admission
WITH x AS (
  SELECT NULLIF(hadm_id,'') AS hadm_id, COUNT(*) AS n_dx
  FROM hosp.diagnoses_icd
  WHERE NULLIF(hadm_id,'') IS NOT NULL
  GROUP BY 1
)
SELECT
  COUNT(*) AS n_adm_with_dx,
  MIN(n_dx) AS min_dx,
  PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY n_dx) AS median_dx,
  MAX(n_dx) AS max_dx
FROM x;
/*
n_adm_with_dx|min_dx|median_dx|max_dx|
-------------+------+---------+------+
          275|     2|     14.0|    39|
*/



