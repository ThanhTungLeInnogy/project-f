from pathlib import Path
import os

import duckdb


ROOT = Path(__file__).resolve().parent
DATABASE = ROOT / "fabini.duckdb"
MODEL_FILES = [
    ROOT / "s2_intermediate" / "sql" / "01_union_orders.sql",
    ROOT / "s2_intermediate" / "sql" / "02_sales_lines.sql",
    ROOT / "s3_marts" / "sql" / "01_fact_sales.sql",
    ROOT / "s3_marts" / "sql" / "02_fact_daily_metrics.sql",
]
EXPORTS = {
    "fact_sales": ROOT / "s3_marts" / "data" / "fact_sales.csv",
    "fact_daily_metrics": ROOT / "s3_marts" / "data" / "fact_daily_metrics.csv",
}
ORDER_COLUMNS = """
    order_id, line_id, created_at, sku, quantity, price_with_vat,
    discount_with_vat, currency, customer_id, cancelled_at, exported_at, shop
"""

CHECKS = [
    (
        "int_orders matches the staged order Parquet files",
        f"""
        WITH expected_orders AS (
            SELECT {ORDER_COLUMNS}
            FROM read_parquet('s1_staging/data/orders_cz.parquet')
            UNION ALL
            SELECT {ORDER_COLUMNS}
            FROM read_parquet('s1_staging/data/orders_sk.parquet')
            UNION ALL
            SELECT {ORDER_COLUMNS}
            FROM read_parquet('s1_staging/data/orders_hu.parquet')
        ),
        extra_rows AS (
            SELECT {ORDER_COLUMNS} FROM int_orders
            EXCEPT ALL
            SELECT {ORDER_COLUMNS} FROM expected_orders
        ),
        missing_rows AS (
            SELECT {ORDER_COLUMNS} FROM expected_orders
            EXCEPT ALL
            SELECT {ORDER_COLUMNS} FROM int_orders
        )
        SELECT (SELECT COUNT(*) FROM extra_rows) + (SELECT COUNT(*) FROM missing_rows)
        """,
    ),
    (
        "int_orders has unique line IDs",
        """
        SELECT COUNT(*) FROM (
            SELECT line_id
            FROM int_orders
            GROUP BY line_id
            HAVING COUNT(*) > 1
        )
        """,
    ),
    (
        "cancelled lines are excluded and active line counts reconcile",
        """
        WITH expected_rows AS (
            SELECT shop, COUNT(*) AS row_count
            FROM int_orders
            WHERE cancelled_at IS NULL
            GROUP BY shop
        ),
        actual_rows AS (
            SELECT shop, COUNT(*) AS row_count
            FROM int_sales_lines
            GROUP BY shop
        )
        SELECT COUNT(*)
        FROM expected_rows
        FULL OUTER JOIN actual_rows USING (shop)
        WHERE expected_rows.row_count IS DISTINCT FROM actual_rows.row_count
        """,
    ),
    (
        "intermediate sales lines have required values",
        """
        SELECT COUNT(*) FROM int_sales_lines
        WHERE shop IS NULL
            OR line_id IS NULL
            OR order_id IS NULL
            OR source_sku IS NULL
            OR quantity IS NULL
            OR currency IS NULL
            OR reporting_date IS NULL
            OR vat_rate IS NULL
            OR fx_rate IS NULL
            OR gross_sales_czk IS NULL
            OR discounts_czk IS NULL
            OR net_sales_czk IS NULL
        """,
    ),
    (
        "intermediate sales lines have unique shop-line keys",
        """
        SELECT COUNT(*) FROM (
            SELECT shop, line_id
            FROM int_sales_lines
            GROUP BY shop, line_id
            HAVING COUNT(*) > 1
        )
        """,
    ),
    (
        "VAT and currency mappings match the shop",
        """
        SELECT COUNT(*)
        FROM int_sales_lines
        WHERE (shop = 'CZ' AND (currency <> 'CZK' OR vat_rate <> 0.21))
            OR (shop = 'SK' AND (currency <> 'EUR' OR vat_rate <> 0.23))
            OR (shop = 'HU' AND (currency <> 'HUF' OR vat_rate <> 0.27))
            OR shop NOT IN ('CZ', 'SK', 'HU')
        """,
    ),
    (
        "VAT-exclusive local values reconcile to the source unit price and discount",
        """
        SELECT COUNT(*)
        FROM int_sales_lines AS sales
        INNER JOIN int_orders AS orders
            ON sales.shop = orders.shop AND sales.line_id = orders.line_id
        WHERE sales.gross_sales_local IS DISTINCT FROM CAST(
                (orders.price_with_vat * orders.quantity) / (1 + sales.vat_rate)
                AS DECIMAL(28, 8)
            )
            OR sales.discounts_local IS DISTINCT FROM CAST(
                orders.discount_with_vat / (1 + sales.vat_rate)
                AS DECIMAL(28, 8)
            )
        """,
    ),
    (
        "FX coverage, latest-date selection, and conversion direction are valid",
        """
        WITH expected_rates AS (
            SELECT
                sales.shop,
                sales.line_id,
                sales.reporting_date,
                sales.currency,
                fx_rates.date AS expected_fx_rate_date,
                fx_rates.fx_rate AS expected_fx_rate
            FROM int_sales_lines AS sales
            ASOF LEFT JOIN read_parquet('s1_staging/data/fx_rates.parquet') AS fx_rates
                ON sales.currency = fx_rates.currency
                AND sales.reporting_date >= fx_rates.date
            WHERE sales.currency <> 'CZK'
        )
        SELECT COUNT(*)
        FROM int_sales_lines AS sales
        LEFT JOIN expected_rates
            ON sales.shop = expected_rates.shop
            AND sales.line_id = expected_rates.line_id
        WHERE sales.currency = 'CZK'
            AND (sales.fx_rate <> 1 OR sales.fx_rate_date IS NOT NULL)
            OR sales.currency <> 'CZK'
            AND (
                expected_rates.expected_fx_rate IS NULL
                OR sales.fx_rate IS DISTINCT FROM expected_rates.expected_fx_rate
                OR sales.fx_rate_date IS DISTINCT FROM expected_rates.expected_fx_rate_date
                OR sales.fx_rate_date > sales.reporting_date
                OR sales.gross_sales_czk IS DISTINCT FROM CAST(
                    ROUND(sales.gross_sales_local / sales.fx_rate, 2) AS DECIMAL(18, 2)
                )
                OR sales.discounts_czk IS DISTINCT FROM CAST(
                    ROUND(sales.discounts_local / sales.fx_rate, 2) AS DECIMAL(18, 2)
                )
            )
        """,
    ),
    (
        "bundle definitions parse and reference known components with costs",
        """
        WITH component_definitions AS (
            SELECT
                bundle.sku AS bundle_sku,
                definitions.component_definition,
                split_part(definitions.component_definition, ':', 1) AS component_sku,
                split_part(definitions.component_definition, ':', 2) AS quantity_text
            FROM read_parquet('s1_staging/data/products.parquet') AS bundle
            CROSS JOIN UNNEST(string_split(bundle.bundle_components, '|'))
                AS definitions(component_definition)
            WHERE bundle.is_bundle
        )
        SELECT COUNT(*)
        FROM component_definitions AS definitions
        LEFT JOIN read_parquet('s1_staging/data/products.parquet') AS component
            ON definitions.component_sku = component.sku
        WHERE definitions.component_sku = ''
            OR NOT regexp_full_match(definitions.quantity_text, '[0-9]+')
            OR TRY_CAST(definitions.quantity_text AS BIGINT) IS NULL
            OR TRY_CAST(definitions.quantity_text AS BIGINT) <= 0
            OR length(definitions.component_definition)
                - length(replace(definitions.component_definition, ':', '')) <> 1
            OR component.sku IS NULL
            OR component.unit_cost_czk IS NULL
        """,
    ),
    (
        "bundle allocation weights are positive",
        """
        WITH bundle_costs AS (
            SELECT
                bundle.sku,
                SUM(component.unit_cost_czk * TRY_CAST(
                    split_part(definitions.component_definition, ':', 2) AS BIGINT
                )) AS total_component_cost
            FROM read_parquet('s1_staging/data/products.parquet') AS bundle
            CROSS JOIN UNNEST(string_split(bundle.bundle_components, '|'))
                AS definitions(component_definition)
            LEFT JOIN read_parquet('s1_staging/data/products.parquet') AS component
                ON split_part(definitions.component_definition, ':', 1) = component.sku
            WHERE bundle.is_bundle
            GROUP BY bundle.sku
        )
        SELECT COUNT(*)
        FROM bundle_costs
        WHERE total_component_cost IS NULL OR total_component_cost <= 0
        """,
    ),
    (
        "every active source line is represented in fact_sales",
        """
        SELECT COUNT(*)
        FROM int_sales_lines AS sales
        LEFT JOIN (
            SELECT DISTINCT shop, line_id
            FROM fact_sales
        ) AS facts
            ON sales.shop = facts.shop AND sales.line_id = facts.line_id
        WHERE facts.line_id IS NULL
        """,
    ),
    (
        "bundle component rows match their definitions",
        """
        WITH expected_components AS (
            SELECT
                sales.shop,
                sales.line_id,
                sales.source_sku,
                split_part(definitions.component_definition, ':', 1) AS sku,
                TRY_CAST(split_part(definitions.component_definition, ':', 2) AS BIGINT)
                    AS bundle_component_quantity
            FROM int_sales_lines AS sales
            INNER JOIN read_parquet('s1_staging/data/products.parquet') AS bundle
                ON sales.source_sku = bundle.sku AND bundle.is_bundle
            CROSS JOIN UNNEST(string_split(bundle.bundle_components, '|'))
                AS definitions(component_definition)
        ),
        actual_components AS (
            SELECT shop, line_id, source_sku, sku, bundle_component_quantity
            FROM fact_sales
            WHERE is_bundle_component
        ),
        missing_components AS (
            SELECT * FROM expected_components
            EXCEPT ALL
            SELECT * FROM actual_components
        ),
        extra_components AS (
            SELECT * FROM actual_components
            EXCEPT ALL
            SELECT * FROM expected_components
        )
        SELECT
            (SELECT COUNT(*) FROM missing_components)
            + (SELECT COUNT(*) FROM extra_components)
        """,
    ),
    (
        "bundle gross sales, discounts, and net sales reconcile after allocation",
        """
        WITH allocated_lines AS (
            SELECT
                shop,
                line_id,
                source_sku,
                SUM(gross_sales_czk) AS gross_sales_czk,
                SUM(discounts_czk) AS discounts_czk,
                SUM(net_sales_czk) AS net_sales_czk
            FROM fact_sales
            GROUP BY shop, line_id, source_sku
        )
        SELECT COUNT(*)
        FROM int_sales_lines AS sales
        LEFT JOIN allocated_lines AS allocated
            ON sales.shop = allocated.shop
            AND sales.line_id = allocated.line_id
            AND sales.source_sku = allocated.source_sku
        WHERE allocated.gross_sales_czk IS DISTINCT FROM sales.gross_sales_czk
            OR allocated.discounts_czk IS DISTINCT FROM sales.discounts_czk
            OR allocated.net_sales_czk IS DISTINCT FROM sales.net_sales_czk
        """,
    ),
    (
        "fact_sales has a unique shop-line-SKU key",
        """
        SELECT COUNT(*) FROM (
            SELECT shop, line_id, sku
            FROM fact_sales
            GROUP BY shop, line_id, sku
            HAVING COUNT(*) > 1
        )
        """,
    ),
    (
        "unknown product rows and unknown costs are preserved",
        """
        SELECT COUNT(*)
        FROM fact_sales
        WHERE (product_match_status = 'UNKNOWN' AND (
                product_name IS NOT NULL OR unit_cost_czk IS NOT NULL OR cogs_czk IS NOT NULL
            ))
            OR (product_match_status = 'MATCHED' AND (
                product_name IS NULL OR unit_cost_czk IS NULL OR cogs_czk IS NULL
            ))
            OR product_match_status NOT IN ('UNKNOWN', 'MATCHED')
        """,
    ),
    (
        "unknown product SKU coverage matches the active source lines",
        """
        WITH products AS (
            SELECT sku FROM read_parquet('s1_staging/data/products.parquet')
        ),
        expected_skus AS (
            SELECT DISTINCT sales.source_sku AS sku
            FROM int_sales_lines AS sales
            LEFT JOIN products ON sales.source_sku = products.sku
            WHERE products.sku IS NULL
        ),
        actual_skus AS (
            SELECT DISTINCT sku
            FROM fact_sales
            WHERE product_match_status = 'UNKNOWN'
        ),
        missing AS (
            SELECT * FROM expected_skus
            EXCEPT
            SELECT * FROM actual_skus
        ),
        extra AS (
            SELECT * FROM actual_skus
            EXCEPT
            SELECT * FROM expected_skus
        )
        SELECT (SELECT COUNT(*) FROM missing) + (SELECT COUNT(*) FROM extra)
        """,
    ),
    (
        "fact_daily_metrics has one row per reporting date and shop",
        """
        SELECT COUNT(*) FROM (
            SELECT reporting_date, shop
            FROM fact_daily_metrics
            GROUP BY reporting_date, shop
            HAVING COUNT(*) > 1
        )
        """,
    ),
    (
        "daily sales and cost metrics reconcile to fact_sales",
        """
        WITH fact_totals AS (
            SELECT
                reporting_date,
                shop,
                SUM(gross_sales_czk) AS gross_sales_czk,
                SUM(discounts_czk) AS discounts_czk,
                SUM(net_sales_czk) AS net_sales_czk,
                SUM(cogs_czk) FILTER (WHERE cogs_czk IS NOT NULL) AS known_cogs_czk,
                SUM(net_sales_czk) FILTER (WHERE cogs_czk IS NULL) AS uncosted_net_sales_czk,
                COUNT(*) FILTER (WHERE cogs_czk IS NULL) AS unknown_cost_line_count,
                CASE
                    WHEN COUNT(*) FILTER (WHERE cogs_czk IS NULL) > 0 THEN NULL
                    ELSE SUM(cogs_czk)
                END AS cogs_czk,
                COUNT(DISTINCT order_id) AS order_count
            FROM fact_sales
            GROUP BY reporting_date, shop
        )
        SELECT COUNT(*)
        FROM fact_totals
        FULL OUTER JOIN fact_daily_metrics
            USING (reporting_date, shop)
        WHERE fact_totals.gross_sales_czk IS DISTINCT FROM fact_daily_metrics.gross_sales_czk
            OR fact_totals.discounts_czk IS DISTINCT FROM fact_daily_metrics.discounts_czk
            OR fact_totals.net_sales_czk IS DISTINCT FROM fact_daily_metrics.net_sales_czk
            OR fact_totals.known_cogs_czk IS DISTINCT FROM fact_daily_metrics.known_cogs_czk
            OR fact_totals.uncosted_net_sales_czk
                IS DISTINCT FROM fact_daily_metrics.uncosted_net_sales_czk
            OR fact_totals.unknown_cost_line_count
                IS DISTINCT FROM fact_daily_metrics.unknown_cost_line_count
            OR fact_totals.cogs_czk IS DISTINCT FROM fact_daily_metrics.cogs_czk
            OR fact_totals.order_count IS DISTINCT FROM fact_daily_metrics.order_count
        """,
    ),
    (
        "daily totals aggregate consistently to month and shop",
        """
        WITH monthly_daily AS (
            SELECT
                reporting_month,
                shop,
                SUM(gross_sales_czk) AS gross_sales_czk,
                SUM(discounts_czk) AS discounts_czk,
                SUM(net_sales_czk) AS net_sales_czk,
                SUM(known_cogs_czk) AS known_cogs_czk,
                SUM(uncosted_net_sales_czk) AS uncosted_net_sales_czk,
                SUM(unknown_cost_line_count) AS unknown_cost_line_count,
                CASE
                    WHEN SUM(unknown_cost_line_count) > 0 THEN NULL
                    ELSE SUM(known_cogs_czk)
                END AS cogs_czk,
                CASE
                    WHEN SUM(unknown_cost_line_count) > 0 THEN NULL
                    ELSE SUM(net_sales_czk) - SUM(known_cogs_czk)
                END AS gross_margin_czk,
                SUM(order_count) AS daily_order_count
            FROM fact_daily_metrics
            GROUP BY reporting_month, shop
        ),
        monthly_facts AS (
            SELECT
                reporting_month,
                shop,
                SUM(gross_sales_czk) AS gross_sales_czk,
                SUM(discounts_czk) AS discounts_czk,
                SUM(net_sales_czk) AS net_sales_czk,
                SUM(cogs_czk) FILTER (WHERE cogs_czk IS NOT NULL) AS known_cogs_czk,
                SUM(net_sales_czk) FILTER (WHERE cogs_czk IS NULL) AS uncosted_net_sales_czk,
                COUNT(*) FILTER (WHERE cogs_czk IS NULL) AS unknown_cost_line_count,
                CASE
                    WHEN COUNT(*) FILTER (WHERE cogs_czk IS NULL) > 0 THEN NULL
                    ELSE SUM(cogs_czk)
                END AS cogs_czk,
                CASE
                    WHEN COUNT(*) FILTER (WHERE cogs_czk IS NULL) > 0 THEN NULL
                    ELSE SUM(net_sales_czk) - SUM(cogs_czk)
                END AS gross_margin_czk,
                COUNT(DISTINCT order_id) AS order_count
            FROM fact_sales
            GROUP BY reporting_month, shop
        )
        SELECT COUNT(*)
        FROM monthly_daily
        FULL OUTER JOIN monthly_facts
            USING (reporting_month, shop)
        WHERE monthly_daily.gross_sales_czk IS DISTINCT FROM monthly_facts.gross_sales_czk
            OR monthly_daily.discounts_czk IS DISTINCT FROM monthly_facts.discounts_czk
            OR monthly_daily.net_sales_czk IS DISTINCT FROM monthly_facts.net_sales_czk
            OR monthly_daily.known_cogs_czk IS DISTINCT FROM monthly_facts.known_cogs_czk
            OR monthly_daily.uncosted_net_sales_czk
                IS DISTINCT FROM monthly_facts.uncosted_net_sales_czk
            OR monthly_daily.unknown_cost_line_count
                IS DISTINCT FROM monthly_facts.unknown_cost_line_count
            OR monthly_daily.cogs_czk IS DISTINCT FROM monthly_facts.cogs_czk
            OR monthly_daily.gross_margin_czk IS DISTINCT FROM monthly_facts.gross_margin_czk
            OR monthly_daily.daily_order_count IS DISTINCT FROM monthly_facts.order_count
        """,
    ),
    (
        "staged budget has unique month-shop keys",
        """
        SELECT COUNT(*) FROM (
            SELECT month, shop
            FROM read_parquet('s1_staging/data/budget.parquet')
            GROUP BY month, shop
            HAVING COUNT(*) > 1
        )
        """,
    ),
    (
        "every budget month-shop key has actual daily metrics",
        """
        SELECT COUNT(*)
        FROM read_parquet('s1_staging/data/budget.parquet') AS budget
        LEFT JOIN (
            SELECT DISTINCT reporting_month, shop
            FROM fact_daily_metrics
        ) AS actual
            ON budget.month = actual.reporting_month AND budget.shop = actual.shop
        WHERE actual.reporting_month IS NULL
        """,
    ),
    (
        "all source, fact, and budget datasets cover the expected shops",
        """
        WITH expected_shops(shop) AS (
            VALUES ('CZ'), ('SK'), ('HU')
        ),
        expected_datasets(dataset) AS (
            VALUES
                ('int_orders'),
                ('int_sales_lines'),
                ('fact_sales'),
                ('fact_daily_metrics'),
                ('staged_budget')
        ),
        expected_coverage AS (
            SELECT dataset, shop
            FROM expected_datasets
            CROSS JOIN expected_shops
        ),
        actual_shops AS (
            SELECT 'int_orders' AS dataset, shop FROM int_orders
            UNION ALL
            SELECT 'int_sales_lines', shop FROM int_sales_lines
            UNION ALL
            SELECT 'fact_sales', shop FROM fact_sales
            UNION ALL
            SELECT 'fact_daily_metrics', shop FROM fact_daily_metrics
            UNION ALL
            SELECT 'staged_budget', shop
            FROM read_parquet('s1_staging/data/budget.parquet')
        ),
        missing_shops AS (
            SELECT dataset, shop FROM expected_coverage
            EXCEPT
            SELECT DISTINCT dataset, shop FROM actual_shops
        ),
        extra_shops AS (
            SELECT DISTINCT dataset, shop FROM actual_shops
            EXCEPT
            SELECT dataset, shop FROM expected_coverage
        )
        SELECT
            (SELECT COUNT(*) FROM missing_shops)
            + (SELECT COUNT(*) FROM extra_shops)
        """,
    ),
]


