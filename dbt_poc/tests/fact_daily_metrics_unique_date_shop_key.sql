SELECT reporting_date, shop, COUNT(*) AS row_count
FROM {{ ref('fact_daily_metrics') }}
GROUP BY reporting_date, shop
HAVING COUNT(*) > 1
