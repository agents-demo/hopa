"""Thin, testable wrapper around the Android ``adb`` CLI.

Only what HOPA needs: target discovery, shell commands, raw stdout, pull. The
command construction is separate from process execution, so tests never need a
device (see ``test_adb.py``).
"""

from __future__ import annotations

import os
import shutil
import subprocess
from pathlib import Path
from typing import Any


class AdbError(RuntimeError):
    """adb is missing, refused a command, or the device is gone."""


def find_adb() -> str:
    """Locate ``adb``: HOPA_ADB -> ANDROID_HOME -> LOCALAPPDATA -> PATH."""
    override = os.environ.get("HOPA_ADB")
    if override:
        if Path(override).exists() or shutil.which(override):
            return override
        raise AdbError(f"HOPA_ADB is set but no executable exists at: {override}")

    name = "adb.exe" if os.name == "nt" else "adb"
    candidates: list[Path] = []
    for variable in ("ANDROID_HOME", "ANDROID_SDK_ROOT"):
        root = os.environ.get(variable)
        if root:
            candidates.append(Path(root) / "platform-tools" / name)
    local = os.environ.get("LOCALAPPDATA")
    if local:
        candidates.append(Path(local) / "Android" / "Sdk" / "platform-tools" / name)
    for candidate in candidates:
        if candidate.exists():
            return str(candidate)

    found = shutil.which("adb")
    if found:
        return found
    raise AdbError(
        "adb not found. Set HOPA_ADB to the executable, put platform-tools on "
        "PATH, or set ANDROID_HOME to the SDK root."
    )


class Adb:
    """One adb executable and, optionally, one target serial."""

    def __init__(
        self,
        serial: str = "",
        *,
        executable: str | None = None,
        runner: Any = None,
        timeout: float = 60.0,
    ) -> None:
        self.serial = serial
        self.executable = executable or find_adb()
        self._runner = runner or subprocess.run
        self.timeout = timeout

    def _args(self, *args: str) -> list[str]:
        base = [self.executable]
        if self.serial:
            base += ["-s", self.serial]
        return base + list(args)

    def _run(self, args: list[str]) -> bytes:
        completed = self._runner(
            self._args(*args),
            capture_output=True,
            timeout=self.timeout,
        )
        if completed.returncode != 0:
            error = completed.stderr.decode(errors="replace").strip()
            raise AdbError(error or f"adb {' '.join(args)} failed")
        return completed.stdout

    def devices(self) -> list[str]:
        output = self._run(["devices"]).decode(errors="replace")
        serials: list[str] = []
        for line in output.splitlines()[1:]:
            parts = line.split()
            if len(parts) >= 2 and parts[1] == "device":
                serials.append(parts[0])
        return serials

    def shell(self, command: str, *, timeout: float | None = None) -> str:
        completed = self._runner(
            self._args("shell", command),
            capture_output=True,
            timeout=timeout or self.timeout,
        )
        if completed.returncode != 0:
            error = completed.stderr.decode(errors="replace").strip()
            raise AdbError(error or f"adb shell failed: {command}")
        return completed.stdout.decode(errors="replace")

    def exec_out(self, command: str, *, timeout: float | None = None) -> bytes:
        completed = self._runner(
            self._args("exec-out", command),
            capture_output=True,
            timeout=timeout or self.timeout,
        )
        if completed.returncode != 0:
            error = completed.stderr.decode(errors="replace").strip()
            raise AdbError(error or f"adb exec-out failed: {command}")
        return completed.stdout

    def pull(self, remote: str, local: str) -> None:
        self._run(["pull", remote, str(local)])
