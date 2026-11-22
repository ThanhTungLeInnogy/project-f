-- analysis | management question 1 | monthly performance
-- Reads from: fact_daily_metrics and fact_sales
-- Period: Prague-local reporting dates, January-September 2026

WITH monthly_sales AS (
    SELECT
        reporting_month,
        shop,
        SUM(net_sales_czk) AS net_sales_czk,
        SUM(known_cogs_czk) AS known_cogs_subtotal_czk,
        SUM(uncosted_net_sales_czk) AS uncosted_net_sales_czk,
        SUM(unknown_cost_line_count) AS unknown_cost_line_count
    FROM fact_daily_metrics
    WHERE reporting_date >= DATE '2026-01-01'
        AND reporting_date < DATE '2026-10-01'
    GROUP BY reporting_month, shop
),
monthly_orders AS (
    SELECT
        reporting_month,
        shop,
        COUNT(DISTINCT order_id) AS order_count
    FROM fact_sales
    WHERE reporting_date >= DATE '2026-01-01'
        AND reporting_date < DATE '2026-10-01'
    GROUP BY reporting_month, shop
)
SELECT
    sales.reporting_month,
    sales.shop,
    sales.net_sales_czk,
    sales.known_cogs_subtotal_czk,
    sales.uncosted_net_sales_czk,
    sales.unknown_cost_line_count,
    CASE
        WHEN sales.unknown_cost_line_count = 0 THEN sales.known_cogs_subtotal_czk
        ELSE NULL
    END AS total_cogs_czk,
    CASE
        WHEN sales.unknown_cost_line_count = 0
            THEN sales.net_sales_czk - sales.known_cogs_subtotal_czk
        ELSE NULL
    END AS gross_margin_czk,
    CASE
        WHEN sales.unknown_cost_line_count = 0 THEN CAST(
            (sales.net_sales_czk - sales.known_cogs_subtotal_czk)
                / NULLIF(sales.net_sales_czk, 0)
            AS DECIMAL(18, 4)
        )
        ELSE NULL
    END AS gross_margin_pct,
    sales.unknown_cost_line_count = 0 AS cogs_complete,
    orders.order_count
FROM monthly_sales AS sales
INNER JOIN monthly_orders AS orders
    USING (reporting_month, shop)
ORDER BY sales.reporting_month, sales.shop;

WITH quarterly_sales AS (
    SELECT
        shop,
        CASE
            WHEN reporting_month IN ('2026-01', '2026-02', '2026-03') THEN 'Q1'
            WHEN reporting_month IN ('2026-07', '2026-08', '2026-09') THEN 'Q3'
        END AS quarter,
        SUM(net_sales_czk) AS net_sales_czk
    FROM fact_daily_metrics
    WHERE reporting_date >= DATE '2026-01-01'
        AND reporting_date < DATE '2026-10-01'
        AND reporting_month IN (
            '2026-01', '2026-02', '2026-03',
            '2026-07', '2026-08', '2026-09'
        )
    GROUP BY shop, quarter
),
quarter_comparison AS (
    SELECT
        shop,
        MAX(net_sales_czk) FILTER (WHERE quarter = 'Q1') AS q1_net_sales_czk,
        MAX(net_sales_czk) FILTER (WHERE quarter = 'Q3') AS q3_net_sales_czk
    FROM quarterly_sales
    GROUP BY shop
),
growth AS (
    SELECT
        shop,
        q1_net_sales_czk,
        q3_net_sales_czk,
        q3_net_sales_czk - q1_net_sales_czk AS change_czk,
        CAST(
            100 * (q3_net_sales_czk - q1_net_sales_czk) / q1_net_sales_czk
            AS DECIMAL(18, 2)
        ) AS change_pct
    FROM quarter_comparison
)
SELECT
    shop,
    q1_net_sales_czk,
    q3_net_sales_czk,
    change_czk,
    change_pct,
    RANK() OVER (ORDER BY change_pct DESC) AS growth_rank
FROM growth
ORDER BY growth_rank, shop;
