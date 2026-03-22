/*
===============================================================================
Assignment 2 v1.1 Feature Audit
Project: ICU Patient Care Analysis (MIMIC-IV Clinical Database Demo)
Author: Luis Gonzalez
Phase: CRISP-DM Data Preparation / Modeling Iteration
Last updated: 2026-03-22

Purpose
-------
This script is a targeted audit for a small v1.1 feature refresh. The goal is
not to reopen the whole project. The goal is to check a few practical changes
that could improve the final model without turning this into a much bigger
build.

Why this audit is being done
----------------------------
The first final-model run worked, but it highlighted two issues:

1. A workflow / measurement-intensity feature (`n_chartevents_24h`) showed up
   as very important.
2. Some useful features were intentionally left out of v1 to keep the first
   pass simple.

That is not a failure. It is part of the normal CRISP-DM process. At this
stage, the right move is a small and disciplined revision, not a full rebuild.

What this script is checking
----------------------------
1. Whether `admission_type` should be collapsed into fewer categories.
2. Whether `first_careunit` should be collapsed into fewer categories.
3. Whether a small 24-hour lab panel is worth adding to the prepared dataset.
4. Whether the candidate labs are usually measured once or multiple times in
   the first 24 hours.

Working rule for v1.1
---------------------
Only add features that are:
- available early,
- easy to explain,
- reasonably well covered,
- and worth the extra integration work.

This script is for audit and decision-making. It is not the final feature
construction script.
===============================================================================
*/


/*
===============================================================================
Section 1: Raw admission_type counts and prolonged-stay rates

Why run this query:
The raw `admission_type` field may be useful, but it likely has more categories
than this small demo cohort can support cleanly. This query checks how many
stays fall into each category and whether the prolonged-stay rate looks
different across them.

How to use the result:
- If there are many very small categories, the field should probably be
  collapsed before modeling.
- If a few categories dominate the cohort, a coarse grouped version is likely
  more stable and easier to explain.
===============================================================================
*/
WITH icu_anchor AS (
    SELECT
        NULLIF(TRIM(stay_id), '')::int AS stay_id,
        NULLIF(TRIM(hadm_id), '')::int AS hadm_id,
        los::numeric AS los_days,
        CASE WHEN los::numeric >= 8 THEN 1 ELSE 0 END AS prolonged_los_8d
    FROM icu.icustays
    WHERE NULLIF(TRIM(stay_id), '') IS NOT NULL
),
adm AS (
    SELECT
        NULLIF(TRIM(hadm_id), '')::int AS hadm_id,
        NULLIF(TRIM(admission_type), '') AS admission_type
    FROM hosp.admissions
)
SELECT
    COALESCE(adm.admission_type, '[NULL]') AS admission_type,
    COUNT(*) AS n_stays,
    SUM(a.prolonged_los_8d) AS n_prolonged,
    ROUND(AVG(a.prolonged_los_8d::numeric), 4) AS prolonged_rate
FROM icu_anchor a
LEFT JOIN adm
    ON a.hadm_id = adm.hadm_id
GROUP BY COALESCE(adm.admission_type, '[NULL]')
ORDER BY n_stays DESC, admission_type;

/*
Interpretation:
admission_type             |n_stays|n_prolonged|prolonged_rate|
---------------------------+-------+-----------+--------------+
EW EMER.                   |     67|          8|        0.1194|
URGENT                     |     31|          3|        0.0968|
OBSERVATION ADMIT          |     17|          4|        0.2353|
SURGICAL SAME DAY ADMISSION|     15|          0|        0.0000|
DIRECT EMER.               |      5|          1|        0.2000|
ELECTIVE                   |      5|          0|        0.0000|

What I am looking for:
- Are there too many tiny categories to use raw?
- Are a few categories doing most of the work?
- Does this field look worth collapsing instead of dropping?

Takeaway:
The raw admission_type field looks worth keeping, but not in its current form. A few categories are doing most of 
the work, while the rest are pretty small. In a dataset this size, that is more detail than I can really 
justify keeping as-is.
So the raw field is probably too sparse for modeling, but it does look useful enough to collapse rather than drop.
*/


