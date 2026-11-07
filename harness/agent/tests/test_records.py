from __future__ import annotations

from pathlib import Path

from hopa_agent.records import RunRecord, RunStore


def _record(step: int) -> RunRecord:
    return RunRecord(
        run_id="r1",
        step=step,
        trace_id="t1",
        action={"schemaVersion": "1", "kind": "ui.tap", "ref": "e1", "timeoutMs": 10000},
        classification="read",
        approved=True,
        observation_hash="h",
        verified=True,
        executed=True,
    )


def test_hash_chain(tmp_path: Path):
    store = RunStore(tmp_path / "runs.jsonl")
    store.append(_record(0))
    store.append(_record(1))

    assert store.verify_chain() == []
    assert store.resume_step("r1") == 2
    assert len(store.read_all()) == 2


def test_tampering_is_detected(tmp_path: Path):
    path = tmp_path / "runs.jsonl"
    store = RunStore(path)
    store.append(_record(0))
    store.append(_record(1))

    text = path.read_text(encoding="utf-8")
    path.write_text(text.replace('"verified":true', '"verified":false', 1), encoding="utf-8")

    errors = store.verify_chain()
    assert errors
    assert any("hash mismatch" in error for error in errors)
