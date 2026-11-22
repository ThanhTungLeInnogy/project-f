# FABINI Task Tracker

## Current priority

**Task 4 — Build one dashboard page (`TODO`)**

## Required case study tasks

### Task 1 — Explore raw data (`DONE`)

Acceptance: source exploration and cross-source findings are recorded.

### Task 2 — Clean and model data (`DONE`)

Acceptance: validated staging, intermediate models, and two final facts; audit and limitations are recorded in [tests/AUDIT.md](tests/AUDIT.md).

### Task 3 — Answer management questions (`DONE`)

Acceptance: four reproducible analyses in `analysis/` and results in [answers.md](answers.md).

### Task 4 — Build one dashboard page (`TODO`)

Acceptance: one completed Power BI page and exported PDF in `dashboard/`.

### Task 5 — Final README and submission review (`TODO`)

Acceptance: concise one-page [README.md](README.md) accurately documents setup, assumptions, limitations, outputs, and one-day improvements; complete final consistency and submission review.

## dbt migration validation

The dbt project in `dbt_poc/` contains six staged sources, four business models, eight SQL data-quality tests, and two CSV exports. The manual `dbt-ci.yml` workflow runs the six Polars staging notebooks, `dbt build`, tests, and export checks.

- **Standalone DuckDB pipeline:** executed and validated; remains the reference baseline.
- **dbt implementation:** static validation passed; runtime **NOT RUN**.
- **GitHub Actions:** configured for manual execution; **NOT RUN**.

Remaining: run the workflow after it is available on the default branch, resolve any installation or runtime issues, and reconcile dbt results and exports against the standalone baseline. Do not replace the standalone runner until validation passes.
