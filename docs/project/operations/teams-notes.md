# Team topology: working notes and plain-language companion

Status: **working notes, kept beside the proposal.** Written 2026-11-14.
Read [`teams.md`](teams.md) first; this page holds the reasoning, the plain-word
version, and the discussion log so the conversation can resume later without
re-deriving anything.

Audience: the product owner and team leads. Managers can use the "For managers"
section directly; engineers can use the glossary and the edges table in
[`teams.md`](teams.md).

## Plain-word glossary

| Term | Plain meaning |
|---|---|
| **Brick** | One part of the product that can break and be fixed on its own. A candidate team. |
| **Client application** | What a person touches: chat, buttons, approvals, notifications, settings. |
| **Execution** | Doing one step on the phone and checking that it actually worked. |
| **Task** | The record of what a person asked for: who asked, when, who approves, done or not. |
| **Family approval** | The rule about who must confirm an action before it happens. |
| **App knowledge (a "recipe")** | Step-by-step instructions for one app, plus how to tell the step worked. |
| **Knowledge factory** | How instructions are produced: models propose, humans review. |
| **Knowledge delivery** | Shipping signed instruction versions, switching them on gradually, rolling back. |
| **Verification farm** | Many phones and emulators that re-check instructions, especially after app updates. |
| **Notification understanding** | Turning a noisy notification into a task: what, when, who, how urgent. |
| **Product lab** | Research and measurement with a mandate: what to fix first, what the numbers say. |
| **Platform** | The transport: devices and services find each other and exchange messages. |
| **Architecture and security** | The shared rules: contracts, CI, release, approval policy, secrets. |

A "recipe" is not a task. A recipe is the cookbook page; a task is the order.
The cookbook does not know who is hungry, and the order does not contain the
steps.

## One request, start to finish

```
Mum: "Pay the internet"

1. CLIENT APPS       records the request and shows "understood"
2. TASKS             it is Mum's request, she confirms payments herself,
                     so it runs on her phone
3. FAMILY            the rule says: her own payments need her confirmation
4. APP KNOWLEDGE     the steps: open the bank, Payments, Internet,
                     amount, confirm
5. EXECUTION         performs one step at a time and verifies the screen
6. TASKS             each step closes; the task moves to done
7. PRODUCT LAB       records: succeeded, 5 steps, 40 seconds,
                     confirmation took 6 seconds
```

## The simple version (four teams) and why it changed

The first sketch had four teams:

```
Client apps - Tasks and family space - App knowledge and test farm - Research
```

Two problems surfaced while walking through it:

1. **"Tasks and family space" was two different things in one box.** A task
   answers "what and when"; a family rule answers "who may approve". They change
   for different reasons, so they became two bricks.
2. **"Research" is not a mandate.** It describes an activity, not a reason to
   hold the team. It was renamed by outcome: the Product lab exists to decide
   what to fix first and to prove the effect.

The intermediate name "reliability and trust" was rejected as well: in Russian it
reads like a QA department. The final name is **Product lab**, with a written
mandate.

## For managers

### Why each team exists

| Team | The reason it is funded |
|---|---|
| Client applications | A person gets the result on their own device |
| Execution and verification | A step runs on the phone and is proven to have worked |
| Tasks and notifications | A request is never lost; a notification can become a task |
| Family and approvals | The family decides who may do what, without HOPA deciding for them |
| App knowledge | A new app is supported in days, not months, and survives updates |
| Product lab | We know what to fix first and can prove the effect with numbers |
| Platform and integrations | Devices and services find each other and stay connected |
| Architecture and security (shared) | One set of rules and a green build for everyone |

### Slide-ready line

```
Client apps · Tasks and notifications · Family and approvals ·
App knowledge · Product lab
```

Execution, farm, platform and architecture are enablers shown underneath.

### What the Product lab lead says when asked "why do we fund this?"

> "We do not test code. We answer three questions: what to fix first, what we can
> promise partners, and how to make approval effortless. The output is decisions
> and numbers, not a test report."

### Headcount at seven teams

About 12 full-time equivalents:

