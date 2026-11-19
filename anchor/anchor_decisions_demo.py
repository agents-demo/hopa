#!/usr/bin/env python3
"""Decision Anchors Demo: dependency-free Python rule engine, data-driven edition.

Python 3.8+; stdlib only (json, argparse, dataclasses, unittest, statistics,
time, os). No installs, model, GPU, network, or online learning required.

Rules, cases and the UI state graph are NOT hardcoded: they are loaded from
external JSON files (see --rules / --cases / --graph). The data set
implements Google Maps navigation ("navigate from ${src} to ${dst} by ...",
mode = car / walk / public transport). The graph is converted from the
captured UI state tree in map_tree.xml (see map_tree_to_json.py): addresses
are templated as ${src} / ${dst}, and transitions carry selectors ("find")
instead of hard-coded tap points, so the engine locates the button at
runtime (substitute real addresses before replaying).

Semantics: the current state is the last element of `calls`; every firing
rule votes for a next state with a probability. Votes for the same state are
max-aggregated. If the highest raw probability is below --threshold (default
0.2 = 20%) the engine abstains ("ASK MODEL") and the teacher is asked
instead. No action is ever executed here; a match is not approval to act.

Run:
    python anchor_decisions_demo.py
    python anchor_decisions_demo.py --case 13
    python anchor_decisions_demo.py --list-rules
    python anchor_decisions_demo.py --iterations 10000 --teacher-ms 400
    python anchor_decisions_demo.py --threshold 0.1 --case 13
    python anchor_decisions_demo.py --self-test

Importable API: DecisionCase, AnchorRule, Prediction, Transition, GraphState,
Graph, words, load_rules, load_cases, load_graph, validate_data, decide,
predict.

Provenance: ports the rule/decision engine embedded in the Android
AnchorDecisionsDemo-0.1.0 (Nov 5, 2026), extended with (1) rules/cases/graph
from external JSON, (2) intent_value lists ("any word of"), (3) a per-rule
probability, and (4) a confidence threshold that falls back to the model.
The navigation probabilities are ILLUSTRATIVE: assigned by hand from the
map_tree.json transition structure, not estimated from a held-out evaluation.
The original APK's historical figures (152/2364 = 6.43% coverage, 0 observed
disagreements) were exploratory and belong to that demo's data only, not to
this navigation data set. The benchmark uses perf_counter_ns rather than
Java System.nanoTime; timings are Python on YOUR CPU, not Android timings
or a model comparison.
"""

import argparse
import json
import os
import re
import statistics
import time
from collections import Counter
from dataclasses import dataclass, replace
from typing import Dict, FrozenSet, Optional, Sequence, Tuple, Union

_HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULT_RULES = os.path.join(_HERE, "anchor_navigation_rules.json")
DEFAULT_CASES = os.path.join(_HERE, "anchor_navigation_cases.json")
DEFAULT_GRAPH = os.path.join(_HERE, "map_tree.json")
DEFAULT_THRESHOLD = 0.2
ASK_MODEL = "ask_model"
FINISH = "finish"  # synthetic "goal reached, stay" state (not in the graph)

# Populated by main(); library callers pass explicit arguments instead.
RULES: Tuple["AnchorRule", ...] = ()
CASES: Tuple["DecisionCase", ...] = ()
GRAPH: Optional["Graph"] = None

_WORD_SPLIT = re.compile(r"[^a-z0-9_]+")


def words(text: str) -> Tuple[str, ...]:
    """Match the APK's lowercase ASCII word feature space (empty tokens dropped)."""
    return tuple(w for w in _WORD_SPLIT.split((text or "").lower()) if w)


@dataclass(frozen=True)
class DecisionCase:
    task: str
    question: str
    calls: Tuple[str, ...]
    options: FrozenSet[str]
    # Test metadata: the expected next state, or "ask_model" when the
    # engine must fall back to the model. Not part of the decision input.
    expected: Optional[str] = None


