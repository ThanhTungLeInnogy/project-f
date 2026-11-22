-- analysis | management question 2 | Q3 actual vs budget
-- Reads from: fact_daily_metrics, fact_sales, and vw_12_budget
-- Period: Prague-local reporting dates, July-September 2026

-- Volume effect = (actual orders - budget orders) * budget AOV.
-- AOV effect = actual orders * (actual AOV - budget AOV).
-- Round volume effect to cents; assign the cent residual to AOV effect
-- so the displayed effects equal the total sales variance exactly.
WITH actual_sales AS (
    SELECT
        shop,
        SUM(net_sales_czk) AS actual_net_sales_czk
    FROM fact_daily_metrics
    WHERE reporting_date >= DATE '2026-07-01'
        AND reporting_date < DATE '2026-10-01'
    GROUP BY shop
),
actual_orders AS (
    SELECT
        shop,
        COUNT(DISTINCT order_id) AS actual_order_count
    FROM fact_sales
    WHERE reporting_date >= DATE '2026-07-01'
        AND reporting_date < DATE '2026-10-01'
    GROUP BY shop
),
budget AS (
    SELECT
        shop,
        SUM(orders_budget) AS budget_order_count,
        SUM(net_sales_czk_budget) AS budget_net_sales_czk
    FROM vw_12_budget
    WHERE month IN ('2026-07', '2026-08', '2026-09')
    GROUP BY shop
),
combined AS (
    SELECT
        actual_sales.shop,
        actual_sales.actual_net_sales_czk,
        actual_orders.actual_order_count,
        budget.budget_net_sales_czk,
        budget.budget_order_count,
        actual_sales.actual_net_sales_czk - budget.budget_net_sales_czk
            AS net_sales_variance_czk,
        CAST(
            100 * (actual_sales.actual_net_sales_czk - budget.budget_net_sales_czk)
                / budget.budget_net_sales_czk
            AS DECIMAL(18, 2)
        ) AS net_sales_variance_pct,
        actual_orders.actual_order_count - budget.budget_order_count
            AS order_count_variance,
        CAST(
            100 * (actual_orders.actual_order_count - budget.budget_order_count)
                / budget.budget_order_count
            AS DECIMAL(18, 2)
        ) AS order_count_variance_pct,
        CAST(
            actual_sales.actual_net_sales_czk / actual_orders.actual_order_count
            AS DECIMAL(18, 8)
        ) AS actual_aov_exact,
        CAST(
            budget.budget_net_sales_czk / budget.budget_order_count
            AS DECIMAL(18, 8)
        ) AS budget_aov_exact
    FROM actual_sales
    INNER JOIN actual_orders USING (shop)
    INNER JOIN budget USING (shop)
),
effects AS (
    SELECT
        combined.*,
        CAST(ROUND(
            (actual_order_count - budget_order_count) * budget_aov_exact,
            2
        ) AS DECIMAL(18, 2)) AS volume_effect_czk
    FROM combined
)
SELECT
    shop,
    actual_net_sales_czk,
    budget_net_sales_czk,
    net_sales_variance_czk,
    net_sales_variance_pct,
    actual_order_count,
    budget_order_count,
    order_count_variance,
    order_count_variance_pct,
    CAST(ROUND(actual_aov_exact, 2) AS DECIMAL(18, 2)) AS actual_aov_czk,
    CAST(ROUND(budget_aov_exact, 2) AS DECIMAL(18, 2)) AS budget_aov_czk,
    volume_effect_czk,
    CAST(net_sales_variance_czk - volume_effect_czk AS DECIMAL(18, 2))
        AS aov_effect_czk
FROM effects
ORDER BY shop;
