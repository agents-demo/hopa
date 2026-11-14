# packages: the client engine

Libraries that ride inside the Kotlin clients. They are not apps and not
services: no `main`, no UI, no Android SDK on the classpath.

```
packages/
  core/           contracts, loop, gate, records, ports
  data/           settings, secrets, conversations, memory, skills (interfaces and models)
  capabilities/   model clients and the bridge client
```

## Who uses them

| Package | Used by |
|---|---|
| `core` | `apps/android`, the Windows client and its sidecar |
| `data` | `apps/android`, the Windows sidecar (a desktop store implements these interfaces) |
| `capabilities` | `apps/android`, the Windows sidecar (bridge and model clients) |

`apps/harmony` does **not** use these packages: it is ArkTS and frozen
(ADR-0020). Its own kit lives in `apps/harmony/app`.

## Rules

- Kotlin package names stay `com.hopa.*`; moving a module changes only Gradle
  paths, never imports.
- No Android imports in `core` or `data`; the structure check enforces `core`.
- A client never imports another client; both import `packages/`.
- Platform implementations stay with the platform: Room and DataStore remain in
  `apps/android/data`, accessibility and voice in `apps/android/capabilities`.
  This package holds the interfaces and the pure models they implement.
- One owner per package.

## Gradle wiring

The Android build lives in `apps/android`, so it includes these directories:

```kotlin
include(":core")
project(":core").projectDir = file("../../packages/core")
```

A future Windows build does the same from its own `settings.gradle.kts`.