/*
===============================================================================
Section 2: Proposed coarse admission_type grouping

Why run this query:
Once the raw categories are reviewed, the next step is to test whether a
coarser grouped version produces a cleaner and more stable field for modeling.

This query groups admission type into:
- elective
- urgent/emergent
- other
- unknown

How to use the result:
If the grouped version keeps most of the signal while reducing sparsity, it is
a better choice for v1.1 than the raw field.
===============================================================================
*/
WITH icu_anchor AS (
    SELECT
        NULLIF(TRIM(stay_id), '')::int AS stay_id,
        NULLIF(TRIM(hadm_id), '')::int AS hadm_id,
        CASE WHEN los::numeric >= 8 THEN 1 ELSE 0 END AS prolonged_los_8d
    FROM icu.icustays
    WHERE NULLIF(TRIM(stay_id), '') IS NOT NULL
),
adm AS (
    SELECT
        NULLIF(TRIM(hadm_id), '')::int AS hadm_id,
        UPPER(NULLIF(TRIM(admission_type), '')) AS admission_type
    FROM hosp.admissions
),
grouped AS (
    SELECT
        a.stay_id,
        a.prolonged_los_8d,
        CASE
            WHEN adm.admission_type IN ('ELECTIVE', 'SURGICAL SAME DAY ADMISSION') THEN 'elective'
            WHEN adm.admission_type IN ('URGENT', 'EMERGENCY', 'DIRECT EMER.', 'EW EMER.') THEN 'urgent_emergent'
            WHEN adm.admission_type IS NULL THEN 'unknown'
            ELSE 'other'
        END AS admission_type_grp
    FROM icu_anchor a
    LEFT JOIN adm
        ON a.hadm_id = adm.hadm_id
)
SELECT
    admission_type_grp,
    COUNT(*) AS n_stays,
    SUM(prolonged_los_8d) AS n_prolonged,
    ROUND(AVG(prolonged_los_8d::numeric), 4) AS prolonged_rate
FROM grouped
GROUP BY admission_type_grp
ORDER BY n_stays DESC;

/*
Interpretation:
admission_type_grp|n_stays|n_prolonged|prolonged_rate|
------------------+-------+-----------+--------------+
urgent_emergent   |    103|         12|        0.1165|
elective          |     20|          0|        0.0000|
other             |     17|          4|        0.2353|

What I am looking for:
- Does the grouped field look more stable than the raw one?
- Do the collapsed buckets still show meaningful differences?
- Is this simple enough to defend in the report?

Takeaway:
The grouped version looks a lot cleaner and more usable. Most stays fall into urgent_emergent, 
elective is a smaller cleaner bucket, and other is not huge but does look a little different 
from the main group.

That is basically what I wanted. The grouped version is simpler, easier to explain, and a better 
fit for this dataset than the raw field.
*/


/*
===============================================================================
Section 3: Raw first_careunit counts and prolonged-stay rates

Why run this query:
`first_careunit` is a plausible early pathway variable because it describes
where the patient started in the ICU. In a real hospital workflow, that can
matter because different units often see different types of patients.

This query checks whether the raw categories are large enough to use directly
or whether they should be collapsed.

How to use the result:
- If there are only a few larger units, the raw field might be okay.
- If several categories are very small, a grouped version is probably better.
===============================================================================
*/
WITH icu_anchor AS (
    SELECT
        NULLIF(TRIM(stay_id), '')::int AS stay_id,
        NULLIF(TRIM(first_careunit), '') AS first_careunit,
        CASE WHEN los::numeric >= 8 THEN 1 ELSE 0 END AS prolonged_los_8d
    FROM icu.icustays
    WHERE NULLIF(TRIM(stay_id), '') IS NOT NULL
)
SELECT
    COALESCE(first_careunit, '[NULL]') AS first_careunit,
    COUNT(*) AS n_stays,
    SUM(prolonged_los_8d) AS n_prolonged,
    ROUND(AVG(prolonged_los_8d::numeric), 4) AS prolonged_rate
