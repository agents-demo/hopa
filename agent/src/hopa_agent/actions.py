"""Action contract and validation.

The model may propose an action, but only this module decides whether it is
well formed. Unknown kinds fail closed. ``isPayment`` is never read from the
model: payment is a property of the screen and the action, classified by
``policy.py``.
"""

from __future__ import annotations

import hashlib
import json
import re
from dataclasses import dataclass, field
from typing import Any

from .errors import ActionError, SchemaError

SCHEMA_VERSION = "1"

UI_KINDS = {
    "ui.observe",
    "ui.tap",
    "ui.doubleTap",
    "ui.longPress",
    "ui.type",
    "ui.swipe",
    "ui.scroll",
    "ui.back",
    "ui.home",
    "ui.launch",
    "ui.stop",
    "ui.wait",
}
WEB_KINDS = {"web.navigate", "web.read", "web.click", "web.type"}
SYSTEM_KINDS = {
    "system.setAlarm",
    "system.addEvent",
    "system.openLink",
    "system.share",
    "system.sendMessage",
    "system.call",
    "system.delete",
    "system.uninstall",
    "system.reset",
}
SANDBOX_KINDS = {"sandbox.run"}
PAYMENT_KINDS = {
    "payment.pay",
    "payment.confirm",
    "payment.checkout",
    "payment.enterCard",
    "payment.authorize",
}

ALL_KINDS = UI_KINDS | WEB_KINDS | SYSTEM_KINDS | SANDBOX_KINDS | PAYMENT_KINDS

REF_KINDS = {"ui.tap", "ui.doubleTap", "ui.longPress", "ui.type", "ui.scroll"}
COORD_KINDS = {"ui.tap", "ui.doubleTap", "ui.longPress"}

_JSON_FENCE = re.compile(r"^```(?:json)?\s*|\s*```$", re.IGNORECASE)


@dataclass
class Action:
    kind: str
    ref: str = ""
    text: str = ""
    x: int | None = None
    y: int | None = None
    to_x: int | None = None
    to_y: int | None = None
    app: str = ""
    url: str = ""
    timeout_ms: int = 10_000
    direction: str = ""
    ignored_fields: list[str] = field(default_factory=list)

    # -- construction --------------------------------------------------------

    @classmethod
    def from_dict(cls, data: Any, *, source: str = "model") -> Action:
        if not isinstance(data, dict):
            raise SchemaError(f"action must be an object, got {type(data).__name__}")
        kind = data.get("kind")
        if not isinstance(kind, str) or not kind:
            raise SchemaError("action is missing a string `kind`")
        if kind not in ALL_KINDS:
            raise ActionError(f"unknown action kind: {kind}")

        ignored: list[str] = []
        if "isPayment" in data:
            ignored.append("isPayment")

        action = cls(
            kind=kind,
            ref=str(data.get("ref") or ""),
            text=str(data.get("text") if data.get("text") is not None else ""),
            x=_int_or_none(data.get("x")),
            y=_int_or_none(data.get("y")),
            to_x=_int_or_none(data.get("toX", data.get("to_x"))),
            to_y=_int_or_none(data.get("toY", data.get("to_y"))),
            app=str(data.get("app") or ""),
            url=str(data.get("url") or ""),
            timeout_ms=_int_or_none(data.get("timeoutMs", data.get("timeout_ms"))) or 10_000,
            direction=str(data.get("direction") or data.get("text") or ""),
            ignored_fields=ignored,
        )
        action.validate()
        if source != "model" and ignored:
            action.ignored_fields = ignored
        return action

    @classmethod
    def from_json(cls, text: str) -> Action:
        """Parse one JSON action, tolerating a markdown fence."""
        cleaned = _JSON_FENCE.sub("", text.strip())
        try:
            data = json.loads(cleaned)
        except json.JSONDecodeError as exc:
            raise SchemaError(f"action is not valid JSON: {exc}") from exc
        return cls.from_dict(data)

    # -- validation ----------------------------------------------------------

    def validate(self) -> None:
        kind = self.kind
        if kind in COORD_KINDS:
            has_ref = bool(self.ref)
            has_point = self.x is not None and self.y is not None
            if not has_ref and not has_point:
                raise ActionError(f"{kind} needs `ref` or `x`+`y`")
        if kind == "ui.type" and not self.text:
            raise ActionError("ui.type needs `text`")
        if kind == "ui.swipe":
            has_points = all(value is not None for value in (self.x, self.y, self.to_x, self.to_y))
            if not has_points and not self.direction:
                raise ActionError("ui.swipe needs coordinates or a direction")
        if kind == "ui.launch" and not self.app:
            raise ActionError("ui.launch needs `app`")
        if kind == "ui.stop" and not self.app:
            raise ActionError("ui.stop needs `app`")
        if kind == "web.navigate" and not self.url:
            raise ActionError("web.navigate needs `url`")
        if kind in {"system.call", "system.sendMessage", "system.delete"} and not self.text:
            raise ActionError(f"{kind} needs `text`")
        if kind == "sandbox.run" and not self.text:
            raise ActionError("sandbox.run needs `text`")

    # -- serialization -------------------------------------------------------

    def to_dict(self) -> dict:
        payload: dict[str, Any] = {
            "schemaVersion": SCHEMA_VERSION,
            "kind": self.kind,
            "timeoutMs": self.timeout_ms,
        }
        if self.ref:
            payload["ref"] = self.ref
        if self.text:
            payload["text"] = self.text
        if self.x is not None:
            payload["x"] = self.x
        if self.y is not None:
            payload["y"] = self.y
        if self.to_x is not None:
            payload["toX"] = self.to_x
        if self.to_y is not None:
            payload["toY"] = self.to_y
        if self.app:
            payload["app"] = self.app
        if self.url:
            payload["url"] = self.url
        if self.direction:
            payload["direction"] = self.direction
        return payload

    def hash(self) -> str:
        blob = json.dumps(self.to_dict(), ensure_ascii=False, sort_keys=True, separators=(",", ":"))
        return hashlib.sha256(blob.encode("utf-8")).hexdigest()

    def describe(self) -> str:
        bits = [self.kind]
        if self.ref:
            bits.append(f"ref={self.ref}")
        if self.text:
            bits.append(f"text={self.text!r}")
        if self.app:
            bits.append(f"app={self.app}")
        return " ".join(bits)


def _int_or_none(value: Any) -> int | None:
    if value is None or value == "":
        return None
    try:
        return int(value)
    except (TypeError, ValueError) as exc:
        raise SchemaError(f"expected an integer, got {value!r}") from exc
