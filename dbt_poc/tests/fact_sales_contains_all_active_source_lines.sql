SELECT sales.shop, sales.line_id, sales.source_sku
FROM {{ ref('int_sales_lines') }} AS sales
LEFT JOIN (
    SELECT DISTINCT shop, line_id
    FROM {{ ref('fact_sales') }}
) AS facts
    ON sales.shop = facts.shop
    AND sales.line_id = facts.line_id
WHERE facts.line_id IS NULL
