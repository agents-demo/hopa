# 16. Risks

| Risk | Impact | Mitigation | Owner |
|---|---|---|---|
| Accessibility ACL denied | no standalone product | PC-tethered fallback; file at Phase 3 start | TBD |
| AppGallery rejects automation | no distribution | foreground-only, explicit consent, no hidden pages | TBD |
| Payment misclassification | financial harm | screen-semantic classifier, fail-closed, 100% bench | TBD |
| Custom-drawn UIs unreadable | task failure | OCR + vision, unsupported list | TBD |
| HarmonyOS knowledge gap | bad routing | rebuild 23 files, `list_apps` first | TBD |
| WASM limits | scripts break | pure Python/JS only, companion fallback | TBD |
| Model outage | unusable | clear error, fallback list, no infinite retry | TBD |
| Cost/latency | poor UX | caps, small routing model, caching | TBD |
| Scope creep toward â€œMika cloneâ€ | never ships | this documentâ€™s out-of-scope list | TBD |

Critical path: ACL â†’ a11y â†’ M4. Everything before M4 must ship without it.

---

