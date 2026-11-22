# FABINI Data / BI Analyst Case Study

This repository is organized into four numbered stages. Keep source files unchanged, use paths relative to the repository root, and commit related work in logical milestones.

## Repository structure

| Stage | Purpose |
| --- | --- |
| `s0_raw/` | Original CSV files in `data/` and DuckDB exploration queries in `sql/`. |
| `s1_staging/` | One Jupyter notebook per source table in `notebooks/`; write its Parquet output to `data/`. |
| `s2_analytics/` | Standalone DuckDB SQL files, separated into `models/`, `validation/`, and `management_analysis/`. |
| `s3_reporting/` | Power BI Project (`.pbip`) files in `powerbi/`. |

Use lowercase `snake_case` for table-based notebook and SQL filenames. Name a source table's notebook `<source_table>.ipynb` and its staged output `<source_table>.parquet`. Keep notebook code and documentation in English, and use `display()` to show notebook outputs.

## Python environment

Use Python 3.11 or newer:

```bash
python -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements.txt
jupyter lab
```

In PowerShell, activate the environment with `.venv\Scripts\Activate.ps1`.

The required Python packages are pinned in `requirements.txt`. Do not add transformations or placeholder source-specific notebooks until the source tables are known.

## Raw data exploration

Place original CSV files in `s0_raw/data/` and leave them unchanged. Store exploration queries as standalone `.sql` files in `s0_raw/sql/`. The workspace recommends SQLTools and its DuckDB driver; use a local DuckDB database or an in-memory connection and keep file paths relative to the repository root.

## Staging, analysis, and reporting

Create one notebook in `s1_staging/notebooks/` for each source table. Each notebook will load and stage that table with Polars and write its Parquet output to `s1_staging/data/`.

Keep business logic, analytical models, data validation, and management analysis in standalone DuckDB SQL files under the corresponding `s2_analytics/` subdirectory. Build reporting artifacts as a Power BI Project under `s3_reporting/powerbi/`.

This repository initialization provides structure and dependencies only; it does not implement data transformations.
