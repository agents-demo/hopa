## Summary

<!-- One paragraph. What changed and why. -->

## Phase and checkboxes

- Phase:
- Boxes moved:
- Evidence (CI run, test, screenshot):

## Safety review

- [ ] Every new action goes through the executor.
- [ ] No model-supplied payment flag is trusted.
- [ ] Denied actions are recorded and not retried.
- [ ] Emergency-number path is unaffected.
- [ ] No secrets, keys or personal data added.

## Front door

- [ ] README reflects the change (capability, name, promise).
- [ ] Banner and README hero agree; re-rendered if the promise or name changed.
- [ ] Screenshots show the current UI, or are removed.
- [ ] CHANGELOG entry added where the change is user-visible.

## Repository shape

- [ ] If a new top-level folder appeared, the allow-list in
      `tools/checks/check-tree.py` and ADR-0007 were updated in the same PR.
- [ ] If a module moved, package names stayed the same and CI paths were updated
      in the same PR.
- [ ] `packages/` keeps no Android imports (`python tools/checks/check-android-structure.py`).

## Verification

- [ ] `ruff check` and `ruff format --check` pass.
- [ ] `pytest services/wire services/bridge services/relay services/evals/bench services/evals/baseline` passes.
- [ ] `python tools/scripts/plan-status.py --lint` passes (`--plan docs/project/plan/windows` for that plan).
- [ ] If Android: `./gradlew :core:check :capabilities:test :capabilities-android:testDebugUnitTest :data:test :app:testDebugUnitTest :app:assembleDebug` passes.
- [ ] If ArkTS: core Local Tests pass (attach the run).
