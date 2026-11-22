-- S3 | sales | fact_daily_metrics_unique_date_shop_key
-- Reads from: fact_daily_metrics
-- Produces: duplicate date-shop keys; zero rows means pass

SELECT reporting_date, shop, COUNT(*) AS row_count
FROM {{ ref('fact_daily_metrics') }}
GROUP BY reporting_date, shop
HAVING COUNT(*) > 1
