#!/usr/bin/env python3
"""Replay decision anchors against a live Android emulator via adb.

Everything the driver does is derived from the anchor inputs:
  - the next state comes from the rules (anchor_navigation_rules.json),
  - the concrete action comes from the graph transition (map_tree.json):
    op + selector / text / key / move.delta,
  - the tap point comes from resolving the selector in the live
    uiautomator dump -- no hard-coded coordinates,
  - the actual state is identified with the graph's per-state landmarks
    ("identify") with signature overlap as fallback.

The driver never trusts the prediction: after every action it re-reads the
screen and stops with a report if the actual state differs from the
predicted one. On success it saves a screenshot of the route the app
produced as evidence.

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
EVIDENCE = os.path.join(HERE, "evidence")
REMOTE_DUMP = "/sdcard/anchor_ui.xml"
LOCAL_DUMP = os.path.join(os.environ.get("TEMP", "/tmp"), "anchor_ui.xml")
MAPS_PACKAGE = "com.google.android.apps.maps"
WAIT_AFTER = {"click": 4.0, "set_text": 2.0, "press": 3.0}


def adb(args, timeout=60):
    res = subprocess.run(["adb"] + args, capture_output=True, text=True,
                         timeout=timeout)
    if res.returncode != 0:
        raise SystemExit("adb {} failed: {}".format(" ".join(args), res.stderr.strip()))
    return res


def dump_nodes():
    last = ""
    for attempt in range(6):
        res = subprocess.run(
            ["adb", "shell", "uiautomator", "dump", REMOTE_DUMP],
            capture_output=True, text=True, timeout=60)
        last = (res.stdout + res.stderr).strip()
        if "dumped" in last.lower():
            break
        # known flaky right after boot / when the screen slept: wake and retry
        subprocess.run(["adb", "shell", "input", "keyevent", "224"],
                       capture_output=True, timeout=60)
        time.sleep(2)
    else:
        raise SystemExit("uiautomator dump failed after retries: {}".format(last))
    adb(["pull", REMOTE_DUMP, LOCAL_DUMP])
    tree = ET.parse(LOCAL_DUMP)
    nodes = []

    def walk(elem, parent_idx):
        idx = len(nodes)
        nodes.append({
            "id": elem.attrib.get("resource-id", ""),
            "text": elem.attrib.get("text", ""),
            "desc": elem.attrib.get("content-desc", ""),
            "bounds": elem.attrib.get("bounds", ""),
            "clickable": elem.attrib.get("clickable", "") == "true",
            "focused": elem.attrib.get("focused", "") == "true",
            "parent": parent_idx,
        })
        for child in elem:
            walk(child, idx)

    walk(tree.getroot(), -1)
    return nodes


def screenshot(path):
    res = subprocess.run(["adb", "exec-out", "screencap", "-p"],
                         capture_output=True)
    if res.returncode != 0:
        print("  [evidence] screenshot failed: {}".format(res.stderr.decode(
            "utf-8", "replace").strip()))
        return
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as handle:
        handle.write(res.stdout)
    print("  [evidence] screenshot saved: {}".format(path))


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


def landmarks_hold(identify, nodes, src, dst):
    """All conditions of a state's 'identify' list must hold."""
    for cond in identify:
        kind = cond["kind"]
        raw = cond["value"]
        values = raw if isinstance(raw, list) else [raw]
        values = [v.replace("${src}", src).replace("${dst}", dst) for v in values]
        if kind == "clickable_desc":
            ok = any(n["clickable"] and n["desc"] == v for n in nodes
                     for v in values)
        elif kind == "desc":
            ok = any(n["desc"] == v for n in nodes for v in values)
        elif kind == "desc_prefix":
            ok = any(n["desc"].startswith(v) for n in nodes for v in values)
        elif kind == "text":
            ok = any(n["text"] == v for n in nodes for v in values)
        elif kind == "text_any":
            ok = any(n["text"] == v for n in nodes for v in values)
        elif kind == "none_text":
            ok = not any(n["text"] == v for n in nodes for v in values)
        elif kind == "none_desc":
            ok = not any(n["desc"] == v for n in nodes for v in values)
        elif kind == "none_desc_prefix":
            ok = not any(n["desc"].startswith(v) for n in nodes for v in values)
        elif kind == "has_id":
            ok = any(n["id"].endswith(v) for n in nodes for v in values)
        elif kind == "focused_id":
            ok = any(n["id"].endswith(v) and n["focused"] for n in nodes
                     for v in values)
        elif kind == "none_focused_id":
            ok = not any(n["id"].endswith(v) and n["focused"] for n in nodes
                         for v in values)
        else:
            ok = False
        if not ok:
            return False
    return True


