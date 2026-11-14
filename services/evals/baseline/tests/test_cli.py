from __future__ import annotations

import json
import sys
from pathlib import Path

from hopa_baseline import cli
from hopa_baseline.actions import Action
from hopa_baseline.records import RunRecord, RunStore

from .conftest import BLUETOOTH, PAYMENT, SETTINGS, FakeDevice


def test_observe_json(monkeypatch, capsys):
    device = FakeDevice([SETTINGS])
    monkeypatch.setattr(cli, "_make_device", lambda args: device)
    code = cli.main(["observe", "--json"])
    assert code == 0
    payload = json.loads(capsys.readouterr().out)
    assert payload["schemaVersion"] == "1"
    assert payload["hash"].startswith("sha256:")


def test_observe_screenshot(monkeypatch, capsys, tmp_path: Path):
    device = FakeDevice([SETTINGS])
    monkeypatch.setattr(cli, "_make_device", lambda args: device)
    code = cli.main(["observe", "--json", "--screenshot", "--out", str(tmp_path)])
    assert code == 0
    payload = json.loads(capsys.readouterr().out)
    assert payload["screenshotRef"].endswith(".jpeg")
    assert Path(payload["screenshotRef"]).exists()


def test_observe_human_output(monkeypatch, capsys):
    monkeypatch.setattr(cli, "_make_device", lambda args: FakeDevice([SETTINGS]))
    assert cli.main(["observe"]) == 0
    assert "Settings" in capsys.readouterr().out


def test_run_stub_succeeds(monkeypatch, capsys, tmp_path: Path):
    steps = tmp_path / "steps.json"
    steps.write_text(json.dumps([{"kind": "ui.tap", "ref": "e3"}]), encoding="utf-8")
    monkeypatch.setattr(cli, "_make_device", lambda args: FakeDevice([SETTINGS, BLUETOOTH]))
    code = cli.main(
        [
            "run",
            "tap it",
            "--steps",
            str(steps),
            "--record",
            str(tmp_path / "runs.jsonl"),
            "--json",
        ]
    )
    assert code == 0
    payload = json.loads(capsys.readouterr().out)
    assert payload["success"] is True
    assert payload["steps"] == 2


def test_run_stub_denied_payment(monkeypatch, capsys, tmp_path: Path):
    steps = tmp_path / "steps.json"
    steps.write_text(json.dumps([{"kind": "ui.tap", "ref": "e5"}]), encoding="utf-8")
    monkeypatch.setattr(cli, "_make_device", lambda args: FakeDevice([PAYMENT]))
    monkeypatch.setattr(sys.stdin, "isatty", lambda: False)
    code = cli.main(
        [
            "run",
            "pay",
            "--steps",
            str(steps),
            "--record",
            str(tmp_path / "runs.jsonl"),
        ]
    )
    assert code == 1
    assert "denied" in capsys.readouterr().out


def test_run_stub_needs_steps(monkeypatch, capsys):
    monkeypatch.setattr(cli, "_make_device", lambda args: FakeDevice([SETTINGS]))
    assert cli.main(["run", "x"]) == 2
    assert "--steps" in capsys.readouterr().err


def test_run_openai_needs_key(monkeypatch, capsys, tmp_path: Path):
    monkeypatch.delenv("HOPA_API_KEY", raising=False)
    monkeypatch.setattr(cli, "_make_device", lambda args: FakeDevice([SETTINGS]))
    assert cli.main(["run", "x", "--model", "openai"]) == 2
    assert "HOPA_API_KEY" in capsys.readouterr().err


def test_records_and_verify(monkeypatch, capsys, tmp_path: Path):
    path = tmp_path / "runs.jsonl"
    store = RunStore(path)
    store.append(
        RunRecord(
            run_id="r1",
            step=0,
            trace_id="t1",
            action=Action.from_dict({"kind": "ui.tap", "ref": "e1"}).to_dict(),
            classification="read",
            approved=True,
            observation_hash="h",
            verified=True,
            executed=True,
        )
    )
    assert cli.main(["records", "--path", str(path)]) == 0
    assert "r1" in capsys.readouterr().out
    assert cli.main(["verify-chain", "--path", str(path)]) == 0
    assert "ok" in capsys.readouterr().out


def test_approver_refuses_payment_without_opt_in():
    approver = cli._make_approver(yes=True, approve_payment=False)
    request = cli.ApprovalRequest(classification="payment", reason="pay")
    assert approver(request) is False


def test_approver_yes():
    approver = cli._make_approver(yes=True, approve_payment=True)
    request = cli.ApprovalRequest(classification="payment", reason="pay")
    assert approver(request) is True
