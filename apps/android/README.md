# HOPA for Android

**Status: reserved.** No code yet. This file exists so the folder answers "what
goes here" before anyone writes the first line (ADR-0007).

## What an Android HOPA is

A **full client**: it runs the whole agent loop, holds its own model key, and
acts on the device (ADR-0016). Two execution paths behind one seam (ADR-0017):

- the PC bridge over `adb` (primary, the way `hdc` works on Harmony);
- an on-device `AccessibilityService` (fallback, after an explicit grant).

It shares behaviour with the other clients through `contracts/schemas` and
`contracts/fixtures`, not through code.

The build plan, phases and effort: `docs/project/plan/android/README.md`.

## What is in the app

| Part | Android implementation | Contract |
|---|---|---|
| Loop and gate | Kotlin, no Android imports | `contracts/schemas`, `contracts/fixtures` |
| UI | Kotlin + Jetpack Compose | own state, shared JSON shapes |
| Bridge adapter | OKHttp client to `services/bridge` (`adb` transport) | bridge OpenAPI |
| On-device adapter | `AccessibilityService` + gestures | `DevicePort` semantics |

The bridge's `DevicePort` is the seam described in
[adding a platform](../../services/docs/guides/adding-a-platform.md). Today it has
`dump_layout`, `foreground`, `tap`, `swipe`, `type_text`, `press_key`,
`press_key_many`, `launch`, `stop`, `shell`, `pull`, plus `serial` and `platform`.
The Android plan extends it with `screenshot` and `apps` (A6), since both the
Harmony and the new `adb` adapters need them. The Android client itself defines a
Kotlin port with observation/action methods; an adapter implements it either over
HTTP or over `AccessibilityService`.

## Rules

1. No HarmonyOS imports and no copy of `apps/harmony/core` — the loop is
   **reimplemented in Kotlin** and must pass the conformance fixtures.
2. Every screen comes from the contract, never from scraping another app's files.
3. Payment and destructive actions go through the same ask-first gate as the
   phone; the adapter never decides.
4. Nothing in this folder may be imported by `services/` or `evals/`.

## First steps when work starts

The ordered phases are in `docs/project/plan/android/README.md` (A0–A14). The
first three checkboxes there are the ones to start with: the Gradle project, the
contract types with schema validation, and the conformance runner on the JVM.