FROM icu_anchor
GROUP BY COALESCE(first_careunit, '[NULL]')
ORDER BY n_stays DESC, first_careunit;

/*
Interpretation:
first_careunit                                  |n_stays|n_prolonged|prolonged_rate|
------------------------------------------------+-------+-----------+--------------+
Medical Intensive Care Unit (MICU)              |     29|          3|        0.1034|
Surgical Intensive Care Unit (SICU)             |     29|          2|        0.0690|
Cardiac Vascular Intensive Care Unit (CVICU)    |     25|          0|        0.0000|
Medical/Surgical Intensive Care Unit (MICU/SICU)|     23|          4|        0.1739|
Trauma SICU (TSICU)                             |     16|          3|        0.1875|
Coronary Care Unit (CCU)                        |     13|          3|        0.2308|
Neuro Surgical Intensive Care Unit (Neuro SICU) |      3|          1|        0.3333|
Neuro Intermediate                              |      1|          0|        0.0000|
Neuro Stepdown                                  |      1|          0|        0.0000|

What I am looking for:
- Are there a few careunits with most of the volume?
- Are there tiny careunits that should be collapsed?
- Does this look worth keeping as a pathway feature?

Takeaway:
The raw first_careunit field looks useful, but it is a little too fragmented to use directly. 
A few units carry most of the volume, and then there are some very small specialty categories 
that are probably too sparse to stand on their own.

So I think this field is worth keeping, but in a collapsed form. It looks like a real pathway 
feature, just not one I want to leave fully raw.
*/


/*
===============================================================================
Section 4: Proposed coarse first_careunit grouping

Why run this query:
This tests whether the raw first-careunit values can be reduced to a smaller
set of more stable pathway groups.

Important note:
The demo data uses long unit names, so the grouping logic uses broad text
matching rather than short abbreviations only.

How to use the result:
If the grouped version produces a few sensible buckets with decent counts, it
is probably a better choice than the raw field.
===============================================================================
*/
WITH icu_anchor AS (
    SELECT
        NULLIF(TRIM(stay_id), '')::int AS stay_id,
        UPPER(NULLIF(TRIM(first_careunit), '')) AS first_careunit,
        CASE WHEN los::numeric >= 8 THEN 1 ELSE 0 END AS prolonged_los_8d
    FROM icu.icustays
    WHERE NULLIF(TRIM(stay_id), '') IS NOT NULL
),
grouped AS (
    SELECT
        stay_id,
        prolonged_los_8d,
        CASE
            WHEN first_careunit IS NULL THEN 'unknown'
            WHEN first_careunit LIKE '%MICU/SICU%' THEN 'mixed_micu_sicu'
            WHEN first_careunit LIKE '%(MICU)%' OR first_careunit LIKE '%MEDICAL INTENSIVE CARE UNIT%' THEN 'medical'
            WHEN first_careunit LIKE '%(SICU)%' OR first_careunit LIKE '%(TSICU)%'
                 OR first_careunit LIKE '%SURGICAL INTENSIVE CARE UNIT%'
                 OR first_careunit LIKE '%TRAUMA SURGICAL%' THEN 'surgical_trauma'
            WHEN first_careunit LIKE '%(CVICU)%' OR first_careunit LIKE '%(CCU)%'
                 OR first_careunit LIKE '%(CSRU)%'
                 OR first_careunit LIKE '%CARDIAC%' THEN 'cardiac'
            WHEN first_careunit LIKE '%NEURO%' OR first_careunit LIKE '%NICU%'
                 OR first_careunit LIKE '%NEONATAL%' THEN 'specialty'
            ELSE 'other'
        END AS first_careunit_grp
    FROM icu_anchor
)
SELECT
    first_careunit_grp,
    COUNT(*) AS n_stays,
    SUM(prolonged_los_8d) AS n_prolonged,
    ROUND(AVG(prolonged_los_8d::numeric), 4) AS prolonged_rate