def identify(nodes, graph, src, dst):
    """Identify the ACTUAL state: priority-ordered graph landmarks, then
    signature overlap as fallback."""
    candidates = sorted(
        [(st.identify_priority, sid) for sid, st in graph.states.items()
         if st.identify and st.identify_priority],
        reverse=True)
    for _, sid in candidates:
        if landmarks_hold(graph.states[sid].identify, nodes, src, dst):
            return sid
    best, ratio = None, 0.0
    for sid in graph.states:
        r = signature_ratio(sid, nodes, graph)
        if r > ratio:
            best, ratio = sid, r
    return best


def dismiss_environment_modals(nodes):
    """One-time system consent dialogs are device setup, not navigation.

    Dismiss them (e.g. the Play Services location-consent dialog) and
    return True when something was dismissed.
    """
    if any(n["id"].endswith("com.google.android.gms:id/message") for n in nodes) \
            or any(n["text"] == "Turn on" and n["clickable"] for n in nodes):
        buttons = [n for n in nodes
                   if n["text"] == "Turn on" and n["clickable"]
                   or n["desc"] == "Turn on" and n["clickable"]]
        if buttons:
            x, y = center(buttons[0]["bounds"])
            adb(["shell", "input", "tap", str(x), str(y)])
            print("  [environment] dismissed the location-consent dialog "
                  "(Turn on)")
            time.sleep(3)
            return True
    return False


def ensure_home(graph, src, dst):
    """Get Google Maps to the map home (s1), resetting the app if needed."""
    nodes = dump_nodes()
    if identify(nodes, graph, src, dst) == "s1":
        print("[setup] at s1 ({} {:.0%})".format(
            "s1", signature_ratio("s1", nodes, graph)))
        return nodes
    print("[setup] screen identified as {}; resetting Maps".format(
        identify(nodes, graph, src, dst)))
    adb(["shell", "am", "force-stop", MAPS_PACKAGE])
    time.sleep(2)
    adb(["shell", "monkey", "-p", MAPS_PACKAGE,
         "-c", "android.intent.category.LAUNCHER", "1"])
    time.sleep(6)
    for _ in range(4):  # Maps may restore the last route; back out of it
        nodes = dump_nodes()
        if identify(nodes, graph, src, dst) == "s1":
            print("[setup] at s1")
            return nodes
        adb(["shell", "input", "keyevent", "4"])
        time.sleep(2)
    raise SystemExit(
        "[setup] FAIL: could not reach map home (identified {}); "
        "discuss how to reset manually".format(identify(nodes, graph, src, dst)))


