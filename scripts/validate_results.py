#!/usr/bin/env python3
"""Validate completed FABINI dbt CSV exports without rebuilding the pipeline."""

import argparse
import csv
import sys
from collections import Counter, defaultdict
from datetime import date
from decimal import Decimal, InvalidOperation
from pathlib import Path


FACT_SALES_COLUMNS = (
    "shop", "reporting_date", "reporting_month", "order_id", "line_id",
    "source_sku", "sku", "product_name", "category", "product_match_status",
    "customer_id", "currency", "fx_rate_date", "fx_rate", "created_at",
    "source_line_quantity", "bundle_component_quantity", "sold_quantity",
    "is_bundle_component", "component_ordinal", "unit_cost_czk",
    "gross_sales_czk", "discounts_czk", "net_sales_czk", "cogs_czk",
    "gross_margin_czk",
)
FACT_DAILY_COLUMNS = (
    "reporting_date", "reporting_month", "shop", "gross_sales_czk",
    "discounts_czk", "net_sales_czk", "cogs_czk", "known_cogs_czk",
    "uncosted_net_sales_czk", "unknown_cost_line_count", "gross_margin_czk",
    "gross_margin_pct", "order_count",
)
FACT_SALES_DECIMALS = {
    "fx_rate", "unit_cost_czk", "gross_sales_czk", "discounts_czk",
    "net_sales_czk", "cogs_czk", "gross_margin_czk",
}
FACT_DAILY_DECIMALS = {
    "gross_sales_czk", "discounts_czk", "net_sales_czk", "cogs_czk",
    "known_cogs_czk", "uncosted_net_sales_czk", "gross_margin_czk",
    "gross_margin_pct",
}
NULL_TOKEN = r"\N"
EXPECTED_Q3_NET_SALES = Decimal("10098945.10")


def parse_value(column, value, decimal_columns, integer_columns, boolean_columns):
    if value == NULL_TOKEN:
        return None
    if column in decimal_columns:
        try:
            parsed = Decimal(value)
        except InvalidOperation as error:
            raise ValueError(f"{column} is not a DECIMAL: {value!r}") from error
        if not parsed.is_finite():
            raise ValueError(f"{column} is not a finite DECIMAL: {value!r}")
        return parsed
    if column in integer_columns:
        try:
            return int(value)
        except ValueError as error:
            raise ValueError(f"{column} is not an integer: {value!r}") from error
    if column in boolean_columns:
        if value.lower() == "true":
            return True
        if value.lower() == "false":
            return False
        raise ValueError(f"{column} is not a boolean: {value!r}")
    return value


def read_export(path, columns, decimal_columns, integer_columns=(), boolean_columns=()):
    with path.open(newline="", encoding="utf-8-sig") as file:
        reader = csv.DictReader(file)
        if tuple(reader.fieldnames or ()) != columns:
            raise ValueError(
                f"{path}: schema mismatch; expected {columns}, got {reader.fieldnames}"
            )
        rows = []
        for line_number, row in enumerate(reader, start=2):
            if None in row:
                raise ValueError(f"{path}:{line_number}: extra CSV fields")
            if any(value is None for value in row.values()):
                raise ValueError(f"{path}:{line_number}: missing CSV values")
            rows.append({
                column: parse_value(
                    column, row[column], decimal_columns, integer_columns, boolean_columns
                )
                for column in columns
            })
    return rows


def report(checks, label, passed, detail):
    print(f"{'PASS' if passed else 'FAIL'} | {label}: {detail}")
    checks.append(passed)


def check_unique(rows, columns, label, checks):
    counts = Counter(tuple(row[column] for column in columns) for row in rows)
    duplicates = [(key, count) for key, count in counts.items() if count > 1]
    detail = "no duplicate keys" if not duplicates else f"{len(duplicates)} duplicate keys; sample={duplicates[:3]}"
    report(checks, label, not duplicates, detail)


