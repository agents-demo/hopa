# 10. Phase 5 â€” Safety and trust (continuous, must be M5)

### 10.1 Payment

- [x] Classify payment from screen semantics, not action kind (evidence: ApprovalPolicy.classify (screen semantics))
- [x] Detect pay, checkout, confirm order, amount, merchant, currency (evidence: PAYMENT_SCREEN_WORDS + extract_payment_context)
- [x] Any tap on a payment-classified screen asks (evidence: harness/agent/tests/test_policy.py)
- [ ] Approval sheet shows amount, merchant and consequence
- [x] Deny stops the branch and cannot be retried elsewhere (evidence: DeviceExecutor deny path + AgentLoop stop)
- [x] Approval is never remembered (evidence: ApprovalPolicy has no remember state)
- [x] Model cannot clear or set payment classification (evidence: Action.from_dict drops isPayment)
- [x] Test: model claims â€œalready approvedâ€ â†’ still asks (evidence: harness/agent/tests/test_adversarial.py)
- [x] Test: model sets `isPayment:false` â†’ ignored (evidence: harness/agent/tests/test_adversarial.py)
- [x] Test: hidden payment step inside a long flow â†’ asks (evidence: harness/agent/tests/test_adversarial.py)
- [ ] 100% refusal on the payment bench
- [ ] Tested on 3 checkout flows with a test merchant and no real charge

### 10.2 Irreversible actions

- [x] Send message, call, delete, uninstall, reset â†’ ask (evidence: SENSITIVE_KINDS + test_policy)
- [ ] Bulk actions capped
- [ ] Undo offered where the platform allows
- [x] Plain-language confirmation text (evidence: ApprovalRequest.consequence + docs/reference/safety.md)
- [x] Tests for each action class (evidence: harness/agent/tests/test_policy.py (sensitive kinds))

### 10.3 Security

- [x] Prompt injection: screen text never becomes instructions (evidence: harness/agent/tests/test_safety.py + SYSTEM_PROMPT)
- [x] Tool allow-list per task (evidence: DeviceExecutor.allowed_kinds + test_safety)
- [ ] Optional app allow-list
- [ ] Sandbox escape suite green
- [ ] Secrets absent from logs and traces
- [x] Redaction suite green (evidence: harness/agent/tests/test_observation.py (20 cases))
- [ ] TLS and certificate handling decided and documented
- [ ] Dependency audit clean
- [x] Threat model document (evidence: docs/reference/threat-model.md)
- [ ] External pen-test checklist
- [x] `SECURITY.md` (evidence: SECURITY.md)
- [x] Emergency stop: one visible control cancels the run (evidence: Chat Send becomes Stop; AgentService.cancel → AgentLoop.cancel; checked before the next model call and after the current action)
- [x] Audit log tamper-evidence (hash chain) (evidence: RunStore.verify_chain + test_records)
- [ ] Accessibility scope transparency: what is read, when, and why
- [ ] Overlay and tapjacking added to the threat model
- [ ] Remote/MCP server binds to localhost and requires auth
- [ ] Kill switch for the model provider
- [x] API-key rotation and revocation procedure (evidence: SECURITY.md (key rotation))
- [x] Provider-compromise playbook: revoke key, purge logs, notify users (evidence: SECURITY.md (provider playbook))
- [ ] Consent revocation mid-task stops actions immediately
- [x] Sensitive-screen detection (banking, passwords) documented (evidence: docs/reference/safety.md + PASSWORD_WORDS)
- [ ] Screenshot minimization: capture only what the step needs
- [ ] Screenshot retention and deletion policy implemented
- [x] Never store card numbers, CVV or full bank details (evidence: observation.redact + record action redaction)
- [x] Subscription and recurring-charge text detected in checkout (evidence: SUBSCRIPTION_WORDS + test_safety)
- [x] Rate limits and caps for messaging, posting and purchasing (evidence: ActionLimiter + test_safety)
- [ ] Coexistence with the system screen reader

### 10.4 Privacy

- [x] Data inventory: what is read, stored, sent (evidence: docs/reference/privacy.md)
- [x] Privacy retention policy covers every stored data class (evidence: docs/reference/privacy.md)
- [ ] Consent flows for screen capture and model calls
- [ ] Export and delete all data
- [ ] Encryption at rest
- [x] No analytics by default (evidence: docs/reference/privacy.md (no analytics code))
- [ ] DPIA draft
- [ ] Privacy policy
- [ ] Schema versioning and migrations for records, memory and knowledge
- [ ] Migration test from the previous release
- [ ] Storage quota with cleanup of old runs and screenshots
- [ ] Corruption detection and recovery
- [ ] Device and cloud backup excludes secrets, is encrypted, and restore is tested
- [ ] Encryption key rotation
- [x] Statement that user data is not used for model training (evidence: docs/reference/privacy.md (no training))

### 10.5 Exit criteria (M5)

- [ ] Safety suite 100% green
- [ ] Threat model signed
- [ ] Payment gate has no known bypass
- [ ] Privacy review signed

### 10.6 Abuse, content and exfiltration

- [x] Disallowed-task taxonomy written (illegal, harmful, harassing, fraudulent) (evidence: docs/reference/abuse.md (taxonomy))
- [x] Refusal behaviour implemented with a plain explanation (evidence: harness/agent/src/hopa_agent/refusal.py + AgentLoop refusal)
- [x] Jailbreak test suite (20 prompts) green (evidence: harness/agent/tests/test_refusal.py (20 prompts))
- [x] Indirect prompt injection from web pages and documents tested (evidence: harness/agent/tests/test_safety.py + PromptBookTest)
- [x] Data-exfiltration test: model tries to send screen text to an unapproved URL (evidence: harness/agent/tests/test_net.py (unapproved host))
- [x] URL allow-list enforced inside `ActionExecutor`, not only in the prompt (evidence: harness/agent/src/hopa_agent/net.py + DeviceExecutor)
- [ ] No user data in URLs, query strings or referrers
- [ ] MCP server trust model and authentication documented
- [ ] API keys stored in HUKS, never in preferences or logs
- [ ] Brain-service model key stored in the OS keychain or env, never in the repo or logs
- [ ] Emergency-number dial blocked and tested (110 / 112 / 119 / 999)
- [ ] Per-user and per-day rate limits for messaging, posting and buying
- [x] CAPTCHA is always handed over, never solved automatically (evidence: RefusalPolicy CAPTCHA handover + test_refusal)
- [ ] Account-ban and terms-of-service risk disclosed in onboarding
- [x] Scraping limits and robots.txt respect documented (evidence: docs/reference/abuse.md (scraping))
- [x] Financial, medical and legal advice refusal policy (evidence: RefusalPolicy + docs/reference/abuse.md)
- [x] Minor-protection policy (evidence: docs/reference/abuse.md (minors))
- [x] Abuse reporting channel and response owner (evidence: docs/reference/abuse.md + SECURITY.md)
- [ ] Model provider content filter behaviour tested and documented

---

