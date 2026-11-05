"""HOPA-Bench task format and loader.

A task is YAML or JSON with this shape::

    schema_version: 1
    id: settings-bluetooth
    goal: "Open Settings and reach the Bluetooth screen"
    app: Settings
    bundle: com.huawei.hmos.settings        # optional; inferred from `app`
    success:
      type: text_visible                    # text_visible | app_foreground | always
      any: ["Bluetooth", "Bluetooth settings"]
    steps:                                  # optional scripted path for the stub model
      - action: launch
      - action: wait
        seconds: 2
      - action: tap_text
        text: Bluetooth
    max_steps: 10
"""

from __future__ import annotations

import json
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

import yaml

SCHEMA_VERSION = 1

# Best-effort bundle ids for the preinstalled apps. They vary by region and
# device image; a task can always override `bundle`.
APP_BUNDLES = {
    "settings": "com.huawei.hmos.settings",
    "clock": "com.huawei.hmos.clock",
    "calendar": "com.huawei.hmos.calendar",
    "browser": "com.huawei.hmos.browser",
    "notes": "com.huawei.hmos.notepad",
}

KNOWN_ACTIONS = {
    "launch",
    "tap",
    "tap_text",
    "tap_id",
    "type",
    "swipe",
    "key",
    "wait",
    "finish",
}

SUCCESS_TYPES = {"text_visible", "app_foreground", "always"}


class TaskError(ValueError):
    """Raised when a task file is missing or invalid."""


@dataclass
class Action:
    action: str
    params: dict[str, Any] = field(default_factory=dict)


@dataclass
class SuccessCheck:
    type: str = "always"
    any: list[str] = field(default_factory=list)
    all: list[str] = field(default_factory=list)
    bundle: str | None = None


@dataclass
class Task:
    id: str
    goal: str
    app: str
    bundle: str | None = None
    success: SuccessCheck = field(default_factory=SuccessCheck)
    steps: list[Action] = field(default_factory=list)
    max_steps: int = 15
    source: str | None = None

    @property
    def resolved_bundle(self) -> str:
        if self.bundle:
            return self.bundle
        return APP_BUNDLES.get(self.app.lower(), self.app)

    @classmethod
    def from_dict(cls, data: Any, *, source: str | None = None) -> Task:
        if not isinstance(data, dict):
            raise TaskError(f"task must be a mapping, got {type(data).__name__}")
        for key in ("id", "goal", "app"):
            if not data.get(key):
                raise TaskError(f"task is missing required field: {key}")
        if data.get("schema_version", SCHEMA_VERSION) != SCHEMA_VERSION:
            raise TaskError(f"unsupported schema_version: {data.get('schema_version')}")

        success_raw = data.get("success") or {"type": "always"}
        if not isinstance(success_raw, dict):
            raise TaskError("success must be a mapping")
        success = SuccessCheck(
            type=str(success_raw.get("type", "always")),
            any=[str(item) for item in (success_raw.get("any") or [])],
            all=[str(item) for item in (success_raw.get("all") or [])],
            bundle=success_raw.get("bundle"),
        )
        if success.type not in SUCCESS_TYPES:
            raise TaskError(f"unknown success.type: {success.type}")
        if success.type == "text_visible" and not (success.any or success.all):
            raise TaskError("text_visible success check needs `any` or `all`")

        steps: list[Action] = []
        for raw in data.get("steps") or []:
            if not isinstance(raw, dict) or "action" not in raw:
                raise TaskError("each step needs an `action` field")
            action = str(raw["action"])
            if action not in KNOWN_ACTIONS:
                raise TaskError(f"unknown action: {action}")
            params = {key: value for key, value in raw.items() if key != "action"}
            steps.append(Action(action=action, params=params))

        return cls(
            id=str(data["id"]),
            goal=str(data["goal"]),
            app=str(data["app"]),
            bundle=data.get("bundle"),
            success=success,
            steps=steps,
            max_steps=int(data.get("max_steps", 15)),
            source=source,
        )


def load_task(path: str | Path) -> Task:
    path = Path(path)
    if not path.exists():
        raise TaskError(f"task not found: {path}")
    text = path.read_text(encoding="utf-8")
    suffix = path.suffix.lower()
    if suffix in {".yaml", ".yml"}:
        data = yaml.safe_load(text)
    elif suffix == ".json":
        data = json.loads(text)
    else:
        raise TaskError(f"unsupported task extension: {path.suffix}")
    return Task.from_dict(data, source=str(path))


def load_tasks(directory: str | Path) -> list[Task]:
    directory = Path(directory)
    paths = sorted(
        path
        for path in directory.iterdir()
        if path.is_file() and path.suffix.lower() in {".yaml", ".yml", ".json"}
    )
    return [load_task(path) for path in paths]
