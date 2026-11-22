-- S3 | sales | fact_daily_metrics_reconcile_to_fact_sales
-- Reads from: fact_sales, vw_22_sales_lines, and fact_daily_metrics
-- Produces: violating daily reconciliation rows; zero rows means pass

WITH fact_totals AS (
    SELECT
        reporting_date,
        shop,
        SUM(gross_sales_czk) AS gross_sales_czk,
        SUM(discounts_czk) AS discounts_czk,
        SUM(net_sales_czk) AS net_sales_czk,
        SUM(cogs_czk) FILTER (WHERE cogs_czk IS NOT NULL) AS known_cogs_czk,
        SUM(net_sales_czk) FILTER (WHERE cogs_czk IS NULL) AS uncosted_net_sales_czk,
        COUNT(*) FILTER (WHERE cogs_czk IS NULL) AS unknown_cost_line_count,
        CASE
            WHEN COUNT(*) FILTER (WHERE cogs_czk IS NULL) > 0 THEN NULL
            ELSE SUM(cogs_czk)
        END AS cogs_czk
    FROM {{ ref('fact_sales') }}
    GROUP BY reporting_date, shop
),
orders_by_day AS (
    SELECT
        reporting_date,
        shop,
        COUNT(DISTINCT order_id) AS order_count
    FROM {{ ref('vw_22_sales_lines') }}
    GROUP BY reporting_date, shop
),
expected_daily AS (
    SELECT
        COALESCE(fact_totals.reporting_date, orders_by_day.reporting_date) AS reporting_date,
        COALESCE(fact_totals.shop, orders_by_day.shop) AS shop,
        fact_totals.gross_sales_czk,
        fact_totals.discounts_czk,
        fact_totals.net_sales_czk,
        fact_totals.known_cogs_czk,
        fact_totals.uncosted_net_sales_czk,
        fact_totals.unknown_cost_line_count,
        fact_totals.cogs_czk,
        orders_by_day.order_count
    FROM fact_totals
    FULL OUTER JOIN orders_by_day
        USING (reporting_date, shop)
)
SELECT
    reporting_date,
    shop,
    expected_daily.gross_sales_czk AS fact_gross_sales_czk,
    fact_daily_metrics.gross_sales_czk AS daily_gross_sales_czk,
    expected_daily.discounts_czk AS fact_discounts_czk,
    fact_daily_metrics.discounts_czk AS daily_discounts_czk,
    expected_daily.net_sales_czk AS fact_net_sales_czk,
    fact_daily_metrics.net_sales_czk AS daily_net_sales_czk,
    expected_daily.known_cogs_czk AS fact_known_cogs_czk,
    fact_daily_metrics.known_cogs_czk AS daily_known_cogs_czk,
    expected_daily.uncosted_net_sales_czk AS fact_uncosted_net_sales_czk,
    fact_daily_metrics.uncosted_net_sales_czk AS daily_uncosted_net_sales_czk,
    expected_daily.unknown_cost_line_count AS fact_unknown_cost_line_count,
    fact_daily_metrics.unknown_cost_line_count AS daily_unknown_cost_line_count,
    expected_daily.cogs_czk AS fact_cogs_czk,
    fact_daily_metrics.cogs_czk AS daily_cogs_czk,
    expected_daily.order_count AS line_order_count,
    fact_daily_metrics.order_count AS daily_order_count
FROM expected_daily
FULL OUTER JOIN {{ ref('fact_daily_metrics') }} AS fact_daily_metrics
    USING (reporting_date, shop)
WHERE expected_daily.gross_sales_czk IS DISTINCT FROM fact_daily_metrics.gross_sales_czk
    OR expected_daily.discounts_czk IS DISTINCT FROM fact_daily_metrics.discounts_czk
    OR expected_daily.net_sales_czk IS DISTINCT FROM fact_daily_metrics.net_sales_czk
    OR expected_daily.known_cogs_czk IS DISTINCT FROM fact_daily_metrics.known_cogs_czk
    OR expected_daily.uncosted_net_sales_czk
        IS DISTINCT FROM fact_daily_metrics.uncosted_net_sales_czk
    OR expected_daily.unknown_cost_line_count
        IS DISTINCT FROM fact_daily_metrics.unknown_cost_line_count
    OR expected_daily.cogs_czk IS DISTINCT FROM fact_daily_metrics.cogs_czk
    OR expected_daily.order_count IS DISTINCT FROM fact_daily_metrics.order_count
