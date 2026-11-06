# Knowledge format

HOPA stores app knowledge as Markdown with a small, strict front-matter block.
No YAML library is required; the parser accepts only `key: value` lines.

## Layout

```
brain/knowledge/apps/
├── settings/APP.md
├── clock/APP.md
├── calendar/APP.md
├── contacts/APP.md
├── notepad/APP.md
├── files/APP.md
├── camera/APP.md
├── gallery/APP.md
├── browser/APP.md
├── appgallery/APP.md
├── petal-maps/APP.md
└── music/APP.md
```

## File format

```markdown
---
name: settings
display: Settings
bundle: com.huawei.hmos.settings
aliases: [设置, settings]
pace: careful
validated: pending
platform: harmonyos
---
# Settings

- Open Settings to change Wi-Fi, Bluetooth, Display or Battery.
```

| Field | Required | Meaning |
|---|---|---|
| `name` | yes | Stable id used by the router |
| `display` | yes | Human label |
| `bundle` | yes | HarmonyOS bundle name |
| `aliases` | no | Comma-separated names in `[a, b]` |
| `pace` | yes | `careful` for irreversible paths |
| `validated` | yes | A version/date, or `pending` |
| `platform` | yes | Must be `harmonyos` |
| `service` | no | Groups aliases; defaults to `name` |

`validated: pending` means the file has **not** been smoke-tested on a device.
That is honest: the loader validates the format, not the screen selectors.

## Add an app

1. Create `brain/knowledge/apps/<name>/APP.md`.
2. Fill the required fields. Use the real bundle from `hdc shell bm dump -a`.
3. Write the shortest path to the task, with irreversible steps marked.
4. Run:

```bash
./scripts/brain.sh          # or .\scripts\brain.ps1
```

The `KnowledgeLoaderTest` loads every file and fails on a missing field or a
non-HarmonyOS platform.

## Current state

- 12 HarmonyOS system apps: Settings, Clock, Calendar, Contacts, Notepad,
  Files, Camera, Gallery, Browser, AppGallery, Petal Maps, Music.
- All are `validated: pending`.
- No Mika app/site corpus has been ported yet.
- No skills or guide catalog yet.

## Honest limits

- Format validation is not screen validation.
- The selectors are prose, not executable selectors yet.
- The 23 Mika app files and 18 site files are a separate port.
