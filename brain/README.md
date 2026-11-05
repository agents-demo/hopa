# HOPA brain (JVM reference)

Pure-Kotlin routing logic for the HOPA brain. It is the first real JVM slice of
Phase 2 and the contract both the JVM service and the ArkTS core will follow.

- JDK 17
- Kotlin 2.1.0
- No Android imports
- No network
- No UI

## Build and test

Windows:

```powershell
.\scripts\brain.ps1
```

Linux/macOS:

```bash
./scripts/brain.sh
```

The script downloads the pinned Kotlin compiler into `.tools/` (gitignored),
compiles `brain/src`, and runs `RouterTest` and `ServerTest`:

```text
RouterTest: 17 assertions passed
ServerTest: 17 assertions passed
```

The HTTP contract is documented in [`docs/brain.md`](../docs/brain.md).

## Scope

- `KnowledgeStore.matchTask` — lexical, installed-first, word boundaries
- `KnowledgeStore.packageFor`
- `KnowledgeStore.byPackage` / `byDomain`
- `ChannelAdvisor.line` — app vs web vs signed-in
- `GET /health`, `GET /version`, `POST /decide`, `GET /session/{id}`

## Not in this slice

- model calls
- the Mika knowledge files
- skills and the guide catalog
- ArkTS parity

Those are tracked in `docs/rebuild-plan.md` Phase 2.
