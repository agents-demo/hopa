"""The device boundary the bridge API is allowed to see.

Every platform adapter implements this. The HTTP handlers import this Protocol,
never `hdc` and never `Device`, so adding Android or Windows is a new adapter
rather than a change to the API (ADR-0007, R6 in docs/plan/refactor).
"""

from __future__ import annotations

from typing import Any, Protocol, runtime_checkable


@runtime_checkable
class DevicePort(Protocol):
    """One device, whatever the platform underneath."""

    serial: str
    platform: str

    def dump_layout(self, *, include_attrs: bool = False, timeout: float | None = None) -> Any: ...

    def foreground(self) -> str: ...

    def tap(self, x: int, y: int) -> None: ...

    def swipe(
        self, from_x: int, from_y: int, to_x: int, to_y: int, *, velocity: int = 600
    ) -> None: ...

    def type_text(self, text: str, *, x: int | None = None, y: int | None = None) -> None: ...

    def press_key(self, key: str) -> None: ...

    def press_key_many(self, key: str, count: int) -> None: ...

    def launch(self, bundle: str, ability: str = "", raise_window: bool = False) -> None: ...

    def stop(self, bundle: str) -> None: ...

    def shell(self, command: str) -> str:
        """Run a device shell command (used for screenshots); platform specific."""

    def pull(self, remote: str, local: str) -> None:
        """Copy a file off the device (used for screenshots)."""
