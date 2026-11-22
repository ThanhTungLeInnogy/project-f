# Data Quality Audit

## dbt CI validation

The latest reported GitHub Actions run completed staging and `dbt build` successfully, including the eight configured SQL tests, and generated both expected CSV exports under `dbt_poc/`.

A complete row-by-row comparison against the former standalone pipeline was not performed.

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

**Status:** dbt is the primary workflow; its latest reported GitHub Actions build and exports succeeded. Task 2 is complete. Full row-level reconciliation against the former pipeline remains unperformed.
