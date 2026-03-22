#!/usr/bin/env bash
set -euo pipefail

# -----------------------------------------------------------------------------
# run_v1_pipeline.sh
#
# Purpose:
#   Rebuild the v1 data preparation pipeline end-to-end:
#     07 -> vitals features (0-24h window; stay_id grain)
#     08 -> modeling table (stay_id grain; LOS>=8d label)
#     09 -> report-ready evidence tables (CSV exports)
#   Then export:
#     - data/processed/icu_stay_modeling_24h_v1.csv
#     - outputs/tables/report_*_v1.csv
#
# Why:
#   "Show your work" isn't just notebooks—it's reproducibility.
#   This script is the single-command replay of your M7/M8 foundation.
#
# Usage:
#   export PGURI='host=localhost port=5432 dbname=mimic_demo user=mimic_reader'
#   ./scripts/run_v1_pipeline.sh
#
# Notes:
#   - Assumes psql is installed and PGURI points to your local Postgres.
#   - Uses ON_ERROR_STOP to fail fast if any SQL step breaks.
# -----------------------------------------------------------------------------

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SQL_DIR="${ROOT_DIR}/data/sql"
OUT_DIR="${ROOT_DIR}/outputs/tables"
PROC_DIR="${ROOT_DIR}/data/processed"

: "${PGURI:?PGURI is not set. Example: export PGURI='host=localhost port=5432 dbname=mimic_demo user=mimic_reader'}"

mkdir -p "${OUT_DIR}" "${PROC_DIR}"

echo "==> [1/6] Running 07_construct_vitals_24h_features.sql"
psql "$PGURI" -v ON_ERROR_STOP=1 -f "${SQL_DIR}/07_construct_vitals_24h_features.sql"

echo "==> [2/6] Running 08_build_modeling_table_icu_stay_24h.sql"
psql "$PGURI" -v ON_ERROR_STOP=1 -f "${SQL_DIR}/08_build_modeling_table_icu_stay_24h.sql"

echo "==> [3/6] Sanity checks (row count, distinct stay_id, outcome prevalence)"
psql "$PGURI" -v ON_ERROR_STOP=1 -c "
SELECT
  COUNT(*) AS n_rows,
  COUNT(DISTINCT stay_id) AS n_distinct_stay_id
FROM derived.icu_stay_modeling_24h_v1;
"

psql "$PGURI" -v ON_ERROR_STOP=1 -c "
SELECT prolonged_los_8d, COUNT(*) AS n
FROM derived.icu_stay_modeling_24h_v1
GROUP BY 1
ORDER BY 1;
"

echo "==> [4/6] Export processed modeling CSV"
psql "$PGURI" -v ON_ERROR_STOP=1 -c "\copy (
  SELECT *
  FROM derived.icu_stay_modeling_24h_v1
  ORDER BY stay_id
) TO '${PROC_DIR}/icu_stay_modeling_24h_v1.csv' CSV HEADER"

echo "==> [5/6] Running 09_report_tables_assignment1.sql (writes report_*_v1.csv)"
# 09 should contain \copy statements that output to outputs/tables/
psql "$PGURI" -v ON_ERROR_STOP=1 -f "${SQL_DIR}/09_report_tables_assignment1.sql"

echo "==> [6/6] Done."
echo "Outputs:"
echo "  - ${PROC_DIR}/icu_stay_modeling_24h_v1.csv"
echo "  - ${OUT_DIR}/report_*_v1.csv"