@dataclass(frozen=True)
class AnchorRule:
    rule_id: str
    decision: str
    intent_kind: str
    intent_value: Union[str, Tuple[str, ...]]
    progress_kind: str
    progress_value: Optional[str]
    probability: float
    description: str
    heldout_correct: int = 0
    heldout_total: int = 0

    def fires(self, case: DecisionCase) -> bool:
        values: Sequence[str] = (
            self.intent_value
            if isinstance(self.intent_value, (list, tuple))
            else (self.intent_value,)
        )
        if self.intent_kind == "question_word":
            intent = any(v in words(case.question) for v in values)
        elif self.intent_kind == "task_word":
            intent = any(v in words(case.task) for v in values)
        elif self.intent_kind == "task_bigram":
            tokens = words(case.task)
            bigrams = {a + "_" + b for a, b in zip(tokens, tokens[1:])}
            intent = any(v in bigrams for v in values)
        else:
            return False

        if self.progress_kind == "last_call":
            progress = bool(case.calls) and case.calls[-1] == self.progress_value
        elif self.progress_kind == "history_has":
            progress = self.progress_value in case.calls
        elif self.progress_kind == "no_calls":
            progress = not case.calls
        else:
            return False
        return intent and progress and self.decision in case.options


@dataclass(frozen=True)
class Prediction:
    distribution: Tuple[Tuple[str, float], ...]  # raw vote per decision, rule order
    normalized: Tuple[Tuple[str, float], ...]    # raw votes scaled to sum to 1
    chosen: Optional[str]
    confidence: float                            # highest raw vote
    ask_model: bool
    matched: Tuple[AnchorRule, ...]


def decide(case: DecisionCase, rules: Sequence[AnchorRule] = None) -> Optional[AnchorRule]:
    """Return the FIRST firing rule, or None (engine primitive kept from the port)."""
    if rules is None:
        rules = RULES
    for rule in rules:
        if rule.fires(case):
            return rule
    return None


def predict(case: DecisionCase, rules: Sequence[AnchorRule] = None,
            threshold: float = DEFAULT_THRESHOLD) -> Prediction:
    """Aggregate every firing rule into a next-state probability distribution.

    Votes for the same decision are max-aggregated. The gate uses the RAW
    highest vote (not the normalized share): if no rule fires, or the highest
    raw vote is below `threshold`, the engine abstains (ask_model=True) and
    the teacher/model is asked instead. Executes no action.
    """
    if rules is None:
        rules = RULES
    matched = tuple(rule for rule in rules if rule.fires(case))
    raw: Dict[str, float] = {}
    for rule in matched:
        if rule.probability > raw.get(rule.decision, -1.0):
            raw[rule.decision] = rule.probability
    total = sum(raw.values())
    normalized = tuple((d, p / total) for d, p in raw.items()) if total > 0 else ()
    chosen = max(raw, key=lambda d: raw[d]) if raw else None  # ties keep rule order
    confidence = raw[chosen] if chosen is not None else 0.0
    ask_model = chosen is None or confidence < threshold
    return Prediction(tuple(raw.items()), normalized, chosen, confidence, ask_model, matched)


# ---------------------------------------------------------------------------
# External data loading
# ---------------------------------------------------------------------------

INTENT_KINDS = ("question_word", "task_word", "task_bigram")
PROGRESS_KINDS = ("last_call", "history_has", "no_calls")


def _load_json(path: str) -> dict:
    try:
        with open(path, encoding="utf-8") as handle:
            data = json.load(handle)
    except (OSError, ValueError) as exc:
        raise ValueError("cannot read {}: {}".format(path, exc)) from exc
    if not isinstance(data, dict):
        raise ValueError("{}: top level must be a JSON object".format(path))
    return data


def _fail(path: str, item: dict, message: str) -> "ValueError":
    entry = item.get("id") if isinstance(item, dict) else None
    return ValueError("{}: entry {!r}: {}".format(path, entry, message))


