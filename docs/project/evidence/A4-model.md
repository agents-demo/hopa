# A4 - OpenAI client and the model form

Date: 2026-11-13. Two items only.

## Client

`OpenAiClient` posts to `<endpoint>/chat/completions` with:

- `max_tokens` from `ModelRequest` (default 2048) and `reasoning_effort`
  (default `low`);
- 30 s connect and 60 s read timeouts;
- token usage from `usage.prompt_tokens` / `completion_tokens` / `total_tokens`;
- an `IOException("model returned an empty answer")` on blank content.

## Model form

`SettingsScreen` has provider, endpoint, model and API-key fields plus Save; the
key is written through `KeystoreSecretStore` (AES-GCM, Android Keystore) and is
never shown again. Profiles and Launchpad links sit below the form.

## Not done in A4

- No Anthropic or Gemini client; `ModelFactory` only chooses OpenAI, stub or none.
- The LAN preset is inferred from an `http://` endpoint; there is no reachability
  check and no private-range cleartext policy yet.
- Provider states are `CLOUD/LAN/DEMO/NO_MODEL`, not the planned `SHELL_ONLY`, and
  a turn is not refused before it starts.
- The Keystore holds `hopa_model_key` only; there is no `hopa_bridge_session`.
- Settings has 7 fields, not 26.
- No client tests (request body, error mapping, key round-trip, logging).
