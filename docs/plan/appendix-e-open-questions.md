# Appendix E â€” Assumptions and open questions

Each assumption must be confirmed or replaced by a decision record before the
phase that depends on it. Unresolved rows block the milestone, not the whole
project.

### E.1 Assumptions

- [ ] Target is HarmonyOS 6+ only; older versions are explicitly unsupported
- [ ] `AccessibilityExtensionAbility` remains the only on-device path
- [ ] The ACL decision arrives before Phase 4 exit; otherwise the fallback ships
- [ ] A physical HarmonyOS phone is available for the whole project
- [ ] The model provider stays reachable and within budget
- [ ] The `pc-agent` `hdc` + `uitest` evaluation rig is acceptable for enterprise use
- [ ] The upstream licence permits the planned reuse
- [ ] AppGallery accepts a foreground-only automation app, or sideloading is acceptable
- [ ] Chinese and English are the only launch locales
- [ ] The team can hire or contract ArkTS and Kotlin skills

### E.2 Open questions

- [ ] Decide: default model provider and fallback order (recorded in ADR-0006 during Phase 0)
- [ ] Decide: free, paid or internal-only distribution
- [ ] Decide: China-first or global launch
- [ ] Decide: open-source the HOPA core or keep it closed
- [ ] Decide: data residency for prompts and screenshots
- [ ] Decide: is a PC companion part of the product or only a dev tool
- [ ] Decide: support Android via a companion app, or not at all
- [ ] Decide: maximum task length and cost per task
- [ ] Decide: retention defaults for screenshots and run records
- [ ] Decide: whether users may bring their own model key
- [ ] Decide: minimum device and OS support matrix
- [ ] Decide: phone only, or also tablet, foldable and HarmonyOS PC
- [ ] Decide: whether HOPA needs its own account at all
- [ ] Decide: which 10 third-party apps are officially supported at launch

---