def _require_str(path: str, item: dict, key: str, allow_empty: bool = False) -> str:
    value = item.get(key)
    if not isinstance(value, str) or (not value and not allow_empty):
        raise _fail(path, item, "field '{}' must be a string{}".format(
            key, "" if allow_empty else " and not empty"))
    return value


def _coerce_intent_value(path: str, item: dict,
                         value: object) -> Union[str, Tuple[str, ...]]:
    if isinstance(value, str) and value:
        return value
    if (isinstance(value, list) and value
            and all(isinstance(v, str) and v for v in value)):
        values = tuple(value)
        return values[0] if len(values) == 1 else values
    raise _fail(path, item, "'intent_value' must be a non-empty string or a "
                "non-empty list of strings")


def load_rules(path: str) -> Tuple[AnchorRule, ...]:
    """Load a rules JSON file; returns the rules in file order."""
    data = _load_json(path)
    raw_rules = data.get("rules")
    if not isinstance(raw_rules, list) or not raw_rules:
        raise ValueError("{}: 'rules' must be a non-empty list".format(path))
    rules = []
    for item in raw_rules:
        if not isinstance(item, dict):
            raise ValueError("{}: every rule must be an object".format(path))
        decision = _require_str(path, item, "decision")
        intent_kind = _require_str(path, item, "intent_kind")
        if intent_kind not in INTENT_KINDS:
            raise _fail(path, item, "unknown intent_kind {!r} (expected one of {})".format(
                intent_kind, ", ".join(INTENT_KINDS)))
        intent_value = _coerce_intent_value(path, item, item.get("intent_value"))
        progress_kind = _require_str(path, item, "progress_kind")
        if progress_kind not in PROGRESS_KINDS:
            raise _fail(path, item, "unknown progress_kind {!r} (expected one of {})".format(
                progress_kind, ", ".join(PROGRESS_KINDS)))
        progress_value = item.get("progress_value")
        if progress_kind == "no_calls":
            if progress_value is not None:
                raise _fail(path, item, "'progress_value' must be null for no_calls")
        elif not isinstance(progress_value, str) or not progress_value:
            raise _fail(path, item, "'progress_value' must be a non-empty string")
        probability = item.get("probability")
        if (isinstance(probability, bool) or not isinstance(probability, (int, float))
                or not 0.0 <= probability <= 1.0):
            raise _fail(path, item, "'probability' must be a number in [0, 1]")
        rules.append(AnchorRule(
            rule_id=item.get("id", ""),
            decision=decision,
            intent_kind=intent_kind,
            intent_value=intent_value,
            progress_kind=progress_kind,
            progress_value=progress_value,
            probability=float(probability),
            description=_require_str(path, item, "description"),
            heldout_correct=int(item.get("heldout_correct", 0) or 0),
            heldout_total=int(item.get("heldout_total", 0) or 0),
        ))
    return tuple(rules)


def load_cases(path: str) -> Tuple[DecisionCase, ...]:
    """Load a cases JSON file; returns the cases (expected outcomes included)."""
    data = _load_json(path)
    raw_cases = data.get("cases")
    if not isinstance(raw_cases, list) or not raw_cases:
        raise ValueError("{}: 'cases' must be a non-empty list".format(path))
    cases = []
    for item in raw_cases:
        if not isinstance(item, dict):
            raise ValueError("{}: every case must be an object".format(path))
        task = _require_str(path, item, "task")
        question = _require_str(path, item, "question", allow_empty=True)
        calls = item.get("calls", [])
        options = item.get("options", [])
        if not isinstance(calls, list) or not all(isinstance(c, str) and c for c in calls):
            raise _fail(path, item, "'calls' must be a list of non-empty strings")
        if not isinstance(options, list) or not all(isinstance(o, str) and o for o in options):
            raise _fail(path, item, "'options' must be a list of non-empty strings")
        expected = item.get("expected")
        if expected is not None and not isinstance(expected, str):
            raise _fail(path, item, "'expected' must be a string or absent")
        options_set = frozenset(options)
        if isinstance(expected, str) and expected != ASK_MODEL and expected not in options_set:
            raise _fail(path, item, "expected {!r} is not one of the options".format(expected))
        cases.append(DecisionCase(task, question, tuple(calls), options_set, expected))
    return tuple(cases)


