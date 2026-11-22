-- S2 | sales | vw_21_orders
-- Reads from: vw_11_orders_cz, vw_11_orders_sk, and vw_11_orders_hu
-- Produces: union of staged order lines at the source row grain

SELECT
    order_id,
    line_id,
    created_at,
    sku,
    quantity,
    price_with_vat,
    discount_with_vat,
    currency,
    customer_id,
    cancelled_at,
    exported_at,
    shop
FROM {{ ref('vw_11_orders_cz') }}

UNION ALL

SELECT
    order_id,
    line_id,
    created_at,
    sku,
    quantity,
    price_with_vat,
    discount_with_vat,
    currency,
    customer_id,
    cancelled_at,
    exported_at,
    shop
FROM {{ ref('vw_11_orders_sk') }}

UNION ALL

SELECT
    order_id,
    line_id,
    created_at,
    sku,
    quantity,
    price_with_vat,
    discount_with_vat,
    currency,
    customer_id,
    cancelled_at,
    exported_at,
    shop
FROM {{ ref('vw_11_orders_hu') }}
