#!/usr/bin/env python3
"""Check the cross-client observation hash vector.

The observation hash is defined in docs/reference/contracts/observation.md:
sha256 over canonical JSON (sorted keys, no whitespace, UTF-8) of the projection
``{displayId, windowId, rotation, width, height, focus, text, tree}``, prefixed
``sha256:``. Any client that wants its records compared with another must
produce the same hash for this fixture (ADR-0018).
"""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
FIXTURES = ROOT / "contracts" / "fixtures" / "observation-hash.json"
SCHEMAS = ROOT / "contracts" / "schemas"


def _validator():
    from jsonschema import Draft202012Validator
    from referencing import Registry, Resource

    registry = Registry()
    document = json.loads((SCHEMAS / "observation.schema.json").read_text(encoding="utf-8"))
    registry = registry.with_resource(
        "https://github.com/agents-demo/hopa/schemas/observation.schema.json",
        Resource.from_contents(document),
    )
    return Draft202012Validator(document, registry=registry)


def projection(observation: dict) -> dict:
    size = observation.get("screenSize") or {}
    return {
        "displayId": observation.get("displayId", 0),
        "windowId": observation.get("windowId", "active"),
        "rotation": observation.get("rotation", 0),
        "width": size.get("width", 0),
        "height": size.get("height", 0),
        "focus": observation.get("focus", ""),
        "text": observation.get("text", ""),
        "tree": observation.get("tree"),
    }


def digest(observation: dict) -> str:
    blob = json.dumps(
        projection(observation), ensure_ascii=False, sort_keys=True, separators=(",", ":")
    )
    return "sha256:" + hashlib.sha256(blob.encode("utf-8")).hexdigest()


def check(path: Path = FIXTURES) -> list[str]:
    problems: list[str] = []
    if not path.exists():
        return [f"missing fixtures: {path.relative_to(ROOT)}"]
    document = json.loads(path.read_text(encoding="utf-8"))
    if document.get("schemaVersion") != "1":
        problems.append("observation-hash: schemaVersion must be '1'")
    cases = document.get("cases")
    if not isinstance(cases, list) or not cases:
        return problems + ["observation-hash: no cases"]

    validator = _validator()
    for case in cases:
        name = case.get("name") or "<unnamed>"
        observation = case.get("observation")
        if not isinstance(observation, dict):
            problems.append(f"{name}: missing observation")
            continue
        problems += [
            f"{name}: observation {error.message}"
            for error in validator.iter_errors(observation)
        ]
        expected = case.get("hash")
        actual = digest(observation)
        if expected != actual:
            problems.append(f"{name}: hash {expected!r}, computed {actual!r}")
        if observation.get("hash") != actual:
            problems.append(f"{name}: observation.hash does not match the digest")
    return problems


def main() -> int:
    problems = check()
    for problem in problems:
        print(f"FAIL  {problem}")
    print(f"{len(problems)} observation hash problem(s)")
    return 1 if problems else 0


if __name__ == "__main__":
    raise SystemExit(main())