def daily_from_sales(sales_rows):
    groups = defaultdict(list)
    for row in sales_rows:
        groups[(row["reporting_date"], row["shop"])].append(row)

    daily = {}
    for key, rows in groups.items():
        known_cost_rows = [row for row in rows if row["cogs_czk"] is not None]
        unknown_cost_rows = [row for row in rows if row["cogs_czk"] is None]

        def total(column, selected_rows):
            values = [row[column] for row in selected_rows if row[column] is not None]
            return sum(values, Decimal("0")) if values else None

        daily[key] = {
            "gross_sales_czk": total("gross_sales_czk", rows),
            "discounts_czk": total("discounts_czk", rows),
            "net_sales_czk": total("net_sales_czk", rows),
            "known_cogs_czk": total("cogs_czk", known_cost_rows),
            "uncosted_net_sales_czk": total("net_sales_czk", unknown_cost_rows),
            "unknown_cost_line_count": len(unknown_cost_rows),
            "cogs_czk": None if unknown_cost_rows else total("cogs_czk", rows),
            "order_count": len({row["order_id"] for row in rows}),
        }
    return daily


def check_daily_reconciliation(sales_rows, daily_rows, checks):
    expected = daily_from_sales(sales_rows)
    actual = {(row["reporting_date"], row["shop"]): row for row in daily_rows}
    mismatches = []
    for key in sorted(expected.keys() | actual.keys()):
        if key not in expected or key not in actual:
            mismatches.append((key, "missing or extra daily key"))
            continue
        for column, value in expected[key].items():
            if actual[key][column] != value:
                mismatches.append((key, column, value, actual[key][column]))
                break
    report(
        checks,
        "daily reconciliation",
        not mismatches,
        "all date-shop metrics reconcile" if not mismatches else f"{len(mismatches)} mismatches; sample={mismatches[:3]}",
    )


def row_counter(rows, columns):
    return Counter(tuple(row[column] for column in columns) for row in rows)


def compare_reference(label, actual_rows, reference_rows, columns, checks):
    actual = row_counter(actual_rows, columns)
    reference = row_counter(reference_rows, columns)
    actual_only = actual - reference
    reference_only = reference - actual
    passed = not actual_only and not reference_only
    detail = (
        "complete datasets match, including duplicate multiplicities"
        if passed
        else f"dbt-only={sum(actual_only.values())}, reference-only={sum(reference_only.values())}; "
             f"dbt-only sample={list(actual_only.items())[:2]}, "
             f"reference-only sample={list(reference_only.items())[:2]}"
    )
    report(checks, label, passed, detail)


def validate_business(sales_rows, daily_rows, checks):
    report(checks, "fact_sales row count", len(sales_rows) == 26734, f"{len(sales_rows)} (expected 26734)")
    report(checks, "fact_daily_metrics row count", len(daily_rows) == 820, f"{len(daily_rows)} (expected 820)")
    check_unique(sales_rows, ("shop", "line_id", "sku"), "fact_sales key", checks)
    check_unique(daily_rows, ("reporting_date", "shop"), "fact_daily_metrics key", checks)
    check_daily_reconciliation(sales_rows, daily_rows, checks)

    try:
        dated_sales = [(date.fromisoformat(row["reporting_date"]), row) for row in sales_rows]
        dated_daily = [date.fromisoformat(row["reporting_date"]) for row in daily_rows]
    except (TypeError, ValueError) as error:
        report(checks, "reporting dates", False, str(error))
        return

    jan_sep_start = date(2026, 1, 1)
    jan_sep_end = date(2026, 9, 30)
    spillover_date = date(2026, 10, 1)
    jan_sep_sales = [row for day, row in dated_sales if jan_sep_start <= day <= jan_sep_end]
    spillover_sales = [row for day, row in dated_sales if day == spillover_date]
    unexpected_dates = [
        day for day, _ in dated_sales
        if not jan_sep_start <= day <= jan_sep_end and day != spillover_date
    ]
    unexpected_dates.extend(
        day for day in dated_daily
        if not jan_sep_start <= day <= jan_sep_end and day != spillover_date
    )
    report(checks, "reporting period", not unexpected_dates,
           f"Jan-Sep 2026 rows={len(jan_sep_sales)}; Oct 1 spillover rows={len(spillover_sales)}"
           + (f"; unexpected dates={unexpected_dates[:3]}" if unexpected_dates else ""))

    q3_rows = [
        row for day, row in dated_sales
        if date(2026, 7, 1) <= day <= date(2026, 9, 30)
    ]
    q3_sales = sum(
        (row["net_sales_czk"] for row in q3_rows if row["net_sales_czk"] is not None),
        Decimal("0"),
    )
    report(checks, "Q3 net sales", q3_sales == EXPECTED_Q3_NET_SALES,
           f"CZK {q3_sales:.2f} (expected CZK {EXPECTED_Q3_NET_SALES:.2f})")

    unknown_cost_rows = sum(row["cogs_czk"] is None for row in sales_rows)
    report(checks, "unknown-cost sales rows", unknown_cost_rows == 277,
           f"{unknown_cost_rows} (expected 277)")
    jan_sep_unknown = sum(
        row["cogs_czk"] is None for day, row in dated_sales
        if jan_sep_start <= day <= jan_sep_end
    )
    spillover_net = sum(
        (row["net_sales_czk"] for day, row in dated_sales
         if day == spillover_date and row["net_sales_czk"] is not None),
        Decimal("0"),
    )
    print(
        "INFO | period split: "
        f"Jan-Sep net sales CZK "
        f"{sum((row['net_sales_czk'] for row in jan_sep_sales if row['net_sales_czk'] is not None), Decimal('0')):.2f}; "
        f"unknown-cost rows={jan_sep_unknown}; "
        f"Oct 1 spillover net sales CZK {spillover_net:.2f}"
    )


