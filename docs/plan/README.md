# Plan

The active plan is [`refactor/README.md`](refactor/README.md).

The earlier rebuild plan (M1-M6: phases 0-10, appendices A-F, definition of
finished, risks) is **retired** (ADR-0014). It is kept in git, not in the tree:

```bash
git show rebuild-plan-2026-11-13:docs/plan/README.md
git show rebuild-plan-2026-11-13:docs/plan/phase-4-capabilities.md
```

Why it left the tree: nobody maintained it, its 547-row verification log made the
progress number meaningless, and no live document depended on it. The decisions
that mattered are ADRs; the current work is the refactor plan.
