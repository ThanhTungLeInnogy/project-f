-- S3 | sales | fact_sales
-- Reads from: vw_22_sales_lines and vw_12_products
-- Produces: allocated order-line sales at one row per order line and product/component

WITH products AS (
    SELECT *
    FROM {{ ref('vw_12_products') }}
),
standalone_lines AS (
    SELECT
        sales.shop,
        sales.reporting_date,
        sales.order_id,
        sales.line_id,
        sales.source_sku,
        sales.source_sku AS sku,
        product.product_name,
        product.category,
        sales.customer_id,
        sales.currency,
        sales.fx_rate_date,
        sales.fx_rate,
        sales.created_at,
        sales.quantity AS source_line_quantity,
        CAST(1 AS BIGINT) AS bundle_component_quantity,
        sales.quantity AS sold_quantity,
        FALSE AS is_bundle_component,
        CAST(1 AS BIGINT) AS component_ordinal,
        product.unit_cost_czk,
        CAST(1 AS BIGINT) AS allocation_weight,
        sales.gross_sales_czk AS line_gross_sales_czk,
        sales.discounts_czk AS line_discounts_czk,
        sales.net_sales_czk AS line_net_sales_czk
    FROM {{ ref('vw_22_sales_lines') }} AS sales
    LEFT JOIN products AS product
        ON sales.source_sku = product.sku
    WHERE product.is_bundle IS DISTINCT FROM TRUE
),
bundle_components AS (
    SELECT
        sales.shop,
        sales.reporting_date,
        sales.order_id,
        sales.line_id,
        sales.source_sku,
        component.sku,
        component.product_name,
        component.category,
        sales.customer_id,
        sales.currency,
        sales.fx_rate_date,
        sales.fx_rate,
        sales.created_at,
        sales.quantity AS source_line_quantity,
        TRY_CAST(split_part(component_definition, ':', 2) AS BIGINT) AS bundle_component_quantity,
        sales.quantity * TRY_CAST(split_part(component_definition, ':', 2) AS BIGINT)
            AS sold_quantity,
        TRUE AS is_bundle_component,
        component_ordinal,
        component.unit_cost_czk,
        CAST(component.unit_cost_czk * TRY_CAST(split_part(component_definition, ':', 2) AS BIGINT) * 100
            AS BIGINT) AS allocation_weight,
        sales.gross_sales_czk AS line_gross_sales_czk,
        sales.discounts_czk AS line_discounts_czk,
        sales.net_sales_czk AS line_net_sales_czk
    FROM {{ ref('vw_22_sales_lines') }} AS sales
    INNER JOIN products AS bundle
        ON sales.source_sku = bundle.sku
        AND bundle.is_bundle
    CROSS JOIN UNNEST(string_split(bundle.bundle_components, '|'))
        WITH ORDINALITY AS definitions(component_definition, component_ordinal)
    LEFT JOIN products AS component
        ON split_part(component_definition, ':', 1) = component.sku
),
expanded_lines AS (
    SELECT * FROM standalone_lines
    UNION ALL
    SELECT * FROM bundle_components
),
weighted_lines AS (
    SELECT
        expanded_lines.*,
        SUM(expanded_lines.allocation_weight) OVER (
            PARTITION BY expanded_lines.shop, expanded_lines.line_id, expanded_lines.source_sku
        ) AS total_allocation_weight,
        CAST(ROUND(expanded_lines.line_gross_sales_czk * 100) AS BIGINT) AS line_gross_cents,
        CAST(ROUND(expanded_lines.line_discounts_czk * 100) AS BIGINT) AS line_discount_cents,
        CAST(ROUND(expanded_lines.line_gross_sales_czk * 100) AS DECIMAL(38, 0))
            * expanded_lines.allocation_weight AS gross_weighted_cents,
        CAST(ROUND(expanded_lines.line_discounts_czk * 100) AS DECIMAL(38, 0))
            * expanded_lines.allocation_weight AS discount_weighted_cents
    FROM expanded_lines
),
base_allocations AS (
    SELECT
        weighted_lines.*,
        CAST(FLOOR(gross_weighted_cents / total_allocation_weight) AS BIGINT) AS gross_base_cents,
        CAST(MOD(gross_weighted_cents, total_allocation_weight) AS BIGINT) AS gross_remainder,
        CAST(FLOOR(discount_weighted_cents / total_allocation_weight) AS BIGINT) AS discount_base_cents,
        CAST(MOD(discount_weighted_cents, total_allocation_weight) AS BIGINT) AS discount_remainder
    FROM weighted_lines
),
ranked_allocations AS (
    SELECT
        base_allocations.*,
        line_gross_cents - SUM(gross_base_cents) OVER (
            PARTITION BY shop, line_id, source_sku
        ) AS gross_extra_cents,
        line_discount_cents - SUM(discount_base_cents) OVER (
            PARTITION BY shop, line_id, source_sku
        ) AS discount_extra_cents,
        ROW_NUMBER() OVER (
            PARTITION BY shop, line_id, source_sku
            ORDER BY gross_remainder DESC, component_ordinal
        ) AS gross_remainder_rank,
        ROW_NUMBER() OVER (
            PARTITION BY shop, line_id, source_sku
            ORDER BY discount_remainder DESC, component_ordinal
        ) AS discount_remainder_rank
    FROM base_allocations
),
allocated_lines AS (
    SELECT
        ranked_allocations.*,
        CAST(
            gross_base_cents + CASE WHEN gross_remainder_rank <= gross_extra_cents THEN 1 ELSE 0 END
            AS BIGINT
        ) AS allocated_gross_cents,
        CAST(
            discount_base_cents
                + CASE WHEN discount_remainder_rank <= discount_extra_cents THEN 1 ELSE 0 END
            AS BIGINT
        ) AS allocated_discount_cents
    FROM ranked_allocations
)
SELECT
    shop,
    reporting_date,
    strftime(reporting_date, '%Y-%m') AS reporting_month,
    order_id,
    line_id,
    source_sku,
    sku,
    product_name,
    category,
    CASE WHEN product_name IS NULL THEN 'UNKNOWN' ELSE 'MATCHED' END AS product_match_status,
    customer_id,
    currency,
    fx_rate_date,
    fx_rate,
    created_at,
    source_line_quantity,
    bundle_component_quantity,
    sold_quantity,
    is_bundle_component,
    component_ordinal,
    unit_cost_czk,
    CAST(CAST(allocated_gross_cents AS DECIMAL(18, 0)) / 100 AS DECIMAL(18, 2))
        AS gross_sales_czk,
    CAST(CAST(allocated_discount_cents AS DECIMAL(18, 0)) / 100 AS DECIMAL(18, 2))
        AS discounts_czk,
    CAST(
        CAST(allocated_gross_cents - allocated_discount_cents AS DECIMAL(18, 0)) / 100
        AS DECIMAL(18, 2)
    ) AS net_sales_czk,
    CAST(unit_cost_czk * sold_quantity AS DECIMAL(18, 2)) AS cogs_czk,
    CASE
        WHEN unit_cost_czk IS NULL THEN NULL
        ELSE CAST(
            CAST(allocated_gross_cents - allocated_discount_cents AS DECIMAL(18, 0)) / 100
                - unit_cost_czk * sold_quantity
            AS DECIMAL(18, 2)
        )
    END AS gross_margin_czk
FROM allocated_lines
