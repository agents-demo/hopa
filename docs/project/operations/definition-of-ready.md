# Definition of ready

A phase may start only when all of these are true.

- [ ] The previous phase's exit criteria are met, or the gap is written down.
- [ ] A named owner and a named reviewer exist.
- [ ] The phase's checkboxes are in `docs/project/plan/README.md` and are specific.
- [ ] Every dependency has an owner and a lead time (`docs/project/operations/owners.md`).
- [ ] The environment is reproducible: pinned versions in `docs/guides/harmony/setup.md`.
- [ ] The test plan exists: unit, contract, device and safety tests.
- [ ] The evidence target is named (CI run, device screenshot, bench report).
- [ ] The rollback or fallback is written down.
- [ ] The budget for devices and model calls is approved.
- [ ] The safety impact of the phase is reviewed against `docs/reference/threat-model.md`.

If any box is unchecked, the phase is not ready. Record the exception and its
owner; do not start silently.
