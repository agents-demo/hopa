# Definition of ready

A phase may start only when all of these are true.

- [ ] The previous phase's exit criteria are met, or the gap is written down.
- [ ] A named owner and a named reviewer exist.
- [ ] The phase's checkboxes are in `docs/rebuild-plan.md` and are specific.
- [ ] Every dependency has an owner and a lead time (`docs/owners.md`).
- [ ] The environment is reproducible: pinned versions in `docs/setup.md`.
- [ ] The test plan exists: unit, contract, device and safety tests.
- [ ] The evidence target is named (CI run, device screenshot, bench report).
- [ ] The rollback or fallback is written down.
- [ ] The budget for devices and model calls is approved.
- [ ] The safety impact of the phase is reviewed against `docs/threat-model.md`.

If any box is unchecked, the phase is not ready. Record the exception and its
owner; do not start silently.
