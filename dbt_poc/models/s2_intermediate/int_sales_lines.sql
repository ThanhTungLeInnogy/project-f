-- Reads from: int_orders and staged FX rates
-- Produces: non-cancelled order-line sales in CZK at the Prague reporting date

WITH vat_rates AS (
    SELECT *
    FROM (
        VALUES
            ('CZ', CAST(0.21 AS DECIMAL(5, 4))),
            ('SK', CAST(0.23 AS DECIMAL(5, 4))),
            ('HU', CAST(0.27 AS DECIMAL(5, 4)))
    ) AS rates(shop, vat_rate)
),
eligible_lines AS (
    SELECT
        orders.shop,
        orders.line_id,
        orders.order_id,
        orders.sku AS source_sku,
        orders.quantity,
        orders.price_with_vat,
        orders.discount_with_vat,
        orders.currency,
        orders.customer_id,
        orders.created_at,
        CAST(orders.created_at AT TIME ZONE 'Europe/Prague' AS DATE) AS reporting_date,
        vat_rates.vat_rate
    FROM {{ ref('int_orders') }} AS orders
    INNER JOIN vat_rates
        ON orders.shop = vat_rates.shop
    WHERE orders.cancelled_at IS NULL
),
fx_rated AS (
    SELECT
        eligible_lines.*,
        CASE
            WHEN eligible_lines.currency = 'CZK' THEN CAST(1 AS DECIMAL(18, 6))
            ELSE fx_rates.fx_rate
        END AS fx_rate,
        CASE
            WHEN eligible_lines.currency = 'CZK' THEN NULL
            ELSE fx_rates.date
        END AS fx_rate_date
    FROM eligible_lines
    ASOF LEFT JOIN {{ source('staged', 'fx_rates') }} AS fx_rates
        ON eligible_lines.currency = fx_rates.currency
        AND eligible_lines.reporting_date >= fx_rates.date
),
local_amounts AS (
    SELECT
        fx_rated.*,
        CAST(
            (fx_rated.price_with_vat * fx_rated.quantity) / (1 + fx_rated.vat_rate)
            AS DECIMAL(28, 8)
        ) AS gross_sales_local,
        CAST(
            fx_rated.discount_with_vat / (1 + fx_rated.vat_rate)
            AS DECIMAL(28, 8)
        ) AS discounts_local
    FROM fx_rated
),
czk_amounts AS (
    SELECT
        local_amounts.*,
        CAST(ROUND(local_amounts.gross_sales_local / local_amounts.fx_rate, 2) AS DECIMAL(18, 2))
            AS gross_sales_czk,
        CAST(ROUND(local_amounts.discounts_local / local_amounts.fx_rate, 2) AS DECIMAL(18, 2))
            AS discounts_czk
    FROM local_amounts
)
SELECT
    shop,
    line_id,
    order_id,
    source_sku,
    quantity,
    price_with_vat,
    discount_with_vat,
    currency,
    customer_id,
    created_at,
    reporting_date,
    vat_rate,
    fx_rate_date,
    fx_rate,
    gross_sales_local,
    discounts_local,
    CAST(gross_sales_local - discounts_local AS DECIMAL(28, 8)) AS net_sales_local,
    gross_sales_czk,
    discounts_czk,
    CAST(gross_sales_czk - discounts_czk AS DECIMAL(18, 2)) AS net_sales_czk
FROM czk_amounts
