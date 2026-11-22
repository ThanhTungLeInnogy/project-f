-- Reads from: fact_sales and int_sales_lines
-- Produces: daily shop sales, cost coverage, margin, and distinct order counts

WITH sales_by_day AS (
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
    FROM {{ ref('int_sales_lines') }}
    GROUP BY reporting_date, shop
),
daily_metrics AS (
    SELECT
        COALESCE(sales_by_day.reporting_date, orders_by_day.reporting_date) AS reporting_date,
        COALESCE(sales_by_day.shop, orders_by_day.shop) AS shop,
        sales_by_day.gross_sales_czk,
        sales_by_day.discounts_czk,
        sales_by_day.net_sales_czk,
        sales_by_day.known_cogs_czk,
        sales_by_day.uncosted_net_sales_czk,
        sales_by_day.unknown_cost_line_count,
        sales_by_day.cogs_czk,
        orders_by_day.order_count
    FROM sales_by_day
    FULL OUTER JOIN orders_by_day
        USING (reporting_date, shop)
)
SELECT
    reporting_date,
    strftime(reporting_date, '%Y-%m') AS reporting_month,
    shop,
    gross_sales_czk,
    discounts_czk,
    net_sales_czk,
    cogs_czk,
    known_cogs_czk,
    uncosted_net_sales_czk,
    unknown_cost_line_count,
    CASE
        WHEN cogs_czk IS NULL THEN NULL
        ELSE CAST(net_sales_czk - cogs_czk AS DECIMAL(18, 2))
    END AS gross_margin_czk,
    CASE
        WHEN cogs_czk IS NULL OR net_sales_czk = 0 THEN NULL
        ELSE CAST((net_sales_czk - cogs_czk) / net_sales_czk AS DECIMAL(18, 4))
    END AS gross_margin_pct,
    order_count
FROM daily_metrics
