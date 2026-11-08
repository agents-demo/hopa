from __future__ import annotations

import json
from pathlib import Path

from hopa_bench.report import aggregate, percentile, render_markdown


def _result(app: str, success: bool | None, failure: str | None = None) -> dict:
    return {
        "app": app,
        "success": success,
        "failure": failure,
        "tokens": 10,
        "duration_s": 1.5,
        "steps": [{"latency_ms": 100.0}, {"latency_ms": 300.0}],
    }


def test_percentile() -> None:
    assert percentile([], 0.5) == 0.0
    assert percentile([100, 200, 300], 0.5) == 200
    assert percentile([100, 200, 300], 0.95) == 290.0


def test_aggregate_counts_and_rates() -> None:
    report = aggregate(
        [
            _result("Settings", True),
            _result("Settings", True),
            _result("Clock", False, "target_not_found"),
        ]
    )
    assert report["total"] == 3
    assert report["passed"] == 2
    assert report["failed"] == 1
    assert report["failures"] == {"target_not_found": 1}
    assert report["per_app"]["Settings"] == {"total": 2, "passed": 2}
    assert report["latency_ms"]["p50"] == 200.0
    assert report["tokens"] == 30


def test_render_markdown() -> None:
    text = render_markdown(aggregate([_result("Settings", True)]))
    assert "# HOPA-Bench report" in text
    assert "| Settings | 1 | 1 |" in text


def test_report_file_round_trip(tmp_path: Path) -> None:
    path = tmp_path / "results.json"
    path.write_text(json.dumps({"results": [_result("Settings", True)]}), encoding="utf-8")
    payload = json.loads(path.read_text(encoding="utf-8"))
    assert aggregate(payload["results"])["passed"] == 1
