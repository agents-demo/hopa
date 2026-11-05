# ADR-0002 — Knowledge format and HarmonyOS bundle mapping

- Status: accepted
- Date: 2026-11-05

## Context

Mika stores 23 app files (`APP.md`) and 18 site files (`SITE.md`) as Markdown
with YAML front matter. Android package names do not map to HarmonyOS bundles.

## Decision

- Keep the Markdown + YAML front-matter format.
- Every app file declares `bundle`, `aliases`, `pace`, `validated` and
  `platform: harmonyos`.
- Build the real bundle map from `hdc shell bm dump -a`; never guess.
- Triage Mika's apps into **available**, **web-only** and **absent**. Absent
  apps are dropped with a written note, not silently rewritten.
- Store HarmonyOS system apps as first-class entries.

## Consequences

- Content is portable; package names are not.
- The loader must reject an app file whose bundle is missing.
- Knowledge is versioned per release and can be rolled back.

## Alternatives considered

- Embed knowledge in ArkTS constants: harder to review and update.
- Reuse Android package ids: wrong on HarmonyOS.
