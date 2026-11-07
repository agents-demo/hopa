"""One-off: move the Harmony project to apps/harmony and fix paths."""

from __future__ import annotations

import re
import shutil
import subprocess
from pathlib import Path

ROOT = Path(".").resolve()


def replace(path: Path, pairs: list[tuple[str, str]]) -> None:
    if not path.exists():
        return
    text = path.read_text(encoding="utf-8")
    updated = text
    for old, new in pairs:
        updated = updated.replace(old, new)
    if updated != text:
        path.write_text(updated, encoding="utf-8", newline="\n")
        print("updated", path.relative_to(ROOT))


def main() -> None:
    (ROOT / "apps").mkdir(exist_ok=True)
    target = ROOT / "apps/harmony"
    if not target.exists():
        try:
            subprocess.run(["git", "mv", "app", "apps/harmony"], check=True)
        except subprocess.CalledProcessError:
            print("git mv failed, using Move-Item")
            shutil.move(str(ROOT / "app"), str(target))
    else:
        print("apps/harmony already exists, skipping the move")

    ps_pairs = [
        ("Join-Path $root 'app'", "Join-Path $root 'apps\\harmony'"),
        ("$root 'app\\entry", "$root 'apps\\harmony\\entry"),
        ("$app\\entry", "$app\\entry"),
    ]
    for name in ("build.ps1", "sign-app.ps1", "install-to-device.ps1", "run-tests.ps1"):
        replace(ROOT / "tools/scripts" / name, ps_pairs)

    sh_pairs = [
        ('APP="$ROOT/app"', 'APP="$ROOT/apps/harmony"'),
        ('app="$root/app"', 'app="$root/apps/harmony"'),
        ("$ROOT/app/entry", "$ROOT/apps/harmony/entry"),
    ]
    for name in ("build.sh", "sign-app.sh", "install-to-device.sh", "run-tests.sh"):
        replace(ROOT / "tools/scripts" / name, sh_pairs)

    replace(
        ROOT / "tools/scripts/build-app-catalog.py",
        [
            ('TARGET = ROOT / "app" / "entry"', 'TARGET = ROOT / "apps" / "harmony" / "entry"'),
        ],
    )
    replace(
        ROOT / "tools/scripts/test_app_catalog.py",
        [
            ('ROOT / "app" / "entry"', 'ROOT / "apps" / "harmony" / "entry"'),
        ],
    )

    replace(
        ROOT / ".github/workflows/ci.yml",
        [
            ("          cd app\n", "          cd apps/harmony\n"),
            ("path: app/entry/build/", "path: apps/harmony/entry/build/"),
        ],
    )

    # docs and root files: only rewrite the known app sub-paths
    app_re = re.compile(r"(?<![\w/.-])app/(?=(core|entry|capabilities|AppScope|build-profile|oh-package|hvigor|src))")
    skip = {ROOT / "docs/architecture/target-structure.md"}
    for path in [ROOT / "README.md", ROOT / "CONTRIBUTING.md", ROOT / "CLAUDE.md"] + list((ROOT / "docs").rglob("*.md")):
        if not path.exists() or path.resolve() in skip:
            continue
        text = path.read_text(encoding="utf-8")
        updated = app_re.sub("apps/harmony/", text)
        updated = updated.replace("cd app\n", "cd apps/harmony\n")
        updated = updated.replace("`app/", "`apps/harmony/")
        if updated != text:
            path.write_text(updated, encoding="utf-8", newline="\n")
            print("docs:", path.relative_to(ROOT))


if __name__ == "__main__":
    main()
