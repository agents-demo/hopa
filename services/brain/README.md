# HOPA brain (JVM reference)

Pure-Kotlin routing logic for the HOPA brain. It is the first real JVM slice of
Phase 2 and the contract both the JVM service and the ArkTS core will follow.

- JDK 17
- Kotlin 2.4.21, through Gradle only
- No Android imports
- No network
- No UI

## Build and test

From the repository root:

```bash
./apps/android/gradlew -p services/brain check
```

`check` compiles `brain/src` and runs the six `*TestKt` programs as JavaExec
tasks; Gradle's Kotlin plugin is the only compiler:

```text
RouterTest: 17 assertions passed
ServerTest: 20 assertions passed
```

To build the runnable reference server:

```bash
./apps/android/gradlew -p services/brain fatJar
java -jar services/brain/build/brain.jar 8731
```

The HTTP contract is documented in [`docs/brain.md`](../../services/docs/reference/brain.md).

## Scope

- `KnowledgeStore.matchTask` — lexical, installed-first, word boundaries
- `KnowledgeStore.packageFor`
- `KnowledgeStore.byPackage` / `byDomain`
- `ChannelAdvisor.line` — app vs web vs signed-in
- `KnowledgeLoader` — Markdown + front matter for 12 HarmonyOS apps
- `PromptBook` — system rules, intent gate, channel order, truncation
- `SkillLoader` — 6 `SKILL.md` manifests with trigger terms
- `SiteLoader` — 18 `SITE.md` manifests with domains
- `GET /health`, `GET /version`, `POST /decide`, `GET /session/{id}`

## Not in this slice

- model calls
- the app knowledge files
- skills and the guide catalog
- ArkTS parity

Those are tracked in `docs/rebuild-plan.md` Phase 2.
