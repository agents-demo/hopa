"""Append-only, hash-chained run records.

Each line is one step. ``prevHash`` points at the previous line's ``hash``, so
removing or editing a line is detectable. The store only appends; it never
rewrites history.
"""

from __future__ import annotations

import hashlib
import json
import os
from dataclasses import dataclass, field
from datetime import UTC, datetime
from pathlib import Path
from typing import Any


def _canonical(payload: dict) -> str:
    return json.dumps(payload, ensure_ascii=False, sort_keys=True, separators=(",", ":"))


@dataclass
class RunRecord:
    run_id: str
    step: int
    trace_id: str
    action: dict
    classification: str
    approved: bool | None
    observation_hash: str
    before_hash: str = ""
    after_hash: str = ""
    verified: bool = False
    executed: bool = False
    error: str | None = None
    timestamp: str = field(default_factory=lambda: datetime.now(UTC).isoformat())
    prev_hash: str = ""
    hash: str = ""

    def to_dict(self) -> dict[str, Any]:
        return {
            "schemaVersion": "1",
            "runId": self.run_id,
            "step": self.step,
            "timestamp": self.timestamp,
            "traceId": self.trace_id,
            "action": self.action,
            "classification": self.classification,
            "approved": self.approved,
            "observationHash": self.observation_hash,
            "beforeHash": self.before_hash,
            "afterHash": self.after_hash,
            "verified": self.verified,
            "executed": self.executed,
            "error": self.error,
            "prevHash": self.prev_hash,
            "hash": self.hash,
        }

    def seal(self, prev_hash: str) -> RunRecord:
        self.prev_hash = prev_hash
        self.hash = _digest(self, prev_hash)
        return self

    @classmethod
    def from_dict(cls, data: dict) -> RunRecord:
        return cls(
            run_id=str(data.get("runId", "")),
            step=int(data.get("step", 0)),
            trace_id=str(data.get("traceId", "")),
            action=dict(data.get("action") or {}),
            classification=str(data.get("classification", "")),
            approved=data.get("approved"),
            observation_hash=str(data.get("observationHash", "")),
            before_hash=str(data.get("beforeHash", "")),
            after_hash=str(data.get("afterHash", "")),
            verified=bool(data.get("verified", False)),
            executed=bool(data.get("executed", False)),
            error=data.get("error"),
            timestamp=str(data.get("timestamp", "")),
            prev_hash=str(data.get("prevHash", "")),
            hash=str(data.get("hash", "")),
        )


class RunStore:
    """JSONL store with an append-only hash chain."""

    def __init__(self, path: str | Path) -> None:
        self.path = Path(path)

    def _last_line(self) -> dict | None:
        if not self.path.exists():
            return None
        last: dict | None = None
        with self.path.open("r", encoding="utf-8") as handle:
            for line in handle:
                line = line.strip()
                if line:
                    last = json.loads(line)
        return last

    def last_hash(self) -> str:
        last = self._last_line()
        return str(last.get("hash", "")) if last else ""

    def append(self, record: RunRecord) -> RunRecord:
        self.path.parent.mkdir(parents=True, exist_ok=True)
        record.seal(self.last_hash())
        line = json.dumps(record.to_dict(), ensure_ascii=False, separators=(",", ":")) + "\n"
        descriptor = os.open(self.path, os.O_APPEND | os.O_CREAT | os.O_WRONLY, 0o644)
        try:
            os.write(descriptor, line.encode("utf-8"))
            os.fsync(descriptor)
        finally:
            os.close(descriptor)
        return record

    def read_all(self) -> list[RunRecord]:
        if not self.path.exists():
            return []
        records: list[RunRecord] = []
        with self.path.open("r", encoding="utf-8") as handle:
            for line in handle:
                line = line.strip()
                if line:
                    records.append(RunRecord.from_dict(json.loads(line)))
        return records

    def for_run(self, run_id: str) -> list[RunRecord]:
        return [record for record in self.read_all() if record.run_id == run_id]

    def resume_step(self, run_id: str) -> int:
        records = self.for_run(run_id)
        return max((record.step for record in records), default=-1) + 1

    def verify_chain(self) -> list[str]:
        errors: list[str] = []
        previous = ""
        for index, record in enumerate(self.read_all()):
            if record.prev_hash != previous:
                errors.append(
                    f"line {index + 1}: prevHash mismatch "
                    f"(expected {previous!r}, got {record.prev_hash!r})"
                )
            expected = _digest(record, record.prev_hash)
            if record.hash != expected:
                errors.append(f"line {index + 1}: hash mismatch (record was edited)")
            previous = record.hash
        return errors


def _digest(record: RunRecord, prev_hash: str) -> str:
    payload = record.to_dict()
    payload["prevHash"] = prev_hash
    payload.pop("hash", None)
    return "sha256:" + hashlib.sha256(_canonical(payload).encode("utf-8")).hexdigest()
