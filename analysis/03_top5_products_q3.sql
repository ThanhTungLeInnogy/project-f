-- analysis | management question 3 | top products by known gross profit
-- Reads from: fact_sales and s1_staging/data/products.parquet
-- Period: Prague-local reporting dates, July-September 2026

WITH product_sales AS (
    SELECT
        sku,
        SUM(gross_sales_czk) AS gross_sales_czk,
        SUM(discounts_czk) AS discounts_czk,
        SUM(net_sales_czk) AS net_sales_czk,
        SUM(cogs_czk) AS cogs_czk,
        SUM(gross_margin_czk) AS gross_profit_czk,
        COUNT(*) AS sales_rows,
        COUNT(*) FILTER (WHERE cogs_czk IS NULL) AS unknown_cost_rows
    FROM fact_sales
    WHERE reporting_date >= DATE '2026-07-01'
        AND reporting_date < DATE '2026-10-01'
    GROUP BY sku
),
known_products AS (
    SELECT
        product_sales.*,
        products.product_name,
        products.category,
        CAST(100 * product_sales.discounts_czk / NULLIF(product_sales.gross_sales_czk, 0)
            AS DECIMAL(18, 2)) AS discount_to_gross_sales_pct
    FROM product_sales
    INNER JOIN read_parquet('s1_staging/data/products.parquet') AS products
        USING (sku)
    WHERE product_sales.unknown_cost_rows = 0
),
ranked_products AS (
    SELECT
        ROW_NUMBER() OVER (ORDER BY gross_profit_czk DESC, sku) AS profit_rank,
        *
    FROM known_products
)
SELECT
    profit_rank,
    sku,
    product_name,
    category,
    gross_sales_czk,
    discounts_czk,
    discount_to_gross_sales_pct,
    net_sales_czk,
    cogs_czk,
    gross_profit_czk
FROM ranked_products
WHERE profit_rank <= 5
ORDER BY profit_rank;

SELECT
    sku,
    COUNT(*) AS uncosted_rows,
    SUM(net_sales_czk) AS uncosted_net_sales_czk
FROM fact_sales
WHERE reporting_date >= DATE '2026-07-01'
    AND reporting_date < DATE '2026-10-01'
    AND cogs_czk IS NULL
GROUP BY sku
ORDER BY uncosted_net_sales_czk DESC, sku;