@dataclass(frozen=True)
class Transition:
    to: str
    op: str
    action: str = ""
    target: str = ""
    find: Optional[dict] = None       # selector resolved at runtime, never a point
    move: Optional[dict] = None       # drag/swipe delta, e.g. {"delta": [0, 126]}
    text: Optional[str] = None        # set_text payload
    key: Optional[str] = None         # press key name
    needs_review: bool = False
    review_reason: str = ""


@dataclass(frozen=True)
class GraphState:
    state_id: str
    label: str
    final: bool
    transitions: Tuple[Transition, ...]
    explored: Tuple[str, ...]
    resource_ids: FrozenSet[str]


@dataclass(frozen=True)
class Graph:
    meta: Dict[str, str]
    states: Dict[str, GraphState]


def load_graph(path: str) -> Graph:
    """Load the UI state graph (map_tree.json); returns a Graph."""
    data = _load_json(path)
    meta = data.get("meta")
    raw_states = data.get("states")
    if not isinstance(meta, dict):
        raise ValueError("{}: 'meta' must be an object".format(path))
    if not isinstance(raw_states, list) or not raw_states:
        raise ValueError("{}: 'states' must be a non-empty list".format(path))
    states: Dict[str, GraphState] = {}
    for item in raw_states:
        if not isinstance(item, dict):
            raise ValueError("{}: every state must be an object".format(path))
        sid = _require_str(path, item, "id")
        transitions = []
        for tr in item.get("transitions", []):
            if not isinstance(tr, dict):
                raise ValueError("{}: state {}: every transition must be an object".format(
                    path, sid))
            if "point" in tr or "raw_adb" in tr:
                raise ValueError(
                    "{}: state {}: transitions must not carry 'point'/'raw_adb' "
                    "(selectors only, resolved at runtime)".format(path, sid))
            transitions.append(Transition(
                to=_require_str(path, tr, "to"),
                op=_require_str(path, tr, "op"),
                action=tr.get("action", ""),
                target=tr.get("target", ""),
                find=tr.get("find"),
                move=tr.get("move"),
                text=tr.get("text"),
                key=tr.get("key"),
                needs_review=bool(tr.get("needs_review", False)),
                review_reason=tr.get("review_reason", ""),
            ))
        explored = item.get("explored", [])
        if not isinstance(explored, list) or not all(isinstance(e, str) for e in explored):
            raise _fail(path, item, "'explored' must be a list of strings")
        signature = item.get("signature") or {}
        resource_ids = signature.get("resource_ids", [])
        if not isinstance(resource_ids, list):
            raise _fail(path, item, "'signature.resource_ids' must be a list")
        states[sid] = GraphState(
            state_id=sid,
            label=_require_str(path, item, "label"),
            final=bool(item.get("final", False)),
            transitions=tuple(transitions),
            explored=tuple(explored),
            resource_ids=frozenset(resource_ids),
        )
    return Graph(meta=dict(meta), states=states)


