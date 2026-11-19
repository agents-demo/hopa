#!/usr/bin/env python3
"""Generate ANCHOR_REPORT.md from the anchor data (rules + cases + graph).

The report shows, for every case: the current state, the rules that fired,
the per-next-state scores (raw vote and normalized share), the chosen
decision against the threshold gate, and the concrete action the graph
would execute for it. Regenerate any time the data changes:

    python anchor_report.py [--threshold 0.2]
"""
import argparse
import os
from datetime import datetime, timezone

from anchor_decisions_demo import (ASK_MODEL, FINISH, load_cases, load_graph,
                                   load_rules, predict)

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "ANCHOR_REPORT.md")


def action_for(graph, current, decision):
    """Describe the concrete action for transition current -> decision."""
    if decision == FINISH:
        return "stay (goal reached)"
    state = graph.states.get(current)
    if state is None:
        return "(not in graph)"
    for tr in state.transitions:
        if tr.to != decision:
            continue
        if tr.find:
            match = "~{}".format(tr.find.get("match", "exact"))
            if "child_index" in tr.find:
                match += " #{}".format(tr.find["child_index"])
            sel = "find {}=\"{}\"{}".format(tr.find["by"], tr.find["value"], match)
        elif tr.text is not None:
            sel = "type {!r}".format(tr.text)
        elif tr.key:
            sel = "press {}".format(tr.key)
        else:
            sel = "swipe/drag delta {}".format(tr.move.get("delta")
                                               if tr.move else "?")
        return "{}{} ({})".format(tr.op, " [NEEDS REVIEW]" if tr.needs_review else "",
                                  sel)
    return "(no transition)"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--threshold", type=float, default=0.2)
    parser.add_argument("--verbose", action="store_true",
                        help="add a rule-by-rule evaluation trace (intent / "
                             "progress / option gate) and full action detail "
                             "to every case")
    args = parser.parse_args()
    rules = load_rules(os.path.join(HERE, "anchor_navigation_rules.json"))
    cases = load_cases(os.path.join(HERE, "anchor_navigation_cases.json"))
    graph = load_graph(os.path.join(HERE, "map_tree.json"))
    n_transitions = sum(len(s.transitions) for s in graph.states.values())

    w = []
    w.append("# Anchor Decision Engine — Report")
    w.append("")
    w.append("Generated {} by `anchor_report.py`. Data: `map_tree.json` "
             "({} states, {} transitions), `anchor_navigation_rules.json` "
             "({} rules), `anchor_navigation_cases.json` ({} cases). "
             "Threshold: {:.0%}.".format(
                 datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC"),
                 len(graph.states), n_transitions, len(rules), len(cases),
                 args.threshold))
    w.append("")
    w.append("## How a decision is made")
    w.append("")
    w.append("1. **Current state** = last element of `calls` (the UI history).")
    w.append("2. **Rules fire** when all three hold: the intent cue matches the "
             "command (`question_word` / `task_word` / `task_bigram`, any-of "
             "lists allowed), the progress cue matches the history "
             "(`last_call` / `history_has` / `no_calls`), and the rule's "
             "decision is among the case's `options` (available-option gate).")
    w.append("3. **Votes are max-aggregated** per next state.")
    w.append("4. **Chosen** = state with the highest RAW vote (ties keep rule "
             "order).")
    w.append("5. **Gate**: no rule fired, or highest raw vote < {:.0%} → "
             "**ASK MODEL** (teacher/SLM fallback); nothing is executed "
             "blindly.".format(args.threshold))
    w.append("6. **Action selection**: the graph transition "
             "`current → chosen` supplies the operation + selector "
             "(`find` / `text` / `key` / `move.delta`); `anchor_replay.py` "
             "resolves the selector against the live uiautomator dump at "
             "runtime — no hard-coded coordinates.")
    w.append("")
    w.append("## Summary matrix (per state, from the cases)")
    w.append("")
    w.append("| Current state | Next-state scores | Outcome |")
    w.append("|---|---|---|")
    by_state = {}
    for case in cases:
        current = case.calls[-1] if case.calls else "(none)"
        pred = predict(case, rules, args.threshold)
        by_state.setdefault(current, []).append((case, pred))
    for current in sorted(by_state, key=lambda s: (len(s), s)):
        entries = {}
        abstained = 0
        single_outcome = None
        for case, pred in by_state[current]:
            for decision, p in pred.distribution:
                entries[decision] = max(entries.get(decision, 0.0), p)
            if pred.ask_model:
                abstained += 1
            elif single_outcome is None:
                single_outcome = pred.chosen
        label = graph.states[current].label if current in graph.states else ""
        parts = ["{} {:.0%}".format(d, p)
                 for d, p in sorted(entries.items(), key=lambda kv: -kv[1])]
        if abstained:
            parts.append("ASK MODEL ({} case{})".format(
                abstained, "s" if abstained > 1 else ""))
        if len(by_state[current]) == 1:
            outcome = single_outcome or "ASK MODEL"
        else:
            outcome = "mode-dependent"
        w.append("| {} ({}) | {} | {} |".format(current, label,
                                                " · ".join(parts), outcome))
    w.append("")
    w.append("(Per-mode detail at s9: `finish` 92% when the command says car, "
             "`s11` 90% for walk, `s10` 88% for public transport/bus; with no "
             "or unknown mode the only vote is 10% → ASK MODEL.)")
    w.append("")
    w.append("## Case-by-case details")
    w.append("")
    for i, case in enumerate(cases, 1):
        current = case.calls[-1] if case.calls else "(none)"
        label = graph.states[current].label if current in graph.states else ""
        pred = predict(case, rules, args.threshold)
        w.append("### Case {} — state {} ({})".format(i, current, label))
        w.append("")
        w.append("- Command: `{}`".format(case.task))
        if case.question:
            w.append("- Question: `{}`".format(case.question))
        w.append("- Options considered: {}".format(", ".join(sorted(case.options))))
        w.append("- Matched rules:")
        for r in pred.matched:
            w.append("  - `{}` p={:.0%}: {}".format(r.rule_id, r.probability,
                                                     r.description))
        if not pred.matched:
            w.append("  - (none)")
        if args.verbose:
            w.append("")
            w.append("Rule-by-rule trace (intent / progress / in-options):")
            w.append("")
            w.append("| Rule | p | intent | progress | in-options | fires |")
            w.append("|---|---|---|---|---|---|")
            for r in rules:
                t = r.trace(case)
                w.append("| `{}` | {:.0%} | {} | {} | {} | {} |".format(
                    r.rule_id, r.probability,
                    "yes" if t.intent else "no",
                    "yes" if t.progress else "no",
                    "yes" if t.in_options else "no",
                    "YES" if t.fires else "-"))
            w.append("")
        w.append("")
        w.append("| Next state | Raw vote | Normalized | Action |")
        w.append("|---|---|---|---|")
        norm = dict(pred.normalized)
        for decision, p in pred.distribution:
            dlabel = graph.states[decision].label if decision in graph.states else ""
            w.append("| {} — {} | {:.0%} | {:.0%} | {} |".format(
                decision, dlabel, p, norm.get(decision, 0.0),
                action_for(graph, current, decision)))
        w.append("")
        if pred.ask_model:
            reason = ("no rule fired" if pred.chosen is None
                      else "max vote {:.0%} < {:.0%}".format(
                          pred.confidence, args.threshold))
            w.append("**ASK MODEL** — {} (teacher/SLM fallback)".format(reason))
        else:
            w.append("**DECISION: {}** ({:.0%} ≥ {:.0%})".format(
                pred.chosen, pred.confidence, args.threshold))
        if args.verbose and not pred.ask_model and pred.chosen != FINISH:
            tr = next((t for t in graph.states[current].transitions
                       if t.to == pred.chosen), None)
            if tr is not None:
                w.append("")
                w.append("Action detail: `op={}` `find={}` `text={}` "
                         "`key={}` `move={}`".format(
                             tr.op, tr.find, tr.text, tr.key, tr.move))
        if case.expected:
            actual = ASK_MODEL if pred.ask_model else pred.chosen
            w.append("")
            w.append("Expected: {} → {}".format(
                case.expected, "MATCH" if actual == case.expected else "MISMATCH"))
        w.append("")
    w.append("## Model-fallback cases (where the concept hands over)")
    w.append("")
    for i, case in enumerate(cases, 1):
        pred = predict(case, rules, args.threshold)
        if pred.ask_model:
            reason = ("no rule fired" if pred.chosen is None
                      else "max vote {:.0%} < {:.0%}".format(
                          pred.confidence, args.threshold))
            w.append("- Case {} ({}): {} — {}".format(i, case.task, reason,
                                                      case.expected))
    w.append("")

    out = os.path.join(HERE, "ANCHOR_REPORT_VERBOSE.md" if args.verbose
                       else "ANCHOR_REPORT.md")
    with open(out, "w", encoding="utf-8", newline="\n") as handle:
        handle.write("\n".join(w))
    print("wrote {} ({} cases{})".format(
        out, len(cases), ", verbose" if args.verbose else ""))


if __name__ == "__main__":
    main()
