SELECT
    sales.shop,
    sales.line_id,
    sales.order_id,
    orders.cancelled_at
FROM {{ ref('int_sales_lines') }} AS sales
INNER JOIN {{ ref('int_orders') }} AS orders
    ON sales.shop = orders.shop
    AND sales.line_id = orders.line_id
WHERE orders.cancelled_at IS NOT NULL
