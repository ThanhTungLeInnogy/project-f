-- S1 | sales | vw_12_budget
-- Reads from: raw budget CSV source
-- Produces: typed budget at one row per source month and shop

SELECT
    month,
    shop,
    CAST(orders_budget AS BIGINT) AS orders_budget,
    CAST(net_sales_czk_budget AS DECIMAL(18, 2)) AS net_sales_czk_budget
FROM {{ source('raw', 'budget') }}