FROM grouped
GROUP BY first_careunit_grp
ORDER BY n_stays DESC;

/*
Interpretation:
first_careunit_grp|n_stays|n_prolonged|prolonged_rate|
------------------+-------+-----------+--------------+
surgical_trauma   |     48|          6|        0.1250|
cardiac           |     38|          3|        0.0789|
medical           |     29|          3|        0.1034|
mixed_micu_sicu   |     23|          4|        0.1739|
specialty         |      2|          0|        0.0000|

What I am looking for:
- Did the grouping actually work this time?
- Are the buckets large enough to be usable?
- Is the grouped version cleaner than the raw one?

Takeaway:
This worked a lot better. The grouped version is much cleaner and gives me a small number of buckets 
that actually have enough stays to be usable.

The only part I would still watch is specialty, because that bucket is tiny. Might want to just
fold it into `other`, but other than that, this grouped version looks a lot more reasonable than 
the raw field and is probably the right direction for our model
*/


/*
===============================================================================
Section 5: Early 24-hour lab coverage audit

Why run this query:
Before adding lab features, I need to know which labs are actually present in
the first 24 hours of the ICU stay. There is no point expanding the dataset
with a lab feature that has poor coverage or only appears in a small fraction
of stays.

How to use the result:
This query helps identify a small lab panel that is:
- measured early,
- common enough to be useful,
- and easy to explain.
===============================================================================
*/
WITH icu_anchor AS (
    SELECT
        NULLIF(TRIM(stay_id), '')::int AS stay_id,
        NULLIF(TRIM(hadm_id), '')::int AS hadm_id,
        intime::timestamp AS intime
    FROM icu.icustays
    WHERE NULLIF(TRIM(stay_id), '') IS NOT NULL
),
labs AS (
    SELECT
        NULLIF(TRIM(hadm_id), '')::int AS hadm_id,
        NULLIF(TRIM(itemid), '')::int AS itemid,
        COALESCE(charttime::timestamp, storetime::timestamp) AS labtime,
        NULLIF(TRIM(valueuom), '') AS valueuom,
        valuenum::numeric AS valuenum
    FROM hosp.labevents
    WHERE NULLIF(TRIM(hadm_id), '') IS NOT NULL
      AND NULLIF(TRIM(itemid), '') IS NOT NULL
      AND valuenum IS NOT NULL
),
lab_dict AS (
    SELECT
        NULLIF(TRIM(itemid), '')::int AS itemid,
        NULLIF(TRIM(label), '') AS label
    FROM hosp.d_labitems
)
SELECT
    d.label,
    COUNT(*) AS n_events,
    COUNT(DISTINCT a.stay_id) AS n_stays_with_lab,
    ROUND(
        COUNT(DISTINCT a.stay_id)::numeric / (SELECT COUNT(*) FROM icu_anchor),
        4
    ) AS stay_coverage_pct
FROM icu_anchor a
JOIN labs l
    ON a.hadm_id = l.hadm_id
   AND l.labtime >= a.intime
   AND l.labtime <  a.intime + interval '24 hour'
JOIN lab_dict d
    ON l.itemid = d.itemid
GROUP BY d.label
HAVING COUNT(DISTINCT a.stay_id) >= 5
ORDER BY n_stays_with_lab DESC, n_events DESC
LIMIT 50;

