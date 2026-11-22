# S1 Staging Specification

This specification summarizes executed findings in the [source exploration notebooks](../s0_sources/sql/). “Verified” refers to those outputs; staging types and unresolved semantics are identified separately.

## Orders

The three order files share this schema. DuckDB's inferred source types are shown first; staging types follow the exploration decisions and project requirements.

Evidence: [CZ orders](../s0_sources/sql/01_raw_orders_cz.ipynb), [SK orders](../s0_sources/sql/01_raw_orders_sk.ipynb), and [HU orders](../s0_sources/sql/01_raw_orders_hu.ipynb).

| Columns | Source type | Staging type |
| --- | --- | --- |
| `order_id`, `sku`, `currency`, `customer_id` | VARCHAR | String |
| `line_id` | BIGINT | String; preserve identifier semantics |
| `quantity` | BIGINT | Int64 |
| `price_with_vat`, `discount_with_vat` | DOUBLE | Decimal(18,2) |
| `created_at`, `cancelled_at` | TIMESTAMP WITH TIME ZONE | UTC Datetime |
| `exported_at` | TIMESTAMP | Datetime; source has no timezone suffix |
| `shop` | Derived from source file | String |

| Shop | Currency | Raw rows | Duplicate rows | Expected staged rows | Missing customers | Cancelled rows | Cancellation updates |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| CZ | CZK | 14,709 | 610 | 14,099 | 1,035 | 381 | 272 |
| SK | EUR | 5,439 | 263 | 5,176 | 375 | 152 | 118 |
| HU | HUF | 3,101 | 146 | 2,955 | 168 | 93 | 75 |

Verified checks found no missing required fields, invalid numeric values, currencies, timestamps, or business values. Deduplicate by `line_id`, keeping the latest `exported_at`; preserve cancellation updates, `cancelled_at`, and NULL `customer_id`. Preserve source currency; do not convert it in staging.

## Products

Evidence: [product exploration](../s0_sources/sql/01_raw_products.ipynb).

Source columns are `sku`, `product_name`, `category`, `unit_cost_czk`, `is_bundle`, and `bundle_components` (read as VARCHAR during exploration). Suggested staging types: String for identifiers and descriptions, Decimal(18,2) for `unit_cost_czk`, Boolean for `is_bundle`, and String for `bundle_components`.

Verified: 28 rows and unique SKUs; four bundles contain 12 component entries. Bundle costs are NULL; all components and component costs resolve. Preserve those NULLs and definitions; do not expand bundles in staging.

## FX rates

Evidence: [FX exploration](../s0_sources/sql/01_raw_fx_rates.ipynb).

Source columns are `date`, `currency`, and `fx_rate` (read as VARCHAR during exploration). Suggested staging types: Date, String, and Decimal(18,6), respectively; the exploration validates rates using Decimal(18,6).

Verified: 382 rates (191 each for EUR and HUF), from 2025-12-29 through 2026-09-30; no duplicate date-currency keys or invalid/missing values. Each currency has 85 calendar days without a rate. All 8,540 raw SK/HU order rows have historical rate coverage. The original assignment confirms the quote as foreign currency units per 1 CZK. Downstream sales use the latest rate on or before the Prague-local order date and divide foreign-currency amounts by that rate to convert them to CZK. Preserve source dates and rates; do not fill missing dates or convert currencies in staging.

## Budget

Evidence: [budget exploration](../s0_sources/sql/01_raw_budget.ipynb).

Source columns are `month`, `shop`, `orders_budget`, and `net_sales_czk_budget` (read as VARCHAR during exploration). Suggested types: String for `shop`, Int64 for `orders_budget`, and Decimal(18,2) for `net_sales_czk_budget`. Convert the month to Date only after confirming its canonical representation.

Verified: 27 rows, one row per month-shop, with all three shops represented for January–September 2026. No duplicate keys or missing/invalid values were found. Budget sales amounts are in CZK and remain unchanged in staging.

## Cross-source findings

Evidence: [cross-source validation](../s0_sources/sql/01_cross_source_validation.ipynb).

Four SKUs are absent from the product catalog, affecting 297 raw order rows: 180 CZ, 83 SK, and 34 HU. Preserve the order rows without inventing product attributes or costs.

| Missing SKU | Affected raw order rows |
| --- | ---: |
| `FB-PAN-24-LTD` | 113 |
| `FB-WOK-30-BLK` | 79 |
| `FB-KNF-UTIL` | 63 |
| `FB-POT-28` | 42 |

## Pending decisions

- The current staged orders have no `line_id` values with equal latest `exported_at` timestamps. A tie-breaker for that case in future source data remains undefined.
