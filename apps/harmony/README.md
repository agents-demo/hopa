# HOPA for HarmonyOS (frozen)

Status: **frozen** (ADR-0020). Android is the active client; Windows is next.

This tree is ArkTS and ArkUI. It does **not** use `packages/` (the Kotlin client
engine): that code belongs to the Android and Windows clients. The shared kit
for this app lives in `apps/harmony/app`.

The code is kept as the reference for the visual language and for the Harmony
build, which still runs in CI when the Huawei toolchain secret is present.