def main():
    os.chdir(ROOT)
    (ROOT / "s3_marts" / "data").mkdir(parents=True, exist_ok=True)
    connection = duckdb.connect(str(DATABASE))
    try:
        for model_file in MODEL_FILES:
            connection.execute(model_file.read_text(encoding="utf-8"))
            print(f"Built {model_file.relative_to(ROOT)}")

        for check_name, query in CHECKS:
            invalid_rows = connection.execute(query).fetchone()[0]
            if invalid_rows:
                raise RuntimeError(
                    f"FAIL {check_name}: {invalid_rows} invalid row(s)"
                )
            print(f"PASS {check_name}")

        print("\nValidated row counts:")
        for table_name in (
            "int_orders",
            "int_sales_lines",
            "fact_sales",
            "fact_daily_metrics",
        ):
            row_count = connection.execute(
                f"SELECT COUNT(*) FROM {table_name}"
            ).fetchone()[0]
            print(f"  {table_name}: {row_count:,}")

        for table_name, export_path in EXPORTS.items():
            path_sql = export_path.as_posix().replace("'", "''")
            connection.execute(
                f"COPY {table_name} TO '{path_sql}' "
                "(HEADER, DELIMITER ',', OVERWRITE_OR_IGNORE true)"
            )
            exported_rows = connection.execute(
                f"SELECT COUNT(*) FROM read_csv_auto('{path_sql}')"
            ).fetchone()[0]
            table_rows = connection.execute(
                f"SELECT COUNT(*) FROM {table_name}"
            ).fetchone()[0]
            if exported_rows != table_rows:
                raise RuntimeError(
                    f"FAIL {export_path.name} row count: expected {table_rows}, "
                    f"got {exported_rows}"
                )
            print(f"PASS {export_path.name} row count ({exported_rows:,})")

        unbudgeted_months = connection.execute(
            """
            SELECT actual.reporting_month, actual.shop
            FROM (
                SELECT DISTINCT reporting_month, shop
                FROM fact_daily_metrics
            ) AS actual
            LEFT JOIN read_parquet('s1_staging/data/budget.parquet') AS budget
                ON actual.reporting_month = budget.month AND actual.shop = budget.shop
            WHERE budget.month IS NULL
            ORDER BY actual.reporting_month, actual.shop
            """
        ).fetchall()
        if unbudgeted_months:
            print("\nActual month-shop keys without a budget (retained; no budget was inferred):")
            for month, shop in unbudgeted_months:
                print(f"  {month} | {shop}")

        print(
            f"\nPASS: {len(CHECKS)} data-quality checks and "
            f"{len(EXPORTS)} CSV exports."
        )
    finally:
        connection.close()


if __name__ == "__main__":
    main()
