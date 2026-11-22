-- S3 | sales | fact_sales_unique_shop_line_sku_key
-- Reads from: fact_sales
-- Produces: duplicate shop-line-SKU keys; zero rows means pass

SELECT shop, line_id, sku, COUNT(*) AS row_count
FROM {{ ref('fact_sales') }}
GROUP BY shop, line_id, sku
HAVING COUNT(*) > 1
