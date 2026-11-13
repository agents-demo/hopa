# Shared data (ADR-0018)

Each client owns its loop (ADR-0016). What they **read** is shared here, and a
generator turns it into each platform's code at build time. A client that
hand-edits its copy fails CI.

| Data | Source | Generated into | Check |
|---|---|---|---|
| Apps and sites | `services/brain/knowledge/{apps,sites}` | `contracts/catalog/catalog.v1.json`, then `apps/harmony/app/.../AppCatalog.ets` (Kotlin on demand) | `build-app-catalog.py --check` |
| Approval vocabulary | `contracts/policy/approval.v1.json` | `apps/harmony/core/.../gate/PolicyData.ets` | `build-policy-data.py --check` |
| Prompt rules | `contracts/prompts/rules.v1.json` | `apps/harmony/core/.../agent/PromptRules.ets` | `build-prompt-rules.py --check` |
| Routing cases | `contracts/fixtures/routing.json` | tests, not code | `check-routing.py` |
| Observation limits | `contracts/observation/limits.v1.json` | tests, not code | read by A1 tests |
| Observation hash | `contracts/fixtures/observation-hash.json` | tests, not code | `check-observation-hash.py` |

## Rules

- Change the source, run the generator, commit both. `--check` runs in CI and in
  `tools/scripts/run-tests.ps1`.
- The catalogue is platform-neutral: `id`, `display`, `aliases`, `purpose`,
  `actions`, and a `platforms` map. HarmonyOS launch details are under
  `platforms.harmonyos`; Android fills `platforms.android` in A11 of the
  Android plan.
- The policy file is the whole vocabulary, including the amount and merchant
  regexes. The gate logic is still per client; it must not re-declare the lists.
- The prompt file lists **promises**, not wording. A client test asserts every
  phrase is present in its rendered system prompt; platform-specific wording
  and the action syntax stay local.
- The routing fixture is executed by `tools/checks/check-routing.py` and must be
  reproduced by `AppRouter.ets` and the Android port.
- The observation vector pins `sha256` over the canonical projection; see
  [observation.md](contracts/observation.md).

## Why not a backend call

The phone and the laptop must work offline, and these files are static. Fetching
them at runtime would add a dependency without adding freshness; the generator
runs at build time instead.
