# Expansion portfolio: what to build beyond client + backend

Status: **proposal for staffing.** Written 2026-11-13. This is not the active
delivery plan; the Android plan and the bridge/backend work continue separately.

Context: the classic tracks already have owners — one developer on pure clients,
one on the bridge/backend. **Two additional full-time developers** and **one PhD
researcher** can take work that is additive: new product layers, new services,
integrations and research.

## Principles

- **Clients are hosts, not the architecture.** HarmonyOS, Android and Windows
  differ in adapters and UI, not in what HOPA is.
- **Tasks and recipes are shared contracts.** The client does not own the task
  model or the app knowledge.
- **Mapping is a service.** The app consumes signed recipe packages; it does not
  build a mapping factory.
- **Intent and system APIs first, GUI last.** Accessibility is a fallback, not
  the product.
- **No hidden-execution promise.** Virtual display and input injection depend on
  platform permissions; on Android the model differs from HarmonyOS.
- **Research does not ship production code.** It produces methods, datasets,
  benchmarks, prototypes and user studies that engineering can adopt.

## Architecture map

```
┌──────────────────────────────────────────────────────────────┐
│                           PEOPLE                             │
└────────────────────────────┬─────────────────────────────────┘
                             │
┌────────────────────────────▼─────────────────────────────────┐
│ CLIENTS                                                      │
│ Harmony · Android · Windows · (tablet / watch / TV later)    │
│ chat · voice · notifications · approvals · task inbox        │
└────────────────────────────┬─────────────────────────────────┘
                             │
┌────────────────────────────▼─────────────────────────────────┐
│ TRANSPORT                                                    │
│ Bridge / Relay · DSoftBus (Harmony) · A2A / MCP              │
└────────────────────────────┬─────────────────────────────────┘
                             │
┌────────────────────────────▼─────────────────────────────────┐
│ PRODUCT CORE                                                 │
│                                                              │
│  ┌───────────────────────┐      ┌─────────────────────────┐  │
│  │ TASK ORCHESTRATOR     │◄────►│ FAMILY SPACE            │  │
│  │ tasks, states,        │      │ roles, shared tasks,    │  │
│  │ resume, handoff       │      │ elder / kid approvals   │  │
│  └──────────┬────────────┘      └─────────────────────────┘  │
│             │                                                │
│  ┌──────────▼────────────┐      ┌─────────────────────────┐  │
│  │ NOTIFIER              │      │ OPEN LOOPS              │  │
│  │ event → card          │      │ deadlines until closed  │  │
│  └──────────┬────────────┘      └─────────────────────────┘  │
└─────────────┼───────────────────────────────────────────────┘
              │
┌─────────────▼───────────────────────────────────────────────┐
│ ON-DEVICE EXECUTION                                          │
│ 1 intent / system → 2 share → 3 GUI (accessibility)          │
│ after every step: verify the postcondition                   │
└─────────────┬───────────────────────────────────────────────┘
              │ consumes signed recipes
┌─────────────▼───────────────────────────────────────────────┐
│ APP INTELLIGENCE                                             │
│                                                              │
│  ┌───────────────────────┐     ┌──────────────────────────┐ │
│  │ RECIPE LIBRARY        │◄────│ RECIPE FACTORY           │ │
│  │ versions, signatures  │     │ cloud: models, consensus │ │
│  └──────────┬────────────┘     └────────────┬─────────────┘ │
│             │                                │               │
│  ┌──────────▼────────────┐     ┌─────────────▼────────────┐ │
│  │ REGISTRY / OTA        │     │ RESEARCH                 │ │
│  │ canary, rollback      │     │ recipe robustness,       │ │
│  └───────────────────────┘     │ notifications, approval  │ │
│                                 └──────────────────────────┘ │
│  ┌─────────────────────────────────────────────────────────┐│
│  │ TEST FARM: devices, regression, failure taxonomy, metrics││
│  └─────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────┘

NEXT (6–12 months)
┌──────────────────────┬──────────────────────┬──────────────────────┐
│ Capability Registry  │ Model Gateway        │ Pilot Metrics        │
│ who can do what      │ model proxy, quotas  │ time, steps, repeat  │
├──────────────────────┼──────────────────────┼──────────────────────┤
│ SDK / HOPA inside    │ Policy & Security    │ Localization         │
│ embedding            │ rules, audit         │ languages            │
└──────────────────────┴──────────────────────┴──────────────────────┘

LATER
┌──────────────────────┬──────────────────────┬──────────────────────┐
│ Recipe Marketplace   │ Enterprise / MDM     │ On-device / LAN model│
│ partners publish     │ SSO, audit, DLP      │ no cloud             │
├──────────────────────┼──────────────────────┼──────────────────────┤
│ Virtual display      │ Tablet / watch / TV  │ Integrations:        │
│ hidden execution     │ new hosts            │ calendar, mail,      │
│ (if permitted)       │                      │ messaging, ride,     │
│                      │                      │ smart home, school   │
└──────────────────────┴──────────────────────┴──────────────────────┘
```

