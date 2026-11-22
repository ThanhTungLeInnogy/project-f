-- S1 | sales | vw_11_orders_cz
-- Reads from: raw orders_cz CSV source
-- Produces: latest typed CZ order row per line_id

WITH parsed_orders AS (
    SELECT
        order_id,
        line_id,
        strptime(created_at, '%Y-%m-%dT%H:%M:%SZ') AT TIME ZONE 'UTC' AS created_at,
        sku,
        CAST(quantity AS BIGINT) AS quantity,
        CAST(price_with_vat AS DECIMAL(18, 2)) AS price_with_vat,
        CAST(discount_with_vat AS DECIMAL(18, 2)) AS discount_with_vat,
        currency,
        customer_id,
        CASE
            WHEN cancelled_at IS NULL THEN NULL
            ELSE strptime(cancelled_at, '%Y-%m-%dT%H:%M:%SZ') AT TIME ZONE 'UTC'
        END AS cancelled_at,
        strptime(exported_at, '%Y-%m-%d %H:%M:%S') AS exported_at,
        'CZ' AS shop
    FROM {{ source('raw', 'orders_cz') }}
),
valid_orders AS (
    SELECT *
    FROM parsed_orders
    WHERE CASE
        WHEN order_id IS NULL OR line_id IS NULL OR created_at IS NULL OR sku IS NULL
            OR quantity IS NULL OR price_with_vat IS NULL OR discount_with_vat IS NULL
            OR currency IS NULL OR exported_at IS NULL
            OR currency IS DISTINCT FROM 'CZK'
            OR quantity <= 0 OR price_with_vat < 0 OR discount_with_vat < 0
        THEN error('Invalid required CZ order field or value') IS NULL
        ELSE TRUE
    END
),
latest_orders AS (
    SELECT *
    FROM valid_orders
    QUALIFY exported_at = MAX(exported_at) OVER (PARTITION BY line_id)
),
checked_latest_orders AS (
    SELECT *
    FROM latest_orders
    QUALIFY CASE
        WHEN COUNT(*) OVER (PARTITION BY line_id) > 1
            THEN error('Latest exported_at ties found for CZ line_id') IS NULL
        ELSE TRUE
    END
)
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
FROM checked_latest_orders
