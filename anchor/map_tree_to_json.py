#!/usr/bin/env python3
"""Convert the captured map_tree.xml into the operational map_tree.json graph.

- Drops the giant uiautomator DOMs; keeps a compact per-state signature
  (distinct resource-ids) for future runtime state matching.
- Drops <point> and <raw_adb>: transitions carry a machine-usable selector
  ("find") instead. For drag/swipe the captured geometry survives as a
  delta ("move.delta") derived from the removed points, so the runtime
  engine resolves the element bounds and applies the offset itself.
- Selectors are derived from the parent state's DOM by matching the
  action/target description (id=..., desc='...', text='...'). Transitions
  that cannot be resolved automatically are emitted with
  "needs_review": true and listed at the end; see OVERRIDES for hand-
  resolved ones.

Usage: python map_tree_to_json.py
Input:  map_tree.xml   (same directory, ${src}/${dst} templated)
Output: map_tree.json  (2-space indent)
"""
import json
import os
import re
import sys
import xml.etree.ElementTree as ET

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "map_tree.xml")
DST = os.path.join(HERE, "map_tree.json")

SYNTHETIC = {"finish"}

# Hand-resolved selectors for transitions the heuristics cannot derive.
# Key: (state_id, op, to) -> find dict, or None to force needs_review.
# "child_index" = Nth matching node in document order (0-based), for cases
# where several nodes share the same text/desc/id.
OVERRIDES = {
    # s4 DOM desc is "Directions to ${src}, ${src}" (extra city suffix).
    ("s4", "click", "s5"): {"by": "desc", "value": "Directions to ${src}",
                            "match": "prefix"},
    ("s9", "click", "s44"): {"by": "resource-id",
                             "value": "com.google.android.apps.maps:id/street_view_thumbnail"},
    ("s9", "click", "s51"): {"by": "resource-id",
                             "value": "com.google.android.apps.maps:id/trip_details_summary_header"},
    # The transit trip card is the selected-route summary card (desc carries
    # a volatile ETA, so prefix-match the stable part).
    ("s10", "click", "s49"): {"by": "desc", "value": "Selected route",
                              "match": "prefix"},
    ("s20", "click", "s23"): {"by": "text", "value": "Driving avatar"},
    # Avatar images have no id/text/desc; the carousel is the stable anchor,
    # option 2 = second child. Kept flagged via needs_review (see below).
    ("s31", "click", "s32"): {"by": "resource-id",
                              "value": "android:id/numberpicker_input",
                              "child_index": 0},
    ("s47", "click", "s48"): {"by": "resource-id",
                              "value": "com.google.android.apps.maps:id/edit_waypoints_done_button"},
    # Step row: first text='${dst}' node (the second one is the map marker).
    ("s51", "click", "s53"): {"by": "text", "value": "${dst}",
                              "child_index": 0},
    # Two identical clickable 'Save trip' descs; the footer button is the
    # first in document order.
    ("s56", "click", "s59"): {"by": "desc", "value": "Save trip",
                              "child_index": 0},
    # Avatar carousel children carry no stable attributes; index 1 is an
    # order-based guess -> leave unresolved for device confirmation.
    ("s23", "click", "s24"): None,
}


def _attrs(node: ET.Element) -> dict:
    return {
        "resource_id": node.attrib.get("resource-id", ""),
        "text": node.attrib.get("text", ""),
        "desc": node.attrib.get("content-desc", ""),
        "class": node.attrib.get("class", ""),
        "clickable": node.attrib.get("clickable", "false") == "true",
    }


def _trim_eta(value: str):
    """'Transit mode: 1 hour 11 minutes' -> ('Transit mode', 'prefix').

    ETA/duration suffixes vary with the time of day; the stable part is
    everything before the colon.
    """
    m = re.match(r"^(.+?): \d+ (hour|min|hr)s?\b", value)
    if m:
        return m.group(1), "prefix"
    return value, "exact"


