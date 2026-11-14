# ADR-0019 - The model needs a network; the shell does not

- Status: accepted
- Date: 2026-11-13
- Relates to: ADR-0016 (clients own the loop), ADR-0018 (shared data)

## Context

The clients run the loop themselves and call a model provider over HTTPS
(`OpenAiCompatibleClient`, `AnthropicClient`, `GeminiClient`). There is no
on-device model. A sentence like "offline core" was therefore ambiguous: it
meant "no PC and no bridge", not "no network". Without a network the app can
open, show history and settings, and act on the device, but it cannot decide.

That must be a stated product boundary, not a surprise in a lift.

## Decision

- **The offline promise is tiered, and the tiers are named in the UI.**
  - **Tier 0 - shell (offline).** Chat history, settings, records, catalogue,
    policy, launchpad, accessibility inspection, and a small set of
    deterministic commands that need no model.
  - **Tier 1 - local network model.** Any OpenAI-compatible server on the LAN
    (Ollama, llama.cpp, vLLM) through the bridge or directly; no internet. The
    endpoint is a setting, the key is optional, and cleartext is allowed only to
    private ranges (A0).
  - **Tier 2 - cloud model (today).** The current providers, BYOK, full quality.
  - **Tier 3 - on-device model.** A **spike**, not a promise. It ships only if
    it passes the acceptance criteria in the Android plan (S1).
- **Data delivery stays compiled-in (ADR-0018).** A signed, versioned catalogue
  delta may be added later; policy, prompt rules and the observation hash are
  never fetched in a way that can weaken the payment gate. The gate is local in
  every tier.
- **Honest state, never a silent failure.** The client shows `cloud`, `LAN`,
  `shell only`, or `no model`, with the reason. A turn that needs a model and
  has none says so before it starts; it does not queue and pretend.
- **No queued requests as an "offline" answer.** A request that will run when
  the network returns is a deferred task, not an offline assistant, and is not
  counted as one.

## Consequences

- Documentation and store copy say "works without a PC; needs a network or a
  LAN model for answers", not "works offline".
- Android A4 adds the LAN preset and the provider state; the on-device work is
  a separate spike with a go/no-go.
- The evaluation suite gains a provider dimension: a task must state whether it
  ran on cloud, LAN or a stub, so a quality claim cannot mix them.
- A LAN model has no vendor key to protect; a cloud key stays in Keystore.
- The user can run a capable model on a PC without sending prompts to a cloud,
  which is also the privacy answer for a local-first deployment.

## Alternatives considered

- **On-device model first.** Rejected as a v1 dependency: RAM, heat, battery,
  latency and JSON reliability vary by device; it is a spike, not a foundation.
- **A hosted proxy for the model.** Useful for billing and key hiding in a
  hosted product, but it makes the network a prerequisite and needs an account;
  it does not solve offline.
- **Ship a tiny model for routing only.** Possible after S1, but it is still a
  model; it does not remove the dependency for real answers.
- **Pretend the shell is the assistant.** Rejected: dishonest and quickly
  visible.
