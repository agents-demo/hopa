from __future__ import annotations

from pathlib import Path

import pytest

from hopa_bench.task import APP_BUNDLES, Task, TaskError, load_task, load_tasks

TASKS_DIR = Path(__file__).resolve().parents[1] / "tasks"


def test_loads_all_example_tasks() -> None:
    tasks = load_tasks(TASKS_DIR)
    assert len(tasks) == 20
    ids = {task.id for task in tasks}
    assert len(ids) == 20
    assert {
        "settings-wlan",
        "clock-open-alarm",
        "calendar-new-event",
        "browser-search-harmonyos",
        "notes-create-note",
    } <= ids
    assert "settings-wifi-toggle" in ids
    assert "settings-brightness" in ids


def test_loads_yaml_task() -> None:
    task = load_task(TASKS_DIR / "01-settings-wlan.yaml")
    assert task.app == "Settings"
    assert task.resolved_bundle == "com.huawei.hmos.settings"
    assert task.success.type == "text_visible"
    assert task.success.any == ["WLAN", "Wi-Fi"]
    assert task.steps[0].action == "launch"


def test_loads_json_task() -> None:
    task = load_task(TASKS_DIR / "05-notes-create-note.json")
    assert task.id == "notes-create-note"
    assert task.steps[-1].action == "type"


def test_bundle_inference() -> None:
    task = Task.from_dict({"id": "x", "goal": "g", "app": "Clock"})
    assert task.resolved_bundle == APP_BUNDLES["clock"]


def test_missing_required_field() -> None:
    with pytest.raises(TaskError, match="goal"):
        Task.from_dict({"id": "x", "app": "Settings"})


def test_unknown_success_type() -> None:
    with pytest.raises(TaskError, match="success.type"):
        Task.from_dict(
            {
                "id": "x",
                "goal": "g",
                "app": "Settings",
                "success": {"type": "magic"},
            }
        )


def test_text_visible_needs_terms() -> None:
    with pytest.raises(TaskError, match="needs"):
        Task.from_dict(
            {
                "id": "x",
                "goal": "g",
                "app": "Settings",
                "success": {"type": "text_visible"},
            }
        )


def test_unknown_action() -> None:
    with pytest.raises(TaskError, match="unknown action"):
        Task.from_dict(
            {
                "id": "x",
                "goal": "g",
                "app": "Settings",
                "steps": [{"action": "teleport"}],
            }
        )