def _find_by(nodes, field, value, match="exact"):
    if match == "exact":
        hits = [n for n in nodes if n[field] == value]
    else:
        hits = [n for n in nodes if n[field].startswith(value)]
    # Several nodes can share a text/desc (row + label); the tappable one is
    # the clickable node. Prefer it when it disambiguates.
    if len(hits) > 1:
        clickable = [n for n in hits if n.get("clickable")]
        if len(clickable) == 1:
            return clickable
    return hits


def _selector(nodes, action, target):
    """Derive a unique selector for the transition, or (None, reason)."""
    nodes = [_attrs(n) for n in nodes]

    # 1. shortened resource-id in the target, e.g. (id=search_omnibox_text_box)
    for short_id in re.findall(r"\(id=([A-Za-z0-9_.]+)", target):
        hits = [n for n in nodes if n["resource_id"].endswith(short_id)]
        if len(hits) == 1:
            return {"by": "resource-id", "value": hits[0]["resource_id"],
                    "match": "exact"}, None
        if len(hits) > 1:
            return None, "id={} matches {} nodes".format(short_id, len(hits))

    # 2. desc='...' in the action (stable content-descriptions)
    for value in re.findall(r"desc='([^']+)'", action):
        stable, match = _trim_eta(value)
        hits = _find_by(nodes, "desc", stable, match)
        if len(hits) == 1:
            return {"by": "desc", "value": stable, "match": match}, None
        if len(hits) > 1:
            return None, "desc={!r} matches {} nodes".format(value, len(hits))

    # 3. text='...' in the action
    for value in re.findall(r"text='([^']+)'", action):
        hits = _find_by(nodes, "text", value)
        if len(hits) == 1:
            return {"by": "text", "value": value, "match": "exact"}, None
        if len(hits) > 1:
            return None, "text={!r} matches {} nodes".format(value, len(hits))

    # 3b. bare quoted strings in the action, e.g. ui.click('Done')
    for value in re.findall(r"^ui\.\w+\('([^']+)'\)", action):
        for field, by in (("text", "text"), ("desc", "desc")):
            hits = _find_by(nodes, field, value)
            if len(hits) == 1:
                return {"by": by, "value": value, "match": "exact"}, None
            if len(hits) > 1:
                return None, "action {!r} matches {} nodes".format(value, len(hits))

    # 4. quoted strings in the target, tried against text then desc
    for value in re.findall(r"'([^']+)'", target):
        for field, by in (("text", "text"), ("desc", "desc")):
            hits = _find_by(nodes, field, value)
            if len(hits) == 1:
                return {"by": by, "value": value, "match": "exact"}, None
            if len(hits) > 1:
                return None, "target {!r} matches {} nodes".format(value, len(hits))

    return None, "no id/desc/text cue in action or target"


def _op_params(op, action, target, point, parent_nodes):
    """Return (extra_fields, needs_review)."""
    extra = {}
    if op == "click":
        find, reason = _selector(parent_nodes, action, target)
        if find is None:
            extra["find"] = None
            extra["needs_review"] = True
            extra["review_reason"] = reason
        else:
            extra["find"] = find
        return extra, extra.get("needs_review", False)

    if op == "set_text":
        m = re.search(r"ui\.setText\('([^']+)'\)", action)
        extra["text"] = m.group(1) if m else ""
        find, _ = _selector(parent_nodes, action, target)
        if find is not None:
            extra["find"] = find
        return extra, False

    if op == "press":
        m = re.search(r"ui\.press\('([^']+)'\)", action)
        extra["key"] = m.group(1) if m else ""
        return extra, False

    if op in ("drag", "swipe"):
        find, _ = _selector(parent_nodes, action, target)
        extra["find"] = find  # None is fine: swipe acts on the screen by delta
        m = re.match(r"\((\d+),(\d+)\)->\((\d+),(\d+)\)", point or "")
        if m:
            x1, y1, x2, y2 = (int(v) for v in m.groups())
            extra["move"] = {"delta": [x2 - x1, y2 - y1]}
        else:
            extra["move"] = {"delta": [0, 0]}
            extra["needs_review"] = True
            extra["review_reason"] = "point {!r} not a pair".format(point)
        return extra, extra.get("needs_review", False)

    raise ValueError("unknown op {!r}".format(op))


