# 14. Phase 9 â€” Optional and explicitly gated

Both optional branches default to **no**. Each branch is a decision pair; exactly
one side of each pair must be checked. Detailed work for an approved branch is
prose below and is **not** counted until the branch is approved, at which point
it becomes its own gated plan with its own boxes.

Background mode:

- [ ] Decision: pursue a background / virtual-screen mode? (default: no)
- [ ] Background mode: **approved and shipped**
- [ ] Background mode: **denied and documented** (one of the two must be checked)

If approved: file the `ACCESS_VIRTUAL_SCREEN` ACL request, build a
virtual-screen prototype, define the background lifecycle and the user-facing
indicator, and complete a separate safety review for hidden operation. If
denied: close with a written rationale and update the README and Appendix D.

Companion Linux sandbox:

- [ ] Decision: pursue a companion Linux sandbox? (default: no)
- [ ] Companion sandbox: **approved and shipped**
- [ ] Companion sandbox: **denied and documented** (one of the two must be checked)

If approved, it ships as a separate release track, never as part of the MVP. If
the WASM sandbox proves insufficient, write the companion-service design doc
first and treat it as a new project.

---

