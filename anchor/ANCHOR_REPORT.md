# Anchor Decision Engine — Report

Generated 2026-11-19 14:51 UTC by `anchor_report.py`. Data: `map_tree.json` (63 states, 62 transitions), `anchor_navigation_rules.json` (18 rules), `anchor_navigation_cases.json` (22 cases). Threshold: 20%.

## How a decision is made

1. **Current state** = last element of `calls` (the UI history).
2. **Rules fire** when all three hold: the intent cue matches the command (`question_word` / `task_word` / `task_bigram`, any-of lists allowed), the progress cue matches the history (`last_call` / `history_has` / `no_calls`), and the rule's decision is among the case's `options` (available-option gate).
3. **Votes are max-aggregated** per next state.
4. **Chosen** = state with the highest RAW vote (ties keep rule order).
5. **Gate**: no rule fired, or highest raw vote < 20% → **ASK MODEL** (teacher/SLM fallback); nothing is executed blindly.
6. **Action selection**: the graph transition `current → chosen` supplies the operation + selector (`find` / `text` / `key` / `move.delta`); `anchor_replay.py` resolves the selector against the live uiautomator dump at runtime — no hard-coded coordinates.

## Summary matrix (per state, from the cases)

| Current state | Next-state scores | Outcome |
|---|---|---|
| s1 (Map home (Explore)) | s2 95% · ASK MODEL (1 case) | mode-dependent |
| s2 (Search page - search box focused, empty) | s3 90% | s3 |
| s3 (Search page - origin typed, suggestion listed) | s4 85% | s4 |
| s4 (Place page - ${src}) | s5 90% | s5 |
| s5 (Directions form - ${src} filled as destination, start empty) | s6 85% | s6 |
| s6 (Directions form - start = ${src}, destination empty) | s63 85% | s63 |
| s7 (Directions form - destination field focused) | s8 90% | s8 |
| s8 (Search page - destination typed, suggestion listed) | s9 90% | s9 |
| s9 (Route chosen - car (driving) by default) | finish 92% · s11 90% · s10 88% · ASK MODEL (3 cases) | mode-dependent |
| s10 (Method: public transport (1 hr 11 min)) | s9 90% · s49 85% | mode-dependent |
| s11 (Method: walking (4 hr 47 min)) | finish 90% | finish |
| s62 (Typed, no suggestion (live-discovered 2026-11-19)) | ASK MODEL (1 case) | ASK MODEL |
| s63 (Destination search (live-discovered 2026-11-19)) | s8 90% | s8 |

(Per-mode detail at s9: `finish` 92% when the command says car, `s11` 90% for walk, `s10` 88% for public transport/bus; with no or unknown mode the only vote is 10% → ASK MODEL.)

## Case-by-case details

### Case 1 — state s1 (Map home (Explore))

- Command: `navigate from ${src} to ${dst} by car`
- Question: `Where would you like to go?`
- Options considered: s2
- Matched rules:
  - `r01-open-search` p=95%: navigation command at map home -> open the search box

| Next state | Raw vote | Normalized | Action |
|---|---|---|---|
| s2 — Search page - search box focused, empty | 95% | 100% | click (find resource-id="com.google.android.apps.maps:id/search_omnibox_text_box"~exact) |

**DECISION: s2** (95% ≥ 20%)

Expected: s2 → MATCH

### Case 2 — state s2 (Search page - search box focused, empty)

- Command: `navigate from ${src} to ${dst} by car`
- Options considered: s3
- Matched rules:
  - `r02-type-origin` p=90%: search box focused -> type the origin

| Next state | Raw vote | Normalized | Action |
|---|---|---|---|
| s3 — Search page - origin typed, suggestion listed | 90% | 100% | set_text (find resource-id="com.google.android.apps.maps:id/search_omnibox_edit_text"~exact) |

**DECISION: s3** (90% ≥ 20%)

Expected: s3 → MATCH

### Case 3 — state s3 (Search page - origin typed, suggestion listed)

- Command: `navigate from ${src} to ${dst} by car`
- Options considered: s4
- Matched rules:
  - `r03-commit-origin` p=85%: origin typed ('from A') -> tap the top suggestion to open the place page

