# ADR-0004 — ACL strategy and foreground fallback

- Status: accepted
- Date: 2026-11-05

## Context

On-device control of other apps needs an accessibility extension and a Huawei
ACL review. Approval is outside our control and may take weeks or be denied.
Everything before M4 must ship without it.

## Decision

1. File the accessibility ACL request in **week 1**, not in Phase 4.
2. Ship a **foreground-only** product when the ACL is granted: the user sees
   what HOPA sees, and a live indicator is always visible.
3. If the ACL is denied or delayed, ship the **PC-tethered** fallback: the phone
   is driven over `hdc` + `uitest` from a PC.
4. Background / virtual-screen mode stays in Phase 9 and defaults to **no**.
5. The app never pretends the capability exists. The UI shows "unavailable".

## Consequences

- M0–M3 do not block on Huawei.
- Two supported shapes must be documented and tested.
- The ACL ticket, date and contact are recorded in the plan.

## Alternatives considered

- Wait for the ACL before building: unacceptable.
- Hidden virtual display: explicitly out of scope.