def validate_data(graph: Graph, rules: Sequence[AnchorRule],
                  cases: Sequence[DecisionCase]) -> None:
    """Cross-check rules/cases against the graph; raises ValueError on drift."""
    problems = []
    allowed = set(graph.states) | {FINISH}
    for rule in rules:
        if rule.decision not in allowed:
            problems.append("rule {!r}: decision {!r} is not a graph state".format(
                rule.rule_id, rule.decision))
        if rule.progress_kind != "no_calls" and rule.progress_value not in allowed:
            problems.append("rule {!r}: progress {!r} is not a graph state".format(
                rule.rule_id, rule.progress_value))
    for case in cases:
        for call in case.calls:
            if call not in allowed:
                problems.append("case {!r}: call {!r} is not a graph state".format(
                    case.task, call))
        if case.calls:
            current = case.calls[-1]
            if current in graph.states:
                children = {t.to for t in graph.states[current].transitions}
                extra = case.options - children - {FINISH}
                if extra:
                    problems.append(
                        "case {!r}: options {} are not transitions of {} "
                        "(children: {})".format(case.task, sorted(extra), current,
                                                sorted(children)))
    if problems:
        raise ValueError("data/graph drift:\n  " + "\n  ".join(problems))


# ---------------------------------------------------------------------------
# Display, benchmark, tests
# ---------------------------------------------------------------------------

def _transition_summary(graph: Graph, current: Optional[str], decision: str) -> str:
    if decision == FINISH:
        return "goal reached (stay)"
    if current is None or current not in graph.states:
        return ""
    for tr in graph.states[current].transitions:
        if tr.to == decision:
            note = " [NEEDS REVIEW]" if tr.needs_review else ""
            return "{}{} {}".format(tr.op, note, tr.target[:48])
    return "(not a transition of {})".format(current)


def show_case(index: int, case: DecisionCase, rules: Sequence[AnchorRule],
              threshold: float, graph: Graph) -> None:
    # Same 200-evaluation sampling pattern as the APK, including Python overhead.
    durations = []
    prediction = Prediction((), (), None, 0.0, True, ())
    for _ in range(200):
        start = time.perf_counter_ns()
        prediction = predict(case, rules, threshold)
        durations.append(time.perf_counter_ns() - start)
    state = case.calls[-1] if case.calls else None
    print("\nCase {}: {}".format(index, case.task))
    print("  Question: {}".format(case.question or "(none)"))
    print("  History: {}".format(" -> ".join(case.calls) or "(none)"))
    if state is not None and state in graph.states:
        print("  Current state: {} - {}".format(state, graph.states[state].label))
    print("  Available next states: {}".format(", ".join(sorted(case.options)) or "(none)"))
    for rule in prediction.matched:
        print("  Matched {} (p={:.0%}): {}".format(rule.rule_id, rule.probability,
                                                   rule.description))
    if prediction.matched:
        print("  Next-state probabilities (raw -> normalized):")
        normalized = dict(prediction.normalized)
        for decision, probability in prediction.distribution:
            label = graph.states[decision].label if decision in graph.states else ""
            suffix = " - " + label if label else ""
            summary = _transition_summary(graph, state, decision)
            print("    {:<10} {:>6.1%} -> {:>6.1%}{}{}".format(
                decision, probability, normalized.get(decision, 0.0), suffix,
                " | " + summary if summary else ""))
    if prediction.ask_model:
        if prediction.chosen is None:
            reason = "no rule fired"
        else:
            reason = "max vote {:.1%} < threshold {:.1%}".format(
                prediction.confidence, threshold)
        print("  -> ASK MODEL ({})".format(reason))
    else:
        print("  -> DECISION: {} ({:.1%} >= threshold {:.1%})".format(
            prediction.chosen, prediction.confidence, threshold))
    if case.expected is not None:
        actual = ASK_MODEL if prediction.ask_model else prediction.chosen
        print("  Expected: {} -> {}".format(case.expected,
                                            "MATCH" if actual == case.expected else "MISMATCH"))
    print("  Measured Python rule evaluation: {:.2f} us (median of 200)".format(
        statistics.median(durations) / 1000))