/*
label                          |n_events|n_stays_with_lab|stay_coverage_pct|
-------------------------------+--------+----------------+-----------------+
Chloride                       |     332|             139|           0.9929|
Potassium                      |     332|             139|           0.9929|
Sodium                         |     331|             139|           0.9929|
Glucose                        |     443|             138|           0.9857|
Urea Nitrogen                  |     310|             138|           0.9857|
Bicarbonate                    |     309|             138|           0.9857|
Creatinine                     |     309|             138|           0.9857|
Anion Gap                      |     307|             138|           0.9857|
Hemoglobin                     |     383|             136|           0.9714|
Hematocrit                     |     356|             136|           0.9714|
MCV                            |     311|             136|           0.9714|
MCHC                           |     311|             136|           0.9714|
Red Blood Cells                |     311|             136|           0.9714|
White Blood Cells              |     311|             136|           0.9714|
RDW                            |     311|             136|           0.9714|
MCH                            |     311|             136|           0.9714|
Platelet Count                 |     315|             135|           0.9643|
Magnesium                      |     287|             133|           0.9500|
Calcium, Total                 |     272|             127|           0.9071|
Phosphate                      |     271|             127|           0.9071|
PTT                            |     249|             116|           0.8286|
PT                             |     239|             115|           0.8214|
INR(PT)                        |     239|             115|           0.8214|
pH                             |     417|              99|           0.7071|
Lactate                        |     261|              86|           0.6143|
Base Excess                    |     344|              83|           0.5929|
pCO2                           |     344|              83|           0.5929|
Calculated Total CO2           |     344|              83|           0.5929|
pO2                            |     344|              83|           0.5929|
Free Calcium                   |     197|              66|           0.4714|
Bilirubin, Total               |      94|              60|           0.4286|
RDW-SD                         |     143|              59|           0.4214|
Alanine Aminotransferase (ALT) |      88|              59|           0.4214|
Asparate Aminotransferase (AST)|      88|              59|           0.4214|
Alkaline Phosphatase           |      88|              59|           0.4214|
Lymphocytes                    |      68|              53|           0.3786|
Monocytes                      |      65|              53|           0.3786|
Basophils                      |      62|              50|           0.3571|
Neutrophils                    |      61|              50|           0.3571|
Eosinophils                    |      61|              50|           0.3571|
Oxygen Saturation              |     111|              44|           0.3143|
Potassium, Whole Blood         |     141|              40|           0.2857|
Lactate Dehydrogenase (LD)     |      54|              39|           0.2786|
Specific Gravity               |      38|              38|           0.2714|
Creatine Kinase, MB Isoenzyme  |      67|              36|           0.2571|
Creatine Kinase (CK)           |      54|              35|           0.2500|
Albumin                        |      43|              35|           0.2500|
Fibrinogen, Functional         |      56|              33|           0.2357|
Temperature                    |      68|              32|           0.2286|
Protein                        |      31|              31|           0.2214|

What I am looking for:
- Which labs show up often enough in the first 24 hours to be worth considering?
- Are the expected candidates (creatinine, WBC, hemoglobin, lactate) actually present?
- Is a small lab panel realistic?

Takeaway:
A small early lab panel looks realistic. Creatinine, hemoglobin, and white blood cells 
all have very strong 24-hour coverage, and lactate is not as universal but still shows 
up often enough to be worth considering.

That is a good result because it means I can add a small number of clinically meaningful 
labs without forcing the project into a huge feature expansion.
*/


/*
===============================================================================
Section 6: Candidate lab item IDs

Why run this query:
Before building lab features, I need to confirm which item IDs correspond to
the concepts I care about.

This is especially important because some lab concepts appear under multiple
labels or multiple item IDs in the dictionary.

How to use the result:
This query is a lookup step. It helps decide whether each lab concept should be
represented by:
- one canonical item ID, or
- a concept mapping across multiple valid item IDs.
===============================================================================
*/
SELECT
    NULLIF(TRIM(itemid), '')::int AS itemid,
    NULLIF(TRIM(label), '') AS label
FROM hosp.d_labitems
WHERE UPPER(label) LIKE ANY (ARRAY[
    '%LACTATE%',
    '%CREATININE%',
    '%WBC%',
    '%WHITE BLOOD%',
    '%HEMOGLOBIN%',
    '%HGB%'
])
ORDER BY label, itemid;

