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
