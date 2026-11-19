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

# Precise state-identification landmarks, hand-authored from the capture.
# Each entry: {"priority": N, "conditions": [ ... ]}. The conditions must
# ALL hold; states with higher priority win when several match (the live
# search box can hold the geocoded canonical form while a place page is
# opening, so s4 must outrank the generic empty-search states).
IDENTIFY = {
    "s2": {"priority": 10, "conditions": [
        {"kind": "focused_id", "value": "search_omnibox_edit_text"},
        {"kind": "none_text", "value": "${src}"},
        {"kind": "none_text", "value": "${dst}"}]},
    "s3": {"priority": 50, "conditions": [
        {"kind": "focused_id", "value": "search_omnibox_edit_text"},
        {"kind": "text", "value": "${src}"},
        {"kind": "desc_prefix", "value": "Activate to enter suggestion"},
        {"kind": "none_desc", "value": "Swap start and destination"}]},
    "s4": {"priority": 80, "conditions": [
        {"kind": "desc_prefix", "value": "Directions to"}]},
    "s5": {"priority": 70, "conditions": [
        {"kind": "desc", "value": "Swap start and destination"},
        {"kind": "none_text", "value": "Choose destination"}]},
    "s6": {"priority": 70, "conditions": [
        {"kind": "text", "value": "Choose destination"},
        {"kind": "none_focused_id", "value": "search_omnibox_edit_text"}]},
    "s7": {"priority": 60, "conditions": [
        {"kind": "focused_id", "value": "search_omnibox_edit_text"},
        {"kind": "desc", "value": "Swap start and destination"}]},
    "s8": {"priority": 50, "conditions": [
        {"kind": "focused_id", "value": "search_omnibox_edit_text"},
        {"kind": "text", "value": "${dst}"},
        {"kind": "desc_prefix", "value": "Activate to enter suggestion"}]},
    "s9": {"priority": 90, "conditions": [
        {"kind": "clickable_desc", "value": "Drive"}]},
    "s10": {"priority": 90, "conditions": [
        {"kind": "clickable_desc", "value": "Public transport"}]},
    "s11": {"priority": 90, "conditions": [
        {"kind": "clickable_desc", "value": "Walk"}]},
    "s49": {"priority": 100, "conditions": [
        {"kind": "has_id", "value": "transit_departure_row"}]},
}

# Live-discovered correction (2026-11-19, first real replay): pressing ENTER
# on a query opens a "Partial matches" screen when the query does not
# geocode cleanly. Tapping the TOP SUGGESTION while typing is the reliable
# path (the same mechanism as s8 -> s9). The capture predates this.
TRANSFORM = {
    ("s3", "press", "s4"): {
        "op": "click",
        "action": "ui.click(first suggestion '${src}')",
        "target": "top suggestion row for '${src}'",
        "find": {"by": "desc", "value": "Activate to enter suggestion",
                 "match": "prefix", "child_index": 0,
                 "tap": "clickable_ancestor"},
    },
    # Live: tapping 'Choose destination' opens a FULL-SCREEN destination
    # search (s2-shaped), not the capture's inline field.
    ("s6", "click", "s7"): {"to": "s63"},
}

# Live-discovered edge (2026-11-19): the app remembers the last mode tab,
# so a car command can land on the transit screen; switch back to driving.
POST_TRANSITIONS = {
    "s10": [
        {"to": "s9", "op": "click",
         "action": "ui.click(Driving mode tab)",
         "target": "driving mode tab",
         "find": {"by": "desc", "value": "Driving mode", "match": "prefix"},
         "live_discovered": True},
    ],
}

# Live-discovered states (2026-11-19, first real replay).
POST_STATES = [
    {
        "id": "s62",
        "label": "Typed, no suggestion (live-discovered 2026-11-19)",
        "final": False,
        "live_discovered": True,
        "identify": {"priority": 55, "conditions": [
            {"kind": "focused_id", "value": "search_omnibox_edit_text"},
            {"kind": "text_any", "value": ["${src}", "${dst}"]},
            {"kind": "none_desc_prefix", "value": "Activate to enter suggestion"},
        ]},
        "signature": {"resource_ids": []},
        "transitions": [],
        "explored": ["nothing to tap; the engine abstains and the model is asked"],
    },
    {
        "id": "s63",
        "label": "Destination search (live-discovered 2026-11-19)",
        "final": False,
        "live_discovered": True,
        "identify": {"priority": 10, "conditions": [
            {"kind": "focused_id", "value": "search_omnibox_edit_text"},
            {"kind": "none_text", "value": "${src}"},
            {"kind": "none_text", "value": "${dst}"},
        ]},
        "signature": {"resource_ids": []},
        "transitions": [
            {"to": "s8", "op": "set_text",
             "action": "ui.setText('${dst}')",
             "target": "destination search box (id=search_omnibox_edit_text, focused)",
             "text": "${dst}",
             "find": {"by": "resource-id",
                      "value": "com.google.android.apps.maps:id/search_omnibox_edit_text"}},
        ],
        "explored": [],
    },
]

# Hand-resolved selectors for transitions the heuristics cannot derive.
# Key: (state_id, op, to) -> find dict, or None to force needs_review.
# "child_index" = Nth matching node in document order (0-based), for cases
# where several nodes share the same text/desc/id.
OVERRIDES = {
    # The Directions button desc shows the geocoded canonical address, not
    # the typed ${src} (e.g. 'Directions to HaHarash St 4, ...'), so the
    # selector must not contain the address at all; the plain prefix is
    # unique on the place page.
    ("s4", "click", "s5"): {"by": "desc", "value": "Directions to",
                            "match": "prefix"},
    ("s9", "click", "s44"): {"by": "resource-id",
                             "value": "com.google.android.apps.maps:id/street_view_thumbnail"},
    ("s9", "click", "s51"): {"by": "resource-id",
                             "value": "com.google.android.apps.maps:id/trip_details_summary_header"},
    # The transit trip card is the first card in the trip list; the stable
    # cue is its 'Duration ...' desc (ETA text varies). Tap the card's
    # clickable ancestor, not the summary header.
    ("s10", "click", "s49"): {"by": "desc", "value": "Duration",
                              "match": "prefix", "child_index": 0,
                              "tap": "clickable_ancestor"},
    ("s20", "click", "s23"): {"by": "text", "value": "Driving avatar"},
    # The suggestion row shows the geocoded canonical form, not the typed
    # string, so exact text='${dst}' would match the edit field instead of
    # the row. The row's arrow carries the stable desc 'Activate to enter
    # suggestion ...'; tap the clickable row ancestor of that arrow.
    ("s8", "click", "s9"): {"by": "desc",
                            "value": "Activate to enter suggestion",
                            "match": "prefix", "child_index": 0,
                            "tap": "clickable_ancestor"},
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
            "identify": IDENTIFY.get(sid, {"priority": 0, "conditions": []}),
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
            transform = TRANSFORM.get(key)
            if transform:
                if "to" in transform:
                    to = transform["to"]
                    key = (sid, op, to)
                op = transform.get("op", op)
                action = transform.get("action", action)
                target = transform.get("target", target)
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
                if transform and "find" in transform:
                    item = {"to": to, "op": op, "action": action,
                            "target": target, "find": transform["find"]}
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
    for sid, extra_transitions in POST_TRANSITIONS.items():
        for st in states_out:
            if st["id"] == sid:
                st["transitions"].extend(extra_transitions)
                break
    states_out.extend(POST_STATES)
    meta["states"] = str(len(states_out))
    meta["transitions"] = str(sum(len(s["transitions"]) for s in states_out))

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
