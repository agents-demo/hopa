# Abuse, refusal and content policy

HOPA is a general-purpose personal assistant. It must refuse clear abuse and hand
professional or verification work back to the user.

## Disallowed tasks

| Category | Examples | Behaviour |
|---|---|---|
| Illegal | malware, ransomware, bombs, keyloggers, account theft | refuse |
| Harmful | poison, weapons, hurting someone | refuse |
| Harassment | stalking, doxxing, repeated unwanted contact | refuse |
| Fraud | scams, phishing, stealing money | refuse |
| Financial advice | "which stock", "should I invest" | refuse, refer to a professional |
| Medical advice | diagnosis, medicine, dosage | refuse, refer to a doctor |
| Legal advice | lawsuits, "legal advice" | refuse, refer to a lawyer |
| CAPTCHA | slider, image, one-time human check | **hand over**, never solve |

The classifier is `services/evals/baseline/src/hopa_baseline/refusal.py`. It runs **before** the model
and before any device observation. A refusal is final for that task.

## Plain messages

Refusals are short and do not lecture:

- "I can't help with that request."
- "I can't help harass or track a person."
- "I can't give medical advice. Please ask a doctor."
- "I can't solve CAPTCHA. Please complete it yourself and tell me to continue."

## CAPTCHA and 2FA

HOPA never solves a CAPTCHA and never types a one-time code. It hands the screen
back to the user, waits, then continues after an explicit "continue".

## Scraping and robots.txt

- Respect `robots.txt` and the site's terms.
- Do not bypass rate limits, paywalls or login walls.
- Bulk extraction is capped by the same rate limiter as messaging and buying.
- The user is told when a task looks like scraping at scale.

## Minors

HOPA is not directed at children. A minor-protection policy (age gate, default
restrictions, guardian consent) is required before a public release. It is not
implemented yet.

## Reporting abuse

- Security issues: private advisory, see `SECURITY.md`.
- Abuse reports: GitHub issue with the `risk` label.
- Response owner: the acting maintainer (`docs/operations/owners.md`).

## Model provider filters

The provider may add its own safety filter. Its behaviour and error messages
must be tested with the chosen provider before release; it is not tested yet.

## Tests

- `services/evals/baseline/tests/test_refusal.py` — 20 jailbreak prompts, CAPTCHA handover,
  professional-advice categories.
- `services/evals/baseline/tests/test_safety.py` — screen text cannot become an instruction.
- `services/evals/baseline/tests/test_net.py` — exfiltration to an unapproved host is blocked.
- `services/evals/baseline/tests/test_policy.py` — payment and irreversible actions ask.
