# Knowledge format

HOPA stores app knowledge as Markdown with a small, strict front-matter block.
No YAML library is required; the parser accepts only `key: value` lines.

## Layout

```
brain/knowledge/apps/
├── settings/APP.md
...
└── music/APP.md

brain/knowledge/sites/
├── amazon.com/SITE.md
...
└── zhipin.com/SITE.md
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
- 15 Mika apps catalogued with `bundle: UNCONFIRMED`: Baijiahao, Bilibili, BOSS
  Zhipin, Dedao, Douyin, Feishu, Jike, Kuaishou, QQ Mail, Toutiao, WeChat,
  Weibo, Xianyu, Xiaohongshu, Zhihu. They match by name/alias but never launch
  by an unverified bundle.
- 21 web sites under `brain/knowledge/sites/`.
- 6 skill manifests under `brain/knowledge/skills/`.
- All are `validated: pending`.
- The 23 Mika Android apps are triaged in `docs/knowledge-triage.md`; 1 is
  replaced, 15 are catalogued with unconfirmed bundles, 7 are web-only.

## The `UNCONFIRMED` bundle

`bundle: UNCONFIRMED` (or `unknown`) means the app is known by name but no
HarmonyOS bundle has been checked on a device. The loader turns it into an empty
package list, so the router can still match the name and answer questions about
the app, but nothing can launch a made-up package. Replace it only after
`bm dump -n` confirms the name.

Add `bundle_verified: YYYY-MM-DD` once the bundle is checked on a device. Without
it, the app catalogue shows the bundle as "unverified".

## The in-app catalogue

`scripts/build-app-catalog.py` reads every `APP.md` and generates
`app/entry/src/main/ets/service/AppCatalog.ets`, which the **Apps** tab shows.
The generated file is committed, and `build-app-catalog.py --check` runs in CI
and in `scripts/run-tests`, so the app and the knowledge cannot drift.

## Sites

`SITE.md` uses the same strict front matter:

```markdown
---
name: xiaohongshu.com
display: Xiaohongshu
domains: [xiaohongshu.com, xhslink.com]
aliases: [小红书, XHS]
apps: [xiaohongshu]
validated: pending
platform: harmonyos
---
```

`SiteLoader` validates every file; `SiteLoaderTest` loads all 18 and checks
that `byDomain` resolves `www.xiaohongshu.com`.

## Honest limits

- Format validation is not screen validation.
- The selectors are prose, not executable selectors yet.
- The 23 Mika app files and 21 site files are a separate port.
