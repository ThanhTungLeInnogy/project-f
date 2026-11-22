CREATE OR REPLACE TABLE int_orders AS
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
FROM read_parquet('s1_staging/data/orders_cz.parquet')

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
FROM read_parquet('s1_staging/data/orders_sk.parquet')

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
FROM read_parquet('s1_staging/data/orders_hu.parquet');
