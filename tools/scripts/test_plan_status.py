"""Tests for scripts/plan-status.py.

Run with:
    uv run --python 3.12 --with pytest --no-project python -m pytest scripts -q
"""

from __future__ import annotations

import importlib.util
from pathlib import Path

SCRIPT = Path(__file__).resolve().parent / "plan-status.py"
spec = importlib.util.spec_from_file_location("plan_status", SCRIPT)
assert spec is not None and spec.loader is not None
plan_status = importlib.util.module_from_spec(spec)
spec.loader.exec_module(plan_status)


def write_plan(tmp_path: Path, body: str) -> Path:
    path = tmp_path / "plan.md"
    path.write_text(body, encoding="utf-8")
    return path


def test_counts_checked_and_unchecked(tmp_path: Path) -> None:
    plan = write_plan(
        tmp_path,
        "# Plan\n\n- [x] done (evidence: PR 1)\n- [ ] open\n",
    )
    report = plan_status.parse(plan)
    assert report["done"] == 1
    assert report["total"] == 2
    assert report["remaining"] == 1


def test_satisfied_decision_pair_marks_sibling_decided(tmp_path: Path) -> None:
    plan = write_plan(
        tmp_path,
        "# Plan\n\n"
        "- [x] Option A: **approved** (evidence: ADR-1)\n"
        "- [ ] Option A: **denied** (one of the two must be checked)\n",
    )
    report = plan_status.parse(plan)
    assert report["done"] == 1
    assert report["decided"] == 1
    assert report["remaining"] == 0


def test_pending_decision_pair_is_not_decided(tmp_path: Path) -> None:
    plan = write_plan(
        tmp_path,
        "# Plan\n\n"
        "- [ ] Option A: **approved**\n"
        "- [ ] Option A: **denied** (one of the two must be checked)\n",
    )
    report = plan_status.parse(plan)
    assert report["decided"] == 0
    assert report["remaining"] == 2


def test_lint_rejects_double_checked_pair(tmp_path: Path) -> None:
    plan = write_plan(
        tmp_path,
        "# Plan\n\n"
        "- [x] Option A: **approved** (evidence: ADR-1)\n"
        "- [x] Option A: **denied** (one of the two must be checked) (evidence: ADR-2)\n",
    )
    errors = plan_status.lint(plan_status.parse(plan))
    assert any("both sides checked" in e for e in errors)


def test_lint_rejects_checked_without_evidence(tmp_path: Path) -> None:
    plan = write_plan(tmp_path, "# Plan\n\n- [x] done\n")
    errors = plan_status.lint(plan_status.parse(plan))
    assert any("no (evidence:" in e for e in errors)


def test_lint_rejects_duplicates(tmp_path: Path) -> None:
    plan = write_plan(
        tmp_path,
        "# Plan\n\n- [ ] same\n- [ ] same\n",
    )
    errors = plan_status.lint(plan_status.parse(plan))
    assert any("duplicate" in e for e in errors)


def test_lint_rejects_conditional_checkboxes(tmp_path: Path) -> None:
    plan = write_plan(tmp_path, "# Plan\n\n- [ ] If approved: build it\n")
    errors = plan_status.lint(plan_status.parse(plan))
    assert any("conditional work" in e.lower() for e in errors)


def test_require_complete_exit_codes(tmp_path: Path) -> None:
    done = write_plan(tmp_path, "# Plan\n\n- [x] done (evidence: PR 1)\n")
    assert plan_status.main(["--plan", str(done), "--require-complete"]) == 0

    open_plan = write_plan(tmp_path, "# Plan\n\n- [ ] open\n")
    assert plan_status.main(["--plan", str(open_plan), "--require-complete"]) == 1
