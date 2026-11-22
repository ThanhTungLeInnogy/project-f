-- analysis | management question 4 | customer sales classification
-- Reads from: fact_sales
-- Period: Prague-local reporting dates, January-September 2026

WITH order_sales AS (
    SELECT
        shop,
        order_id,
        customer_id,
        MIN(reporting_date) AS order_date,
        SUM(net_sales_czk) AS order_net_sales_czk
    FROM fact_sales
    WHERE reporting_date >= DATE '2026-01-01'
        AND reporting_date < DATE '2026-10-01'
    GROUP BY shop, order_id, customer_id
),
first_observed AS (
    SELECT
        shop,
        customer_id,
        MIN(order_date) AS first_observed_date
    FROM order_sales
    WHERE customer_id IS NOT NULL
    GROUP BY shop, customer_id
),
classified_orders AS (
    SELECT
        orders.shop,
        orders.order_id,
        orders.order_net_sales_czk,
        CASE
            WHEN orders.customer_id IS NULL THEN 'missing_customer_id'
            WHEN orders.order_date = first_observed.first_observed_date
                THEN 'first_observed'
            ELSE 'returning'
        END AS customer_status
    FROM order_sales AS orders
    LEFT JOIN first_observed
        ON orders.shop = first_observed.shop
        AND orders.customer_id = first_observed.customer_id
),
shop_sales AS (
    SELECT
        shop,
        SUM(order_net_sales_czk) AS total_net_sales_czk,
        SUM(order_net_sales_czk) FILTER (
            WHERE customer_status = 'first_observed'
        ) AS first_observed_net_sales_czk,
        SUM(order_net_sales_czk) FILTER (
            WHERE customer_status = 'returning'
        ) AS returning_net_sales_czk,
        SUM(order_net_sales_czk) FILTER (
            WHERE customer_status = 'missing_customer_id'
        ) AS missing_id_net_sales_czk,
        COUNT(DISTINCT order_id) FILTER (
            WHERE customer_status = 'missing_customer_id'
        ) AS orders_without_customer_id
    FROM classified_orders
    GROUP BY shop
)
SELECT
    shop,
    total_net_sales_czk,
    first_observed_net_sales_czk,
    CAST(100 * first_observed_net_sales_czk / NULLIF(total_net_sales_czk, 0)
        AS DECIMAL(18, 2)) AS first_observed_sales_share_pct,
    returning_net_sales_czk,
    CAST(100 * returning_net_sales_czk / NULLIF(total_net_sales_czk, 0)
        AS DECIMAL(18, 2)) AS returning_sales_share_pct,
    missing_id_net_sales_czk,
    CAST(100 * missing_id_net_sales_czk / NULLIF(total_net_sales_czk, 0)
        AS DECIMAL(18, 2)) AS missing_id_sales_share_pct,
    orders_without_customer_id
FROM shop_sales
ORDER BY shop;