| Next state | Raw vote | Normalized | Action |
|---|---|---|---|
| s4 — Place page - ${src} | 85% | 100% | click (find desc="Activate to enter suggestion"~prefix #0) |

**DECISION: s4** (85% ≥ 20%)

Expected: s4 → MATCH

### Case 4 — state s4 (Place page - ${src})

- Command: `navigate from ${src} to ${dst} by car`
- Options considered: s5
- Matched rules:
  - `r04-open-directions-form` p=90%: origin place page + destination requested ('to B') -> tap Directions

| Next state | Raw vote | Normalized | Action |
|---|---|---|---|
| s5 — Directions form - ${src} filled as destination, start empty | 90% | 100% | click (find desc="Directions to"~prefix) |

**DECISION: s5** (90% ≥ 20%)

Expected: s5 → MATCH

### Case 5 — state s5 (Directions form - ${src} filled as destination, start empty)

- Command: `navigate from ${src} to ${dst} by car`
- Options considered: s6
- Matched rules:
  - `r05-swap-to-start` p=85%: origin parked as destination ('from A') -> swap start/destination

| Next state | Raw vote | Normalized | Action |
|---|---|---|---|
| s6 — Directions form - start = ${src}, destination empty | 85% | 100% | click (find desc="Swap start and destination"~exact) |

**DECISION: s6** (85% ≥ 20%)

Expected: s6 → MATCH

### Case 6 — state s6 (Directions form - start = ${src}, destination empty)

- Command: `navigate from ${src} to ${dst} by car`
- Options considered: s63
- Matched rules:
  - `r06-focus-destination` p=85%: destination empty ('to B') -> open the destination search (live: full-screen search page)

| Next state | Raw vote | Normalized | Action |
|---|---|---|---|
| s63 — Destination search (live-discovered 2026-11-19) | 85% | 100% | click (find text="Choose destination"~exact) |

**DECISION: s63** (85% ≥ 20%)

Expected: s63 → MATCH

### Case 7 — state s63 (Destination search (live-discovered 2026-11-19))

- Command: `navigate from ${src} to ${dst} by car`
- Options considered: s8
- Matched rules:
  - `r18-destination-search` p=90%: destination search open -> type the destination (live-discovered)

| Next state | Raw vote | Normalized | Action |
|---|---|---|---|
| s8 — Search page - destination typed, suggestion listed | 90% | 100% | set_text (find resource-id="com.google.android.apps.maps:id/search_omnibox_edit_text"~exact) |

**DECISION: s8** (90% ≥ 20%)

Expected: s8 → MATCH

### Case 8 — state s7 (Directions form - destination field focused)

- Command: `navigate from ${src} to ${dst} by car`
- Options considered: s8
- Matched rules:
  - `r07-type-destination` p=90%: destination field focused -> type the destination

| Next state | Raw vote | Normalized | Action |
|---|---|---|---|
| s8 — Search page - destination typed, suggestion listed | 90% | 100% | set_text (find resource-id="com.google.android.apps.maps:id/search_omnibox_edit_text"~exact) |

**DECISION: s8** (90% ≥ 20%)

Expected: s8 → MATCH

### Case 9 — state s8 (Search page - destination typed, suggestion listed)

- Command: `navigate from ${src} to ${dst} by car`
- Options considered: s9
- Matched rules:
  - `r08-commit-destination` p=90%: destination typed -> tap the suggestion, route shown (car default)

| Next state | Raw vote | Normalized | Action |
|---|---|---|---|
| s9 — Route chosen - car (driving) by default | 90% | 100% | click (find desc="Activate to enter suggestion"~prefix #0) |

**DECISION: s9** (90% ≥ 20%)

Expected: s9 → MATCH

### Case 10 — state s9 (Route chosen - car (driving) by default)

- Command: `navigate from ${src} to ${dst} by car`
- Question: `Which travel mode?`
- Options considered: finish, s10, s11, s50
- Matched rules:
  - `r09-mode-car` p=92%: 'by car' at the route screen -> car is already active, goal reached
  - `r13-mode-unspecified` p=10%: mode missing or unknown at the route screen -> low-confidence stay; below threshold, so the model is asked

| Next state | Raw vote | Normalized | Action |
|---|---|---|---|
| finish —  | 92% | 100% | stay (goal reached) |

**DECISION: finish** (92% ≥ 20%)

Expected: finish → MATCH

### Case 11 — state s9 (Route chosen - car (driving) by default)

- Command: `navigate from ${src} to ${dst} by walking`
- Question: `Which travel mode?`
- Options considered: finish, s10, s11, s50
- Matched rules:
  - `r10-mode-walk` p=90%: 'by walk' at the route screen -> tap the Walking mode tab
  - `r13-mode-unspecified` p=10%: mode missing or unknown at the route screen -> low-confidence stay; below threshold, so the model is asked

| Next state | Raw vote | Normalized | Action |
|---|---|---|---|
| s11 — Method: walking (4 hr 47 min) | 90% | 90% | click (find desc="Walking mode"~prefix) |
| finish —  | 10% | 10% | stay (goal reached) |

**DECISION: s11** (90% ≥ 20%)

Expected: s11 → MATCH

### Case 12 — state s9 (Route chosen - car (driving) by default)

- Command: `navigate from ${src} to ${dst} by public transportation`
- Question: `Which travel mode?`
- Options considered: finish, s10, s11, s50
- Matched rules:
  - `r12-mode-transit` p=88%: 'by public transportation' at the route screen -> tap the Transit mode tab
  - `r13-mode-unspecified` p=10%: mode missing or unknown at the route screen -> low-confidence stay; below threshold, so the model is asked

| Next state | Raw vote | Normalized | Action |
|---|---|---|---|
| s10 — Method: public transport (1 hr 11 min) | 88% | 90% | click (find desc="Transit mode"~prefix) |
| finish —  | 10% | 10% | stay (goal reached) |

**DECISION: s10** (88% ≥ 20%)

Expected: s10 → MATCH

### Case 13 — state s9 (Route chosen - car (driving) by default)

- Command: `navigate from ${src} to ${dst} on foot`
- Question: `Which travel mode?`
- Options considered: finish, s10, s11, s50
- Matched rules:
  - `r10-mode-walk` p=90%: 'by walk' at the route screen -> tap the Walking mode tab
  - `r11-mode-walk-bigram` p=90%: 'on foot' at the route screen -> tap the Walking mode tab
  - `r13-mode-unspecified` p=10%: mode missing or unknown at the route screen -> low-confidence stay; below threshold, so the model is asked

| Next state | Raw vote | Normalized | Action |
|---|---|---|---|
| s11 — Method: walking (4 hr 47 min) | 90% | 90% | click (find desc="Walking mode"~prefix) |
| finish —  | 10% | 10% | stay (goal reached) |

**DECISION: s11** (90% ≥ 20%)

Expected: s11 → MATCH

### Case 14 — state s9 (Route chosen - car (driving) by default)

- Command: `navigate from ${src} to ${dst}`
- Question: `Which travel mode?`
- Options considered: finish, s10, s11, s50
- Matched rules:
  - `r13-mode-unspecified` p=10%: mode missing or unknown at the route screen -> low-confidence stay; below threshold, so the model is asked

| Next state | Raw vote | Normalized | Action |
|---|---|---|---|
| finish —  | 10% | 100% | stay (goal reached) |

**ASK MODEL** — max vote 10% < 20% (teacher/SLM fallback)

Expected: ask_model → MATCH

### Case 15 — state s9 (Route chosen - car (driving) by default)

- Command: `navigate from ${src} to ${dst} by bicycle`
- Question: `Which travel mode?`
- Options considered: finish, s10, s11, s50
- Matched rules:
  - `r13-mode-unspecified` p=10%: mode missing or unknown at the route screen -> low-confidence stay; below threshold, so the model is asked

| Next state | Raw vote | Normalized | Action |
|---|---|---|---|
| finish —  | 10% | 100% | stay (goal reached) |

**ASK MODEL** — max vote 10% < 20% (teacher/SLM fallback)

Expected: ask_model → MATCH

### Case 16 — state s9 (Route chosen - car (driving) by default)

- Command: `navigate from ${src} to ${dst} by car`
- Question: `Which travel mode?`
- Options considered: s10, s11, s50
- Matched rules:
  - (none)

| Next state | Raw vote | Normalized | Action |
|---|---|---|---|

**ASK MODEL** — no rule fired (teacher/SLM fallback)

Expected: ask_model → MATCH

### Case 17 — state s10 (Method: public transport (1 hr 11 min))

- Command: `navigate from ${src} to ${dst} by public transportation`
- Options considered: s49
- Matched rules:
  - `r15-transit-card` p=85%: transit method shown -> tap the first transit trip card

| Next state | Raw vote | Normalized | Action |
|---|---|---|---|
| s49 — Transit trip card (expanded) | 85% | 100% | click (find desc="Duration"~prefix #0) |

**DECISION: s49** (85% ≥ 20%)

Expected: s49 → MATCH

### Case 18 — state s11 (Method: walking (4 hr 47 min))

- Command: `navigate from ${src} to ${dst} by walking`
- Options considered: finish
- Matched rules:
  - `r16-walk-arrived` p=90%: walking route shown -> goal reached

| Next state | Raw vote | Normalized | Action |
|---|---|---|---|
| finish —  | 90% | 100% | stay (goal reached) |

**DECISION: finish** (90% ≥ 20%)

Expected: finish → MATCH

### Case 19 — state s9 (Route chosen - car (driving) by default)

- Command: `navigate from ${src} to ${dst}`
- Question: `Prefer the bus?`
- Options considered: finish, s10, s11, s50
- Matched rules:
  - `r13-mode-unspecified` p=10%: mode missing or unknown at the route screen -> low-confidence stay; below threshold, so the model is asked
  - `r14-mode-question` p=85%: the agent's question mentions transit at the route screen -> tap the Transit mode tab

| Next state | Raw vote | Normalized | Action |
|---|---|---|---|
| finish —  | 10% | 11% | stay (goal reached) |
| s10 — Method: public transport (1 hr 11 min) | 85% | 89% | click (find desc="Transit mode"~prefix) |

**DECISION: s10** (85% ≥ 20%)

Expected: s10 → MATCH

### Case 20 — state s1 (Map home (Explore))

- Command: `play some music`
- Options considered: s2
- Matched rules:
  - (none)

| Next state | Raw vote | Normalized | Action |
|---|---|---|---|

**ASK MODEL** — no rule fired (teacher/SLM fallback)

Expected: ask_model → MATCH

### Case 21 — state s62 (Typed, no suggestion (live-discovered 2026-11-19))

- Command: `navigate from ${src} to ${dst} by car`
- Options considered: finish
- Matched rules:
  - (none)

| Next state | Raw vote | Normalized | Action |
|---|---|---|---|

**ASK MODEL** — no rule fired (teacher/SLM fallback)

Expected: ask_model → MATCH

### Case 22 — state s10 (Method: public transport (1 hr 11 min))

- Command: `navigate from ${src} to ${dst} by car`
- Options considered: s49, s9
- Matched rules:
  - `r19-back-to-car` p=90%: transit screen shown but the command asks for car -> switch back to the driving tab (live-discovered)

| Next state | Raw vote | Normalized | Action |
|---|---|---|---|
| s9 — Route chosen - car (driving) by default | 90% | 100% | click (find desc="Driving mode"~prefix) |

**DECISION: s9** (90% ≥ 20%)

Expected: s9 → MATCH

## Model-fallback cases (where the concept hands over)

- Case 14 (navigate from ${src} to ${dst}): max vote 10% < 20% — ask_model
- Case 15 (navigate from ${src} to ${dst} by bicycle): max vote 10% < 20% — ask_model
- Case 16 (navigate from ${src} to ${dst} by car): no rule fired — ask_model
- Case 20 (play some music): no rule fired — ask_model
- Case 21 (navigate from ${src} to ${dst} by car): no rule fired — ask_model
