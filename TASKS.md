# FABINI Task Tracker

## Current priority

**Task 4 — Build one dashboard page (`TODO`)**

## Required case study tasks

### Task 1 — Explore raw data (`DONE`)

Acceptance: source exploration and cross-source findings are recorded.

### Task 2 — Clean and model data (`DONE`)

Acceptance: six staged sources feed the four dbt models; dbt tests and the two final CSV exports are documented in [tests/AUDIT.md](tests/AUDIT.md).

### Task 3 — Answer management questions (`DONE`)

Acceptance: four reproducible analyses in `analysis/` and results in [answers.md](answers.md).

### Task 4 — Build one dashboard page (`TODO`)

Acceptance: one completed Power BI page and exported PDF in `dashboard/`.

### Task 5 — Final README and submission review (`TODO`)

Acceptance: concise one-page [README.md](README.md) accurately documents setup, assumptions, limitations, outputs, and one-day improvements; complete final consistency and submission review.

## Primary data workflow

The dbt project in `dbt_poc/` is the sole SQL transformation workflow. It declares six staged sources, builds four business models, runs eight SQL data-quality tests, and generates two CSV exports.

The latest reported GitHub Actions run completed staging and `dbt build` successfully and generated both exports. A complete row-by-row comparison against the former standalone pipeline has not been performed.
