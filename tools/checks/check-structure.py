#!/usr/bin/env python3
"""Report (and optionally fail) structural drift.

Rules:
1. core/src/main must not import an OS kit (core stays pure).
2. A capability must not import another capability.
3. Only package roots may contain an Index.ets barrel.
4. File-size budgets: pages 400, services 250, core files 250.
   Without --strict the command only reports; CI can raise the bar later.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
APP = ROOT / "apps/harmony"

BUDGETS = {
    "pages": 400,
    "services": 250,
    "core": 250,
}
IMPORT = re.compile(r"from\s+'([^']+)'")
KIT = re.compile(r"from\s+'@kit\.")
CAPABILITY = re.compile(r"from\s+'@hopa/capability-([a-z-]+)")


def ets_files(base: Path) -> list[Path]:
    return [
        path
        for path in base.rglob("*.ets")
        if "build" not in path.parts
        and ".test" not in path.parts
        and "oh_modules" not in path.parts
    ]


def check_core(errors: list[str]) -> None:
    for path in ets_files(APP / "core/src/main"):
        text = path.read_text(encoding="utf-8")
        if KIT.search(text):
            errors.append(f"{path.relative_to(ROOT)}: core imports an OS kit")
        # core must not depend on a capability either
        if CAPABILITY.search(text):
            errors.append(f"{path.relative_to(ROOT)}: core imports a capability")


def check_capabilities(errors: list[str]) -> None:
    root = APP / "capabilities"
    for module in sorted(path for path in root.iterdir() if path.is_dir()):
        own = module.name
        for path in ets_files(module):
            text = path.read_text(encoding="utf-8")
            for imported in CAPABILITY.findall(text):
                if imported != own:
                    errors.append(
                        f"{path.relative_to(ROOT)}: capability '{own}' imports '{imported}'"
                    )


def check_barrels(errors: list[str]) -> None:
    allowed = {
        APP / "core/Index.ets",
        APP / "entry/src/main/ets/pages/Index.ets",  # ArkUI entry page, not a barrel
    } | {path / "Index.ets" for path in (APP / "capabilities").iterdir() if path.is_dir()}
    for path in APP.rglob("Index.ets"):
        if path in allowed:
            continue
        if any(part in {"build", "oh_modules", ".preview", ".test"} for part in path.parts):
            continue
        errors.append(f"{path.relative_to(ROOT)}: Index.ets outside a package root")


def size_report() -> tuple[list[str], list[str]]:
    warnings: list[str] = []
    violations: list[str] = []
    areas = [
        ("pages", APP / "entry/src/main/ets/pages", BUDGETS["pages"]),
        ("services", APP / "entry/src/main/ets/services", BUDGETS["services"]),
        ("core", APP / "core/src/main", BUDGETS["core"]),
    ]
    for name, base, budget in areas:
        for path in ets_files(base):
            if "generated" in path.parts or path.name == "AppCatalog.ets":
                continue
            lines = len(path.read_text(encoding="utf-8").splitlines())
            relative = path.relative_to(ROOT)
            if lines > budget * 2:
                violations.append(f"{relative}: {lines} lines (limit {budget}, hard {budget * 2})")
            elif lines > budget:
                warnings.append(f"{relative}: {lines} lines (limit {budget})")
    return warnings, violations


def main(argv: list[str]) -> int:
    strict = "--strict" in argv
    errors: list[str] = []
    check_core(errors)
    check_capabilities(errors)
    check_barrels(errors)
    warnings, violations = size_report()

    for line in warnings:
        print(f"WARN  {line}")
    for line in violations:
        print(f"FAIL  {line}")
    for line in errors:
        print(f"FAIL  {line}")

    hard_fail = bool(errors) or (strict and bool(violations))
    print(
        f"{len(errors)} rule violation(s), {len(violations)} hard size violation(s), "
        f"{len(warnings)} size warning(s)"
    )
    return 1 if hard_fail else 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