/*
Interpretation:
itemid|label                            |
------+---------------------------------+
 51067|24 hr Creatinine                 |
 50855|Absolute Hemoglobin              |
 53134|Absolute Other WBC               |
 51070|Albumin/Creatinine, Urine        |
 51963|Amylase/Creatinine Clearance     |
 51073|Amylase/Creatinine Ratio, Urine  |
 50805|Carboxyhemoglobin                |
 50912|Creatinine                       |
 52546|Creatinine                       |
 50841|Creatinine, Ascites              |
 51977|Creatinine, Blood                |
 51032|Creatinine, Body Fluid           |
 51080|Creatinine Clearance             |
 51787|Creatinine, CSF                  |
 51021|Creatinine, Joint Fluid          |
 51052|Creatinine, Pleural              |
 51081|Creatinine, Serum                |
 51937|Creatinine, Stool                |
 51082|Creatinine, Urine                |
 52024|Creatinine, Whole Blood          |
 51212|Fetal Hemoglobin                 |
 52351|Fetal Hgb                        |
 51631|Glycated Hemoglobin              |
 50811|Hemoglobin                       |
 51222|Hemoglobin                       |
 51640|Hemoglobin                       |
 51641|Hemoglobin  A                    |
 51642|Hemoglobin  A1                   |
 50852|% Hemoglobin A1c                 |
 51643|Hemoglobin  A2                   |
 51223|Hemoglobin A2                    |
 51644|Hemoglobin  C                    |
 51224|Hemoglobin C                     |
 51645|Hemoglobin, Calculated           |
 51646|Hemoglobin  F                    |
 51225|Hemoglobin F                     |
 52128|Hemoglobin H Inclusion           |
 52129|Hemoglobin Other                 |
 51647|Hemoglobin  S                    |
 52411|Hgb                              |
 50813|Lactate                          |
 52442|Lactate                          |
 53154|Lactate                          |
 50843|Lactate Dehydrogenase, Ascites   |
 51795|Lactate Dehydrogenase, CSF       |
 50954|Lactate Dehydrogenase (LD)       |
 51054|Lactate Dehydrogenase, Pleural   |
 51944|Lactate Dehydrogenase, Stool     |
 50814|Methemoglobin                    |
 52144|Methemoglobin                    |
 52032|P50 of Hemoglobin                |
 52157|Plasma Hemoglobin                |
 51099|Protein/Creatinine Ratio         |
 51285|Reticulocyte, Cellular Hemoglobin|
 52183|Sulf Hgb                         |
 52000|Urine  Creatinine                |
 51106|Urine Creatinine                 |
 51516|WBC                              |
 52407|WBC                              |
 51517|WBC Casts                        |
 51518|WBC Clumps                       |
 51300|WBC Count                        |
 52220|wbcp                             |
 52219|WBCScat                          |
 51301|White Blood Cells                |
 51755|White Blood Cells                |
 51756|White Blood Cells                |

What I am looking for:
- Are there multiple item IDs per lab concept?
- Do I need to choose one canonical item ID or map several into one concept?

Takeaway:
There are clearly multiple item IDs for some of these lab concepts, so  each concept is very likley 
not goign to maps neatly... will need to check more carefully to one code without checking. 
For the final feature build, I will need to decide whether to use one canonical item ID or 
map multiple valid item IDs into the same concept.

That is not a problem. It just means the final lab feature step needs to be explicit about concept mapping 
instead of assuming the first matching item ID is automatically the right one.
*/


