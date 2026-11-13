# HOPA for Android

**Status: reserved.** No code yet. This file exists so the folder answers "what
goes here" before anyone writes the first line (ADR-0007).

## What an Android HOPA is

A **thin client**, the same shape as the Harmony app after the backend split:

- it renders the conversation and the run pane;
- it captures the screen and executes actions **on this device**;
- it talks to `services/backend` (or, today, `services/bridge`) over
  `contracts/` only.

It does **not** run the agent loop, hold a model key, or inline a prompt.

## The two halves

| Half | Android implementation | Contract |
|---|---|---|
| Shell | Kotlin + Jetpack Compose | `contracts/openapi/backend.v1.yaml` (future) |
| Device adapter | `AccessibilityService` + `UiAutomation` | `DevicePort` in `services/bridge` |

`DevicePort` is the seam described in
[adding a platform](../../services/docs/guides/adding-a-platform.md): `observe`, `tap`,
`type`, `swipe`, `screenshot`, `launch`, `foreground`, `apps`, plus `serial` and
`platform`.

## Rules

1. No HarmonyOS imports, no copy of `apps/harmony/core` — the loop is not here.
2. Every screen comes from the contract, never from scraping another app's files.
3. Payment and destructive actions go through the same ask-first gate as the
   phone; the adapter never decides.
4. Nothing in this folder may be imported by `services/` or `evals/`.

## First steps when work starts

- [ ] Pick the minSdk and confirm `AccessibilityService` capture works on it.
- [ ] Implement `DevicePort` against a real device, with the handler tests.
- [ ] Add a contract client generated from `contracts/openapi/`.
- [ ] Prove one task end to end against `services/backend` (or the bridge).
