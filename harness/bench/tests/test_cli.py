from __future__ import annotations

from pathlib import Path

from hopa_bench.cli import build_parser, main

TASKS_DIR = Path(__file__).resolve().parents[1] / "tasks"


def test_parser_run_defaults() -> None:
    args = build_parser().parse_args(["run"])
    assert args.command == "run"
    assert args.task == []
    assert args.fail_on_task_error is False


def test_parser_json_flag() -> None:
    args = build_parser().parse_args(["list", "--json"])
    assert args.json is True


def test_validate_example_tasks(capsys) -> None:
    code = main(["validate", "--tasks", str(TASKS_DIR)])
    assert code == 0
    assert "20 task(s) valid" in capsys.readouterr().out


def test_list_example_tasks(capsys) -> None:
    code = main(["list", "--tasks", str(TASKS_DIR)])
    assert code == 0
    assert "settings-wlan" in capsys.readouterr().out


def test_unknown_task_id_returns_2(capsys) -> None:
    code = main(["run", "--tasks", str(TASKS_DIR), "--task", "does-not-exist"])
    assert code == 2
    assert "unknown task" in capsys.readouterr().err


def test_parser_report() -> None:
    args = build_parser().parse_args(["report", "--input", "results.json"])
    assert args.command == "report"
    assert str(args.input) == "results.json"


def test_report_command(tmp_path, capsys) -> None:
    import json

    path = tmp_path / "results.json"
    path.write_text(
        json.dumps(
            {
                "results": [
                    {
                        "app": "Settings",
                        "success": True,
                        "steps": [{"latency_ms": 10}],
                        "tokens": 3,
                        "duration_s": 1.0,
                    }
                ]
            }
        ),
        encoding="utf-8",
    )
    code = main(["report", "--input", str(path)])
    assert code == 0
    assert "HOPA-Bench report" in capsys.readouterr().out
