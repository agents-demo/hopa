"""Parsing helpers for ``uitest dumpLayout`` output.

The dump is a tree of nodes shaped like::

    {"attributes": {"text": "...", "bounds": "[0,0][1080,2400]", ...},
     "children": [ ... ]}

Different HarmonyOS versions wrap it in an object, a list, or a mapping of
window ids, so the parser is deliberately tolerant.
"""

from __future__ import annotations

import re
from collections.abc import Callable, Iterator
from dataclasses import dataclass, field
from typing import Any

_BOUNDS_RE = re.compile(r"\[\s*(-?\d+)\s*,\s*(-?\d+)\s*\]\s*\[\s*(-?\d+)\s*,\s*(-?\d+)\s*\]")

Bounds = tuple[int, int, int, int]
Point = tuple[int, int]


def _as_bool(value: Any) -> bool:
    if isinstance(value, bool):
        return value
    if value is None:
        return False
    return str(value).strip().lower() in {"true", "1", "yes", "y"}


@dataclass
class Node:
    attributes: dict[str, Any] = field(default_factory=dict)
    children: list[Node] = field(default_factory=list)

    def get(self, key: str, default: Any = None) -> Any:
        return self.attributes.get(key, default)

    @property
    def text(self) -> str:
        return str(self.attributes.get("text") or "")

    @property
    def description(self) -> str:
        return str(self.attributes.get("description") or "")

    @property
    def type(self) -> str:
        return str(self.attributes.get("type") or "")

    @property
    def id(self) -> str:
        return str(self.attributes.get("id") or "")

    @property
    def clickable(self) -> bool:
        return _as_bool(self.attributes.get("clickable"))

    @property
    def enabled(self) -> bool:
        return _as_bool(self.attributes.get("enabled"))

    @property
    def visible(self) -> bool:
        value = self.attributes.get("visible")
        if value is None or value == "":
            return True
        return _as_bool(value)

    @property
    def bounds(self) -> Bounds | None:
        match = _BOUNDS_RE.search(str(self.attributes.get("bounds") or ""))
        if not match:
            return None
        return tuple(int(part) for part in match.groups())  # type: ignore[return-value]

    @property
    def center(self) -> Point | None:
        box = self.bounds
        if box is None:
            return None
        x1, y1, x2, y2 = box
        return ((x1 + x2) // 2, (y1 + y2) // 2)

    def walk(self) -> Iterator[Node]:
        yield self
        for child in self.children:
            yield from child.walk()

    def find_all(self, predicate: Callable[[Node], bool]) -> list[Node]:
        return [node for node in self.walk() if predicate(node)]

    def find(self, predicate: Callable[[Node], bool]) -> Node | None:
        for node in self.walk():
            if predicate(node):
                return node
        return None


@dataclass
class Layout:
    roots: list[Node]
    raw: Any = None

    def walk(self) -> Iterator[Node]:
        for root in self.roots:
            yield from root.walk()

    def find_all(self, predicate: Callable[[Node], bool]) -> list[Node]:
        return [node for node in self.walk() if predicate(node)]

    def find(self, predicate: Callable[[Node], bool]) -> Node | None:
        for node in self.walk():
            if predicate(node):
                return node
        return None

    def find_by_text(
        self,
        text: str,
        *,
        exact: bool = False,
        case_sensitive: bool = False,
        include_description: bool = True,
    ) -> list[Node]:
        needle = text if case_sensitive else text.lower()

        def matches(node: Node) -> bool:
            candidates = [node.text]
            if include_description:
                candidates.append(node.description)
            for candidate in candidates:
                if not candidate:
                    continue
                haystack = candidate if case_sensitive else candidate.lower()
                if (haystack == needle) if exact else (needle in haystack):
                    return True
            return False

        return self.find_all(matches)

    def find_by_id(self, node_id: str, *, exact: bool = True) -> list[Node]:
        needle = node_id if exact else node_id.lower()
        return self.find_all(
            lambda node: (node.id == needle) if exact else (needle in node.id.lower())
        )

    def clickable(self) -> list[Node]:
        return self.find_all(
            lambda node: node.clickable and node.visible and node.bounds is not None
        )

    def texts(self) -> list[str]:
        return [node.text for node in self.walk() if node.text]

    def to_dict(self) -> dict[str, Any]:
        return {"roots": [_node_to_dict(root) for root in self.roots]}


def _node_to_dict(node: Node) -> dict[str, Any]:
    return {
        "attributes": node.attributes,
        "children": [_node_to_dict(child) for child in node.children],
    }


def _parse_node(obj: Any) -> Node | None:
    if not isinstance(obj, dict):
        return None

    attributes: dict[str, Any] = {}
    if isinstance(obj.get("attributes"), dict):
        attributes = dict(obj["attributes"])

    children: list[Node] = []
    raw_children = obj.get("children")
    if isinstance(raw_children, list):
        for child in raw_children:
            parsed = _parse_node(child)
            if parsed is not None:
                children.append(parsed)
    elif isinstance(raw_children, dict):
        # Either a single node object or a mapping of id -> node.
        if "attributes" in raw_children or "children" in raw_children:
            parsed = _parse_node(raw_children)
            if parsed is not None:
                children.append(parsed)
        else:
            for child in raw_children.values():
                parsed = _parse_node(child)
                if parsed is not None:
                    children.append(parsed)

    if not attributes and not children:
        return None
    return Node(attributes=attributes, children=children)


def parse_layout(data: Any) -> Layout:
    """Parse raw ``dumpLayout`` JSON into a :class:`Layout`."""
    roots: list[Node] = []

    if isinstance(data, list):
        for item in data:
            parsed = _parse_node(item)
            if parsed is not None:
                roots.append(parsed)
    elif isinstance(data, dict):
        if "attributes" in data or "children" in data:
            parsed = _parse_node(data)
            if parsed is not None:
                roots.append(parsed)
        else:
            for item in data.values():
                parsed = _parse_node(item)
                if parsed is not None:
                    roots.append(parsed)

    return Layout(roots=roots, raw=data)