/*
===============================================================================
Section 7: Coverage check for a hand-picked candidate lab panel

Why run this query:
After identifying likely lab concepts, this query checks whether the selected
candidate panel has enough early coverage to be worth adding to the prepared
dataset.

Current panel under review:
- creatinine
- lactate
- white blood cells
- hemoglobin

How to use the result:
If coverage is strong enough, these labs are realistic candidates for a small
v1.1 feature expansion.

Important note:
The item IDs below are placeholders until I decide which final mapping I want
to use.
===============================================================================
*/
WITH icu_anchor AS (
    SELECT
        NULLIF(TRIM(stay_id), '')::int AS stay_id,
        NULLIF(TRIM(hadm_id), '')::int AS hadm_id,
        intime::timestamp AS intime
    FROM icu.icustays
    WHERE NULLIF(TRIM(stay_id), '') IS NOT NULL
),
lab_dict AS (
    SELECT *
    FROM (
        VALUES
            -- replace item IDs below with final choices if needed
            (50912, 'creatinine'),
            (50813, 'lactate'),
            (51301, 'wbc'),
            (51222, 'hemoglobin')
    ) AS t(itemid, lab_concept)
),
labs AS (
    SELECT
        NULLIF(TRIM(hadm_id), '')::int AS hadm_id,
        NULLIF(TRIM(itemid), '')::int AS itemid,
        COALESCE(charttime::timestamp, storetime::timestamp) AS labtime,
        valuenum::numeric AS valuenum
    FROM hosp.labevents
    WHERE NULLIF(TRIM(hadm_id), '') IS NOT NULL
      AND NULLIF(TRIM(itemid), '') IS NOT NULL
      AND valuenum IS NOT NULL
),
early_labs AS (
    SELECT
        a.stay_id,
        d.lab_concept,
        l.valuenum,
        l.labtime
    FROM icu_anchor a
    JOIN labs l
        ON a.hadm_id = l.hadm_id
       AND l.labtime >= a.intime
       AND l.labtime <  a.intime + interval '24 hour'
    JOIN lab_dict d
        ON l.itemid = d.itemid
)
SELECT
    lab_concept,
    COUNT(*) AS n_events,
    COUNT(DISTINCT stay_id) AS n_stays_with_lab,
    ROUND(
        COUNT(DISTINCT stay_id)::numeric / (SELECT COUNT(*) FROM icu_anchor),
        4
    ) AS stay_coverage_pct,
    ROUND(AVG(valuenum), 3) AS mean_value,
    ROUND(MIN(valuenum), 3) AS min_value,
    ROUND(MAX(valuenum), 3) AS max_value
FROM early_labs
GROUP BY lab_concept
ORDER BY n_stays_with_lab DESC, lab_concept;

/*
Interpretation:
lab_concept|n_events|n_stays_with_lab|stay_coverage_pct|mean_value|min_value|max_value|
-----------+--------+----------------+-----------------+----------+---------+---------+
creatinine |     309|             138|           0.9857|     1.626|    0.200|   15.200|
hemoglobin |     312|             136|           0.9714|    10.239|    3.900|   16.000|
wbc        |     311|             136|           0.9714|    13.603|    0.400|  116.100|
lactate    |     261|              86|           0.6143|     3.360|    0.600|   13.200|

What I am looking for:
- Is the candidate lab panel strong enough overall?
- Which labs are clearly worth adding?
- Is any lab too sparse to bother with?

Takeaway:
This candidate lab panel looks strong enough to move forward with. Creatinine, hemoglobin, 
and white blood cells are basically no-brainer additions based on coverage alone. 
Lactate is less common, but still present often enough to be worth keeping in the discussion.

So at this point, a targeted lab expansion looks justified instead of speculative.
*/


