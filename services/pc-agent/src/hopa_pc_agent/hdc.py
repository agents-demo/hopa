"""Thin, testable wrapper around the HarmonyOS ``hdc`` CLI.

Only the pieces HOPA needs are implemented: target discovery, shell commands,
file transfer, install/uninstall. Command construction is kept separate from
process execution so it can be unit-tested without a device.
"""

from __future__ import annotations

import os
import shutil
import subprocess
import time
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

    def _is_network_target(self) -> bool:
        # A USB target is a serial such as 63Q0226113049275. A tunneled or
        # wireless target is host:port.
        return bool(self.target) and ":" in str(self.target)

    @staticmethod
    def _needs_reconnect(stdout: str, stderr: str) -> bool:
        text = f"{stdout}\n{stderr}".lower()
        return (
            "device not found or connected" in text
            or "connect-key" in text
            or "connect failed" in text
            or "session is dead" in text
        )

    @staticmethod
    def _session_is_dead(stdout: str, stderr: str) -> bool:
        return "session is dead" in f"{stdout}\n{stderr}".lower()

    def _reset_hdc_server(self) -> None:
        """Clear a dead target session. Only used for a network target.

        ``hdc tconn`` returns "already connected" while the session is dead, so
        a full server reset is the only local remedy. This briefly drops other
        hdc targets; they reconnect through their own tconn/USB path.
        """
        exe = self._resolve()
        for verb in ("kill", "start"):
            try:
                subprocess.run(
                    [exe, verb],
                    capture_output=True,
                    text=True,
                    encoding="utf-8",
                    errors="replace",
                    timeout=10,
                )
            except (OSError, subprocess.TimeoutExpired):
                return

    def _ensure_target(self) -> None:
        """Re-attach an idle TCP target. hdc drops it after a quiet period."""
        if not self._is_network_target():
            return
        cmd = [self._resolve(), "tconn", str(self.target)]
        try:
            subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                encoding="utf-8",
                errors="replace",
                timeout=8,
            )
        except (OSError, subprocess.TimeoutExpired):
            # The retry will surface the real failure.
            pass

    def recover(self) -> bool:
        """Hard-reset the local hdc server and re-attach a TCP target.

        A tunneled target can outlive its session: ``tconn`` reports "already
        connected" while the next command returns an empty result instead of
        an error. Restarting the local server is the only reliable reset.
        USB targets are left alone. Returns True when a reset was performed.
        """
        if not self._is_network_target():
            return False
        self._reset_hdc_server()
        self._ensure_target()
        # Give the freshly started server a moment to accept the target.
        time.sleep(0.4)
        return True

    def _execute(self, cmd: list[str], timeout: float) -> HdcResult:
        try:
            proc = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                encoding="utf-8",
                errors="replace",
                timeout=timeout,
            )
        except FileNotFoundError as exc:
            raise HdcError(f"hdc executable not found: {self._resolve()}") from exc
        except subprocess.TimeoutExpired as exc:
            raise HdcError(f"hdc timed out after {timeout}s: {' '.join(cmd)}") from exc
        return HdcResult(proc.stdout or "", proc.stderr or "", proc.returncode)

    def run(
        self,
        *args: str,
        timeout: float | None = None,
        check: bool = True,
        ensure: bool = True,
    ) -> HdcResult:
        cmd = self.command(*args)
        effective_timeout = self.timeout if timeout is None else timeout
        result = self._execute(cmd, effective_timeout)
        if (
            ensure
            and self._is_network_target()
            and self._needs_reconnect(result.stdout, result.stderr)
        ):
            # The tunnel keeps the target registered but hdc marks it offline
            # after a quiet period. tconn is cheap; replaying the command once
            # makes `observe` and `foreground` survive that state.
            self._ensure_target()
            result = self._execute(cmd, effective_timeout)
            if self._session_is_dead(result.stdout, result.stderr):
                # The phone was suspended long enough for the hdc session to
                # die. tconn says "already connected"; reset the local server,
                # re-attach, and replay once more.
                self._reset_hdc_server()
                self._ensure_target()
                result = self._execute(cmd, effective_timeout)
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
