#!/usr/bin/env python3
"""Smoke the Windows client: one turn, the conversation list, a screenshot.

Local-only: it needs a Windows desktop with the sidecar built. The CI jobs do
not run it.

    python tools/scripts/windows-smoke.py
"""

from __future__ import annotations

import subprocess
import sys
import tempfile
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
EXE = ROOT / "apps" / "windows" / "Hopa.Windows" / "bin" / "Debug" / "net8.0-windows" / "Hopa.Windows.exe"
SHOT = ROOT / "docs" / "media" / "windows-w1.png"


def run(*args: str, timeout: int = 180) -> str:
    out = Path(tempfile.gettempdir()) / f"hopa-windows-{uuid.uuid4().hex}.txt"
    command = [str(EXE), *args, "--out", str(out)]
    subprocess.run(command, check=True, timeout=timeout)
    text = out.read_text(encoding="utf-8")
    out.unlink(missing_ok=True)
    return text


def main() -> int:
    if not EXE.exists():
        print(f"missing {EXE}; run: dotnet build -c Debug")
        return 2

    goal = f"windows smoke {uuid.uuid4().hex[:6]}"
    turn = run("--turn", goal, "--shot", str(SHOT))
    if "HOPA:" not in turn or "Sidecar answered" not in turn:
        print("turn failed:\n" + turn)
        return 1

    listed = run("--list")
    if "|" not in listed:
        print("the conversation list is empty:\n" + listed)
        return 1

    print("turn: ok")
    print("list: ok")
    print(f"screenshot: {SHOT}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
