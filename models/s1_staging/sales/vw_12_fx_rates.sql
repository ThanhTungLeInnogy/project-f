-- S1 | sales | vw_12_fx_rates
-- Reads from: raw fx_rates CSV source
-- Produces: typed observed FX rates at one row per date and currency

SELECT
    CAST(strptime(date, '%Y-%m-%d') AS DATE) AS date,
    currency,
    CAST(fx_rate AS DECIMAL(18, 6)) AS fx_rate
FROM {{ source('raw', 'fx_rates') }}
