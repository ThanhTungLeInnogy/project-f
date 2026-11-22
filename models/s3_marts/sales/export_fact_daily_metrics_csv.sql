-- S3 | sales | export_fact_daily_metrics_csv
-- Reads from: fact_daily_metrics
-- Produces: headered CSV export of the fact_daily_metrics table

{{ config(
    materialized='external',
    format='csv',
    location='exports/fact_daily_metrics.csv',
    options={'header': true, 'NULL': '\\N'},
    csv_read_options={'header': true, 'all_varchar': true, 'nullstr': '\\N'}
) }}

SELECT *
FROM {{ ref('fact_daily_metrics') }}
