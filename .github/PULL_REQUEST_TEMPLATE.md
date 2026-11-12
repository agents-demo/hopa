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

## Verification

- [ ] `ruff check` and `ruff format --check` pass.
- [ ] `pytest pc-agent bench agent` passes.
- [ ] `python scripts/plan-status.py --lint` passes.
- [ ] If ArkTS: core Local Tests pass (attach the run).
