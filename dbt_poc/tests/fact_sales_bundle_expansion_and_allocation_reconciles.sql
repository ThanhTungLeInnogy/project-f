WITH expected_components AS (
    SELECT
        sales.shop,
        sales.line_id,
        sales.source_sku,
        split_part(definitions.component_definition, ':', 1) AS sku,
        TRY_CAST(split_part(definitions.component_definition, ':', 2) AS BIGINT)
            AS bundle_component_quantity
    FROM {{ ref('int_sales_lines') }} AS sales
    INNER JOIN {{ source('staged', 'products') }} AS bundle
        ON sales.source_sku = bundle.sku
        AND bundle.is_bundle
    CROSS JOIN UNNEST(string_split(bundle.bundle_components, '|'))
        AS definitions(component_definition)
),
actual_components AS (
    SELECT shop, line_id, source_sku, sku, bundle_component_quantity
    FROM {{ ref('fact_sales') }}
    WHERE is_bundle_component
),
missing_components AS (
    SELECT * FROM expected_components
    EXCEPT ALL
    SELECT * FROM actual_components
),
extra_components AS (
    SELECT * FROM actual_components
    EXCEPT ALL
    SELECT * FROM expected_components
),
component_errors AS (
    SELECT
        'missing_component' AS issue,
        CAST(shop AS VARCHAR) AS shop,
        CAST(line_id AS VARCHAR) AS line_id,
        CAST(source_sku AS VARCHAR) AS source_sku,
        CAST(sku AS VARCHAR) AS sku,
        CAST(bundle_component_quantity AS VARCHAR) AS details
    FROM missing_components
    UNION ALL
    SELECT
        'extra_component',
        CAST(shop AS VARCHAR),
        CAST(line_id AS VARCHAR),
        CAST(source_sku AS VARCHAR),
        CAST(sku AS VARCHAR),
        CAST(bundle_component_quantity AS VARCHAR)
    FROM extra_components
),
allocated_lines AS (
    SELECT
        shop,
        line_id,
        source_sku,
        SUM(gross_sales_czk) AS gross_sales_czk,
        SUM(discounts_czk) AS discounts_czk,
        SUM(net_sales_czk) AS net_sales_czk
    FROM {{ ref('fact_sales') }}
    GROUP BY shop, line_id, source_sku
),
allocation_errors AS (
    SELECT
        'revenue_allocation' AS issue,
        CAST(sales.shop AS VARCHAR) AS shop,
        CAST(sales.line_id AS VARCHAR) AS line_id,
        CAST(sales.source_sku AS VARCHAR) AS source_sku,
        CAST(NULL AS VARCHAR) AS sku,
        concat(
            'gross expected=', CAST(sales.gross_sales_czk AS VARCHAR),
            '; actual=', coalesce(CAST(allocated.gross_sales_czk AS VARCHAR), 'NULL'),
            '; discount expected=', CAST(sales.discounts_czk AS VARCHAR),
            '; actual=', coalesce(CAST(allocated.discounts_czk AS VARCHAR), 'NULL'),
            '; net expected=', CAST(sales.net_sales_czk AS VARCHAR),
            '; actual=', coalesce(CAST(allocated.net_sales_czk AS VARCHAR), 'NULL')
        ) AS details
    FROM {{ ref('int_sales_lines') }} AS sales
    LEFT JOIN allocated_lines AS allocated
        ON sales.shop = allocated.shop
        AND sales.line_id = allocated.line_id
        AND sales.source_sku = allocated.source_sku
    WHERE allocated.gross_sales_czk IS DISTINCT FROM sales.gross_sales_czk
        OR allocated.discounts_czk IS DISTINCT FROM sales.discounts_czk
        OR allocated.net_sales_czk IS DISTINCT FROM sales.net_sales_czk
)
SELECT * FROM component_errors
UNION ALL
SELECT * FROM allocation_errors
