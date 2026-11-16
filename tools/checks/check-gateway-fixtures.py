#!/usr/bin/env python3
"""Replay the protocol v0 fixtures against the JSON Schema.

Usage:
    python tools/checks/check-gateway-fixtures.py

Exit codes:
    0  every case matches its expectation
    1  a schema or expectation mismatch
    2  the fixtures or the schema are missing
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
FIXTURES = ROOT / "contracts" / "fixtures" / "gateway-v0.json"
SCHEMA = ROOT / "contracts" / "schemas" / "gateway.v1.schema.json"

ALLOWED_ERRORS = {
    "E_AUTH",
    "E_TENANT",
    "E_VERSION",
    "E_RATE",
    "E_QUEUE",
    "E_SCHEMA",
    "E_UNSUPPORTED",
}


def main() -> int:
    for path in (FIXTURES, SCHEMA):
        if not path.exists():
            print(f"missing: {path}", file=sys.stderr)
            return 2

    try:
        from jsonschema import Draft202012Validator
    except ImportError:
        print("jsonschema is required: pip install jsonschema", file=sys.stderr)
        return 2

    cases = json.loads(FIXTURES.read_text(encoding="utf-8"))["cases"]
    validator = Draft202012Validator(json.loads(SCHEMA.read_text(encoding="utf-8")))

    problems = 0
    seen: set[str] = set()
    for case in cases:
        name = case["name"]
        if name in seen:
            print(f"duplicate case: {name}", file=sys.stderr)
            problems += 1
        seen.add(name)

        errors = list(validator.iter_errors(case["message"]))
        schema_valid = case.get("schema", case["ok"])
        if schema_valid and errors:
            print(
                f"{name}: schema should accept, got {errors[0].message}",
                file=sys.stderr,
            )
            problems += 1
        if not schema_valid and not errors:
            print(f"{name}: schema should refuse", file=sys.stderr)
            problems += 1

        if case["ok"]:
            if case.get("error") is not None:
                print(f"{name}: accepted case carries an error", file=sys.stderr)
                problems += 1
        elif case.get("error") not in ALLOWED_ERRORS:
            print(f"{name}: refused case names no known gateway error", file=sys.stderr)
            problems += 1

    if problems:
        print(f"{problems} problem(s) in {len(cases)} case(s)", file=sys.stderr)
        return 1

    print(f"ok {len(cases)} case(s)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