def benchmark(rules: Sequence[AnchorRule], cases: Sequence[DecisionCase],
              threshold: float, iterations: int, teacher_ms: float) -> None:
    hits = 0
    start = time.perf_counter_ns()
    for i in range(iterations):
        if not predict(cases[i % len(cases)], rules, threshold).ask_model:
            hits += 1
    total_ms = (time.perf_counter_ns() - start) / 1_000_000
    per_ms = total_ms / iterations
    # Sequential-wait toy model, not measured teacher performance:
    baseline_ms = iterations * teacher_ms
    hybrid_ms = total_ms + (iterations - hits) * teacher_ms
    print("\nBenchmark: {:,} decisions cycling over {} cases".format(iterations, len(cases)))
    print("  Threshold: {:.0%} (below this the model is asked)".format(threshold))
    print("  Measured local loop: {:.2f} ms total; {:.2f} us/decision".format(
        total_ms, per_ms * 1000))
    print("  Local decisions: {:,}/{:,} ({:.1f}%); model fallbacks: {:,}".format(
        hits, iterations, 100 * hits / iterations, iterations - hits))
    print("  Illustrative hit rate only; probabilities are hand-assigned, not measured.")
    print("  SIMULATED teacher latency: {:g} ms/call; teacher calls made: 0".format(teacher_ms))
    print("  Hypothetical all-teacher sequential wait: {:.2f} s".format(baseline_ms / 1000))
    print("  Hypothetical rules + fallback wait: {:.2f} s".format(hybrid_ms / 1000))
    print("  Hypothetical net wait saved: {:.2f} s".format((baseline_ms - hybrid_ms) / 1000))
    print("  Includes rule-loop cost for ALL decisions, including abstentions.")
    print("  No GPU, energy, FLOP, or actual teacher-time savings measured.")


def _case_for_rule(rule: AnchorRule) -> DecisionCase:
    """Build a minimal case that must fire exactly this rule (test helper)."""
    values = (rule.intent_value if isinstance(rule.intent_value, (list, tuple))
              else (rule.intent_value,))
    first = values[0]
    task = ""
    question = ""
    if rule.intent_kind == "question_word":
        question = "x " + first + " y"
    elif rule.intent_kind == "task_word":
        task = "x " + first + " y"
    elif rule.intent_kind == "task_bigram":
        task = first.replace("_", " ")
    calls: Tuple[str, ...] = ()
    if rule.progress_kind in ("last_call", "history_has"):
        calls = (rule.progress_value or "",)
    return DecisionCase(task, question, calls, frozenset((rule.decision,)))


