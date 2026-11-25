# W10 model source and step source

Status: **Demo, API/LAN and `auto`/`model` are implemented. On-device and
graph/anchors are deliberately not offered.**

## Settings

`Settings → General` (the Answers page) now has three providers:

| Provider | Behaviour |
|---|---|
| `openai` | OpenAI-compatible API, e.g. DeepSeek at `https://api.deepseek.com` |
| `lan` | OpenAI-compatible server on the local network |
| `stub` | Demo answers from `ScriptedModel`; endpoint/model/key fields are hidden |

An explicit `stub` wins over a saved key. Before this, a key always forced the
cloud path even when the provider said stub (`ProviderChoiceRules`), so a UI
item alone would not have worked.

![Answers page with Demo selected](W10-model-source.png)

The endpoint, model name and key fields are hidden for Demo; the hint says no
model or key is used.

`stub` is a real proposer, not an approver: the gate still classifies and
approves every action.

## Step source

`Settings → Run` has `auto`, `anchors` and `model`:

- `auto` — try a known app graph, then a recipe/instant command, then the model;
- `anchors` — graph only; no graph means the turn refuses rather than calling a
  model;
- `model` — skip graphs, recipes and instant commands.

Windows graph v1 is
`apps/windows/sidecar/src/main/resources/windows-graphs.v1.json`: Notepad, File
Explorer and Calculator. A live `--turn "open notepad"` with `steps=anchors`
produced:

```text
sidecar: configured ... steps=anchors
device: launched notepad (foreground=notepad)
step 0: ui.launch tier=uia executed=True
HOPA: Opened Notepad.
```

The catalogue is deliberately small; it is content, not a matcher rewrite.

## On-device

Not offered. `ModelFactory` can build `LocalModel`, but the Windows sidecar has
no `LocalEngine`; an explicit `on-device` provider now fails visibly with
`ModelNotLoaded` instead of silently becoming the demo. A real on-device model
would need an inference runtime, model storage, licences and memory budgets.

## Verification

- `HeadlessTurnTest.an_explicit_stub_provider_wins_over_a_saved_key`
- `RuntimeConfigTest.step_source_is_auto_or_model_only`
- `SettingsStoreTests` round-trip `StepSource`
- `--turn` with `stub` never calls the network; the answer starts with
  `Stub answered`.
