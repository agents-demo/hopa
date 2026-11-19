#!/usr/bin/env python3
"""Replay decision anchors against a live Android emulator via adb.

For each step the driver:
  1. matches/verifies the current UI state (signature + targeted checks),
  2. asks the anchor engine for the next state (rules + threshold),
  3. resolves the graph transition's selector in the live uiautomator dump
     to the element's actual bounds (no hard-coded coordinates),
  4. executes through adb (tap center / input text / keyevent),
  5. re-dumps and verifies the expected state was reached.

It STOPS with a report on the first mismatch -- the point of the test is
to find where the concept breaks, not to guess through it.

Usage:
    python anchor_replay.py "navigate from <src> to <dst> by car"
    python anchor_replay.py "navigate from <src> to <dst> by bus"
"""
import argparse
import os
import re
import subprocess
import sys
import time
import xml.etree.ElementTree as ET

from anchor_decisions_demo import (DecisionCase, FINISH, load_graph,
                                   load_rules, predict)

HERE = os.path.dirname(os.path.abspath(__file__))
REMOTE_DUMP = "/sdcard/anchor_ui.xml"
LOCAL_DUMP = os.path.join(os.environ.get("TEMP", "/tmp"), "anchor_ui.xml")
MAPS_PACKAGE = "com.google.android.apps.maps"
WAIT_AFTER = {"click": 2.5, "set_text": 2.0, "press": 3.0}


def adb(args, timeout=60):
    res = subprocess.run(["adb"] + args, capture_output=True, text=True,
                         timeout=timeout)
    if res.returncode != 0:
        raise SystemExit("adb {} failed: {}".format(" ".join(args), res.stderr.strip()))
    return res


def dump_nodes():
    for _ in range(2):  # uiautomator occasionally fails to settle
        res = adb(["shell", "uiautomator", "dump", REMOTE_DUMP])
        if "dumped" in (res.stdout + res.stderr).lower():
            break
        time.sleep(1)
    adb(["pull", REMOTE_DUMP, LOCAL_DUMP])
    tree = ET.parse(LOCAL_DUMP)
    nodes = []
    for node in tree.getroot().iter("node"):
        nodes.append({
            "id": node.attrib.get("resource-id", ""),
            "text": node.attrib.get("text", ""),
            "desc": node.attrib.get("content-desc", ""),
            "bounds": node.attrib.get("bounds", ""),
            "clickable": node.attrib.get("clickable", "") == "true",
            "focused": node.attrib.get("focused", "") == "true",
        })
    return nodes


def center(bounds):
    m = re.match(r"\[(\d+),(\d+)\]\[(\d+),(\d+)\]", bounds)
    if not m:
        return None
    x1, y1, x2, y2 = (int(v) for v in m.groups())
    return (x1 + x2) // 2, (y1 + y2) // 2


def resolve(find, nodes, src, dst):
    """Resolve a selector against the live dump; (node, error)."""
    if not find:
        return None, "transition has no selector"
    value = find["value"].replace("${src}", src).replace("${dst}", dst)
    field = {"resource-id": "id", "text": "text", "desc": "desc"}[find["by"]]
    if find.get("match", "exact") == "exact":
        hits = [n for n in nodes if n[field] == value]
    else:
        hits = [n for n in nodes if n[field].startswith(value)]
    idx = find.get("child_index")
    if idx is not None:
        hits = hits[idx:idx + 1] if len(hits) > idx else []
    if len(hits) > 1:
        clickable = [n for n in hits if n["clickable"]]
        if len(clickable) == 1:
            hits = clickable
    if len(hits) == 1:
        return hits[0], None
    return None, "selector matched {} nodes".format(len(hits))


def signature_ratio(sid, nodes, graph):
    st = graph.states[sid]
    if not st.resource_ids:
        return 1.0
    live = {n["id"] for n in nodes if n["id"]}
    return len(live & set(st.resource_ids)) / len(st.resource_ids)


def identify(nodes, graph):
    best, ratio = None, 0.0
    for sid in graph.states:
        r = signature_ratio(sid, nodes, graph)
        if r > ratio:
            best, ratio = sid, r
    return best, ratio


def state_present(sid, nodes, graph, src, dst):
    """Targeted per-state verification (test scaffolding, not engine logic)."""
    if sid == "s2":
        return any(n["id"].endswith("search_omnibox_edit_text") and n["focused"]
                   for n in nodes)
    if sid == "s3":
        return any(n["text"] == src for n in nodes)
    if sid == "s5":
        return any(n["desc"] == "Swap start and destination" for n in nodes)
    if sid == "s6":
        return any(n["text"] == "Choose destination" for n in nodes)
    if sid == "s7":
        return any(n["id"].endswith("search_omnibox_edit_text") and n["focused"]
                   for n in nodes)
    if sid == "s8":
        return any(n["text"] == dst for n in nodes)
    if sid == "s9":
        return any(n["desc"].startswith("Driving mode") for n in nodes)
    if sid == "s10":
        return any(n["desc"].startswith("Transit mode") for n in nodes)
    if sid == "s11":
        return any(n["desc"].startswith("Walking mode") for n in nodes)
    return signature_ratio(sid, nodes, graph) >= 0.5


