# FABINI Data & BI Case Study

This project stages six source CSVs, models sales, answers four management questions, and targets a one-page Power BI report. Tasks 1–3 are complete; the dashboard and final submission review remain outstanding.

## Data flow and dbt build

The six Polars notebooks in `s1_staging/notebooks/` read `raw_data/raw_*.csv` and write Parquet files to `s1_staging/data/`. The dbt project declares those six Parquet datasets as sources and builds four models: `int_orders`, `int_sales_lines`, `fact_sales`, and `fact_daily_metrics`. It includes eight focused SQL data-quality tests and exports `fact_sales.csv` and `fact_daily_metrics.csv` under `dbt_poc/`.

From the repository root, the dbt build command is:

```shell
dbt build --project-dir dbt_poc --profiles-dir dbt_poc
```

The GitHub Actions workflow, [dbt-ci.yml](.github/workflows/dbt-ci.yml), installs its pinned dependencies, executes staging, runs `dbt build` and checks/uploads the exports. It uses Python 3.11 and the `workflow_dispatch` event for manual runs from the Actions tab.

## Validation status

- **Standalone DuckDB pipeline:** executed and validated; retained as the reference baseline until dbt passes full reconciliation.
- **dbt implementation:** static validation passed; runtime **NOT RUN**. Its financial results and CSV contents are not yet validated.
- **GitHub Actions:** configured; **NOT RUN**.

Do not replace or remove the standalone runner until dbt has passed runtime, financial, and export reconciliation.

## Assumptions and limitations

- Deduplicate orders by latest `exported_at`; exclude cancelled lines from sales. Interpret timestamps as Prague-local reporting dates.
- Remove VAT at 21% (CZ), 23% (SK), and 27% (HU). FX rates are foreign-currency units per CZK; use the latest rate on or before the reporting date.
- Discounts are line totals; round gross sales and discounts separately to CZK cents before calculating net sales. Allocate bundle sales to components by component cost share. Calculate COGS from sold quantity and catalog unit cost; keep missing costs NULL, not zero.
- Analysis covers January–September 2026. September 30 UTC lines that report as October 1 in Prague are outside that period. “First-observed” customers are only first observed in this dataset.
- Four SKUs are absent from the product catalog, leaving 277 sales rows (about 1.5% of net sales) without known costs. Total COGS and margin are therefore incomplete. The audit also marks independent customer-ID and anomaly checks as pending; see [tests/AUDIT.md](tests/AUDIT.md).

Management SQL is in `analysis/`; results are summarized in [answers.md](answers.md). `dashboard/` is the target for the PBIP report and PDF, but is currently empty. Complete and validate the dashboard, investigate the missing-cost and pending audit items, then finish the submission review.
