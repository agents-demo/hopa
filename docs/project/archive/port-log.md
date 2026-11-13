# Implementation log

Reused ideas are recorded here. HOPA keeps its Apache-2.0 notice and never
copies Android-only code.

| Date | Source | HOPA target | Action | Notes |
|---|---|---|---|---|
| 2026-11-05 | lexical router rules | `services/brain/src/main/kotlin/hopa/brain/routing/Router.kt` | clean-room reimplementation | lexical match, installed-first, word boundaries, generic-word rejection |
| 2026-11-05 | channel advisor rules | `services/brain/src/main/kotlin/hopa/brain/routing/Router.kt` | clean-room reimplementation | app vs web vs signed-in |
| 2026-11-05 | alias and package map | `services/brain/src/main/kotlin/hopa/brain/routing/Router.kt` | clean-room reimplementation | alias and package map |
| 2026-11-05 | — | `pc-agent apps` | new code | installed bundle listing from `bm dump -a` |
| 2026-11-05 | — | `services/brain/src/main/kotlin/hopa/brain/http/Server.kt` | new code | `/health`, `/version`, `/decide`, `/session/{id}`; JDK HTTP server + Gson |
| 2026-11-06 | knowledge format | `services/brain/src/main/kotlin/hopa/brain/knowledge/KnowledgeLoader.kt` | clean-room | Markdown + front matter; 12 HarmonyOS system app files |
| 2026-11-06 | prompt rules | `services/brain/src/main/kotlin/hopa/brain/prompts/Prompts.kt` | clean-room | system rules, intent gate, channel order, truncation |
| 2026-11-06 | skill format | `services/brain/src/main/kotlin/hopa/brain/knowledge/SkillLoader.kt` | clean-room | 6 skill manifests with terms/apps/sites |
| 2026-11-06 | site metadata | `services/brain/knowledge/sites/` | clean-room | 21 sites; domains and aliases, bodies rewritten |
| 2026-11-06 | app catalogue | `services/brain/knowledge/apps/` | clean-room | added 15 catalogued apps with `bundle: UNCONFIRMED`; no guessed packages |

No third-party source file is copied. The routing rules are reimplemented from
documented behaviour.

## Verification

```bash
./tools/scripts/brain.sh          # or .\tools\scripts\brain.ps1
# RouterTest: 19 assertions passed
```

## Honest limits

- Matching is **lexical**, not embeddings.
- There is no auto-learning for an unknown app; the generic list → label →
  launch path is the fallback.
- Pinyin and locale-aware matching are not done yet.

## Not included yet

- `GuideCatalog` and the skills index
- the full app knowledge corpus
- the HTTP `/decide` service for external clients

---

Note (2026-11-12): paths in this log are frozen. `harness/` is now `evals/`
(`evals/bench`, `evals/baseline`) and `services/pc-agent` becomes
`services/bridge`; see ADR-0007 and docs/project/plan/README.md.
