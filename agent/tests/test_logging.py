from __future__ import annotations

from pathlib import Path

from hopa_agent.actions import Action
from hopa_agent.executor import DeviceExecutor
from hopa_agent.logging import JsonlLogger


def test_logs_jsonl_and_reads_back(tmp_path: Path):
    logger = JsonlLogger(tmp_path / "log.jsonl", trace_id="t1")
    logger.log("start", goal="test")
    logger.log("end", ok=True)

    events = logger.read()
    assert [event["event"] for event in events] == ["start", "end"]
    assert events[0]["traceId"] == "t1"
    assert events[1]["ok"] is True


def test_logs_redact_secrets(tmp_path: Path):
    logger = JsonlLogger(tmp_path / "log.jsonl")
    logger.log("contact", value="mail me at a.b@example.com")
    assert "a.b@example.com" not in (tmp_path / "log.jsonl").read_text(encoding="utf-8")


def test_logs_rotate(tmp_path: Path):
    path = tmp_path / "log.jsonl"
    logger = JsonlLogger(path, max_bytes=50)
    logger.log("first", value="x" * 100)
    logger.log("second", value="y" * 100)

    assert path.exists()
    assert (tmp_path / "log.jsonl.1").exists()


def test_level_filter(tmp_path: Path):
    logger = JsonlLogger(tmp_path / "log.jsonl", level="WARNING")
    logger.log("debug", level="DEBUG")
    logger.log("warning", level="WARNING")
    assert [event["event"] for event in logger.read()] == ["warning"]


def test_executor_writes_a_step_event(settings_device, tmp_path: Path):
    logger = JsonlLogger(tmp_path / "log.jsonl")
    executor = DeviceExecutor(settings_device, logger=logger)
    executor.execute(Action.from_dict({"kind": "ui.tap", "ref": "e3"}), run_id="r1", step=0)

    events = logger.read()
    assert events[0]["event"] == "step"
    assert events[0]["runId"] == "r1"
    assert events[0]["executed"] is True