## Horizons

### Core (next 6 months)

| Initiative | What it unlocks | Owner | Effort |
|---|---|---|---|
| **Task Orchestrator** | Durable tasks: start on one device, resume on another; approvals, idempotency, handoff | Dev 1 | 8–10 weeks |
| **Family Space** | Roles, shared tasks, elder/kid approvals; the target audience from the deck | Dev 1 | 8–10 weeks |
| **Open Loops** | Deadlines tracked until closed, reminders, "again?" suggestions | Dev 1 + client dev | 3–4 weeks |
| **Notifier** | Notification → event → card → task; the daily trigger | Client dev + backend contract | 2–3 weeks |
| **Recipe schema + library** | One app, signed package, runtime contract | Dev 2 | 6–8 weeks |
| **Recipe Factory v0** | Cloud pipeline to generate and verify one app's recipe | Dev 2 | 6–8 weeks |
| **Test Farm** | Emulator + one phone, graph regression, failure taxonomy | Dev 2 | 6–8 weeks |
| **Registry / OTA** | Signed versions, canary, rollback, pinned to app build | Dev 2 | 3–4 weeks |
| **Research R1** | Recipes that survive app updates; method, dataset, benchmark | PhD | 6 months |

### Next (6–12 months)

| Initiative | What it unlocks | Owner | Effort |
|---|---|---|---|
| **Capability Registry** | Which apps/files/APIs exist on which device; routing | Backend | 4–6 weeks |
| **A2A / MCP gateway** | Other assistants and tools can ask HOPA to execute | Backend + Dev 2 | 4–6 weeks |
| **Pilot Metrics** | Time saved, app switches, E2E success, 7-day repeat | PhD + backend | 3–4 weeks |
| **Model Gateway** | Key hiding, quotas, provider fallback, hosted mode | Backend | 4–6 weeks |
| **SDK / embedding** | "HOPA inside" for partners | Dev 2 | 8–12 weeks |
| **Policy & Security packs** | Signed rules, audit, threat model, abuse limits | Backend/security | 4–6 weeks |
| **Localization** | Languages for the family/elderly audience | Client dev | 4–6 weeks |

### Later

- Recipe marketplace (partners publish recipes).
- Enterprise / MDM / SSO / DLP.
- On-device or LAN model.
- Virtual display / hidden execution, if the platform permits.
- Additional hosts: tablet, watch, TV.

## Research track

The researcher works on uncertainty the engineers currently guess at. Preferred
first thrust: **R1 — verified app recipes that survive app updates**. Secondary:
R2 or R3.

| Thrust | Questions | Output | Feeds |
|---|---|---|---|
| **R1. Verified App Recipes** | Semantic selectors, consensus across models, postcondition inference, self-healing, version drift | Dataset, benchmark, method, tech report | Dev 2 |
| **R2. Notification Understanding** | Event, date, owner, deadline, urgency from noisy notifications; on-device redaction | Extractor prototype, labeled set, metrics | Notifier, Dev 1 |
| **R3. Human approval & family trust** | How much context reduces errors without fatigue; elder/kid approvals | Study, design guidance | Product, client dev |
| **R4. Evaluation science** | HOPA-Bench, failure taxonomy, reproducibility, pilot metrics | Benchmark protocol, reports | Evals, all tracks |

