#!/usr/bin/env python3
"""Fail when render.yaml points at something that no longer exists.

The blueprint is deployment code that no test imports: a renamed folder or module
breaks the live relay and nothing local notices. This check reads the same file
Render reads and verifies:

- every ``./path`` in a build or start command exists;
- a ``python -m <module>`` start command resolves to a package in this repo;
- the health check path is absolute.

It does not run the commands; `docs/operations/repo-split.md` and the plan's R4
gates cover the local command proof.
"""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BLUEPRINT = ROOT / "render.yaml"
PATH_TOKEN = re.compile(r"(\./[^\s\"']+)")
MODULE_TOKEN = re.compile(r"python\s+-m\s+([A-Za-z_][\w.]*)")


def module_exists(name: str) -> bool:
    package = name.replace(".", "/")
    for base in (ROOT / "services", ROOT / "packages"):
        if (base / package / "__init__.py").exists() or (
            base / f"{package}.py"
        ).exists():
            return True
        for candidate in base.glob("*/src"):
            if (candidate / package / "__init__.py").exists():
                return True
    return False


def check(path: Path = BLUEPRINT, root: Path = ROOT) -> list[str]:
    import yaml

    problems: list[str] = []
    if not path.exists():
        return [f"missing blueprint: {path.name}"]
    document = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    services = document.get("services") or []
    if not services:
        problems.append("render.yaml declares no services")
    for service in services:
        name = service.get("name", "<unnamed>")
        for key in ("buildCommand", "startCommand"):
            command = str(service.get(key, ""))
            for token in PATH_TOKEN.findall(command):
                candidate = (root / token[2:]).resolve()
                if not candidate.exists():
                    problems.append(f"{name}: {key} references a missing path: {token}")
            for module in MODULE_TOKEN.findall(command):
                if not module_exists(module):
                    problems.append(f"{name}: {key} starts an unknown module: {module}")
        health = str(service.get("healthCheckPath", ""))
        if health and not health.startswith("/"):
            problems.append(f"{name}: healthCheckPath must be absolute, got {health!r}")
    return problems


def main() -> int:
    problems = check()
    for problem in problems:
        print(f"FAIL  {problem}")
    print(f"{len(problems)} render problem(s)")
    return 1 if problems else 0


if __name__ == "__main__":
    raise SystemExit(main())
