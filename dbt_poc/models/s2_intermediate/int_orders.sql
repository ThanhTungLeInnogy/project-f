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
FROM {{ source('staged', 'orders_cz') }}

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
FROM {{ source('staged', 'orders_sk') }}

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
FROM {{ source('staged', 'orders_hu') }}
