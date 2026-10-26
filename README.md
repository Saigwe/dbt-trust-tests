# dbt-trust-tests

[![CI](https://github.com/Saigwe/dbt-trust-tests/actions/workflows/ci.yml/badge.svg)](https://github.com/Saigwe/dbt-trust-tests/actions/workflows/ci.yml)

> Seven dbt generic tests for the checks that make finance, risk and regulated data trustworthy: totals that tie out, controls that find exactly the planted errors, well-formed SCD2 history, correct point-in-time joins, and personal data kept out of reporting layers.

**Author:** Stanley Igwe, Lead Data (Analytics) Engineer · [Portfolio](https://saigwe.github.io)
**Works with:** dbt Core 1.10 and 1.11 · tested on DuckDB and Postgres in CI · dialect hooks for Snowflake and BigQuery
**Status:** v0.1.0. Integration suite: 19 tests, each checked for the exact number of failing rows it should return, on 2 adapters × 2 dbt versions.

I wrote these same checks by hand, again and again, across 17 portfolio projects and in client work: reconciling a sub-ledger to the general ledger for auditors, testing audit controls, versioning member history for an insurer. This package turns them into one tested, versioned dependency.

---

## Why these tests
`dbt_utils` and `dbt_expectations` cover column-level checks well. These tests cover the questions a controller, auditor or risk lead actually asks:

| Question | Test |
|---|---|
| Is the grain what we say it is? | `unique_combination` |
| Do the totals tie to the source or the ledger, group by group? | `reconciles_to` |
| Does the control find the errors we planted, and nothing else? | `matches_answer_key` |
| Is the history well formed: no overlaps, no gaps, one current version? | `scd2_valid` |
| Does each fact point at the version that was valid on the event date? | `point_in_time_valid` |
| Has a raw identifier or birth date leaked into silver or gold? | `no_columns_matching` |
| Is the masked key really a hash, and never a raw id? | `hashed_identifier` |

## Install
```yaml
# packages.yml
packages:
  - git: "https://github.com/Saigwe/dbt-trust-tests.git"
    revision: v0.1.0
```
Then `dbt deps`. Arguments go under `arguments:`, the dbt 1.10+ style.

## The tests
### `unique_combination`
```yaml
models:
  - name: fct_revenue_monthly
    tests:
      - trust_tests.unique_combination:
          arguments: {columns: [account_id, month]}
```

### `reconciles_to`
Every group and every measure must match another relation within a tolerance. A group on only one side fails too, and each failing row names the group, the measure and both values.
```yaml
      - trust_tests.reconciles_to:
          arguments:
            to: source('ledger', 'gl_balances')
            measures: {n_rows: "count(*)", amount: "sum(amount_usd)"}
            to_measures: {amount: "sum(debit - credit)"}   # optional: when the source expresses it differently
            group_by: [account_id, month]
            tolerance: 0.01
```

### `matches_answer_key`
The answer-key pattern: plant known errors in test data, list them in a seed, and require the model to find exactly those. It fails on a missed case, an unexpected finding, or a finding with the wrong details.
```yaml
      - trust_tests.matches_answer_key:
          arguments:
            expected: ref('planted_exceptions')
            key_columns: [batch_id]
            compare_columns: [reason, amount]
```

### `scd2_valid`
Overlaps, gaps, versions that end before they start, an open-ended version that isn't the last one, and (with `current_flag`) anything but exactly one current version. `end_convention` is `exclusive` (the next version starts on `valid_to`) or `inclusive_day` (the next version starts the day after).
```yaml
  - name: dim_member
    tests:
      - trust_tests.scd2_valid:
          arguments: {entity_key: member_key, valid_from: valid_from, valid_to: valid_to,
                      current_flag: is_current, end_convention: inclusive_day}
```

### `point_in_time_valid`
Put it on the fact's foreign key. It fails when the event falls outside the referenced version's window, or the key has no dimension row.
```yaml
  - name: fct_claim_line
    columns:
      - name: member_sk
        tests:
          - trust_tests.point_in_time_valid:
              arguments: {to: ref('dim_member'), field: member_sk, event_at: service_from_date,
                          valid_from: valid_from, valid_to: valid_to, end_convention: inclusive_day}
```

### `no_columns_matching`
A column-name policy, read from the warehouse at test time, so it also catches columns added outside the YAML. Patterns are case-insensitive whole-name regular expressions.
```yaml
      - trust_tests.no_columns_matching:
          arguments: {patterns: ['.*birth_?(dt|date).*', 'member_id', '.*npi', 'email.*']}
```

### `hashed_identifier`
Every value is a lowercase hex digest of the given length, and none equals a raw identifier.
```yaml
      - name: member_key
        tests:
          - trust_tests.hashed_identifier:
              arguments: {length: 32, raw_values: {relation: source('bronze', 'members'), column: member_id}}
```

## How it's tested
`integration_tests/` seeds clean data and data with planted problems. Every test declares, in `meta.expect_failures`, exactly how many failing rows it must return: 0 for clean data, or the exact count of planted problems. `run.py` runs them all and fails if any result is off by even one row. A test that's too lenient fails this check, and so does one that's too strict.

| Test | Clean data | Planted problems caught (exactly) |
|---|---|---|
| `unique_combination` | passes ×2 | (covered in the projects that use it) |
| `reconciles_to` | passes ×2 (grouped, ungrouped) | 5 (amount off, a group missing on each side); 4 with a tolerance that absorbs the small difference |
| `matches_answer_key` | passes | 3 (missed, unexpected, wrong amount); 2 when only keys are compared |
| `scd2_valid` | passes ×2 (both conventions) | 5 (overlap, gap, ends before start, two current, open-ended not last); 1 when the convention is wrong |
| `point_in_time_valid` | passes (including a null key) | 4 (on the end date, before the start, unknown key, before the first version) |
| `no_columns_matching` | passes | 3 (including a mixed-case name) |
| `hashed_identifier` | passes | 4 (uppercase hex, not hex, a raw id that is also not hex) |

CI runs the suite on DuckDB and Postgres 16, each with dbt 1.10 and 1.11.

```bash
cd integration_tests
python run.py                          # DuckDB
TRUST_TESTS_TARGET=postgres python run.py   # Postgres (PGHOST, PGUSER, PGPASSWORD, PGDATABASE)
```

## Used in
- [health-claims-warehouse](https://github.com/Saigwe/health-claims-warehouse): `scd2_valid`, `point_in_time_valid`, `reconciles_to`, `no_columns_matching`, `hashed_identifier` replace hand-written tests, on DuckDB and Postgres
- [people-training-analytics](https://github.com/Saigwe/people-training-analytics) and [semiconductor-yield-analytics](https://github.com/Saigwe/semiconductor-yield-analytics): `unique_combination` replaces a copied macro

## Design notes
See [`docs/design_doc.md`](docs/design_doc.md) for the choices (why generic tests and not macros, why exact failure counts, dialect dispatch, versioning).

## Licence
MIT (see `LICENSE`).
