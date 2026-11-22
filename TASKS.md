# FABINI Task Tracker

## Current priority

**Task 4 — Build one dashboard page (`TODO`)**

## Required case study tasks

### Task 1 — Explore raw data (`DONE`)

Acceptance: source exploration and cross-source findings are recorded in [analysis/exploration/](analysis/exploration/).

### Task 2 — Clean and model data (`IMPLEMENTED; RUNTIME VALIDATION PENDING`)

Acceptance: the six raw CSV sources feed six typed S1 SQL views, two S2 intermediate views, and the two final S3 business tables; `dbt build` runs all eight SQL tests and writes both CSV exports. Validate with the authorized GitHub Actions workflow.

### Task 3 — Answer management questions (`DONE`)

Acceptance: four reproducible analyses in [analysis/](analysis/) and results in [answers.md](answers.md).

### Task 4 — Build one dashboard page (`TODO`)

Acceptance: one completed Power BI page and exported PDF in `dashboard/`.

### Task 5 — Final README and submission review (`TODO`)

Acceptance: concise one-page README accurately documents setup, assumptions, limitations, outputs, and one-day improvements; complete final consistency and submission review.

## Primary data workflow

The dbt project at the repository root is the only transformation workflow. It reads six source CSV files, builds six S1 staging views, two S2 intermediate views, and two S3 business tables, runs eight SQL tests, and generates two CSV exports.

Runtime validation of this dbt-only layout is pending. The earlier GitHub Actions success was for the previous Parquet-staging workflow and does not validate this version. Full row-level reconciliation against the former standalone pipeline has not been performed.
