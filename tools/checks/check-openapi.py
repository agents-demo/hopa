#!/usr/bin/env python3
"""Fail when the bridge code and contracts/openapi/bridge.v1.yaml disagree.

The bridge is written as a chain of `self.path == "/x"` checks, so the routes are
read from the source rather than from a framework. Two directions are checked:

- every literal route in `bridge.py` / `bridge_pool.py` is in the spec;
- every path in the spec is handled by one of those files (or is a declared
  routing prefix such as `/d/{serial}`).

A `/prefix/` route (e.g. `/images/`) matches any spec path that begins with it.
"""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SPEC = ROOT / "contracts/openapi/bridge.v1.yaml"
SOURCES = (
    ROOT / "services/bridge/src/hopa_bridge/bridge.py",
    ROOT / "services/bridge/src/hopa_bridge/bridge_pool.py",
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
        if route in declared_prefix or any(
            route.startswith(p) for p in declared_prefix
        ):
            continue
        missing_from_code.append(route)
    return missing_from_spec, missing_from_code


def main() -> int:
    if not SPEC.exists():
        print(f"FAIL  missing spec: {SPEC.relative_to(ROOT)}")
        return 1
    literal, prefix = code_routes(SOURCES)
    spec, declared_prefix = spec_routes(SPEC)
    missing_from_spec, missing_from_code = compare(
        literal, prefix, spec, declared_prefix
    )

    for route in missing_from_spec:
        print(f"FAIL  handled in code, absent from the spec: {route}")
    for route in missing_from_code:
        print(f"FAIL  in the spec, not handled in code: {route}")
    if missing_from_spec or missing_from_code:
        print(
            f"{len(missing_from_spec)} route(s) missing from the spec, "
            f"{len(missing_from_code)} spec path(s) with no handler"
        )
        return 1
    print(
        f"ok {len(spec)} spec path(s), {len(literal)} code route(s), "
        f"{len(prefix)} prefix route(s)"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
