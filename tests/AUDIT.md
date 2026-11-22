# Data Quality Audit

## Checks

- **Orders — PASS:** 22,230 source lines; 21,604 active; 626 cancellations excluded.
- **Financials — PASS:** Net sales CZK 27,546,681.05; reconciliation difference CZK 0.00.
- **FX — PASS:** 7,886 lines verified; no mismatches.
- **Bundles — PASS:** 26,734 rows; no allocation differences.
- **COGS — PASS with limitation:** Known-cost calculations verified; 277 rows have missing costs.
- **Daily metrics — PASS:** 820 date-shop rows; 14,152 orders; no mismatches.
- **Budget — PASS:** 27 month-shop records for January–September 2026.

## Limitations

- **Missing costs:** Four unknown SKUs affect 1.50% of net sales. Total COGS and margin are incomplete.
- **Reporting dates:** 231 lines dated September 30 UTC report as October 1 in Prague; exclude them from Q3.
- **Pending checks:** Customer-ID preservation and anomaly analysis were not independently verified.

**Status:** Core pipeline checks passed. Task 2 is complete.
