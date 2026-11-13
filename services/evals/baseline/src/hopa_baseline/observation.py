"""Observation model: the redacted, hashable picture of one screen.

An ``Observation`` is the only thing the model sees. It contains:

- a deterministic tree of nodes with refs ``e1``, ``e2``, ...;
- flattened visible text;
- screen metadata (display, window, rotation, density, size);
- a content hash and an optional screenshot reference.

Refs are valid for one observation only. A ref from step N must never be used
at step N+1.
"""

from __future__ import annotations

import hashlib
import json
import re
import time
from collections.abc import Iterator
from dataclasses import dataclass, field
from typing import Any

from hopa_bridge.layout import Layout, Node

REDACTED = "[redacted]"
SCHEMA_VERSION = "1"

EMAIL_RE = re.compile(r"[\w.+-]+@[\w-]+\.[\w.-]+")
CARD_RE = re.compile(r"(?<!\d)(?:\d[ -]?){13,19}(?!\d)")
PHONE_RE = re.compile(r"(?<!\d)(?:\+?\d{1,3}[ -]?)?(?:\(?\d{2,4}\)?[ -]?)?\d{3,4}[ -]?\d{4}(?!\d)")
SECRET_RE = re.compile(r"(?i)\b(password|passcode|pin|密码|口令)\b\s*[:=：]?\s*(\S+)")
OTP_CONTEXT_RE = re.compile(
    r"(?i)(?:\botp\b|\bcode\b|verification|one[- ]time|验证码|校验码|动态码)"
)
OTP_RE = re.compile(r"(?<!\d)\d{4,8}(?!\d)")


def redact(text: str) -> str:
    """Remove common secrets from visible text.

    The rules are deliberately conservative: a false positive costs a little
    context, a false negative leaks a secret into the model or the record.
    """
    if not text:
        return text

    text = EMAIL_RE.sub(REDACTED, text)
    text = CARD_RE.sub(REDACTED, text)
    text = SECRET_RE.sub(lambda m: f"{m.group(1)}: {REDACTED}", text)
    text = PHONE_RE.sub(REDACTED, text)

    lines: list[str] = []
    for line in text.splitlines():
        if OTP_CONTEXT_RE.search(line):
            line = OTP_RE.sub(REDACTED, line)
        lines.append(line)
    return "\n".join(lines)


def _as_bool(value: Any, *, default: bool = False) -> bool:
    if value is None or value == "":
        return default
    if isinstance(value, bool):
        return value
    return str(value).strip().lower() in {"true", "1", "yes", "y"}


@dataclass
class ObsNode:
    ref: str
    type: str = ""
    text: str = ""
    description: str = ""
    node_id: str = ""
    bounds: tuple[int, int, int, int] | None = None
    clickable: bool = False
    enabled: bool = True
    checked: bool = False
    scrollable: bool = False
    visible: bool = True
    focused: bool = False
    children: list[ObsNode] = field(default_factory=list)

    def walk(self) -> Iterator[ObsNode]:
        yield self
        for child in self.children:
            yield from child.walk()

    def find_ref(self, ref: str) -> ObsNode | None:
        for node in self.walk():
            if node.ref == ref:
                return node
        return None

    def find_text(self, needle: str, *, exact: bool = False) -> list[ObsNode]:
        needle = needle.lower()
        found: list[ObsNode] = []
        for node in self.walk():
            for candidate in (node.text, node.description):
                if not candidate:
                    continue
                haystack = candidate.lower()
                if (haystack == needle) if exact else (needle in haystack):
                    found.append(node)
                    break
        return found

    def to_dict(self) -> dict:
        payload: dict[str, Any] = {
            "ref": self.ref,
            "type": self.type,
            "text": self.text,
            "description": self.description,
            "id": self.node_id,
            "bounds": list(self.bounds) if self.bounds else None,
            "clickable": self.clickable,
            "enabled": self.enabled,
            "checked": self.checked,
            "scrollable": self.scrollable,
            "visible": self.visible,
            "focused": self.focused,
            "children": [child.to_dict() for child in self.children],
        }
        return payload

    @classmethod
    def from_dict(cls, data: dict) -> ObsNode:
        bounds = data.get("bounds")
        return cls(
            ref=str(data.get("ref", "")),
            type=str(data.get("type", "")),
            text=str(data.get("text", "")),
            description=str(data.get("description", "")),
            node_id=str(data.get("id", "")),
            bounds=tuple(bounds) if bounds else None,  # type: ignore[arg-type]
            clickable=bool(data.get("clickable", False)),
            enabled=bool(data.get("enabled", True)),
            checked=bool(data.get("checked", False)),
            scrollable=bool(data.get("scrollable", False)),
            visible=bool(data.get("visible", True)),
            focused=bool(data.get("focused", False)),
            children=[cls.from_dict(child) for child in data.get("children", [])],
        )


