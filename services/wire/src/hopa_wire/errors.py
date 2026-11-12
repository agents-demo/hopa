"""Errors both halves of the relay raise.

The relay server and the PC link client share these so a caller can catch one
class regardless of which side reported the failure (ADR-0010).
"""

from __future__ import annotations


class RelayError(Exception):
    """A request the relay cannot serve."""


class RelayBusy(RelayError):
    """Too many requests are already waiting for the PC."""


class RelayTimeout(RelayError):
    """The PC did not answer in time."""
