# Case Study Answers

## 1. Monthly Performance

Q1-to-Q3 net sales:

- **HU:** CZK 880,788.19 → 1,369,622.53; +CZK 488,834.34 (+55.50%), fastest growth.
- **CZ:** CZK 5,874,340.20 → 6,501,364.55; +CZK 627,024.35 (+10.67%).
- **SK:** CZK 2,293,396.36 → 2,227,958.02; -CZK 65,438.34 (-2.85%).

January–September net sales by month:

- **CZ:** Jan 2,305,910.87; Feb 1,914,096.09; Mar 1,654,333.24; Apr 1,674,828.48; May 1,982,292.71; Jun 1,589,701.29; Jul 2,248,638.35; Aug 2,117,727.53; Sep 2,134,998.67.
- **HU:** Jan 364,265.76; Feb 213,239.31; Mar 303,283.12; Apr 338,482.33; May 369,238.24; Jun 332,700.17; Jul 510,299.30; Aug 425,083.91; Sep 434,239.32.
- **SK:** Jan 863,681.64; Feb 673,613.53; Mar 756,101.19; Apr 590,119.24; May 646,327.12; Jun 625,596.23; Jul 737,522.45; Aug 822,801.27; Sep 667,634.30.

Monthly COGS and margins cannot be fully calculated because of missing product costs.

**Interpretation:** HU had the fastest percentage growth; CZ had the largest absolute increase, while SK declined. See [01_monthly_performance.sql](analysis/01_monthly_performance.sql).

## 2. Q3 Actual vs Budget

**Overall:** Actual CZK 10,098,945.10; budget CZK 10,308,000.00; variance -CZK 209,054.90 (-2.03%). Volume effect +CZK 314,384.54; AOV effect -CZK 523,439.44.

- **CZ:** Sales CZK 6,501,364.55 vs 6,497,000.00; variance +CZK 4,364.55 (+0.07%). Orders 3,305 vs 3,063 (+242); AOV CZK 1,967.13 vs 2,121.12. Volume effect +CZK 513,311.79; AOV effect -CZK 508,947.24.
- **HU:** Sales CZK 1,369,622.53 vs 1,246,000.00; variance +CZK 123,622.53 (+9.92%). Orders 781 vs 711 (+70); AOV CZK 1,753.68 vs 1,752.46. Volume effect +CZK 122,672.29; AOV effect +CZK 950.24.
- **SK:** Sales CZK 2,227,958.02 vs 2,565,000.00; variance -CZK 337,041.98 (-13.14%). Orders 1,151 vs 1,316 (-165); AOV CZK 1,935.67 vs 1,949.09. Volume effect -CZK 321,599.54; AOV effect -CZK 15,442.44.

Volume effect = (actual orders - budget orders) × budget AOV. AOV effect = actual orders × (actual AOV - budget AOV). Volume is rounded to cents; its rounding residual is assigned to AOV effect so the two effects equal the sales variance.

**Interpretation:** CZ's higher order volume was offset by lower AOV; HU was slightly above budget on both; SK's shortfall was mainly volume-driven.

## 3. Top 5 Products

Q3 ranking by known gross profit (net sales less COGS):

- **Frying pan 24 cm (`FB-PAN-24`):** CZK 868,039.80; discount/gross sales 4.77%.
- **Frying pan 28 cm (`FB-PAN-28`):** CZK 817,788.88; 4.36%.
- **Pot 24 cm (`FB-POT-24`):** CZK 476,277.38; 8.29%.
- **Pot 20 cm (`FB-POT-20`):** CZK 476,263.01; 7.57%.
- **Frying pan 20 cm (`FB-PAN-20`):** CZK 473,064.87; 4.02%.

Bundle revenue and discounts are allocated to components by cost share. Products with unknown COGS are excluded, not ranked at zero; Q3 includes 100 uncosted rows totaling CZK 150,199.44 across four missing SKUs. See [03_top5_products_q3.sql](analysis/03_top5_products_q3.sql).

**Interpretation:** Frying pan 24 cm led known gross profit; all ranked products have known costs.

## 4. Customer Analysis

Sales shares by shop; first-observed means the customer's earliest Prague-local order date within January–September. Later dates are classified as returning.

- **CZ:** First-observed 66.3%; returning 26.7%; missing ID 7.0%. 620 orders without an ID.
- **HU:** First-observed 65.8%; returning 29.3%; missing ID 4.9%. 106 orders without an ID.
- **SK:** First-observed 65.5%; returning 27.7%; missing ID 6.8%. 219 orders without an ID.

Total orders without customer IDs: **945**. First-observed does not mean truly new; customer history before this dataset is unavailable. See [04_customer_analysis.sql](analysis/04_customer_analysis.sql).

**Interpretation:** First-observed sales are the largest identified group in each shop; missing-ID sales account for 4.9–7.0%.
