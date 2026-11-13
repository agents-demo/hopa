# ADR-0014 - Retire the M1-M6 rebuild plan from the working tree

- Status: accepted
- Date: 2026-11-13

## Context

`docs/plan/` carried the original rebuild plan: phases 0-10, appendices A-F, the
definition of finished and a risks file. The work then diverged (the refactor,
the bridge/relay split, the backend direction), and the plan stopped being
maintained.

Two symptoms made it actively misleading:

- `plan-status.py` reported 31.7% from 789 boxes, but 547 of them were a
  verification log that was never kept; the number measured nothing.
- 539 "open" boxes implied pending work that nobody intended to do.

No live document cites the plan files; only the plan and the freeze rule mention
them.

## Decision

- The plan is **removed from the working tree**, not archived in another folder.
- A git tag, `rebuild-plan-2026-11-13`, holds it: any file is one
  `git show <tag>:docs/plan/<file>` away.
- `docs/plan/README.md` points at the active plan and at the tag.
- The active plan is `docs/plan/refactor/README.md`; decisions live in ADRs.
- The freeze rule now names the tag, not files that no longer exist.

## Consequences

- `plan-status.py` with its default path reports the index (no boxes) instead of a
  fake percentage; the refactor plan is counted explicitly with
  `--plan docs/plan/refactor`.
- Git history remains the archive; no second copy in the tree.
- A future plan starts as a new file with real evidence, not by reviving 789
  boxes.

## Alternatives considered

- **Keep the plan with a banner.** Rejected: it still dominates the plan folder
  and its numbers.
- **Move it to `docs/history/rebuild-plan/`.** Rejected: an archive folder nobody
  reads; a tag is cheaper and does not need link maintenance.
- **Delete without a tag.** Rejected: the intent and the port matrix would be
  hard to find by path.
