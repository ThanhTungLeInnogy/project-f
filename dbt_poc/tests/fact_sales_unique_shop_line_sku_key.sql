SELECT shop, line_id, sku, COUNT(*) AS row_count
FROM {{ ref('fact_sales') }}
GROUP BY shop, line_id, sku
HAVING COUNT(*) > 1