| Team | People |
|---|---|
| Client applications | 2 developers + 0.5 designer |
| Execution and verification | 2 developers + 1 test engineer |
| Tasks and notifications | 2 developers + 0.5 product |
| Family and approvals | 2 developers |
| App knowledge | 2 developers |
| Product lab | 1 researcher + 0.5 analyst |
| Platform and integrations | 1 backend developer |
| Architecture and security | 1 engineer (or 0.5 + 0.5 reviewer) |

At five teams the same scope fits in about nine people: Tasks and family merge,
and the two shared roles stay shared.

### Launch waves

```
Weeks 1-2   Preparation: the two shared contracts, folders, plans, rhythm.
            No feature code.
Week 3      All teams start in parallel.
Weeks 3-12  Weekly demo; dependencies named out loud.
Week 12     First end-to-end check: one request, person to result.
Week 24     Keep, park or expand each initiative.
```

### Three checks that the model is working

1. One request runs end to end.
2. No team waits silently for another.
3. Every Friday the build is green and somebody can show it.

## Approval examples (what "approve" means)

| Action | Who asks | Who approves | Example rule |
|---|---|---|---|
| Payment | "pay the internet" | The account holder | Up to 1 000 - self; above - confirmation |
| App install | Child | Parent | A child installs only with a parent |
| Sending a message | "write as me" | The account owner | Always confirmed when sending as someone else |
| Deletion | "delete March photos" | The phone owner | Deletion is always confirmed |
| Acting on another phone | Son helps his mother | The mother or a named helper | Remote help only with the owner's consent |
| Changing settings | "turn off notifications" | The device owner | Privacy settings belong to the owner |
| Taking a shared task | "Mum asks; you do it" | The member who takes it | A member may take a shared task |

Family rules are written by the family, not by HOPA:

```
Child may:     look, search, set an alarm.
Child may not: pay, delete, message strangers.

Mother may do everything, but confirms her own payments.

The son may help remotely until she turns it off.
```

## Decisions taken in this discussion

| Date | Decision | Why |
|---|---|---|
| 2026-11-14 | Teams are named by outcome, not activity | "Research" and "numbers" describe work, not a reason to fund a team |
| 2026-11-14 | Twelve bricks are the full map; seven teams is the starting point | Twelve is maximum parallelism without enough people; seven keeps every brick owned |
| 2026-11-14 | Tasks and family are separate bricks | They change for different reasons |
| 2026-11-14 | Knowledge is separate from tasks | Cookbook page versus order |
| 2026-11-14 | One owner per folder; shared contracts belong to Architecture | Prevents two teams editing the same thing |
| 2026-11-14 | The Product lab is not QA | Its mandate is decisions and numbers, not test reports |
| 2026-11-14 | Four teams is too coarse; five is the floor | At four, tasks and family blur again |

## Alternatives still on the table

| Shape | When it is right | Cost |
|---|---|---|
| 12 teams | Full funding, high parallelism | Heavy coordination, 20+ people |
| 7 teams (recommended) | The intended staffing | Needs the two shared contracts first |
| 5 teams | Smaller budget | Tasks and family share a lead; slower on both |
| 4 teams (the first sketch) | Very small team | Blurred ownership; rejected for now |

## Open questions to settle next

| Question | Recommendation | Consequence if deferred |
|---|---|---|
| Is the task service a new `services/tasks`, or part of the bridge? | Separate service; the bridge stays transport | The task contract cannot be written cleanly |
| Which app gets the first recipe? | A system app first (hermetic), a ride-hailing app for the cross-device demo | The knowledge team picks the wrong harness |
| Is the family local-first or account-based? | Local-first profiles with optional sync | Data model and privacy work move in the wrong direction |
| Where does the Product lab start? | R1 (recipes that survive updates); consider 60/40 with R3 because the approval interface exists | The lab spends a quarter on data plumbing |
| Where does the test farm run? | Start on the existing CI runners, move when flakiness appears | Premature hardware spend |
| When does Windows get a team? | After the Android gates close | Two half-built clients |

## Where the conversation stopped

Next discussion topics, in the order they will block work:

1. Confirm the seven teams and the two shared roles.
2. Confirm the task-service boundary (`services/tasks` versus bridge).
3. Confirm the first recipe app.
4. Draft `contracts/tasks` and `contracts/recipes` (two weeks, no feature code).
5. Agree the weekly rhythm and who runs it (Architecture).
