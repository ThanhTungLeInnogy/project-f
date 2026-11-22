SELECT
    shop,
    line_id,
    sku,
    product_match_status,
    product_name,
    unit_cost_czk,
    cogs_czk
FROM {{ ref('fact_sales') }}
WHERE (product_match_status = 'UNKNOWN' AND (
        product_name IS NOT NULL OR unit_cost_czk IS NOT NULL OR cogs_czk IS NOT NULL
    ))
    OR (product_match_status = 'MATCHED' AND (
        product_name IS NULL OR unit_cost_czk IS NULL OR cogs_czk IS NULL
    ))
    OR product_match_status NOT IN ('UNKNOWN', 'MATCHED')