@dataclass
class Observation:
    id: str
    timestamp: int
    display_id: int = 0
    window_id: str = "active"
    rotation: int = 0
    density: float = 1.0
    width: int = 0
    height: int = 0
    focus: str = ""
    text: str = ""
    tree: ObsNode | None = None
    screenshot_ref: str = ""
    app: str = ""
    hash: str = ""
    truncated: bool = False

    # -- construction --------------------------------------------------------

    def finalize(self) -> Observation:
        if not self.text and self.tree is not None:
            self.text = _flatten_text(self.tree)
        self.hash = self.compute_hash()
        return self

    def compute_hash(self) -> str:
        payload = {
            "displayId": self.display_id,
            "windowId": self.window_id,
            "rotation": self.rotation,
            "width": self.width,
            "height": self.height,
            "focus": self.focus,
            "text": self.text,
            "tree": self.tree.to_dict() if self.tree is not None else None,
        }
        blob = json.dumps(payload, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
        return "sha256:" + hashlib.sha256(blob.encode("utf-8")).hexdigest()

    # -- queries -------------------------------------------------------------

    def walk(self) -> Iterator[ObsNode]:
        if self.tree is not None:
            yield from self.tree.walk()

    def find_ref(self, ref: str) -> ObsNode | None:
        if self.tree is None:
            return None
        return self.tree.find_ref(ref)

    def find_text(self, needle: str, *, exact: bool = False) -> list[ObsNode]:
        if self.tree is None:
            return []
        return self.tree.find_text(needle, exact=exact)

    def clickable(self) -> list[ObsNode]:
        return [
            node
            for node in self.walk()
            if node.clickable and node.visible and node.bounds is not None
        ]

    def contains_any(self, words: set[str] | list[str]) -> bool:
        haystack = self.text.lower()
        return any(word.lower() in haystack for word in words)

    def center(self, ref: str) -> tuple[int, int] | None:
        node = self.find_ref(ref)
        if node is None or node.bounds is None:
            return None
        x1, y1, x2, y2 = node.bounds
        return ((x1 + x2) // 2, (y1 + y2) // 2)

    def summary(self) -> str:
        label = self.app or self.window_id or "screen"
        return f"{label}: {len(self.text)} chars, {sum(1 for _ in self.walk())} nodes"

    # -- serialization -------------------------------------------------------

    def to_dict(self) -> dict:
        return {
            "schemaVersion": SCHEMA_VERSION,
            "id": self.id,
            "timestamp": self.timestamp,
            "displayId": self.display_id,
            "windowId": self.window_id,
            "rotation": self.rotation,
            "density": self.density,
            "screenSize": {"width": self.width, "height": self.height},
            "focus": self.focus,
            "text": self.text,
            "tree": self.tree.to_dict() if self.tree is not None else None,
            "screenshotRef": self.screenshot_ref,
            "app": self.app,
            "hash": self.hash,
            "truncated": self.truncated,
        }

    @classmethod
    def from_dict(cls, data: dict) -> Observation:
        size = data.get("screenSize") or {}
        tree = data.get("tree")
        return cls(
            id=str(data.get("id", "")),
            timestamp=int(data.get("timestamp", 0)),
            display_id=int(data.get("displayId", 0)),
            window_id=str(data.get("windowId", "active")),
            rotation=int(data.get("rotation", 0)),
            density=float(data.get("density", 1.0)),
            width=int(size.get("width", 0)),
            height=int(size.get("height", 0)),
            focus=str(data.get("focus", "")),
            text=str(data.get("text", "")),
            tree=ObsNode.from_dict(tree) if tree else None,
            screenshot_ref=str(data.get("screenshotRef", "")),
            app=str(data.get("app", "")),
            hash=str(data.get("hash", "")),
            truncated=bool(data.get("truncated", False)),
        )


def _flatten_text(node: ObsNode, *, limit: int = 6000) -> str:
    seen: set[str] = set()
    lines: list[str] = []
    for item in node.walk():
        for candidate in (item.text, item.description):
            candidate = candidate.strip()
            if candidate and candidate not in seen:
                seen.add(candidate)
                lines.append(candidate)
    text = "\n".join(lines)
    return text[:limit]


def _convert_node(node: Node, counter: list[int]) -> ObsNode | None:
    attrs = node.attributes
    bounds = node.bounds
    text = redact(node.text)
    description = redact(node.description)
    node_type = node.type

    if not text and not description and bounds is None and not node.children and not node_type:
        return None

    # Pre-order: a parent always gets a lower ref than its children.
    counter[0] += 1
    ref = f"e{counter[0]}"
    children: list[ObsNode] = []
    for child in node.children:
        converted = _convert_node(child, counter)
        if converted is not None:
            children.append(converted)

    return ObsNode(
        ref=ref,
        type=node_type,
        text=text,
        description=description,
        node_id=node.id,
        bounds=bounds,
        clickable=node.clickable,
        enabled=_as_bool(attrs.get("enabled"), default=True),
        checked=_as_bool(attrs.get("checked")),
        scrollable=_as_bool(attrs.get("scrollable")),
        visible=_as_bool(attrs.get("visible"), default=True),
        focused=_as_bool(attrs.get("focused")),
        children=children,
    )


def _bounds_size(roots: list[ObsNode]) -> tuple[int, int]:
    width = 0
    height = 0
    for root in roots:
        for node in root.walk():
            if node.bounds is None:
                continue
            width = max(width, node.bounds[2])
            height = max(height, node.bounds[3])
    return width, height


def observation_from_layout(
    layout: Layout,
    *,
    app: str = "",
    screenshot_ref: str = "",
    display_id: int = 0,
    window_id: str = "active",
    rotation: int = 0,
    density: float = 1.0,
    max_nodes: int = 400,
    now_ms: int | None = None,
) -> Observation:
    """Convert a parsed ``uitest`` layout into a redacted observation."""
    counter = [0]
    nodes: list[ObsNode] = []
    for root in layout.roots:
        converted = _convert_node(root, counter)
        if converted is not None:
            nodes.append(converted)

    tree = ObsNode(ref="", type="root", visible=True, children=nodes)
    width, height = _bounds_size(nodes)
    focus = next((node.ref for node in tree.walk() if node.focused), "")
    timestamp = int(time.time() * 1000) if now_ms is None else now_ms
    observation = Observation(
        id=f"obs_{timestamp}",
        timestamp=timestamp,
        display_id=display_id,
        window_id=window_id,
        rotation=rotation,
        density=density,
        width=width,
        height=height,
        focus=focus,
        text=_flatten_text(tree),
        tree=tree,
        screenshot_ref=screenshot_ref,
        app=app,
    )
    if sum(1 for _ in tree.walk()) > max_nodes:
        observation = truncate_observation(observation, max_nodes=max_nodes, keep_ref=focus)
    return observation.finalize()


def _keep_refs(observation: Observation, max_nodes: int, keep_ref: str) -> set[str]:
    keep: set[str] = set()
    if observation.tree is None:
        return keep
    for node in observation.tree.walk():
        if len(keep) >= max_nodes:
            break
        keep.add(node.ref)

    # Always keep the focus path so the model can see what is selected.
    if keep_ref:
        path = _path_to(observation.tree, keep_ref)
        keep.update(node.ref for node in path)
    return keep


def _path_to(root: ObsNode, ref: str) -> list[ObsNode]:
    stack: list[tuple[ObsNode, list[ObsNode]]] = [(root, [])]
    while stack:
        node, path = stack.pop()
        next_path = [*path, node]
        if node.ref == ref:
            return next_path
        for child in reversed(node.children):
            stack.append((child, next_path))
    return []


def _prune(node: ObsNode, keep: set[str]) -> ObsNode | None:
    if node.ref not in keep and node.ref != "":
        return None
    return ObsNode(
        ref=node.ref,
        type=node.type,
        text=node.text,
        description=node.description,
        node_id=node.node_id,
        bounds=node.bounds,
        clickable=node.clickable,
        enabled=node.enabled,
        checked=node.checked,
        scrollable=node.scrollable,
        visible=node.visible,
        focused=node.focused,
        children=[child for child in (_prune(c, keep) for c in node.children) if child],
    )


def truncate_observation(
    observation: Observation, *, max_nodes: int = 400, keep_ref: str = ""
) -> Observation:
    """Cap the tree, keeping the focus path and the first ``max_nodes`` nodes."""
    if observation.tree is None:
        return observation
    keep = _keep_refs(observation, max_nodes, keep_ref or observation.focus)
    pruned = _prune(observation.tree, keep)
    assert pruned is not None
    observation.tree = pruned
    observation.text = _flatten_text(pruned)
    observation.truncated = True
    observation.hash = observation.compute_hash()
    return observation
