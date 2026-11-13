# A1 - contracts, parsing and the hash vector

Date: 2026-11-13. Scope: what is verified today, not the whole phase.

## Command

```
cd apps/android
.\gradlew.bat :core:test     -> BUILD SUCCESSFUL, 16 tests, 0 failures
python tools/checks/check-android-structure.py -> 0 problems
```

## Verified

- `core/contracts` decodes every fixture with strict JSON
  (`HopaJson.ignoreUnknownKeys = false`), so an unknown field is rejected:
  `ConformanceTest.every_fixture_matches_the_contract`.
- The observation hash vector matches byte for byte:
  `ConformanceTest.the_observation_hash_vector_matches` against
  `contracts/fixtures/observation-hash.json`.
- `ui.teleport` fails with `E_SCHEMA`:
  `DecisionParserTest.rejects_an_unknown_kind`.
- The catalogue Kotlin file is generated, not hand-written:
  `core/src/main/kotlin/com/hopa/catalog/AppCatalog.kt` header and the CI step
  `build-app-catalog.py --check`.

## Not verified (still open)

- JSON-Schema validation with `networknt` — the dependency is declared in
  `gradle/libs.versions.toml` but no validator runs.
- `ObservationProducer` contract tests: there is no producer, so pre-order refs,
  redaction, the 400-node/6 000-char caps and the fixture-screen observation are
  untested.
- The `android` platform map (package/activity per catalogue entry).
- A schema-only conformance stage before the semantic gate.
