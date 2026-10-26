"""Integration check for trust_tests: seed clean and planted-bad data, run every test, and compare each result with the
exact number of failing rows its YAML promises (meta.expect_failures).

A test that should pass must pass; a test that should fail must fail with exactly that many rows, no more, no fewer.
Runs against the target in TRUST_TESTS_TARGET (duckdb by default, or postgres).

Usage (from integration_tests/):  python run.py
"""
from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).parent
DBT = os.environ.get("DBT_BIN") or shutil.which("dbt") or str(Path(sys.executable).parent / "dbt")


def dbt(*args: str) -> int:
    return subprocess.run([DBT, *args, "--profiles-dir", "."], cwd=HERE).returncode


def stage_package() -> None:
    """Copy just the package (dbt_project.yml + macros) to a temp folder and install it from there. dbt copies local
    packages on Windows, and copying ../ would copy this folder into itself."""
    root = HERE.parent
    stage = Path(tempfile.mkdtemp(prefix="trust_tests_"))
    shutil.copy(root / "dbt_project.yml", stage / "dbt_project.yml")
    shutil.copytree(root / "macros", stage / "macros")
    os.environ["TRUST_TESTS_PATH"] = stage.as_posix()


def main() -> None:
    stage_package()
    for step in (("deps",), ("seed", "--full-refresh")):
        if dbt(*step) != 0:
            raise SystemExit(f"dbt {' '.join(step)} failed")
    dbt("test")  # failures are expected here; the comparison below decides the outcome
    manifest = json.loads((HERE / "target" / "manifest.json").read_text())
    results = json.loads((HERE / "target" / "run_results.json").read_text())["results"]

    problems, checked = [], 0
    for r in results:
        node = manifest["nodes"][r["unique_id"]]
        expected = node["config"].get("meta", {}).get("expect_failures")
        if expected is None:
            problems.append(f"{node['name']}: no meta.expect_failures")
            continue
        checked += 1
        actual = r.get("failures")
        if r["status"] == "error":
            problems.append(f"{node['name']}: errored: {r.get('message')}")
        elif (expected == 0 and r["status"] != "pass") or (expected > 0 and actual != expected):
            problems.append(f"{node['name']}: expected {expected} failing rows, got {actual} ({r['status']})")
        else:
            print(f"ok  {node['name']:<55} {'passes' if expected == 0 else f'catches {expected} planted problem' + ('s' if expected > 1 else '')}")
    if problems or checked == 0:
        print("\n".join(problems) or "no tests ran")
        raise SystemExit(1)
    print(f"\nAll {checked} integration tests behaved exactly as expected on {os.environ.get('TRUST_TESTS_TARGET', 'duckdb')}.")


if __name__ == "__main__":
    main()
