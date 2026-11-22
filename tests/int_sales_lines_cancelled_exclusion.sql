-- S2 | sales | int_sales_lines_cancelled_exclusion
-- Reads from: vw_22_sales_lines and vw_21_orders
-- Produces: cancelled order lines in sales; zero rows means pass

SELECT
    sales.shop,
    sales.line_id,
    sales.order_id,
    orders.cancelled_at
FROM {{ ref('vw_22_sales_lines') }} AS sales
INNER JOIN {{ ref('vw_21_orders') }} AS orders
    ON sales.shop = orders.shop
    AND sales.line_id = orders.line_id
WHERE orders.cancelled_at IS NOT NULL
