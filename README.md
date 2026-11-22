# FABINI Data & BI Case Study

This project stages six source CSVs, uses dbt Core with DuckDB as its SQL modeling workflow, answers four management questions, and targets a one-page Power BI report. Tasks 1–3 are complete; the dashboard and final submission review remain outstanding.

## Data flow and dbt build

Install the project dependencies with `pip install -r requirements.txt`. The six Polars notebooks in `s1_staging/notebooks/` read `raw_data/raw_*.csv` and write Parquet files to `s1_staging/data/`. Run those notebooks before building the dbt project.

The dbt project declares the six Parquet datasets as sources and builds four models: `int_orders`, `int_sales_lines`, `fact_sales`, and `fact_daily_metrics`. It includes eight SQL data-quality tests and exports `fact_sales.csv` and `fact_daily_metrics.csv` under `dbt_poc/`.

From the repository root, run:

```shell
dbt build --project-dir dbt_poc --profiles-dir dbt_poc
```

The GitHub Actions workflow, [dbt-ci.yml](.github/workflows/dbt-ci.yml), installs its pinned dependencies, executes staging, runs `dbt build`, and checks and uploads both exports. It uses Python 3.11 and the `workflow_dispatch` event for manual runs from the Actions tab.

The four management SQL analyses in `analysis/` query the dbt output tables in `dbt_poc/fabini_poc.duckdb`. Run them with a DuckDB client connected to that database and with the repository root as the working directory; the budget and product lookups use staged Parquet paths relative to the root.

## Validation status

- **GitHub Actions:** the latest reported run completed staging and `dbt build` successfully, including all eight SQL tests, and generated both expected CSV exports.
- **Reconciliation limitation:** a complete row-by-row comparison against the former standalone pipeline was not performed.


## Assumptions and limitations

- Deduplicate orders by latest `exported_at`; exclude cancelled lines from sales. Interpret timestamps as Prague-local reporting dates.
- Remove VAT at 21% (CZ), 23% (SK), and 27% (HU). FX rates are foreign-currency units per CZK; use the latest rate on or before the reporting date.
- Discounts are line totals; round gross sales and discounts separately to CZK cents before calculating net sales. Allocate bundle sales to components by component cost share. Calculate COGS from sold quantity and catalog unit cost; keep missing costs NULL, not zero.
- Analysis covers January–September 2026. September 30 UTC lines that report as October 1 in Prague are outside that period. “First-observed” customers are only first observed in this dataset.
- Four SKUs are absent from the product catalog, leaving 277 sales rows (about 1.5% of net sales) without known costs. Total COGS and margin are therefore incomplete. The audit also marks independent customer-ID and anomaly checks as pending; see [tests/AUDIT.md](tests/AUDIT.md).

Management SQL is in `analysis/`; results are summarized in [answers.md](answers.md). `dashboard/` is the target for the PBIP report and PDF, but is currently empty. Complete and validate the dashboard, investigate the missing-cost and pending audit items, then finish the submission review.
