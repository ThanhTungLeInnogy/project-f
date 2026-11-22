{{ config(
    materialized='external',
    format='csv',
    location='dbt_poc/fact_daily_metrics.csv',
    options={'header': true},
    csv_read_options={'header': true, 'all_varchar': true}
) }}

SELECT *
FROM {{ ref('fact_daily_metrics') }}
