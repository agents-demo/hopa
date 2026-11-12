#!/usr/bin/env python3
"""Fail when a service's routes and its OpenAPI file disagree.

Each target pairs one spec with the modules that dispatch its paths. Two
directions are checked:

- every literal route in the code is in the spec;
- every path in the spec has a handler (or is a declared routing/prefix route).

A `/prefix/` route (e.g. `/images/`) matches any spec path with that prefix.
A routing prefix such as `/d/{serial}` is declared in `x-path-prefixes`.
"""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

TARGETS = (
    (
        ROOT / "contracts/openapi/bridge.v1.yaml",
        (
            ROOT / "services/bridge/src/hopa_bridge/bridge.py",
            ROOT / "services/bridge/src/hopa_bridge/bridge_pool.py",
        ),
    ),
    (
        ROOT / "contracts/openapi/relay.v1.yaml",
        (ROOT / "services/relay/src/hopa_relay/relay_server.py",),
    ),
)

LITERAL = re.compile(r'self\.path == "([^"]+)"')
PREFIX = re.compile(r'self\.path\.startswith\("([^"]+)"\)')


def code_routes(sources: tuple[Path, ...]) -> tuple[set[str], set[str]]:
    literals: set[str] = set()
    prefixes: set[str] = set()
    for path in sources:
        text = path.read_text(encoding="utf-8")
        literals.update(LITERAL.findall(text))
        prefixes.update(PREFIX.findall(text))
    return literals, prefixes


def spec_routes(spec: Path) -> tuple[set[str], set[str]]:
    import yaml

    document = yaml.safe_load(spec.read_text(encoding="utf-8"))
    paths = set(document.get("paths") or {})
    declared_prefixes = set(document.get("x-path-prefixes") or [])
    return paths, declared_prefixes


def compare(
    literal: set[str], prefix: set[str], spec: set[str], declared_prefix: set[str]
) -> tuple[list[str], list[str]]:
    missing_from_spec = sorted(
        route
        for route in literal
        if route not in spec
        and not any(route.startswith(p) and p != "/" for p in declared_prefix)
    )
    missing_from_code: list[str] = []
    for route in sorted(spec):
        if route in literal:
            continue
        if any(route.startswith(p) for p in prefix):
            continue
        if route in declared_prefix or any(route.startswith(p) for p in declared_prefix):
            continue
        missing_from_code.append(route)
    return missing_from_spec, missing_from_code


def main() -> int:
    failures = 0
    for spec_path, sources in TARGETS:
        if not spec_path.exists():
            print(f"FAIL  missing spec: {spec_path.relative_to(ROOT)}")
            failures += 1
            continue
        literal, prefix = code_routes(sources)
        spec, declared_prefix = spec_routes(spec_path)
        missing_from_spec, missing_from_code = compare(literal, prefix, spec, declared_prefix)

        for route in missing_from_spec:
            print(f"FAIL  {spec_path.name}: handled in code, absent from the spec: {route}")
        for route in missing_from_code:
            print(f"FAIL  {spec_path.name}: in the spec, not handled in code: {route}")
        if missing_from_spec or missing_from_code:
            failures += 1
            continue
        print(
            f"ok {spec_path.name}: {len(spec)} spec path(s), "
            f"{len(literal)} code route(s), {len(prefix)} prefix route(s)"
        )
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