Six-month shape:

1. **Month 1** — literature, benchmark definition, data/consent protocol.
2. **Month 2** — dataset v1 and baselines.
3. **Month 3** — method prototype and offline evaluation.
4. **Month 4** — error analysis, tech report, handoff to Dev 2.
5. **Month 5** — user study (R3) or field pilot.
6. **Month 6** — final report, patent disclosure if any, productionize / park.

Research rules:

- No production ownership, no client features.
- Prototypes go through engineering review before `main`.
- A negative result is a valid result.
- Privacy and consent come before data collection.

## Integrations

| Priority | Integration | Why |
|---|---|---|
| P0 | Calendar, mail, files, share intents | System APIs already exist; closes open loops |
| P0 | Notifications | Daily trigger, cheapest entry |
| P1 | Messengers (WeChat / WhatsApp / Telegram) via share or UI | The deck's demo |
| P1 | Ride-hailing / delivery (DiDi, Uber) | Cross-device scenario |
| P1 | MCP servers and A2A | Extensibility without client code |
| P2 | Smart home / Matter | Family scenario |
| P2 | School apps / e-government | Target audience, partnerships |
| P3 | Enterprise SSO / MDM | Different market |

## Team allocation

| Track | Person | Focus |
|---|---|---|
| Clients | existing client dev | Harmony/Android/Windows shells, Notifier UI, task inbox, handoff, approvals |
| Classic backend | existing backend dev | Bridge/relay, task transport, device registry |
| Tasks & Family | additional Dev 1 | Task Orchestrator, Family Space, open loops |
| App Intelligence | additional Dev 2 | Recipe schema/library, factory v0, Test Farm, registry |
| Research | PhD | R1 first; R2/R3/R4 as capacity allows |

## Metrics and gates

- **Task:** completion rate, resume success, handoff success, approval latency.
- **Recipes:** pass rate on app build N and N+1, human review hours, MTTR.
- **Notifier:** precision/recall of extracted events, false-card rate.
- **Family:** weekly active families, shared tasks completed, elder approval success.
- **Pilot:** time saved, app switches avoided, E2E success, 7-day repeat.
- **Safety:** zero payment executed without approval; zero action outside the
  disclosed scope; audit chain intact.

Proposed gates (hypotheses, to be calibrated in the pilot):

- ≥ 90% end-to-end success on mapped workflows.
- ≥ 95% regression pass across app builds.
- ≥ 80% recovery without a human.
- ≤ 10% of updates need human review.

## Six-month sequence

1. **Week 1** — `contracts/tasks`; Task Orchestrator skeleton.
2. **Weeks 2–8** — Task Orchestrator v0; Notifier v0 in parallel; Recipe schema.
3. **Weeks 4–10** — one app recipe end-to-end; Test Farm on emulator + one phone.
4. **Weeks 8–16** — Family Space v0; Recipe Factory v0; registry/OTA.
5. **Weeks 12–20** — A2A/MCP gateway; pilot metrics; SDK design.
6. **Week 24** — review: keep, park or expand each initiative.

## Explicitly not now

- 50 apps × 250–500 workflows.
- Virtual display / hidden execution as a promise.
- Enterprise MDM/SSO.
- On-device LLM as a product dependency.
- Wearables/TV hosts.
- Recipe marketplace before the library and registry are proven.

## Open decisions

- Is the Task Orchestrator a new service or part of the bridge?
- Is Family Space local-first (profiles + sync) or account-based from day one?
- Does the recipe schema live only in `contracts/` or also in `services/mapping`?
- Which single app is the first recipe: a school app, DiDi, or a system app?
- Does research start with R1 only, or split 60/40 with R2?
