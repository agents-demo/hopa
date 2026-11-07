# Glossary

| Term | Meaning |
|---|---|
| **HOPA** | This project: a GUI agent for HarmonyOS. |
| **Mika** | The Apache-2.0 Android reference product. Not our product; no source copied. |
| **ACL** | Huawei's access-control approval for a restricted capability. |
| **a11y** | Accessibility. The on-device way to read and drive other apps. |
| **Observation** | One redacted, hashable picture of the screen (`e1`, `e2`, …). |
| **Ref** | A short id for a node in one observation. Expires on the next one. |
| **Action** | One device operation, e.g. `ui.tap` or `ui.type`. |
| **Decision** | The model's reply: one action, a sentence, `done`, `needUser`. |
| **Gate** | The single execution path that classifies, approves, executes, verifies and records. |
| **Policy** | The classifier: `read`, `sensitive`, `payment`, `block`. |
| **Capability** | A platform surface: `a11y`, `web`, `sandbox`, `system`. |
| **Tethered** | The PC runs the loop; the phone is driven over `hdc` + `uitest`. |
| **Standalone** | The HAP runs the loop on device. |
| **Record** | One append-only, hash-chained step in `.hopa/runs.jsonl`. |
| **Brain** | The decision layer (JVM service first, ArkTS later). |
| **Body** | The device surface the brain drives. |
| **M0–M6** | Milestones in `docs/plan/README.md`. |
| **WASM** | WebAssembly. The only on-device user-script runtime. |
| **Pyodide** | CPython compiled to WASM, used only inside an optional sandbox page. |
