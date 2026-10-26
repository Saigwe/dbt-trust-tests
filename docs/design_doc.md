# Design doc: dbt-trust-tests

| | |
|---|---|
| **Author** | Stanley Igwe |
| **Status** | v0.1.0 released |
| **Last updated** | 26 Oct 2026 |

## 1. Problem
Across 17 portfolio projects I hand-wrote the same checks many times: a grain test copied into 17 repos, ledger tie-outs, answer-key tests for controls, SCD2 and point-in-time checks, and a masking policy. Copies drift, each one is tested only by the project that holds it, and a new project starts by copying again. In consulting I saw the same pattern at scale: reusable SQL is only reusable when it is packaged, versioned and tested on its own.

## 2. Requirements
| Type | Requirement |
|---|---|
| Functional | Seven generic tests: grain, reconciliation, answer key, SCD2, point in time, column-name policy, hashed identifiers |
| Correctness | Each test proven both ways: passes on clean data and returns exactly the expected failing rows on planted problems |
| Portability | DuckDB and Postgres tested in CI; Snowflake and BigQuery hooks through dispatch |
| Compatibility | dbt Core 1.10 and 1.11, with the `arguments:` syntax |
| Usability | Failing rows explain themselves: the group, measure, entity or key, and the problem in words |

## 3. Design
- **Generic tests, not macros you call in models.** They show up in `dbt test`, in docs and lineage, and in run results with failure counts, so they fit how teams already work.
- **Failure rows that explain themselves.** `reconciles_to` returns the group, measure and both values; `scd2_valid` names the entity and the problem. Store failures and an analyst can act without reading SQL.
- **Exact failure counts as the test oracle.** Each integration test declares `meta.expect_failures`. A test that's too lenient (misses a planted gap) or too strict (flags a clean null key) fails CI. Checking only pass or fail would miss both.
- **Dialect differences in one place.** Only the regular-expression check differs by warehouse (`regex_matches`, dispatched under the `trust_tests` namespace). Dates use dbt's own `dateadd`, types use `dbt.type_numeric()` and `dbt.type_string()`.
- **Conventions as arguments, not assumptions.** SCD2 end dates are either exclusive or inclusive by day; projects differ, so `end_convention` is explicit, and a test proves a wrong choice is caught.

## 4. Options considered
| Decision | Options | Chosen | Why |
|---|---|---|---|
| Distribution | Copy macros / git package / dbt Hub | Git package with version tags | Pinned and reviewable today; Hub listing can follow |
| Test oracle | Pass/fail only / exact failure counts | Exact counts | Catches tests that are too lenient or too strict |
| Column policy | Information schema query / adapter columns at test time | Adapter columns | Works the same on every adapter, and sees columns added outside the YAML |
| Windows local install | `local: ../` / staged copy | Staged copy in `run.py` | dbt copies local packages on Windows, and `../` would copy the test project into itself |

## 5. Results
- 19 integration tests behave exactly as declared on DuckDB locally; CI runs them on DuckDB and Postgres with dbt 1.10 and 1.11.
- Health Claims swapped five hand-written tests for package tests and still passes on DuckDB and Postgres.

## 6. Next
- Snowflake and BigQuery runs in CI (needs warehouse credentials).
- List the package on dbt Hub.
- A `incremental_matches_full_refresh` check as a run-operation.
