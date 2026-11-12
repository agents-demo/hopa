# CLAUDE.md — conventions for future sessions

This file is the contract for anyone (human or AI) changing this repository.
Read it before editing code. When in doubt, prefer the narrower capability and the
stricter safety check.

## Golden rules

1. **Every action goes through `ActionExecutor`.** No capability, UI page, script,
   or test may invoke a device action directly. The only allowed path is
   `ActionExecutor.execute(action)` and its fixed pipeline:
   `guards → payment approval → execute → verify → record`.
2. **Never weaken the payment gate.** Payment-classified actions always require an
   explicit user confirmation. Do not add flags, environment variables, test hooks,
   or "trusted mode" shortcuts that bypass it. New action types must be classified
   conservatively; if unsure, treat it as payment-capable.
3. **Secrets never enter git.** No `.p12`, `.cer`, `.p7b`, `.p7s`, `.csr`, `.key`,
   keystores, signing configs, tokens, or device serials with account data. They
   are in `.gitignore` for a reason.
4. **Capabilities are independent.** `capabilities/*` must not import each other.
   Shared contracts live in `core/`. A capability may depend on `core/`; it must
   not depend on a sibling capability.
5. **`core/` is UI-free.** No ArkUI/`@ohos.arkui` imports, no `@Component`, no page
   code. `core/` must remain unit-testable on the host with local tests.
6. **Credit ideas, never copy code.** Any reused idea or prompt gets a note in
   `NOTICE`. Never import third-party source without a compatible licence or its
   sandbox parts (proot). New third-party code needs a license check and a NOTICE
   entry.

## Toolchain (pinned by the setup)

| Thing | Version |
| --- | --- |
| API / SDK | HarmonyOS SDK **26.0.0** (API 26) |
| DevEco Studio | **26.0.0** |
| Command Line Tools | **26.0.0.851** |
| hvigorw | 6.26.8 |
| ohpm | 26.0.0.630 |
| codelinter | 6.0.240 |
| Node (bundled) | 24.14.1 |
| Python | 3.11+ (3.12 recommended) |

Environment variables are documented in `docs/guides/setup.md`. Do not hard-code absolute
paths in tracked files; scripts should discover tools or read env vars.

## Build

From `apps/harmony/` (or through `tools/scripts/build.*`):

```bash
hvigorw assembleHap --no-daemon
# output: phone/build/default/outputs/default/entry-default-signed.hap (signed)
#         phone/build/default/outputs/default/entry-default-unsigned.hap (unsigned)
```

- Use the **Command Line Tools** `hvigorw` together with the **Command Line Tools**
  SDK. Do not mix the IDE's hvigor with the CLI SDK (or vice versa); it causes
  `SDK component missing` errors.
- `DEVECO_SDK_HOME` / `HOS_SDK_HOME` should be **unset** when running local unit
  tests (`hvigorw test`); a stale value causes an SDK mismatch.

## Test

```bash
# core/ local unit tests (host, no device; Windows/macOS only -- see CI note)
cd apps/harmony
hvigorw test -p module=core@default --no-daemon -p coverage=false

# hopa-bridge + bench
cd services/bridge && python -m pytest
cd bench   && python -m pytest
ruff check hopa-bridge bench
```

- Put pure logic tests in `<module>/src/test/*.test.ets` and **register every suite
  in `src/test/List.test.ets`** or it will silently not run.
- Device/system-API tests belong in `ohosTest/`. Do not put UI tests in `test/`.
- `hvigorw test` (Local Test) is **not supported on Linux**. CI runs it on a
  macOS/Windows runner and builds the HAP on Linux.

## Deploy

```bash
hdc list targets                     # must show the emulator/device
hdc install phone/build/default/outputs/default/entry-default-signed.hap
hdc shell aa start -a EntryAbility -b com.hopa.agent
hdc shell uitest dumpLayout -p /data/local/tmp/layout.json
```

Use `tools/scripts/run-on-device.*` for the supported one-shot flow (build,
sign with the SDK debug kit, install and launch). Signing material stays in
`tools/signing/` and must never be committed.

## Model key

The HAP no longer bundles a model key. On first run the user pastes their own
key in Settings; it is stored in HarmonyOS Asset Store (`services/KeyStore.ets`)
and loaded by `AppBoot`. A leftover `resources/rawfile/deepseek.key` is migrated
into secure storage on first boot, then it should be deleted. Never commit a key.

## Module boundaries

```
phone/entry (ArkUI shell, entry HAP)
  └─ imports core, capabilities/*          (UI may depend on everything)
laptop/entry (2-in-1 shell, entry HAP)
  └─ imports core only for now             (workbench lands later)
core (HAR, plain ArkTS)
  └─ imports nothing in app/               (defines contracts + ActionExecutor)
capabilities/<name> (HAR)
  └─ imports core only                     (never a sibling capability)
```

The app project has two entry modules: `phone` (folder `phone`, module name `entry`,
`deviceTypes: phone/tablet`) and `laptop` (folder `laptop`, module name `laptop`,
`deviceTypes: 2in1`). The module name stays `entry` for the phone so in-place
updates keep working; platform identity lives at the module level.

- `core/` defines: `Action`, `ActionExecutor`, `ToolRegistry`, `ApprovalPolicy`,
  `ModelClient`, `RunRecord`, capability interfaces.
- `capabilities/browser` implements browser actions via ArkWeb.
- `capabilities/sandbox` hosts the hidden WebView + Pyodide/QuickJS. Offline by
  default; no network unless explicitly enabled by the user.
- `capabilities/accessibility` is an `AccessibilityExtensionAbility` skeleton. It depends on
  **restricted permissions / an ACL request**; see `docs/architecture/overview.md`. Do not
  claim it works until the ACL is approved and verified on a device.
- `capabilities/system` uses system intents (alarm, calendar, deep links). Prefer
  public `startAbility` / want APIs over private ones.

## Code style

- ArkTS: strict typing, no `any` in `core/`. Prefer `class` + interfaces; keep
  files small. Follow the surrounding DevEco template style.
- Imports: relative within a module, package name across modules.
- Python: `ruff` (default rules) + `pytest`. Type hints on public functions.
  No network calls in unit tests; mock `hdc`.
- YAML/JSON: 2-space indent; benchmark tasks are data, not code.
- Commits: imperative subject, explain the *why*, reference the milestone (G1–G4).

## Adding a capability

1. Add `apps/harmony/capabilities/<name>/` as a HAR; add it to `apps/harmony/build-profile.json5`.
2. Implement the capability interface from `core/`; expose actions as `Action`
   descriptors registered with `ToolRegistry`.
3. Classify each action's risk in `ApprovalPolicy` (payment conservatively).
4. Add host unit tests where logic allows; device tests go in `ohosTest/`.
5. Update `docs/architecture/overview.md` (boundaries + permissions) and `NOTICE` if you
   add third-party code.

## Benchmarks

- Tasks live in `evals/bench/tasks/*.yaml` and follow the schema in `evals/bench/README.md`.
- A task must declare `goal`, `app` (and ideally `bundle`), and a `success` check.
- Never make a benchmark task bypass the payment gate. Payment tasks assert that
  the gate *blocks* until confirmation.
- `bench run` against the stub model must complete even when tasks fail; success
  is reported, not required, unless `--fail-on-task-error` is passed.
