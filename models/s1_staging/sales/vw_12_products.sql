-- S1 | sales | vw_12_products
-- Reads from: raw products CSV source
-- Produces: typed product catalog at one row per SKU

SELECT
    sku,
    product_name,
    category,
    CAST(unit_cost_czk AS DECIMAL(18, 2)) AS unit_cost_czk,
    CAST(is_bundle AS BOOLEAN) AS is_bundle,
    bundle_components
FROM {{ source('raw', 'products') }}
