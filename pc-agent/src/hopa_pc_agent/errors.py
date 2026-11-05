from __future__ import annotations


class HopaError(RuntimeError):
    """Base class for HOPA PC-agent errors."""


class HdcError(HopaError):
    """Raised when an hdc command fails or hdc cannot be found."""

    def __init__(
        self,
        message: str,
        *,
        command: list[str] | None = None,
        stdout: str = "",
        stderr: str = "",
        returncode: int | None = None,
    ) -> None:
        super().__init__(message)
        self.command = command
        self.stdout = stdout
        self.stderr = stderr
        self.returncode = returncode


class LayoutError(HopaError):
    """Raised when a uitest layout dump cannot be parsed."""


class DeviceError(HopaError):
    """Raised when a device operation cannot be completed."""
