-- S3 | sales | fact_sales_contains_all_active_source_lines
-- Reads from: vw_22_sales_lines and fact_sales
-- Produces: active source lines missing from fact_sales; zero rows means pass

SELECT sales.shop, sales.line_id, sales.source_sku
FROM {{ ref('vw_22_sales_lines') }} AS sales
LEFT JOIN (
    SELECT DISTINCT shop, line_id
    FROM {{ ref('fact_sales') }}
) AS facts
    ON sales.shop = facts.shop
    AND sales.line_id = facts.line_id
WHERE facts.line_id IS NULL
