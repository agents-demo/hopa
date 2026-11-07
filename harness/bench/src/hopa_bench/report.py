"""Aggregate HOPA-Bench results into a small, honest report."""

from __future__ import annotations

from collections import Counter, defaultdict
from typing import Any


def percentile(values: list[float], fraction: float) -> float:
    if not values:
        return 0.0
    ordered = sorted(values)
    position = (len(ordered) - 1) * fraction
    lower = int(position)
    upper = min(lower + 1, len(ordered) - 1)
    weight = position - lower
    return ordered[lower] + (ordered[upper] - ordered[lower]) * weight


def aggregate(results: list[dict[str, Any]]) -> dict[str, Any]:
    total = len(results)
    passed = sum(1 for item in results if item.get("success") is True)
    failed = sum(1 for item in results if item.get("success") is False)
    unknown = total - passed - failed

    failures = Counter(
        str(item.get("failure") or "none") for item in results if item.get("success") is not True
    )
    latencies = [
        float(step.get("latency_ms", 0.0)) for item in results for step in item.get("steps", [])
    ]
    per_app: dict[str, dict[str, int]] = defaultdict(lambda: {"total": 0, "passed": 0})
    for item in results:
        app = str(item.get("app") or "unknown")
        per_app[app]["total"] += 1
        if item.get("success") is True:
            per_app[app]["passed"] += 1

    return {
        "total": total,
        "passed": passed,
        "failed": failed,
        "unknown": unknown,
        "pass_rate": round(passed / total, 3) if total else 0.0,
        "failures": dict(failures),
        "per_app": dict(per_app),
        "latency_ms": {
            "p50": round(percentile(latencies, 0.50), 1),
            "p95": round(percentile(latencies, 0.95), 1),
            "max": round(max(latencies), 1) if latencies else 0.0,
        },
        "tokens": sum(int(item.get("tokens", 0)) for item in results),
        "duration_s": round(sum(float(item.get("duration_s", 0)) for item in results), 3),
    }


def render_markdown(report: dict[str, Any]) -> str:
    lines = [
        "# HOPA-Bench report",
        "",
        f"- Tasks: {report['total']}",
        f"- Passed: {report['passed']}",
        f"- Failed: {report['failed']}",
        f"- Unknown: {report['unknown']}",
        f"- Pass rate: {report['pass_rate'] * 100:.1f}%",
        f"- Tokens: {report['tokens']}",
        f"- Wall clock: {report['duration_s']:.1f}s",
        "",
        "## Latency",
        "",
        f"- p50: {report['latency_ms']['p50']} ms",
        f"- p95: {report['latency_ms']['p95']} ms",
        f"- max: {report['latency_ms']['max']} ms",
        "",
        "## Failures",
        "",
    ]
    if report["failures"]:
        lines.extend(f"- `{name}`: {count}" for name, count in sorted(report["failures"].items()))
    else:
        lines.append("- none")
    lines.extend(["", "## Per app", "", "| App | Passed | Total |", "|---|---|---|"])
    for app, values in sorted(report["per_app"].items()):
        lines.append(f"| {app} | {values['passed']} | {values['total']} |")
    return "\n".join(lines) + "\n"