def self_test(rules: Tuple[AnchorRule, ...], cases: Tuple[DecisionCase, ...],
              graph: Graph, threshold: float) -> None:
    import unittest

    def mini_rule(decision: str = FINISH, intent_kind: str = "task_word",
                  intent_value: Union[str, Tuple[str, ...]] = "car",
                  progress_kind: str = "no_calls",
                  progress_value: Optional[str] = None,
                  probability: float = 0.5) -> AnchorRule:
        return AnchorRule("t", decision, intent_kind, intent_value, progress_kind,
                          progress_value, probability, "mini rule")

    class Tests(unittest.TestCase):
        def test_every_rule_fires_on_its_own_pattern_and_obeys_option_gate(self):
            for rule in rules:
                with self.subTest(rule=rule.rule_id or rule.description):
                    case = _case_for_rule(rule)
                    self.assertTrue(rule.fires(case))
                    self.assertFalse(rule.fires(replace(case, options=frozenset())))

        def test_case_expected_outcomes(self):
            for case in cases:
                if case.expected is None:
                    continue
                with self.subTest(task=case.task):
                    prediction = predict(case, rules, threshold)
                    actual = ASK_MODEL if prediction.ask_model else prediction.chosen
                    self.assertEqual(actual, case.expected)

        def test_graph_transition_targets_exist(self):
            ids = set(graph.states)
            for sid, state in graph.states.items():
                for tr in state.transitions:
                    self.assertIn(tr.to, ids, "{} -> {!r} missing".format(sid, tr.to))

        def test_graph_single_parent(self):
            targets = Counter(tr.to for s in graph.states.values()
                              for tr in s.transitions)
            multi = {k: v for k, v in targets.items() if v > 1}
            self.assertFalse(multi, "multi-parent targets: {}".format(multi))

        def test_graph_final_states_have_no_transitions(self):
            for sid, state in graph.states.items():
                self.assertFalse(state.final and state.transitions,
                                 "final state {} has transitions".format(sid))

        def test_click_transitions_have_selector_or_review(self):
            for sid, state in graph.states.items():
                for tr in state.transitions:
                    if tr.op == "click":
                        self.assertTrue(tr.find is not None or tr.needs_review,
                                        "{} -> {} click has neither selector "
                                        "nor review flag".format(sid, tr.to))

        def test_rules_and_cases_align_with_graph(self):
            validate_data(graph, rules, cases)  # raises on drift

        def test_token_is_not_substring_and_case_insensitive(self):
            rule = mini_rule(decision="s2", intent_kind="task_word", intent_value="car")
            self.assertFalse(rule.fires(DecisionCase("scar", "", (), frozenset(("s2",)))))
            self.assertTrue(rule.fires(DecisionCase("drive by CAR", "", (), frozenset(("s2",)))))

        def test_bigram_must_be_adjacent(self):
            rule = mini_rule(decision="s11", intent_kind="task_bigram", intent_value="on_foot")
            self.assertFalse(rule.fires(DecisionCase("on my foot", "", (), frozenset(("s11",)))))
            self.assertTrue(rule.fires(DecisionCase("go on foot", "", (), frozenset(("s11",)))))

        def test_last_call_is_not_any_history(self):
            rule = mini_rule(decision="x", progress_kind="last_call", progress_value="s9")
            self.assertTrue(rule.fires(DecisionCase("car", "", ("s1", "s9"), frozenset(("x",)))))
            self.assertFalse(rule.fires(DecisionCase("car", "", ("s9", "s1"), frozenset(("x",)))))

        def test_history_has_can_be_anywhere(self):
            rule = mini_rule(decision="x", progress_kind="history_has", progress_value="refund")
            self.assertTrue(rule.fires(DecisionCase("car", "", ("refund", "get_orders"),
                                                   frozenset(("x",)))))
            self.assertFalse(rule.fires(DecisionCase("car", "", ("get_orders",),
                                                    frozenset(("x",)))))

        def test_no_calls_progress(self):
            rule = mini_rule(decision="x", progress_kind="no_calls")
            self.assertTrue(rule.fires(DecisionCase("car", "", (), frozenset(("x",)))))
            self.assertFalse(rule.fires(DecisionCase("car", "", ("s1",), frozenset(("x",)))))

        def test_decide_returns_first_matching_rule(self):
            first = mini_rule(decision="yes", intent_kind="question_word",
                              intent_value="get_orders", progress_kind="last_call",
                              progress_value="find_user")
            second = mini_rule(decision="no", intent_kind="question_word",
                               intent_value="order_id", progress_kind="last_call",
                               progress_value="find_user")
            case = DecisionCase("", "get_orders order_id", ("find_user",),
                                frozenset(("yes", "no")))
            self.assertIs(decide(case, (first, second)), first)

        def test_threshold_gate_boundary(self):
            below = mini_rule(probability=threshold - 0.01)
            at = mini_rule(probability=threshold)
            case = DecisionCase("car", "", (), frozenset((FINISH,)))
            self.assertTrue(predict(case, (below,), threshold).ask_model)
            self.assertFalse(predict(case, (at,), threshold).ask_model)

        def test_votes_max_aggregate_and_normalize(self):
            r1 = mini_rule(decision="s10", intent_kind="task_word", intent_value="a",
                           probability=0.7)
            r2 = mini_rule(decision="s10", intent_kind="task_word", intent_value="b",
                           probability=0.8)
            r3 = mini_rule(decision="s11", intent_kind="task_word", intent_value="a",
                           probability=0.6)
            case = DecisionCase("a b", "", (), frozenset(("s10", "s11")))
            prediction = predict(case, (r1, r2, r3), threshold)
            self.assertEqual(dict(prediction.distribution), {"s10": 0.8, "s11": 0.6})
            self.assertAlmostEqual(sum(p for _, p in prediction.normalized), 1.0)
            self.assertEqual(prediction.chosen, "s10")

    result = unittest.TextTestRunner(verbosity=2).run(
        unittest.defaultTestLoader.loadTestsFromTestCase(Tests))
    if not result.wasSuccessful():
        raise SystemExit(1)