def main() -> int:
    tree = ET.parse(SRC)
    root = tree.getroot()
    meta = dict(root.find("meta").attrib)
    meta["generated_from"] = "map_tree.xml"
    meta["templating"] = ("${src} = origin, ${dst} = destination; substitute "
                          "real addresses before replaying")
    meta["synthetic_states"] = sorted(SYNTHETIC)

    states_out = []
    reviews = []
    seen_as_target = {}
    for state in root.findall("state"):
        sid = state.attrib["id"]
        dom = state.find("dom")
        parent_nodes = list(dom.iter("node")) if dom is not None else []
        signature = sorted({n.attrib.get("resource-id")
                            for n in parent_nodes
                            if n.attrib.get("resource-id")})
        record = {
            "id": sid,
            "label": state.attrib.get("label", ""),
            "final": state.find("final") is not None,
            "signature": {"resource_ids": signature},
            "transitions": [],
            "explored": [e.text or "" for e in state.findall("explored")],
        }
        for tr in state.findall("transition"):
            to = tr.attrib["to"]
            op = tr.attrib["op"]
            action = (tr.findtext("action") or "").strip()
            target = re.sub(r"\s*\(bounds=\[[0-9,\]\[]+\]\)", "",
                            (tr.findtext("target") or "").strip())
            point = (tr.findtext("point") or "").strip()
            seen_as_target[to] = seen_as_target.get(to, 0) + 1
            key = (sid, op, to)
            if key in OVERRIDES:
                override = OVERRIDES[key]
                item = {"to": to, "op": op, "action": action, "target": target}
                if override is None:
                    item.update({"find": None, "needs_review": True,
                                 "review_reason": "manual override: unresolved"})
                else:
                    item["find"] = override
                if op in ("drag", "swipe"):
                    m = re.match(r"\((\d+),(\d+)\)->\((\d+),(\d+)\)", point or "")
                    item["move"] = {"delta": [int(m.group(3)) - int(m.group(1)),
                                              int(m.group(4)) - int(m.group(2))]
                                    } if m else {"delta": [0, 0]}
            else:
                extra, needs_review = _op_params(op, action, target, point,
                                                 parent_nodes)
                item = {"to": to, "op": op, "action": action,
                        "target": target, **extra}
            if item.get("needs_review"):
                reviews.append((sid, op, to, item.get("review_reason", ""),
                                action, target))
            record["transitions"].append(item)
        states_out.append(record)

    ids = {s["id"] for s in states_out}
    problems = []
    for tr in [t for s in states_out for t in s["transitions"]]:
        if tr["to"] not in ids:
            problems.append("transition target {!r} does not exist".format(tr["to"]))
    multi_parent = {k: v for k, v in seen_as_target.items() if v > 1}
    if multi_parent:
        problems.append("multi-parent targets: {}".format(multi_parent))
    for s in states_out:
        if s["final"] and s["transitions"]:
            problems.append("final state {} has transitions".format(s["id"]))
    if problems:
        print("PROBLEMS:")
        for p in problems:
            print("  - " + p)
        return 1

    out = {"meta": meta, "states": states_out}
    with open(DST, "w", encoding="utf-8") as handle:
        json.dump(out, handle, indent=2, ensure_ascii=False)
        handle.write("\n")
    print("wrote {}: {} states, {} transitions".format(
        DST, len(states_out),
        sum(len(s["transitions"]) for s in states_out)))
    print("needs_review: {} transitions".format(len(reviews)))
    for sid, op, to, reason, action, target in reviews:
        print("  {} {}->{}: {} | {}".format(sid, op, to, reason, action[:70]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
