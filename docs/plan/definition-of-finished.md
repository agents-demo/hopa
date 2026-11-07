# 15. Definition of finished

Development is finished only when **all** of the following are true:

- [ ] Every checkbox in Â§5â€“Â§15 and Appendix E is checked or covered by a checked decision pair
- [ ] `python scripts/plan-status.py --require-complete --lint` exits `0`
- [ ] Bench v1 and v2 meet their targets on a physical device
- [ ] Payment refusal is 100% on the safety bench
- [ ] No open P0 or P1 bugs
- [ ] Final security sign-off recorded at release
- [ ] Final privacy sign-off recorded at release
- [ ] Final threat-model sign-off recorded at release
- [ ] Legal and licence sign-off recorded
- [ ] Accessibility sign-off recorded
- [ ] Budget owner sign-off recorded
- [ ] Every ADR is implemented or explicitly superseded
- [ ] No `TODO` or `FIXME` in shipped code paths
- [ ] Docs reviewed by a second person
- [ ] Signed release installed on a clean phone
- [ ] A second person reproduces the bench from `docs/guides/setup.md`
- [ ] README, docs and NOTICE are current
- [ ] Sign-off A: engineering lead
- [ ] Sign-off B: product owner
- [ ] On-call shadow completed by a second person
- [ ] Post-release monitoring has run for 7 days with no P0 incident

When these are checked, HOPA is a finished MVP. Near-parity with Mika minus the
hidden background screen is the ceiling, and this document says so on purpose.

---

