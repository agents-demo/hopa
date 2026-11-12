#!/usr/bin/env python3
"""Fail when the repository grows a folder that does not belong at its level.

Rules (ADR-0007):

1. Top level is exactly `apps`, `services`, `evals`, `contracts`, `tools`, `docs`
   plus `.github`. A new top-level folder is a decision, not an accident, so it
   has to be added here and in the ADR.
2. `harness/` must not exist: it was renamed to `evals/`.
3. No junk drawers anywhere: `utils`, `helpers`, `common`, `misc`, `shared`.

Generated and vendor directories are skipped, and dot-directories are ignored
except `.github`, so a local `.venv`, `.idea` or `.pytest_cache` cannot fail CI.
"""

from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TOP_LEVEL = {
    "apps",
    "services",
    "packages",
    "evals",
    "contracts",
    "tools",
    "docs",
    ".github",
}
JUNK = {"utils", "helpers", "common", "misc", "shared"}
SKIP = {
    "build",
    "oh_modules",
    "node_modules",
    "__pycache__",
    ".git",
    ".venv",
    "venv",
    ".idea",
    ".hvigor",
    ".tools",
    ".pytest_cache",
    ".ruff_cache",
    ".hopa",
    "results",
    "dist",
    "site-packages",
    "*.egg-info",
}


def walk(base: Path):
    for path in sorted(base.iterdir()):
        if not path.is_dir():
            continue
        if path.name in SKIP or path.name.endswith(".egg-info"):
            continue
        if path.name.startswith(".") and path.name != ".github":
            continue
        yield path
        yield from walk(path)


def check(base: Path = ROOT) -> list[str]:
    problems: list[str] = []

    for path in walk(base):
        if path.parent != base:
            continue
        if path.name not in TOP_LEVEL:
            problems.append(f"{path.name}/ is not an allowed top-level folder")

    if (base / "harness").exists():
        problems.append("harness/ still exists; it is evals/ now (ADR-0007)")

    if (base / "packages").exists():
        problems.append("packages/ is gone; shared service code lives in services/wire (ADR-0012)")

    for path in walk(base):
        if path.name.lower() in JUNK:
            problems.append(
                f"{path.relative_to(base)}: junk-drawer folder name '{path.name}'"
            )

    return problems


def main() -> int:
    problems = check()
    for problem in problems:
        print(f"FAIL  {problem}")
    print(f"{len(problems)} tree violation(s)")
    return 1 if problems else 0


if __name__ == "__main__":
    raise SystemExit(main())