/*
===============================================================================
Section 8: Repeated-measure feasibility for candidate labs

Why run this query:
Before deciding how to engineer the lab features, I need to know whether the
candidate labs are usually measured only once in the first 24 hours or whether
they are often repeated.

How to use the result:
- If most stays only have one result early, then `first_24h` may be enough.
- If repeated measurements are common, then summaries like min, max, mean, or
  last become more reasonable.

Important note:
The item IDs below are placeholders until I decide which final mapping I want
to use.
===============================================================================
*/
WITH icu_anchor AS (
    SELECT
        NULLIF(TRIM(stay_id), '')::int AS stay_id,
        NULLIF(TRIM(hadm_id), '')::int AS hadm_id,
        intime::timestamp AS intime
    FROM icu.icustays
    WHERE NULLIF(TRIM(stay_id), '') IS NOT NULL
),
lab_dict AS (
    SELECT *
    FROM (
        VALUES
            -- replace item IDs below with final choices if needed
            (50912, 'creatinine'),
            (50813, 'lactate'),
            (51301, 'wbc'),
            (51222, 'hemoglobin')
    ) AS t(itemid, lab_concept)
),
labs AS (
    SELECT
        NULLIF(TRIM(hadm_id), '')::int AS hadm_id,
        NULLIF(TRIM(itemid), '')::int AS itemid,
        COALESCE(charttime::timestamp, storetime::timestamp) AS labtime,
        valuenum::numeric AS valuenum
    FROM hosp.labevents
    WHERE NULLIF(TRIM(hadm_id), '') IS NOT NULL
      AND NULLIF(TRIM(itemid), '') IS NOT NULL
      AND valuenum IS NOT NULL
),
early_labs AS (
    SELECT
        a.stay_id,
        d.lab_concept,
        l.labtime,
        l.valuenum
    FROM icu_anchor a
    JOIN labs l
        ON a.hadm_id = l.hadm_id
       AND l.labtime >= a.intime
       AND l.labtime <  a.intime + interval '24 hour'
    JOIN lab_dict d
        ON l.itemid = d.itemid
),
stay_lab_counts AS (
    SELECT
        stay_id,
        lab_concept,
        COUNT(*) AS n_obs
    FROM early_labs
    GROUP BY stay_id, lab_concept
)
SELECT
    lab_concept,
    COUNT(*) AS n_stays_with_lab,
    ROUND(AVG(n_obs), 3) AS mean_obs_per_stay,
    MAX(n_obs) AS max_obs_per_stay,
    SUM(CASE WHEN n_obs >= 2 THEN 1 ELSE 0 END) AS n_stays_with_2plus_obs,
    ROUND(
        SUM(CASE WHEN n_obs >= 2 THEN 1 ELSE 0 END)::numeric / COUNT(*),
        4
    ) AS pct_stays_with_2plus_obs
FROM stay_lab_counts
GROUP BY lab_concept
ORDER BY n_stays_with_lab DESC, lab_concept;

/*
Interpretation:
lab_concept|n_stays_with_lab|mean_obs_per_stay|max_obs_per_stay|n_stays_with_2plus_obs|pct_stays_with_2plus_obs|
-----------+----------------+-----------------+----------------+----------------------+------------------------+
creatinine |             138|            2.239|               9|                    98|                  0.7101|
hemoglobin |             136|            2.294|               9|                    90|                  0.6618|
wbc        |             136|            2.287|               9|                    89|                  0.6544|
lactate    |              86|            3.035|              11|                    55|                  0.6395|

What I am looking for:
- Are these labs usually measured once or multiple times early?
- Do I want just first-value features, or simple summaries like first + mean
  or first + max?

Takeaway:
These labs are repeated often enough that I do not need to limit myself to just one first-value feature. 
Creatinine, hemoglobin, and white blood cells are usually measured more than once in the first 24 hours, and 
lactate is repeated even more when it is present.

That means simple summaries are reasonable. I still do not want to go overboard, but something like first 
plus mean for the routine labs and first plus max for lactate looks defensible.
*/


/*
===============================================================================
End-of-script summary placeholder

Use this after reviewing all results.

Questions to answer:
1. Should `admission_type` be collapsed?
2. Should `first_careunit` be collapsed?
3. Which early labs should be added?
4. How simple or rich should the lab summaries be?

Working recommendation:
At this point, I think the right move is a targeted v1.1 expansion, not a full rebuild.

Admission type should be collapsed. First careunit should also be collapsed, because the grouped version 
is much cleaner than the raw field. On the lab side, creatinine, hemoglobin, and white blood cells 
look like strong additions, and lactate looks worth keeping even though its coverage is lower.

For the lab summaries, I do not think I need to get fancy. The audit suggests I can justify a small 
set of early summaries without turning this into a giant lab-feature build. The goal here is to 
improve the feature mix enough to give the model a better shot, while still keeping the dataset 
simple enough to explain and defend.
===============================================================================
*/