#!/usr/bin/env python3
"""Validate the protocol schema, the golden frames and the builders.

Three things must agree:
  * `spec/protocol/schema.v1.json` says which frame families exist and which
    fields are required;
  * `spec/protocol/golden.ndjson` is what the current Kotlin builders emit;
  * `Protocol.kt` and `protocol.md` still know every one of those families.

A missing family, a renamed type or a golden frame that stops matching the
schema fails here, before a host reads a frame it cannot parse.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

try:
    import jsonschema
except ImportError:  # pragma: no cover - CI installs it
    print("jsonschema is missing: python -m pip install jsonschema", file=sys.stderr)
    sys.exit(2)

ROOT = Path(__file__).resolve().parents[2]
SCHEMA = ROOT / "spec/protocol/schema.v1.json"
GOLDEN = ROOT / "spec/protocol/golden.ndjson"
PROTOCOL = ROOT / "apps/windows/sidecar/src/main/kotlin/com/hopa/sidecar/protocol/Protocol.kt"
DOC = ROOT / "docs/project/plan/windows/protocol.md"


def schema_types(node: object) -> set[str]:
    """Every string `const` in the schema is a frame type."""
    found: set[str] = set()
    if isinstance(node, dict):
        value = node.get("const")
        if isinstance(value, str):
            found.add(value)
        for child in node.values():
            found |= schema_types(child)
    elif isinstance(node, list):
        for child in node:
            found |= schema_types(child)
    return found


def main() -> int:
    schema = json.loads(SCHEMA.read_text(encoding="utf-8"))
    frames = [
        json.loads(line)
        for line in GOLDEN.read_text(encoding="utf-8").splitlines()
        if line.strip()
    ]
    problems: list[str] = []

    validator = jsonschema.Draft202012Validator(schema)
    for index, frame in enumerate(frames, start=1):
        for error in validator.iter_errors(frame):
            problems.append(f"golden line {index} ({frame.get('type')}): {error.message}")

    known = {value for value in schema_types(schema) if isinstance(value, str)}
    kotlin = PROTOCOL.read_text(encoding="utf-8")
    built = set(re.findall(r'put\("type",\s*"([a-z][a-z0-9._-]*)"\)', kotlin))
    doc = DOC.read_text(encoding="utf-8")

    for frame in frames:
        frame_type = frame.get("type")
        if frame_type not in built:
            problems.append(f"{frame_type}: no Protocol.kt builder emits this frame")
        if f"`{frame_type}`" not in doc:
            problems.append(f"{frame_type}: protocol.md does not document this family")

    for frame_type in sorted(built - known):
        problems.append(f"{frame_type}: Protocol.kt emits a family the schema does not list")

    if problems:
        print("protocol contract failures:", file=sys.stderr)
        for problem in problems:
            print(f"  - {problem}", file=sys.stderr)
        return 1

    print(
        f"protocol contract ok: {len(frames)} golden frame(s), "
        f"{len(built)} builder type(s), {len(known)} schema type(s)",
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
