# Appendix A â€” Port matrix

### A.1 Port as data

| Source | Files | Action | Note |
|---|---|---|---|
| `core/src/main/resources/knowledge/` | 46 | port format, re-validate content | 23 `APP.md` + 18 `SITE.md` are Android-specific |
| `core/src/main/resources/prompts/` | 118 | port, then prune | strip Android tool names |
| `core/src/main/resources/skills/` | 9 | port | validate manifests |

### A.2 Port as logic (pure Kotlin)

| Source | Files | HOPA target | Note |
|---|---|---|---|
| `core/knowledge/` | 11 | `core/knowledge/` | routing, channel, catalog, learning |
| `core/skills/` | 5 | `core/skills/` | personal skills |
| `core/harness/agent/` | 37 | `core/harness/agent/` | loop, context, recommender |
| `core/tool/` | 18 | `core/tool/` | registry, dispatcher, args |
| `core/uistate/` | 46 | `core/uistate/` | screen model |
| `core/observation/` | 2 | `core/observation/` | observations |
| `core/verify/` | 4 | `core/verify/` | verification |
| `core/record/` | 8 | `core/record/` | run records |
| `core/memory/` | 9 | `core/memory/` | memory |
| `core/guard/` | 4 | `core/guard/` | guards |
| `core/risk/` | 1 | `core/risk/` | risk levels |
| `core/replay/` | 5 | `core/replay/` | replay |
| `core/eval/` | 8 | `core/eval/` | evaluation |
| `core/model/` | 16 | `core/model/` | interface; replace transport |

### A.2b Remaining modules â€” decision required

These modules exist in the original `core/` but are not in the port matrix above. They
must be classified before Phase 3 ends; every "drop" needs a one-line reason.

| Source | Files | Likely action | Reason |
|---|---|---|---|
| `core/action/` | 10 | port | action model shared by loop and gate |
| `core/run/` | 11 | port | run lifecycle |
| `core/gate/` | 2 | port | approval gate |
| `core/context/` | 1 | port | context builder |
| `core/prompt/` | 3 | port | prompt assembly |
| `core/settings/` | 1 | port | settings model |
| `core/trigger/` | 3 | rewrite | HarmonyOS triggers differ |
| `core/usage/` | 5 | port | token and cost accounting |
| `core/trace/` | 5 | port | tracing |
| `core/selfcheck/` | 3 | port | startup self-check |
| `core/net/` | 4 | rewrite | ArkTS HTTP replaces the transport |
| `core/oauth/` | 6 | rewrite | platform sign-in |
| `core/workspace/` | 6 | rewrite | HarmonyOS file sandbox |
| `core/mcp/` | 5 | rewrite | MCP client over ArkTS |
| `core/remote/` | 9 | drop or rewrite | PC/remote assumptions |
| `core/general/` | 15 | triage | utilities; keep only the pure ones |
| `core/assembly/` | 3 | triage | wiring may not port |
| `core/adb/` | 11 | drop | no ADB on HarmonyOS |
| `core/shell/` | 14 | drop | no shell, no uid 2000 helper |
| `core/wechat/` | 1 | drop | Android helper |
| `core/child/` | 1 | drop | Android process model |
| `core/capability/` | 1 | rewrite | platform capability model |

`core/cap/` (73 files) is already listed in A.3 and is not repeated here.

### A.3 Rewrite

| Source | Files | HOPA target |
|---|---|---|
| `core/cap/` | 73 | `apps/harmony/capabilities/*` |
| `core/userscreen/`, `vision/`, `visual/` | 12 | a11y + OCR + vision |
| `apps/harmony/a11y`, `browser`, `sandbox`, `capsule`, `takeover`, `wechat` | â€” | ArkUI + extension |

### A.4 Drop

`adb`, `shell`, `proot`, `VirtualDisplay`, hidden `IActivityTaskManager` /
`ADD_TRUSTED_DISPLAY`, Android `wechat` helper, Android package knowledge, GPL
components.

---

