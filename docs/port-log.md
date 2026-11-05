# Port log

Every reuse of Mika logic is recorded here. HOPA keeps its Apache-2.0 notice
and never copies Android-only code.

| Date | Mika source | HOPA target | Action | Notes |
|---|---|---|---|---|
| 2026-11-05 | `core/knowledge/KnowledgeStore.kt` | `brain/src/main/kotlin/hopa/brain/Router.kt` | clean-room reimplementation | lexical match, installed-first, word boundaries, generic-word rejection |
| 2026-11-05 | `core/knowledge/ChannelAdvisor.kt` | `brain/src/main/kotlin/hopa/brain/Router.kt` | clean-room reimplementation | app vs web vs signed-in |
| 2026-11-05 | `KnowledgeStore.packageFor` | `brain/src/main/kotlin/hopa/brain/Router.kt` | clean-room reimplementation | alias and package map |
| 2026-11-05 | — | `pc-agent apps` | new code | installed bundle listing from `bm dump -a` |

No Mika source file is copied. The routing rules are reimplemented from the
documented behaviour; Mika is credited in `NOTICE`.

## Verification

```bash
./scripts/brain.sh          # or .\scripts\brain.ps1
# RouterTest: 17 assertions passed

grep -r "android\." brain/src || true
# no output
```

## Honest limits

- Matching is **lexical**, not embeddings.
- There is no auto-learning for an unknown app; the generic list → label →
  launch path is the fallback.
- Pinyin and locale-aware matching are not done yet.
- The 23 `APP.md` and 18 `SITE.md` files are not ported yet.

## Not ported yet

- `GuideCatalog` and the skills index
- the Mika knowledge corpus
- the HTTP `/decide` service
- the ArkTS parity layer

These are tracked in `docs/rebuild-plan.md` Phase 2.