def ensure_home(graph):
    """Get Google Maps to the map home (s1), resetting the app if needed."""
    nodes = dump_nodes()
    best, ratio = identify(nodes, graph)
    if best == "s1" and ratio >= 0.5:
        print("[setup] already at s1 ({} {:.0%})".format(best, ratio))
        return nodes
    print("[setup] screen looks like {} ({:.0%}); resetting Maps".format(best, ratio))
    adb(["shell", "am", "force-stop", MAPS_PACKAGE])
    time.sleep(2)
    adb(["shell", "monkey", "-p", MAPS_PACKAGE,
         "-c", "android.intent.category.LAUNCHER", "1"])
    time.sleep(6)
    for _ in range(4):  # Maps may restore the last route; back out of it
        nodes = dump_nodes()
        best, ratio = identify(nodes, graph)
        if best == "s1" and ratio >= 0.5:
            print("[setup] at s1 ({:.0%})".format(ratio))
            return nodes
        adb(["shell", "input", "keyevent", "4"])
        time.sleep(2)
    raise SystemExit(
        "[setup] FAIL: could not reach map home (best={} {:.0%}); "
        "discuss how to reset manually".format(best, ratio))


def execute(tr, node, src, dst):
    if tr.op == "click":
        x, y = center(node["bounds"])
        adb(["shell", "input", "tap", str(x), str(y)])
        return "tap ({}, {})".format(x, y)
    if tr.op == "set_text":
        text = tr.text.replace("${src}", src).replace("${dst}", dst)
        adb(["shell", "input", "text", text.replace(" ", "%s")])
        return "input text {!r}".format(text)
    if tr.op == "press":
        keycode = {"ENTER": "66"}.get(tr.key, tr.key)
        adb(["shell", "input", "keyevent", str(keycode)])
        return "keyevent {}".format(tr.key)
    raise SystemExit("FAIL: op {!r} not handled by this replay".format(tr.op))


def run_mission(mission, threshold, max_steps):
    m = re.match(r"^.*?from (.+?) to (.+?) by (.+)$", mission, re.I)
    if not m:
        raise SystemExit("mission must be 'navigate from <src> to <dst> by <mode>'")
    src, dst, mode = m.groups()
    rules = load_rules(os.path.join(HERE, "anchor_navigation_rules.json"))
    graph = load_graph(os.path.join(HERE, "map_tree.json"))
    print("=" * 72)
    print("MISSION: {!r}".format(mission))
    print("  src={!r} dst={!r} mode={!r} | threshold={:.0%} | max steps={}".format(
        src, dst, mode, threshold, max_steps))

    nodes = ensure_home(graph)
    current = "s1"
    calls = [current]
    for step in range(1, max_steps + 1):
        options = {t.to for t in graph.states[current].transitions} | {FINISH}
        case = DecisionCase(task=mission, question="", calls=tuple(calls),
                            options=frozenset(options))
        pred = predict(case, rules, threshold)
        print("\n[step {}] state={} ({})".format(step, current,
                                                 graph.states[current].label))
        matched = ", ".join("{} p={:.0%}".format(r.rule_id, r.probability)
                            for r in pred.matched) or "(none)"
        print("  matched: {}".format(matched))
        if pred.ask_model:
            raise SystemExit(
                "[step {}] FAIL: engine abstained at {} (confidence {:.0%} < "
                "{:.0%}); discuss".format(step, current, pred.confidence, threshold))
        nxt = pred.chosen
        print("  engine: {} -> {} ({:.0%})".format(current, nxt, pred.confidence))
        if nxt == FINISH:
            if state_present(current, nodes, graph, src, dst):
                print("\nSUCCESS: goal reached at {} ({})".format(
                    current, graph.states[current].label))
                return 0
            raise SystemExit("FAIL: finish decided but route screen not present")
        tr = next(t for t in graph.states[current].transitions if t.to == nxt)
        print("  action: {} | {}".format(tr.op, tr.target[:64]))
        if tr.needs_review:
            raise SystemExit(
                "FAIL: transition {} -> {} flagged needs_review ({})".format(
                    current, nxt, tr.review_reason))
        el = None
        if tr.op in ("click",):  # only element-based ops need a selector
            el, err = resolve(tr.find, nodes, src, dst)
            if el is None:
                raise SystemExit(
                    "[step {}] FAIL: cannot resolve selector for {} -> {} ({}); "
                    "discuss".format(step, current, nxt, err))
        note = execute(tr, el, src, dst)
        print("  executed: {}".format(note))
        time.sleep(WAIT_AFTER.get(tr.op, 2.5))
        nodes = dump_nodes()
        if any(n["text"] == "Something went wrong" for n in nodes):
            raise SystemExit(
                "[step {}] FAIL: app error dialog on screen (network/geocode "
                "failure); discuss".format(step))
        if not state_present(nxt, nodes, graph, src, dst):
            best, ratio = identify(nodes, graph)
            raise SystemExit(
                "[step {}] FAIL: {} not reached after {} (screen looks like "
                "{} {:.0%}); discuss".format(step, nxt, tr.op, best, ratio))
        print("  verified: reached {}".format(nxt))
        current = nxt
        calls.append(current)
    raise SystemExit("FAIL: max steps ({}) reached".format(max_steps))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mission", help="'navigate from <src> to <dst> by <mode>'")
    parser.add_argument("--threshold", type=float, default=0.2)
    parser.add_argument("--max-steps", type=int, default=20)
    args = parser.parse_args()
    if not 0.0 <= args.threshold <= 1.0:
        parser.error("--threshold must be in [0, 1]")
    raise SystemExit(run_mission(args.mission, args.threshold, args.max_steps))


if __name__ == "__main__":
    main()
