# 3-minute walkthrough: dbt-trust-tests

A timed script for a Loom recording of about 3 minutes (screen plus camera bubble, 1080p). Say it in your own words; the lines are a guide, not a teleprompter.

**Open these tabs before you press record:** README, `macros/generic_tests/reconciles_to.sql`, `integration_tests/` (a schema file with `meta.expect_failures`), `integration_tests/run.py`, GitHub Actions (the 2 × 2 matrix), the health-claims-warehouse `_marts.yml` that uses the package, `docs/design_doc.md`.

| Time | On screen | What to say |
|---|---|---|
| 0:00–0:20 | Portfolio card, then the README title | dbt's built-in tests check columns. Controllers and auditors ask different questions: do the totals tie to the ledger, did the control find exactly the planted errors, is the history well formed? This package answers those with seven generic tests. |
| 0:20–0:40 | README intro and the "Why these tests" table | I wrote these same checks by hand across 17 portfolio projects and in client work: tying a sub-ledger to the general ledger, testing audit controls, versioning member history. Now it's one versioned dependency, v0.1.0. |
| 0:40–1:10 | `reconciles_to.sql`, then its YAML example | `reconciles_to` compares every group and every measure against another relation within a tolerance. A group missing on either side fails too, and each failing row names the group, the measure and both values, so an analyst can act on it. |
| 1:10–1:35 | The `matches_answer_key` and `scd2_valid` examples | The answer-key test is the pattern I use most: plant known errors, list them in a seed, and require the model to find exactly those, with no misses and no false alarms. `scd2_valid` catches overlaps, gaps and anything but one current version. |
| 1:35–2:05 | An integration-test schema file with `meta.expect_failures`, then `run.py` | How do you test a test? Every test declares exactly how many failing rows it must return: 0 on clean data, or the exact number of planted problems. `run.py` fails if any count is off by even one row, so a test that's too lenient fails, and so does one that's too strict. |
| 2:05–2:25 | GitHub Actions: the matrix | CI runs all 19 integration tests on DuckDB and Postgres, each with dbt 1.10 and 1.11. Regex differs by database, so it's dispatched per adapter, with hooks for Snowflake and BigQuery. |
| 2:25–2:45 | health-claims-warehouse `_marts.yml` | It's in use: three of my projects install it instead of copying macros. Health Claims replaced two hand-written tests, added five masking checks, and still passes 51 of 51 on the real CMS data. |
| 2:45–3:00 | `docs/design_doc.md`, then the README top | The decision I'd defend: exact failure counts, not pass or fail. It's the difference between knowing a test works and hoping it does. The install snippet is two lines; the link is under the video. |

## Recording checklist
- Close email, chat and notifications. Zoom the browser to 125% so code is readable.
- Run `python integration_tests/run.py` once before recording so you can show the per-test counts if asked.
- Keep to one take per section; Loom lets you trim. Aim for 2:45 to 3:10.
- Show real numbers on screen as you say them; never estimate on camera.

## After recording
1. Copy the Loom share link.
2. In `README.md`, replace the roadmap line with `- [x] [3-minute Loom walkthrough](<your Loom link>)` and add the link under the title.
3. Add the link to this project's card on saigwe.github.io.
