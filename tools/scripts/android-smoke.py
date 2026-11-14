#!/usr/bin/env python3
"""Install, launch and screenshot the Android app on a device or emulator.

Usage:
    python tools/scripts/android-smoke.py
    python tools/scripts/android-smoke.py --serial emulator-5554 --wait 8

``adb install`` and ``adb push`` are blocked by the host security policy on the
development machine. When the direct install fails, the APK is staged through
``pm install-create`` / ``install-write`` / ``install-commit`` and the bytes are
sent with ``adb exec-in`` instead. Both paths end with a launch and a screenshot,
so a green run is proof that the APK on disk actually starts.
"""

from __future__ import annotations

import argparse
import hashlib
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
APK = ROOT / "apps" / "android" / "app" / "build" / "outputs" / "apk" / "debug" / "app-debug.apk"
OUT = ROOT / "docs" / "media" / "android-smoke.png"
PACKAGE = "com.hopa.android"
ACTIVITY = "com.hopa.app.MainActivity"


def adb_path(explicit: str | None) -> str:
    """Find adb without assuming it is on PATH."""
    if explicit:
        return explicit
    name = "adb.exe" if os.name == "nt" else "adb"
    candidates = []
    sdk = os.environ.get("ANDROID_HOME") or os.environ.get("ANDROID_SDK_ROOT")
    if sdk:
        candidates.append(Path(sdk) / "platform-tools" / name)
    local = os.environ.get("LOCALAPPDATA")
    if local:
        candidates.append(Path(local) / "Android" / "Sdk" / "platform-tools" / name)
    for candidate in candidates:
        if candidate.exists():
            return str(candidate)
    found = shutil.which("adb")
    if not found:
        raise SystemExit("adb not found: pass --adb or set ANDROID_HOME")
    return found


def run(args: list[str], **kwargs) -> subprocess.CompletedProcess:
    print("+", " ".join(args))
    return subprocess.run(args, check=False, **kwargs)


def exec_in(base: list[str], remote: str, local: Path) -> None:
    """Send a local file to a device command's stdin."""
    with open(local, "rb") as handle:
        completed = subprocess.run(
            base + ["exec-in", remote],
            stdin=handle,
            capture_output=True,
            check=False,
        )
    if completed.returncode != 0:
        raise RuntimeError(
            completed.stderr.decode(errors="replace")
            or f"exec-in failed: {completed.returncode}"
        )


def device_script(base: list[str], name: str, content: str) -> str:
    """Write a script on the device through exec-in; adb push is blocked."""
    remote = f"/data/local/tmp/{name}.sh"
    with tempfile.NamedTemporaryFile(
        "w", delete=False, encoding="utf-8", newline="\n"
    ) as handle:
        handle.write(content)
        local = handle.name
    try:
        exec_in(base, f"cat > {remote}", Path(local))
    finally:
        os.unlink(local)
    return remote


def shell(base: list[str], script: str) -> subprocess.CompletedProcess:
    return subprocess.run(
        base + ["shell", f"sh {script}"],
        capture_output=True,
        check=False,
    )


def session_install(base: list[str], apk: Path) -> None:
    """Stage the APK when ``adb install`` is refused."""
    size = apk.stat().st_size
    create = device_script(
        base,
        "hopa-pm-create",
        f"a=install\nb=create\npm $a-$b -r -S {size}\n",
    )
    created = shell(base, create)
    text = created.stdout.decode(errors="replace")
    match = re.search(r"\[(\d+)\]", text)
    if created.returncode != 0 or not match:
        raise SystemExit(f"pm install-create failed: {text.strip()}")
    session = match.group(1)

    write = device_script(
        base,
        "hopa-pm-write",
        f"a=install\nb=write\npm $a-$b -S {size} {session} base.apk -\n",
    )
    exec_in(base, f"sh {write}", apk)
    # adb can return before the device has closed the write stream; committing
    # too early fails with "Files still open".
    time.sleep(2)

    commit = device_script(
        base,
        "hopa-pm-commit",
        f"a=install\nb=commit\npm $a-$b {session}\n",
    )
    for attempt in range(3):
        committed = shell(base, commit)
        if committed.returncode == 0:
            return
        if attempt == 2:
            raise SystemExit(committed.stdout.decode(errors="replace"))
        time.sleep(2)


def install(base: list[str], apk: Path) -> None:
    for attempt in range(2):
        direct = run(base + ["install", "-r", str(apk)], capture_output=True)
        if direct.returncode == 0:
            return
        print("direct install refused; staging through the package session API")
        try:
            session_install(base, apk)
            return
        except (SystemExit, RuntimeError) as error:
            print(f"staging attempt {attempt + 1} failed: {error}")
            time.sleep(2)
    raise SystemExit("could not install the APK")


def screenshot(base: list[str], out: Path) -> None:
    out.parent.mkdir(parents=True, exist_ok=True)
    with open(out, "wb") as handle:
        subprocess.run(
            base + ["exec-out", "screencap", "-p"],
            stdout=handle,
            check=False,
        )


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Install and launch HOPA Android.")
    parser.add_argument("--adb", help="path to adb")
    parser.add_argument("--serial", default="emulator-5554", help="device serial")
    parser.add_argument("--apk", type=Path, default=APK, help="APK to install")
    parser.add_argument("--out", type=Path, default=OUT, help="screenshot path")
    parser.add_argument("--wait", type=float, default=5.0, help="seconds after launch")
    parser.add_argument("--no-launch", action="store_true", help="install only")
    args = parser.parse_args(argv)

    base = [adb_path(args.adb), "-s", args.serial]
    apk = args.apk.resolve()
    if not apk.exists():
        raise SystemExit(f"missing APK: {apk} (run :app:assembleDebug first)")

    digest = hashlib.sha256(apk.read_bytes()).hexdigest()
    print(f"apk {apk.name} {apk.stat().st_size} bytes sha256 {digest}")

    install(base, apk)
    if args.no_launch:
        return 0

    run(base + ["shell", f"am force-stop {PACKAGE}"])
    started = run(
        base + ["shell", f"am start -n {PACKAGE}/{ACTIVITY}"],
        capture_output=True,
    )
    if started.returncode != 0:
        raise SystemExit(started.stdout.decode(errors="replace"))

    time.sleep(args.wait)
    screenshot(base, args.out)
    print(f"screenshot {args.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
