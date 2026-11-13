# A2 - parser and context budget

Date: 2026-11-13. Only the two items ticked in the plan are covered.

## Parser

`DecisionParser.parse`:

- strips a fenced block, then scans balanced objects and takes the last one
  (`BalancedObjectScanner`);
- rejects `finish`/`done` carrying an action and returns them as text;
- ignores a model-supplied `isPayment` flag;
- rejects an unknown kind with `E_SCHEMA` (the A1 negative case).

Verified by `DecisionParserTest` (6 tests) and the three negative conformance
fixtures.

## Budget

`ContextBudget` hard-codes the contract numbers: 24 000 chars, keep the last 6
messages untouched, trim older lines to 400 chars, then drop from the front.
`AgentLoop` calls `budget.fit(context.history)` before the first model call.

## Not done in A2

- No 1 500 ms settle between the observation and the next prompt.
- No duplicate-launch short-circuit and no cancellation checkpoints.
- The prompt is hand-written prose; `PROMPT_RULES` is generated but the builder
  does not consume it and no test asserts the phrases.
- `AppRouter` has no test over `contracts/fixtures/routing.json`.
- `RunNarrator` has no tap grouping.
- There is no `ObservationProducer`/`ScreenSource`, so bridge → accessibility →
  browser precedence does not exist.
- No loop test with a stub model (payment stop, cancel, token accounting,
  14-step cap, budget cases).
## Update 2026-11-13: the loop is complete

- `AgentLoop` now settles 1 500 ms after an action, refuses a duplicate launch of
  the same app, checks cancellation before every model call, before an action and
  before the final summary, accumulates token usage across calls, and falls back
  to a plain-text summary after 14 steps.
- `AgentLoopTest` (6 cases) drives a scripted model: read action, refused
  payment, the 14-step cap plus the final call, duplicate launch, cancellation
  and usage totals.
- `SystemPromptTest` asserts every phrase in `contracts/prompts/rules.v1.json`
  through the generated `PROMPT_RULES`, plus the web and no-surface branches.
- `AppRouterTest` reproduces all 12 routing fixtures including score and term.
- Still open: tap grouping in `RunNarrator`, and `ScreenSource` (bridge →
  accessibility → browser) which needs A5/A7.
