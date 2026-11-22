# Data Quality Audit

## Current dbt-only pipeline status

The root-level dbt-only GitHub Actions run completed successfully: **20 PASS, 0 ERROR**, including all eight SQL tests. Local validation of the generated CSV exports completed with **8/8 PASS**.

A complete row-by-row comparison against the former standalone pipeline has not been performed.

## Reference audit figures

These figures were documented during validation of the former pipeline; they are retained as audit context and are not a full row-by-row reconciliation of dbt.

- **Orders:** 22,230 source lines; 21,604 active; 626 cancellations excluded.
- **Financials:** Net sales CZK 27,546,681.05; reconciliation difference CZK 0.00.
- **FX:** 7,886 lines verified; no mismatches.
- **Bundles:** 26,734 rows; no allocation differences.
- **COGS:** Known-cost calculations verified; 277 rows have missing costs.
- **Daily metrics:** 820 date-shop rows; 14,152 orders; no mismatches.
- **Budget:** 27 month-shop records for January–September 2026.

## Limitations

- **Missing costs:** Four unknown SKUs affect 1.50% of net sales. Total COGS and margin are incomplete.
- **Reporting dates:** 231 lines dated September 30 UTC report as October 1 in Prague; exclude them from Q3.
- **Pending checks:** Customer-ID preservation and anomaly analysis were not independently verified.

**Status:** The dbt-only pipeline and local CSV validation passed. Historical audit figures above refer to the former pipeline and are not evidence of full dataset reconciliation. Full row-by-row reconciliation remains unperformed.
