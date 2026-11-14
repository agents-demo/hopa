"""Structured, redacted, rotating JSONL logs.

The log is local, append-only and safe to attach to a bug report. Secrets are
redacted with the same rules as observations.
"""

from __future__ import annotations

import json
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

from .observation import redact

LEVELS = {"DEBUG": 10, "INFO": 20, "WARNING": 30, "ERROR": 40}


class JsonlLogger:
    def __init__(
        self,
        path: str | Path,
        *,
        level: str = "INFO",
        max_bytes: int = 1_000_000,
        trace_id: str = "",
    ) -> None:
        self.path = Path(path)
        self.threshold = LEVELS.get(level.upper(), 20)
        self.max_bytes = max_bytes
        self.trace_id = trace_id

    def log(self, event: str, *, level: str = "INFO", **fields: Any) -> None:
        if LEVELS.get(level.upper(), 20) < self.threshold:
            return
        record = {
            "ts": datetime.now(UTC).isoformat(),
            "level": level.upper(),
            "event": event,
            "traceId": self.trace_id,
            **{key: _clean(value) for key, value in fields.items()},
        }
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self._rotate()
        with self.path.open("a", encoding="utf-8") as handle:
            handle.write(json.dumps(record, ensure_ascii=False, separators=(",", ":")) + "\n")

    def read(self) -> list[dict]:
        if not self.path.exists():
            return []
        with self.path.open("r", encoding="utf-8") as handle:
            return [json.loads(line) for line in handle if line.strip()]

    def _rotate(self) -> None:
        if not self.path.exists() or self.max_bytes <= 0:
            return
        if self.path.stat().st_size < self.max_bytes:
            return
        rotated = self.path.with_name(self.path.name + ".1")
        if rotated.exists():
            rotated.unlink()
        self.path.rename(rotated)


def _clean(value: Any) -> Any:
    if isinstance(value, str):
        return redact(value)
    if isinstance(value, dict):
        return {key: _clean(item) for key, item in value.items()}
    if isinstance(value, list):
        return [_clean(item) for item in value]
    return value
