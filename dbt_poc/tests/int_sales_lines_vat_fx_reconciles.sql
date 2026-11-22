WITH expected_rates AS (
    SELECT
        sales.shop,
        sales.line_id,
        sales.reporting_date,
        sales.currency,
        fx_rates.date AS expected_fx_rate_date,
        fx_rates.fx_rate AS expected_fx_rate
    FROM {{ ref('int_sales_lines') }} AS sales
    ASOF LEFT JOIN {{ source('staged', 'fx_rates') }} AS fx_rates
        ON sales.currency = fx_rates.currency
        AND sales.reporting_date >= fx_rates.date
    WHERE sales.currency <> 'CZK'
),
vat_mapping_errors AS (
    SELECT
        'vat_currency_mapping' AS issue,
        shop,
        line_id,
        concat(
            'currency=', coalesce(currency, 'NULL'),
            '; vat_rate=', coalesce(CAST(vat_rate AS VARCHAR), 'NULL')
        ) AS details
    FROM {{ ref('int_sales_lines') }}
    WHERE shop IS NULL
        OR shop NOT IN ('CZ', 'SK', 'HU')
        OR (shop = 'CZ' AND (
            currency IS DISTINCT FROM 'CZK' OR vat_rate IS DISTINCT FROM 0.21
        ))
        OR (shop = 'SK' AND (
            currency IS DISTINCT FROM 'EUR' OR vat_rate IS DISTINCT FROM 0.23
        ))
        OR (shop = 'HU' AND (
            currency IS DISTINCT FROM 'HUF' OR vat_rate IS DISTINCT FROM 0.27
        ))
),
vat_amount_errors AS (
    SELECT
        'vat_amount_calculation' AS issue,
        sales.shop,
        sales.line_id,
        concat(
            'gross_local expected=',
            CAST(CAST(
                (orders.price_with_vat * orders.quantity) / (1 + sales.vat_rate)
                AS DECIMAL(28, 8)
            ) AS VARCHAR),
            '; actual=', CAST(sales.gross_sales_local AS VARCHAR),
            '; discount_local expected=',
            CAST(CAST(
                orders.discount_with_vat / (1 + sales.vat_rate)
                AS DECIMAL(28, 8)
            ) AS VARCHAR),
            '; actual=', CAST(sales.discounts_local AS VARCHAR)
        ) AS details
    FROM {{ ref('int_sales_lines') }} AS sales
    INNER JOIN {{ ref('int_orders') }} AS orders
        ON sales.shop = orders.shop
        AND sales.line_id = orders.line_id
    WHERE sales.gross_sales_local IS DISTINCT FROM CAST(
            (orders.price_with_vat * orders.quantity) / (1 + sales.vat_rate)
            AS DECIMAL(28, 8)
        )
        OR sales.discounts_local IS DISTINCT FROM CAST(
            orders.discount_with_vat / (1 + sales.vat_rate)
            AS DECIMAL(28, 8)
        )
),
fx_rate_errors AS (
    SELECT
        'fx_rate_selection' AS issue,
        sales.shop,
        sales.line_id,
        concat(
            'rate expected=', coalesce(CAST(expected_rates.expected_fx_rate AS VARCHAR), 'NULL'),
            '; actual=', coalesce(CAST(sales.fx_rate AS VARCHAR), 'NULL'),
            '; date expected=', coalesce(CAST(expected_rates.expected_fx_rate_date AS VARCHAR), 'NULL'),
            '; actual=', coalesce(CAST(sales.fx_rate_date AS VARCHAR), 'NULL')
        ) AS details
    FROM {{ ref('int_sales_lines') }} AS sales
    LEFT JOIN expected_rates
        ON sales.shop = expected_rates.shop
        AND sales.line_id = expected_rates.line_id
    WHERE (
            sales.currency = 'CZK'
            AND (
                sales.fx_rate IS DISTINCT FROM CAST(1 AS DECIMAL(18, 6))
                OR sales.fx_rate_date IS NOT NULL
            )
        )
        OR (
            sales.currency <> 'CZK'
            AND (
                expected_rates.expected_fx_rate IS NULL
                OR sales.fx_rate IS DISTINCT FROM expected_rates.expected_fx_rate
                OR sales.fx_rate_date IS DISTINCT FROM expected_rates.expected_fx_rate_date
                OR sales.fx_rate_date > sales.reporting_date
            )
        )
),
czk_amount_errors AS (
    SELECT
        'czk_conversion_and_rounding' AS issue,
        sales.shop,
        sales.line_id,
        concat(
            'gross_czk expected=',
            CAST(CAST(ROUND(sales.gross_sales_local / sales.fx_rate, 2) AS DECIMAL(18, 2)) AS VARCHAR),
            '; actual=', CAST(sales.gross_sales_czk AS VARCHAR),
            '; discount_czk expected=',
            CAST(CAST(ROUND(sales.discounts_local / sales.fx_rate, 2) AS DECIMAL(18, 2)) AS VARCHAR),
            '; actual=', CAST(sales.discounts_czk AS VARCHAR),
            '; net_czk expected=',
            CAST(CAST(
                sales.gross_sales_czk - sales.discounts_czk
                AS DECIMAL(18, 2)
            ) AS VARCHAR),
            '; actual=', CAST(sales.net_sales_czk AS VARCHAR)
        ) AS details
    FROM {{ ref('int_sales_lines') }} AS sales
    WHERE sales.gross_sales_czk IS DISTINCT FROM CAST(
            ROUND(sales.gross_sales_local / sales.fx_rate, 2) AS DECIMAL(18, 2)
        )
        OR sales.discounts_czk IS DISTINCT FROM CAST(
            ROUND(sales.discounts_local / sales.fx_rate, 2) AS DECIMAL(18, 2)
        )
        OR sales.net_sales_czk IS DISTINCT FROM CAST(
            sales.gross_sales_czk - sales.discounts_czk AS DECIMAL(18, 2)
        )
)
SELECT * FROM vat_mapping_errors
UNION ALL
SELECT * FROM vat_amount_errors
UNION ALL
SELECT * FROM fx_rate_errors
UNION ALL
SELECT * FROM czk_amount_errors
