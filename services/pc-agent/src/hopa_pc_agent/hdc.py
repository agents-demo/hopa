"""Thin, testable wrapper around the HarmonyOS ``hdc`` CLI.

Only the pieces HOPA needs are implemented: target discovery, shell commands,
file transfer, install/uninstall. Command construction is kept separate from
process execution so it can be unit-tested without a device.
"""

from __future__ import annotations

import os
import shutil
import subprocess
from dataclasses import dataclass
from pathlib import Path

from .errors import HdcError

_WINDOWS_CANDIDATES = (
    Path(r"C:\HarmonyOS\command-line-tools\sdk\default\openharmony\toolchains\hdc.exe"),
    Path(r"C:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe"),
    Path(r"C:\Program Files\Huawei\DevEco Studio\tools\sdk\default\openharmony\toolchains\hdc.exe"),
)

_POSIX_CANDIDATES = (
    Path("/opt/command-line-tools/sdk/default/openharmony/toolchains/hdc"),
    Path("/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc"),
    Path.home() / "Library/Huawei/Sdk/openharmony/toolchains/hdc",
)

# Lines from `hdc list targets` that are not actual targets.
_TARGET_NOISE = (
    "[empty]",
    "empty",
    "no device",
    "no target",
    "list targets",
    "error",
    "failed",
    "connect",
    "daemon",
    "waiting",
)


def find_hdc() -> str:
    """Locate the ``hdc`` executable.

    Order: ``HOPA_HDC`` -> ``HOPA_CLT_HOME`` -> common install paths -> PATH.
    """
    override = os.environ.get("HOPA_HDC")
    if override:
        if Path(override).exists() or shutil.which(override):
            return override
        raise HdcError(f"HOPA_HDC is set but no executable exists at: {override}")

    candidates: list[Path] = []
    clt = os.environ.get("HOPA_CLT_HOME") or os.environ.get("COMMANDLINE_TOOLS_HOME")
    if clt:
        candidates.extend(
            [
                Path(clt) / "sdk/default/openharmony/toolchains/hdc.exe",
                Path(clt) / "sdk/default/openharmony/toolchains/hdc",
            ]
        )
    candidates.extend(_WINDOWS_CANDIDATES)
    candidates.extend(_POSIX_CANDIDATES)

    for candidate in candidates:
        if candidate.exists():
            return str(candidate)

    found = shutil.which("hdc")
    if found:
        return found

    raise HdcError(
        "hdc not found. Put the Command Line Tools toolchains directory on PATH, "
        "set HOPA_HDC to the executable, or set HOPA_CLT_HOME to the tools root."
    )


def parse_targets(text: str) -> list[str]:
    """Parse ``hdc list targets`` output into a list of serials/addresses."""
    targets: list[str] = []
    for raw in text.splitlines():
        line = raw.strip()
        if not line:
            continue
        lowered = line.lower()
        if any(noise in lowered for noise in _TARGET_NOISE):
            continue
        if line not in targets:
            targets.append(line)
    return targets


@dataclass
class HdcResult:
    stdout: str
    stderr: str
    returncode: int


class Hdc:
    """Run hdc commands against a target device."""

    def __init__(
        self,
        hdc_path: str | None = None,
        target: str | None = None,
        timeout: float = 60.0,
    ) -> None:
        # Resolved lazily so the MCP server can start even before hdc exists.
        self.hdc_path = hdc_path
        self.target = target
        self.timeout = timeout

    def _resolve(self) -> str:
        if self.hdc_path is None:
            self.hdc_path = find_hdc()
        return self.hdc_path

    def command(self, *args: str) -> list[str]:
        """Build the full command line (without executing it)."""
        cmd = [self._resolve()]
        if self.target:
            cmd.extend(["-t", self.target])
        cmd.extend(str(arg) for arg in args)
        return cmd

    def run(
        self,
        *args: str,
        timeout: float | None = None,
        check: bool = True,
    ) -> HdcResult:
        cmd = self.command(*args)
        effective_timeout = self.timeout if timeout is None else timeout
        try:
            proc = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                encoding="utf-8",
                errors="replace",
                timeout=effective_timeout,
            )
        except FileNotFoundError as exc:
            raise HdcError(f"hdc executable not found: {self._resolve()}") from exc
        except subprocess.TimeoutExpired as exc:
            raise HdcError(f"hdc timed out after {effective_timeout}s: {' '.join(cmd)}") from exc

        result = HdcResult(proc.stdout or "", proc.stderr or "", proc.returncode)
        if check and result.returncode != 0:
            detail = result.stderr.strip() or result.stdout.strip()
            raise HdcError(
                f"hdc exited with {result.returncode}: {' '.join(cmd)}"
                + (f"\n{detail}" if detail else ""),
                command=cmd,
                stdout=result.stdout,
                stderr=result.stderr,
                returncode=result.returncode,
            )
        return result

    # -- convenience helpers -------------------------------------------------

    def shell(self, command: str, *, check: bool = True, timeout: float | None = None) -> str:
        return self.run("shell", command, check=check, timeout=timeout).stdout

    def list_targets(self, timeout: float | None = None) -> list[str]:
        result = self.run("list", "targets", timeout=timeout, check=False)
        return parse_targets(result.stdout + "\n" + result.stderr)

    def file_recv(self, remote: str, local: str | Path, *, timeout: float | None = None) -> Path:
        destination = Path(local)
        destination.parent.mkdir(parents=True, exist_ok=True)
        self.run("file", "recv", str(remote), str(destination), timeout=timeout)
        return destination

    def file_send(self, local: str | Path, remote: str, *, timeout: float | None = None) -> None:
        self.run("file", "send", str(local), str(remote), timeout=timeout)

    def install(self, hap: str | Path, *, timeout: float | None = None) -> str:
        return self.run("install", "-r", str(hap), timeout=timeout).stdout

    def uninstall(self, bundle: str, *, timeout: float | None = None) -> str:
        return self.run("uninstall", bundle, timeout=timeout).stdout