def main() -> None:
    import math
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--rules", default=DEFAULT_RULES,
                        help="rules JSON file (default: %(default)s)")
    parser.add_argument("--cases", default=DEFAULT_CASES,
                        help="cases JSON file (default: %(default)s)")
    parser.add_argument("--graph", default=DEFAULT_GRAPH,
                        help="UI state graph JSON, converted from map_tree.xml "
                             "(default: %(default)s)")
    parser.add_argument("--threshold", type=float, default=DEFAULT_THRESHOLD,
                        help="confidence threshold in [0, 1] (default: %(default)s)")
    parser.add_argument("--case", type=int, help="show just one case, 1..N")
    parser.add_argument("--list-rules", action="store_true",
                        help="list the loaded rules and exit")
    parser.add_argument("--iterations", type=int, default=10000,
                        help="benchmark decisions (default: 10000)")
    parser.add_argument("--teacher-ms", type=float, default=400,
                        help="SIMULATED teacher latency, ms (default: 400)")
    parser.add_argument("--self-test", action="store_true",
                        help="run deterministic rule checks on the loaded data and exit")
    args = parser.parse_args()
    if args.iterations < 1:
        parser.error("--iterations must be positive")
    if not math.isfinite(args.teacher_ms) or args.teacher_ms < 0:
        parser.error("--teacher-ms must be finite and nonnegative")
    if not math.isfinite(args.threshold) or not 0.0 <= args.threshold <= 1.0:
        parser.error("--threshold must be a finite number in [0, 1]")

    global RULES, CASES, GRAPH
    RULES = load_rules(args.rules)
    CASES = load_cases(args.cases)
    GRAPH = load_graph(args.graph)
    validate_data(GRAPH, RULES, CASES)
    if args.case is not None and not 1 <= args.case <= len(CASES):
        parser.error("--case must be in 1..{} ({} cases loaded)".format(
            len(CASES), len(CASES)))

    if args.self_test:
        self_test(RULES, CASES, GRAPH, args.threshold)
        return
    if args.list_rules:
        for i, rule in enumerate(RULES, 1):
            evidence = ""
            if rule.heldout_total:
                evidence = " [historical {}/{}]".format(
                    rule.heldout_correct, rule.heldout_total)
            print("R{} ({}): p={:.2f} {}{}".format(
                i, rule.rule_id, rule.probability, rule.description, evidence))
        print("Threshold (below this the model is asked): {:.0%}".format(args.threshold))
        return
    print("Decision Anchors Demo - data-driven Python port of Android 0.1.0")
    print("Graph:  {} ({} states, {} transitions)".format(
        args.graph, len(GRAPH.states),
        sum(len(s.transitions) for s in GRAPH.states.values())))
    print("Rules:  {} ({} rules)".format(args.rules, len(RULES)))
    print("Cases:  {} ({} cases)".format(args.cases, len(CASES)))
    print("Semantics: rules vote on next states; highest raw vote >= {:.0%} decides,".format(
        args.threshold))
    print("           otherwise ASK MODEL. No action is executed. Probabilities are illustrative.")
    indices = [args.case] if args.case else range(1, len(CASES) + 1)
    for i in indices:
        show_case(i, CASES[i - 1], RULES, args.threshold, GRAPH)
    benchmark(RULES, CASES, args.threshold, args.iterations, args.teacher_ms)


if __name__ == "__main__":
    main()
