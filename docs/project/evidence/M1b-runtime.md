# M1b: Kotlin and JDK runtime

Status: **engineering complete, with one deliberate open item.**

## Versions

| Tool | Version | Where |
|---|---|---|
| Gradle Kotlin | 2.4.21 | `apps/android/gradle/libs.versions.toml` |
| Brain Kotlin | 2.4.21 | `tools/scripts/brain.sh` (aligned) |
| Gradle JVM toolchain | 17 | `build-logic/src/main/kotlin/hopa.kotlin-jvm.gradle.kts` |
| Sidecar package runtime | JDK 21.0.11 | jlink output in the staged package |

Kotlin is Android-coupled: the sidecar shares the Android version catalog and
`core/**` modules. The Gradle toolchain stays 17 so Android bytecode is
unchanged. The package runtime is independent and is now JDK 21.

## Proof

```text
tools/scripts/windows-package.ps1 -Output out/windows-m1b `
  -JdkHome "C:\Program Files\Microsoft\jdk-21.0.11.10-hotspot" -SkipMsi
```

- staged `runtime/release`: `JAVA_VERSION="21.0.11"`
- zip: 124,403,824 bytes
- zip SHA-256: `E3FBEE327899C2642FC1141C61EC265393C70FB866D38C28B653D6811D9F40F0`
- the script refuses a JDK whose `release` file is not 21, so a JDK 17 package
  cannot be produced by accident.

## JDK 25

Not adopted. It adds a larger runtime image and no product capability. JDK 21 is
the LTS target for the sidecar package. Revisit only with a measured need.

## Open

- `services/brain` is still compiled by a standalone `kotlinc` download rather
  than a Gradle module. It now uses the same Kotlin 2.4.21, so the version
  divergence is gone, but the second compiler path remains. Retiring it means
  moving `services/brain` into Gradle and porting its `main`-style tests; that
  is a separate change.
