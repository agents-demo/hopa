# Skills

A skill is a short, reusable procedure the model can invoke by name or by a
trigger term. There are six launch skills.

## Format

`services/brain/knowledge/skills/<name>/SKILL.md`:

```markdown
---
name: documents
display: Documents
description: Read and summarize a PDF or document
terms: [PDF, document, 文档, 提取]
apps: []
sites: []
---
# Documents

- Open the file from Files or a share target.
- Use sandbox.run with the bundled PDF extractor when it is available.
- Summarize the text; never upload the file without consent.
```

| Field | Required | Meaning |
|---|---|---|
| `name` | yes | Stable id |
| `display` | yes | Human label |
| `description` | yes | One line |
| `terms` | no | Trigger words |
| `apps` | no | Bundles the skill may use |
| `sites` | no | Domains the skill may use |

## The six skills

| Skill | Purpose |
|---|---|
| `documents` | PDF extraction and summary |
| `content-transcribe` | audio → text, redacted |
| `info-research` | web/app research with sources |
| `messaging` | draft only; ask before Send |
| `skill-authoring` | create a new skill |
| `configure` | settings, account and permission setup |

## Loader

`services/brain/src/main/kotlin/hopa/services/brain/SkillLoader.kt` parses every `SKILL.md` and
validates the required fields. `SkillLoaderTest` loads all six.

## Status

- Six manifests exist and parse.
- No skill is executed by the app yet.
- Personal skill creation is described, not implemented.
- Skills that need the sandbox are blocked until Pyodide/QuickJS are bundled.

## Add a skill

1. Create `services/brain/knowledge/skills/<name>/SKILL.md`.
2. Fill the front matter and write the shortest reliable path.
3. Mark irreversible steps and ask-before-send actions.
4. Run `./tools/scripts/brain.sh` (or `.\\tools\scripts\\brain.ps1`).
