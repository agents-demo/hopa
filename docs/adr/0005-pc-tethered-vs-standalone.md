# ADR-0005 — PC-tethered vs standalone product split

- Status: accepted
- Date: 2026-11-05

## Context

There are two useful products with the same brain and different bodies:

- a PC-driven harness for development, evaluation and enterprise;
- an on-device app for ordinary users.

Treating them as one product hides the dependency on the ACL.

## Decision

- **Tethered product:** PC runs the loop; phone is a body over `hdc` + `uitest`.
  It is available now and is the M1/M2 target.
- **Standalone product:** the HAP runs the loop on device. It is the M3/M4
  target and needs the accessibility ACL for non-web apps.
- They share the observation, action, decision and record contracts.
- A release declares which shape it is. There is no silent downgrade.

## Consequences

- Benchmarks report the shape and the connection mode.
- The tethered shape is allowed for enterprise and development, not as a
  hidden substitute for the standalone claim.
- The phone app never requires Python or a PC.

## Alternatives considered

- Standalone only: blocks all work on the ACL.
- Tethered only: does not meet the product goal.
