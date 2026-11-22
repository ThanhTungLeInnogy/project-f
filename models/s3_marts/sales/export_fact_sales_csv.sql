-- S3 | sales | export_fact_sales_csv
-- Reads from: fact_sales
-- Produces: headered CSV export of the fact_sales table

{{ config(
    materialized='external',
    format='csv',
    location='exports/fact_sales.csv',
    options={'header': true, 'NULL': '\\N'},
    csv_read_options={'header': true, 'all_varchar': true, 'nullstr': '\\N'}
) }}

SELECT *
FROM {{ ref('fact_sales') }}
