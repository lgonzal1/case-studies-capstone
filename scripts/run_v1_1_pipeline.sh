#!/usr/bin/env bash
set -euo pipefail

# -----------------------------------------------------------------------------
# run_v1_1_pipeline.sh
#
# Purpose:
#   Rebuild the final Assignment 2 data preparation pipeline end-to-end:
#     07 -> stay-level vitals features (0-24h window; stay_id grain)
#     10 -> targeted v1.1 feature audit
#     11 -> stay-level labs + grouped context features
#     12 -> final modeling table (stay_id grain; LOS>=8d label)
#
#   Then:
#     - run sanity checks
#     - export the final processed modeling CSV
#     - optionally export a schema/profile CSV for documentation
#
# Why:
#   Assignment 2 "show your work" needs reproducibility, not just notebooks.
#   This script is the single-command replay of the final v1.1 data preparation
#   workflow used for the report and final modeling run.
#
# Usage:
#   export PGURI='host=localhost port=5432 dbname=mimic_demo user=mimic_reader'
#   ./scripts/run_v1_1_pipeline.sh
#
# Notes:
#   - Assumes psql is installed and PGURI points to your local Postgres.
#   - Uses ON_ERROR_STOP to fail fast if any SQL step breaks.
#   - The schema CSV export requires python3 + pandas. If unavailable, the
#     pipeline still completes and just skips that optional step.
# -----------------------------------------------------------------------------

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SQL_DIR="${ROOT_DIR}/data/sql"
OUT_DIR="${ROOT_DIR}/outputs/tables"
PROC_DIR="${ROOT_DIR}/data/processed"

: "${PGURI:?PGURI is not set. Example: export PGURI='host=localhost port=5432 dbname=mimic_demo user=mimic_reader'}"

mkdir -p "${OUT_DIR}" "${PROC_DIR}"

echo "==> [1/7] Running 07_construct_vitals_24h_features.sql"
psql "$PGURI" -v ON_ERROR_STOP=1 -f "${SQL_DIR}/07_construct_vitals_24h_features.sql"

echo "==> [2/7] Running 10_assignment2_feature_audit_v1_1.sql"
psql "$PGURI" -v ON_ERROR_STOP=1 -f "${SQL_DIR}/10_assignment2_feature_audit_v1_1.sql"

echo "==> [3/7] Running 11_construct_labs_24h_features_v1_1.sql"
psql "$PGURI" -v ON_ERROR_STOP=1 -f "${SQL_DIR}/11_construct_labs_24h_features_v1_1.sql"

echo "==> [4/7] Running 12_build_modeling_table_icu_stay_24h_v1_1.sql"
psql "$PGURI" -v ON_ERROR_STOP=1 -f "${SQL_DIR}/12_build_modeling_table_icu_stay_24h_v1_1.sql"

echo "==> [5/7] Sanity checks (row count, distinct stay_id, outcome prevalence)"
psql "$PGURI" -v ON_ERROR_STOP=1 -c "
SELECT
  COUNT(*) AS n_rows,
  COUNT(DISTINCT stay_id) AS n_distinct_stay_id
FROM derived.icu_stay_modeling_24h_v1_1;
"

psql "$PGURI" -v ON_ERROR_STOP=1 -c "
SELECT prolonged_los_8d, COUNT(*) AS n
FROM derived.icu_stay_modeling_24h_v1_1
GROUP BY 1
ORDER BY 1;
"

echo "==> [6/7] Export processed modeling CSV"
psql "$PGURI" -v ON_ERROR_STOP=1 -c "\copy (
  SELECT *
  FROM derived.icu_stay_modeling_24h_v1_1
  ORDER BY stay_id
) TO '${PROC_DIR}/icu_stay_modeling_24h_v1_1.csv' CSV HEADER"

echo "==> [7/7] Optional schema/profile export (if python3 + pandas are available)"
if command -v python3 >/dev/null 2>&1; then
  export ROOT_DIR
  python3 - <<'PY'
from pathlib import Path
import os

try:
    import pandas as pd
except ImportError:
    print("Skipping schema export: pandas is not installed.")
    raise SystemExit(0)

project_root = Path(os.environ["ROOT_DIR"]).resolve()
csv_path = project_root / "data/processed/icu_stay_modeling_24h_v1_1.csv"
out_path = project_root / "outputs/tables/icu_stay_modeling_24h_v1_1_schema.csv"

df = pd.read_csv(csv_path, parse_dates=["intime", "outtime"])

target_cols = {"prolonged_los_8d"}
audit_cols = {
    "subject_id", "hadm_id", "stay_id",
    "intime", "outtime", "los_days",
    "first_careunit", "last_careunit", "admission_type"
}

def guess_role(col: str) -> str:
    if col in target_cols:
        return "target"
    if col in audit_cols:
        return "audit_only"
    return "predictor"

def guess_feature_family(col: str) -> str:
    if col in target_cols:
        return "target"
    if col in audit_cols:
        return "audit"
    if col.endswith("_grp"):
        return "grouped_context"
    if col.startswith("has_"):
        return "presence_flag"
    if "chartevents" in col or "missing_core_vitals" in col:
        return "measurement_density_or_missingness"
    if any(col.startswith(prefix) for prefix in ["hr_", "rr_", "spo2_", "temp_", "map_"]):
        return "vitals_summary"
    if any(col.startswith(prefix) for prefix in ["creatinine_", "wbc_", "hemoglobin_", "lactate_"]):
        return "lab_summary"
    return "other"

rows = []
for col in df.columns:
    series = df[col]
    non_null = int(series.notna().sum())
    nulls = int(series.isna().sum())
    pct_null = round(nulls / len(df), 4) if len(df) else 0.0
    nunique = int(series.nunique(dropna=True))

    example_vals = series.dropna().astype(str).head(3).tolist()
    example_value = " | ".join(example_vals) if example_vals else ""

    rows.append({
        "column_name": col,
        "pandas_dtype": str(series.dtype),
        "role": guess_role(col),
        "feature_family": guess_feature_family(col),
        "non_null_count": non_null,
        "null_count": nulls,
        "pct_null": pct_null,
        "n_unique_non_null": nunique,
        "example_value": example_value,
    })

schema_df = pd.DataFrame(rows)

role_order = {"target": 0, "audit_only": 1, "predictor": 2}
schema_df["role_sort"] = schema_df["role"].map(role_order).fillna(99)
schema_df = schema_df.sort_values(["role_sort", "feature_family", "column_name"]).drop(columns="role_sort")

out_path.parent.mkdir(parents=True, exist_ok=True)
schema_df.to_csv(out_path, index=False)

print(f"Created schema/profile CSV: {out_path}")
print(f"Rows: {len(df)}")
print(f"Distinct stay_id: {df['stay_id'].nunique()}")
print("Target prevalence:")
print(df["prolonged_los_8d"].value_counts(dropna=False))
print(df["prolonged_los_8d"].value_counts(normalize=True).round(4))
PY
else
  echo "Skipping schema export: python3 not found."
fi

echo "==> Done."
echo "Outputs:"
echo "  - ${PROC_DIR}/icu_stay_modeling_24h_v1_1.csv"
echo "  - ${OUT_DIR}/icu_stay_modeling_24h_v1_1_schema.csv (if python3 + pandas available)"