def parse_args():
    parser = argparse.ArgumentParser(
        description="Validate completed FABINI dbt CSV exports; does not run dbt."
    )
    parser.add_argument("--fact-sales", type=Path, default=Path("exports/fact_sales.csv"))
    parser.add_argument(
        "--fact-daily-metrics", type=Path, default=Path("exports/fact_daily_metrics.csv")
    )
    parser.add_argument("--reference-sales", type=Path)
    parser.add_argument("--reference-daily", type=Path)
    args = parser.parse_args()
    if bool(args.reference_sales) != bool(args.reference_daily):
        parser.error("--reference-sales and --reference-daily must be provided together")
    return args


def main():
    args = parse_args()
    checks = []
    try:
        sales = read_export(
            args.fact_sales,
            FACT_SALES_COLUMNS,
            FACT_SALES_DECIMALS,
            integer_columns={
                "source_line_quantity", "bundle_component_quantity", "sold_quantity",
                "component_ordinal",
            },
            boolean_columns={"is_bundle_component"},
        )
        daily = read_export(
            args.fact_daily_metrics,
            FACT_DAILY_COLUMNS,
            FACT_DAILY_DECIMALS,
            integer_columns={"unknown_cost_line_count", "order_count"},
        )
        validate_business(sales, daily, checks)

        if args.reference_sales and args.reference_daily:
            reference_sales = read_export(
                args.reference_sales, FACT_SALES_COLUMNS, FACT_SALES_DECIMALS,
                integer_columns={
                    "source_line_quantity", "bundle_component_quantity", "sold_quantity",
                    "component_ordinal",
                },
                boolean_columns={"is_bundle_component"},
            )
            reference_daily = read_export(
                args.reference_daily, FACT_DAILY_COLUMNS, FACT_DAILY_DECIMALS,
                integer_columns={"unknown_cost_line_count", "order_count"},
            )
            compare_reference(
                "fact_sales full-row reconciliation",
                sales, reference_sales, FACT_SALES_COLUMNS, checks,
            )
            compare_reference(
                "fact_daily_metrics full-row reconciliation",
                daily, reference_daily, FACT_DAILY_COLUMNS, checks,
            )
        else:
            print("INFO | reference CSVs not supplied")
    except (OSError, csv.Error, ValueError) as error:
        print(f"FAIL | input validation: {error}", file=sys.stderr)
        return 1

    passed = all(checks)
    if args.reference_sales:
        print("PASS" if passed else "FAIL")
    else:
        print("PARTIAL VALIDATION" if passed else "PARTIAL VALIDATION - FAILURES")
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