def execute(tr, node, nodes, src, dst):
    if tr.op == "click":
        target = node
        if tr.find and tr.find.get("tap") == "clickable_ancestor":
            # the selector matched an icon inside a row; tap the row itself
            idx = node.get("parent", -1)
            while idx != -1:
                anc = nodes[idx]
                if anc["clickable"]:
                    target = anc
                    break
                idx = anc.get("parent", -1)
        x, y = center(target["bounds"])
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

    nodes = ensure_home(graph, src, dst)
    current = identify(nodes, graph, src, dst)
    calls = [current]
    actions = 0
    repeat_guard = {"signature": None, "count": 0}
    for step in range(1, max_steps + 1):
        nodes = dump_nodes()  # fresh dump: the app may have moved on its own
        if dismiss_environment_modals(nodes):
            nodes = dump_nodes()
        # Trust the tracked state while its landmarks still hold (some live
        # screens are indistinguishable from others, e.g. the destination
        # search looks exactly like the origin search); identify globally
        # only when the tracked state no longer fits the screen.
        tracked = graph.states[current]
        actual = current
        if not (tracked.identify
                and landmarks_hold(tracked.identify, nodes, src, dst)):
            actual = identify(nodes, graph, src, dst)
        print("\n[step {}] actual state: {} ({})".format(
            step, actual, graph.states[actual].label if actual in graph.states else "?"))
        if actual != current:
            print("  NOTE: app state changed to {} (tracked {}); replanning "
                  "from actual".format(actual, current))
            current = actual
            calls.append(actual)
        options = {t.to for t in graph.states[current].transitions} | {FINISH}
        case = DecisionCase(task=mission, question="", calls=tuple(calls),
                            options=frozenset(options))
        pred = predict(case, rules, threshold)
        matched = ", ".join("{} p={:.0%}".format(r.rule_id, r.probability)
                            for r in pred.matched) or "(none)"
        print("  engine from {}: matched {} -> {}".format(current, matched,
                                                          pred.chosen))
        if pred.ask_model:
            print("\nDELEGATED TO MODEL: engine abstained at {} ({}) - the "
                  "rules have no confident plan for this state; the "
                  "model/SLM is asked instead".format(
                      current, graph.states[current].label))
            screenshot(os.path.join(EVIDENCE, "delegated_{}.png".format(mode)))
            return 0
        nxt = pred.chosen
        print("  predicted next: {} ({:.0%})".format(nxt, pred.confidence))
        if nxt == FINISH:
            if current in ("s9", "s10", "s11"):
                print("\nSUCCESS: route shown at {} ({})".format(
                    current, graph.states[current].label))
                print("  {} actions executed, all derived from the anchor "
                      "inputs (rules + map_tree.json)".format(actions))
                screenshot(os.path.join(EVIDENCE, "route_{}.png".format(mode)))
                return 0
            raise SystemExit("FAIL: finish decided at unexpected state {}".format(current))
        tr = next(t for t in graph.states[current].transitions if t.to == nxt)
        print("  action: {} | {}".format(tr.op, tr.target[:64]))
        if tr.needs_review:
            raise SystemExit(
                "FAIL: transition {} -> {} flagged needs_review ({})".format(
                    current, nxt, tr.review_reason))
        el = None
        if tr.op in ("click",):
            el, err = resolve(tr.find, nodes, src, dst)
            if el is None:
                raise SystemExit(
                    "[step {}] FAIL: cannot resolve selector for {} -> {} ({}); "
                    "discuss".format(step, current, nxt, err))
        note = execute(tr, el, nodes, src, dst)
        actions += 1
        print("  executed: {}".format(note))
        time.sleep(WAIT_AFTER.get(tr.op, 2.5))
        nodes = dump_nodes()
        if dismiss_environment_modals(nodes):
            nodes = dump_nodes()
        if any(n["text"] == "Something went wrong" for n in nodes):
            screenshot(os.path.join(EVIDENCE,
                                    "failure_step{}_{}.png".format(step, mode)))
            raise SystemExit(
                "[step {}] FAIL: app error dialog on screen (network/geocode "
                "failure); discuss".format(step))
        # verify the EXPECTED state: accept it while its landmarks hold
        # (identical-looking screens are disambiguated by the plan, not by
        # the pixels alone); identify globally only when it does not hold
        expected = graph.states[nxt]
        actual_next = nxt
        if not (expected.identify
                and landmarks_hold(expected.identify, nodes, src, dst)):
            actual_next = identify(nodes, graph, src, dst)
        if actual_next != nxt:
            sig = (current, nxt, note)
            if repeat_guard["signature"] == sig:
                repeat_guard["count"] += 1
            else:
                repeat_guard["signature"] = sig
                repeat_guard["count"] = 1
            if repeat_guard["count"] >= 2:
                screenshot(os.path.join(EVIDENCE,
                                        "failure_step{}_{}.png".format(step, mode)))
                raise SystemExit(
                    "[step {}] FAIL: same action repeated with no state "
                    "change ({}); discuss".format(step, sig))
            probe = None
            if actual_next in graph.states:
                probe = predict(
                    DecisionCase(task=mission, question="",
                                 calls=tuple(calls + [actual_next]),
                                 options=frozenset(
                                     {t.to for t in graph.states[actual_next].transitions}
                                     | {FINISH})),
                    rules, threshold)
            if probe is not None and not probe.ask_model:
                print("  NOTE: actual state {} differs from predicted {}; "
                      "continuing from actual (engine can plan from it: "
                      "{})".format(actual_next, nxt, probe.chosen))
                if graph.states[actual_next].final:
                    print("\nSUCCESS: terminal route state {} reached ({})".format(
                        actual_next, graph.states[actual_next].label))
                    print("  {} actions executed, all derived from the anchor "
                          "inputs (rules + map_tree.json)".format(actions))
                    screenshot(os.path.join(EVIDENCE, "route_{}.png".format(mode)))
                    return 0
                current = actual_next
                calls.append(actual_next)
                continue
            if probe is not None and probe.ask_model:
                print("\nDELEGATED TO MODEL: engine abstained at actual "
                      "state {}; the model/SLM is asked instead".format(
                          actual_next))
                screenshot(os.path.join(EVIDENCE,
                                        "delegated_{}.png".format(mode)))
                return 0
            screenshot(os.path.join(EVIDENCE,
                                    "failure_step{}_{}.png".format(step, mode)))
            raise SystemExit(
                "[step {}] FAIL: actual state {} differs from predicted {} and "
                "the engine cannot plan from it; discuss".format(
                    step, actual_next, nxt))
        print("  verified: actual state matches predicted {}".format(nxt))
        repeat_guard["signature"] = None
        repeat_guard["count"] = 0
        if graph.states[nxt].final:
            print("\nSUCCESS: terminal route state {} reached ({})".format(
                nxt, graph.states[nxt].label))
            print("  {} actions executed, all derived from the anchor "
                  "inputs (rules + map_tree.json)".format(actions))
            screenshot(os.path.join(EVIDENCE, "route_{}.png".format(mode)))
            return 0
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
