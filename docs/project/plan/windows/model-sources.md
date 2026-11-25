# MODEL-XX: answer sources, anchors and local models

Status: **MODEL-01…MODEL-06 done; MODEL-07…MODEL-20 pending.** This plan makes
the Windows model-source choices explicit instead of hiding platform
differences behind a single API provider.

"TRC" is not a string in the repository. The working mapping is:

- **TRC anchor-based** → graph/anchors (`HandGraphSource`, `GraphStepSource`);
- **TRC tree-based** → a model that reads the UI Automation tree (the existing
  `ModelDecisionPolicy` input);
- **small language model** → an on-device model file and runtime;
- **API language model** → OpenAI-compatible cloud/LAN (`OpenAiClient`).

If "TRC" means a separate trained model family, MODEL-07 and MODEL-15 change;
the rest of the sequence stays.

## 1. Truth table (MODEL-01)

| Answer source | Input | Needs network | Needs a model file | Windows status |
|---|---|---|---|---|
| Anchors / graph | UIA tree + labels | no | no | ✅ Windows graph v1 |
| Tree model | UIA tree | API/LAN | no | ✅ same as API model; named mode pending |
| Small local model | UIA tree | no | yes | ❌ no runtime/model |
| API model | UIA tree | yes | no | ✅ DeepSeek/OpenAI/LAN |
| Demo | none | no | no | ✅ `stub` |

`auto` means: anchors first for known apps, then a recipe/instant command, then
the model. `anchors` means graph only and refuses without a graph. `model`
skips graphs, recipes and commands.

## 2. Parity and ADR (MODEL-02)

- [x] `parity.md` no longer calls the Answers page a flat `have`; API/LAN/Demo
      is `adapt`, on-device is `new` (a real gap).
- [x] Step source is documented as `auto`/`anchors`/`model`; graph is a
      Windows catalogue, not an Android screen.
- [x] `W10-model-source.md` records the Demo provider and step source.
- [ ] ADR for local runtime (MODEL-07) and a final scope decision: API-only or
      local model.

## 3. Anchors on Windows (MODEL-03…06)

- [x] **MODEL-03** Windows graph v1 resource
      (`apps/windows/sidecar/src/main/resources/windows-graphs.v1.json`):
      Notepad, File Explorer, Calculator.
- [x] **MODEL-04** wire `HandGraphSource` / `GraphStepSource` into `TurnEngine`;
      `useGraphs` follows `stepSource`, not a hard-coded false.
- [x] **MODEL-05** step source `auto` / `anchors` / `model` in Settings and
      `RuntimeConfig`.
- [x] **MODEL-06** tests: graph resource loads, anchor target, anchor-only turn;
      live `--turn "open notepad"` with `steps=anchors` launched Notepad and
      answered `Opened Notepad.` without the model.
- [ ] Expand the catalogue beyond open-app edges (Settings pages, Explorer
      navigation, app-specific flows) as content work.

Evidence:

```text
sidecar: configured ... steps=anchors
device: launched notepad (foreground=notepad)
step 0: ui.launch tier=uia executed=True
HOPA: Opened Notepad.
```

## 4. On-device small model (MODEL-07…13)

- [ ] **MODEL-07** ADR: ONNX Runtime / llama.cpp / Windows ML, model format.
- [ ] **MODEL-08** catalogue: size, licence, RAM/CPU budget, model cards.
- [ ] **MODEL-09** download/import/delete/quota UI, like Android
      `LocalModelSection`.
- [ ] **MODEL-10** `LocalEngine` in sidecar, provider `on-device`; no
      `ModelNotLoaded` placeholder.
- [ ] **MODEL-11** local→API fallback only with consent; no silent cloud.
- [ ] **MODEL-12** model files separate from the MSI; installer size budget.
- [ ] **MODEL-13** offline/performance evidence on a clean VM.

This is the long pole (4–6 weeks) and a product/privacy decision, not a combo
box. Until then the explicit `on-device` provider fails visibly.

## 5. Tree model (MODEL-14…15)

- [ ] **MODEL-14** name the tree mode and show it in the receipt: the current
      API/local model already receives UIA tree + elements.
- [ ] **MODEL-15** only if a separate tree-trained model is actually required;
      otherwise close as `not-applicable` with this evidence.

## 6. Unified UI (MODEL-16…17)

- [ ] **MODEL-16** one Answer source selector: Auto / Anchors / Tree / Local /
      API, with an honest unavailable state.
- [ ] **MODEL-17** model picker, test button, status: local ready / API ready /
      demo / no key.

## 7. Evidence and release (MODEL-18…20)

- [ ] **MODEL-18** Android/Windows screenshots and turn transcripts for each
      available mode.
- [ ] **MODEL-19** clean-VM/offline gate for local and API turns.
- [ ] **MODEL-20** rollout flags, docs, remove the old hard-coded paths.

## Current answer

Windows now has **API/LAN, Demo, and Anchors** plus `auto`/`anchors`/`model`.
**On-device small LM** and a **separate TRC-trained model** remain gaps; tree
input already exists for the API model.
