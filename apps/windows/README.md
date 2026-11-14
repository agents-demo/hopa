# HOPA for Windows

**Status: reserved.** No code yet. This file exists so the folder answers "what
goes here" before anyone writes the first line (ADR-0007).

## What a Windows HOPA is

A **thin client** with a desktop body, the same shape as the Harmony 2-in-1 shell:

- it renders the conversation and the run pane;
- it captures the screen and executes actions **on this machine**;
- it talks to `services/backend` over `contracts/` only.

It does **not** run the agent loop, hold a model key, or inline a prompt.

## The two halves

| Half | Windows implementation | Contract |
|---|---|---|
| Shell | WinUI 3 (or WPF if the toolchain forces it) | `contracts/openapi/backend.v1.yaml` (future) |
| Device adapter | UI Automation (`UIAutomationClient`) + `PrintWindow`/DXGI capture | `DevicePort` in `services/bridge` |

`DevicePort` is the seam described in
[adding a platform](../../services/docs/guides/adding-a-platform.md): `observe`, `tap`,
`type`, `swipe`, `screenshot`, `launch`, `foreground`, `apps`, plus `serial` and
`platform`.

## Rules

1. No HarmonyOS imports and no copy of `apps/harmony/core` — the loop is not here.
2. The adapter reports **what it can see**, never what it assumes: UIA trees are
   sparse, so `observe` must say when it only has window titles.
3. Payment and destructive actions go through the same ask-first gate; the
   adapter never decides.
4. Nothing in this folder may be imported by `services/` or `evals/`.

## First steps when work starts

- [ ] Prove UIA `observe` on a real window tree (notepad first, then a browser).
- [ ] Implement `DevicePort` and run the handler tests on the fake.
- [ ] Add a contract client generated from `contracts/openapi/`.
- [ ] Prove one task end to end against `services/backend` (or the bridge).
