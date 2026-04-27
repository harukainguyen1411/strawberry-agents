---
title: demo-studio-v3 — drop _vanilla_session_configs cache and system-message initial_config block
slug: 2026-04-27-demo-studio-v3-drop-vanilla-cache
concern: work
project: bring-demo-studio-live-e2e-v1
owner: karma
tier: quick
complexity: quick
status: approved
created: 2026-04-27
orianna_gate_version: 2
tests_required: true
qa_plan: required
qa_co_author: senna
---

## Context

Manual testing of stg revision `00040-kgk` (post-#126/#127) surfaced a gaslighting bug in
demo-studio-v3: when the agent calls `set_config(brand=Aviva)` mid-session against a session
seeded with Allianz, S2 (Firestore) correctly persists Aviva, but the agent then hedges with
"the session may still be pinned to the prior snapshot." Root cause: the agent's system message
carries an `initial_config` block populated at turn 1 from a module-level `_vanilla_session_configs`
cache. The agent trusts the static snapshot in its system context over the fresh tool result —
a known agent-design footgun where the prompt and the tool surface disagree about state.

The architectural fix (Option A in `agents/sona/memory/decisions/log/2026-04-27-vanilla-cache-arch-fix.md`):
remove the cache and the system-message state-injection entirely. The agent's only window into
config state becomes the `get_config` / `set_config` tool pair. The system prompt explicitly tells
the agent: "There is no config in your context — only tool calls return truth."

ADR-3 (`plans/approved/work/2026-04-27-adr-3-default-config-greeting.md`) D1 keeps `DEFAULT_SEED`
as Allianz/DE — that value is **not** changed here. S2 is still seeded at `/session/new`. The fix
is surgical: kill the cache, kill the system-message snapshot, update the prompt contract.

## Surface

- `tools/demo-studio-v3/main.py:192` — `_vanilla_session_configs: dict[str, dict]` module cache (REMOVE).
- `tools/demo-studio-v3/main.py:221-243` — first-turn cache populate from S2 (REMOVE).
- `tools/demo-studio-v3/main.py:254` — `initial_config=initial_config` arg passed to agent (REMOVE).
- `tools/demo-studio-v3/agent_proxy.py` — `SYSTEM_PROMPT` interpolation that consumes `initial_config`
  (find via grep; remove the substitution, drop the parameter, rewrite the contract paragraph).
- `tools/demo-studio-v3/seed_config.py:DEFAULT_SEED` — **untouched** (ADR-3 D1 invariant).

## Decision

Option A: drop the cache, lazy-fetch via tool calls only. No fallback, no flag, no migration —
the cache is dead code after this PR.

## Tasks

1. **xfail behavioral round-trip test** — kind: test. estimate_minutes: 15.
   Files: `tools/demo-studio-v3/tests/test_config_roundtrip.py` (new). <!-- orianna: ok -->
   Detail: `pytest.mark.xfail(strict=True)` test that creates a session (Allianz seed),
   invokes the agent's `set_config` handler with brand=Aviva, then invokes `get_config` and
   asserts the returned brand is Aviva. Test must reference this plan slug in a comment.
   Commit message: `chore: xfail roundtrip test for set→get config (plan 2026-04-27-demo-studio-v3-drop-vanilla-cache)`.
   DoD: test runs, fails xfail-strict on `main` (pre-fix), references plan slug.

2. **xfail static system-message assertion** — kind: test. estimate_minutes: 15.
   Files: `tools/demo-studio-v3/tests/test_system_message_no_brand.py` (new). <!-- orianna: ok -->
   Detail: `pytest.mark.xfail(strict=True)` test that constructs the agent invocation
   payload for a fresh Allianz-seeded session and asserts the system message string
   contains NONE of the brand tokens drawn from `DEFAULT_SEED` — at minimum the literals
   `Allianz`, `DE`, and the hex color `#003781`. Pull the token list from `DEFAULT_SEED`
   itself so it stays in sync with `seed_config.py`. Reference plan slug in a comment.
   DoD: test runs, fails xfail-strict on `main` (pre-fix).

3. **Remove the cache and the initial_config wiring** — kind: code. estimate_minutes: 25.
   Files: `tools/demo-studio-v3/main.py`, `tools/demo-studio-v3/agent_proxy.py`.
   Detail:
   (a) delete the `_vanilla_session_configs` module-level dict and any imports of it;
   (b) delete the first-turn populate block (~main.py:221-243) including the S2 fetch
       used solely to seed the cache — if that S2 fetch has no other consumer, remove it;
       if it does, leave the fetch but drop the cache-write side-effect;
   (c) remove the `initial_config=initial_config` keyword from the agent invocation
       at main.py:254 and any upstream variable that only fed it;
   (d) in `agent_proxy.py`, drop the `initial_config` parameter from the function
       signature, remove the `{config_block}` (or equivalent) substitution from the
       SYSTEM_PROMPT f-string, and remove any helper that formatted that block.
   DoD: grep for `_vanilla_session_configs`, `initial_config`, and `config_block`
   across `tools/demo-studio-v3/` returns zero hits. `_handle_set_config` and
   `_handle_get_config` are textually unchanged. `DEFAULT_SEED` literal is unchanged.
   `/session/new` S2 seeding flow is unchanged.

4. **Rewrite SYSTEM_PROMPT contract paragraph** — kind: code. estimate_minutes: 15.
   Files: `tools/demo-studio-v3/agent_proxy.py`.
   Detail: replace the section of SYSTEM_PROMPT that previously rendered `initial_config`
   with an explicit contract paragraph stating: (i) "Use `get_config` to read current
   config state. Use `set_config` to write." (ii) "There is no config visible in your
   context — only tool calls return truth." (iii) "Do not infer, cache, or remember
   config values across turns; always re-read via `get_config` when you need them."
   Tone-match surrounding prompt text. DoD: prompt no longer mentions a "current"
   or "initial" config snapshot; explicit tool-only contract is present.

5. **Flip xfails to passing; verify** — kind: test. estimate_minutes: 10.
   Files: `tools/demo-studio-v3/tests/test_config_roundtrip.py`,
   `tools/demo-studio-v3/tests/test_system_message_no_brand.py`.
   Detail: remove `@pytest.mark.xfail(strict=True)` decorators. Run
   `pytest tools/demo-studio-v3/tests/` and confirm both pass. DoD: green local run;
   no other demo-studio-v3 tests regress.

## Test plan

Tests protect two invariants:

- **Invariant A — tool-result truth wins**: after `set_config(X)`, a subsequent `get_config()`
  returns X within the same session. Guarded by Task 1 round-trip test.
- **Invariant B — system message carries no brand state**: the system message string passed
  to the Anthropic SDK contains zero tokens drawn from `DEFAULT_SEED`. Guarded by Task 2
  static assertion. This is the structural guard against the gaslighting bug recurring —
  if anyone re-introduces a config snapshot in the prompt, this test trips.

Both tests live under `tools/demo-studio-v3/tests/` and run in the existing demo-studio-v3
pytest suite (picked up by the pre-commit hook for changed packages, Rule 14).

## QA Plan

**UI involvement:** no

(Python service + agent prompt; no browser-renderable artifact.)

### Acceptance criteria

Senna (code-check QA co-author per `qa_co_author: senna`) confirms:

1. The two new tests genuinely fail xfail-strict on the pre-fix commit and pass on the post-fix commit
   (Rule 12 xfail-first discipline).
2. `_handle_set_config` and `_handle_get_config` are byte-identical pre/post.
3. `DEFAULT_SEED` literal is byte-identical pre/post (ADR-3 D1 invariant).
4. `/session/new` S2 seeding flow is unchanged — no behavioral edit to `_seed_s2_config` or `create_new_session_ui`.
5. `SYSTEM_PROMPT` explicitly states the tool-only contract (Task 4 wording present).
6. `_vanilla_session_configs` and any `initial_config`/`config_block` system-message interpolation are gone.
7. PR body carries the `QA-Verification:` line listing the four commands below; no `QA-Waiver:` accepted.

### Happy path (user flow)

The invocation flow this plan guards:

- Session created via `/session/new`. S2 receives the `DEFAULT_SEED` (Allianz/DE) seed exactly as today (ADR-3 invariant).
- Agent's first turn: SYSTEM_PROMPT is rendered with NO config block — no brand strings, no colors, no logo URLs. Static system-message-shape assertion test passes.
- Agent calls `set_config({...Aviva...})`. `_handle_set_config` POSTs to S2; tool_result returns success.
- Agent calls `get_config()`. `_handle_get_config` returns the freshly-written Aviva config — round-trip behavioral test asserts the read returns the value just written, not the seed.
- No path through the agent leaks `_vanilla_session_configs` or any system-prompt config snapshot.

### Failure modes (what could break)

Regression guards prevent these breakage modes:

- Cache stub remains in `main.py` and a future change re-introduces interpolation → static system-message test (TX2) catches any `Allianz`/`DE`/`#003781` token leakage.
- Someone touches `DEFAULT_SEED` value as part of "while we're here" cleanup → Senna acceptance criterion #3 + the seed-byte-identity grep in §QA artifacts.
- `_handle_set_config` or `_handle_get_config` accidentally edited (semantic change to tool-result contract) → Senna acceptance criterion #2 byte-identity check.
- Subtle silent failure in S2 round-trip (e.g., `set_config` call fails but agent flow continues with stale read) → behavioral round-trip test (TX1) asserts the actual write→read sequence.
- `/session/new` S2 seeding regression → Senna acceptance criterion #4 + an existing E2E session-create test stays green.

### QA artifacts expected

PR body carries `QA-Verification:` listing:

- `pytest tools/demo-studio-v3/tests/test_config_roundtrip.py -v` — passing
- `pytest tools/demo-studio-v3/tests/test_system_message_no_brand.py -v` — passing
- `rg -n '_vanilla_session_configs|initial_config|config_block' tools/demo-studio-v3/` — zero hits
- `rg -n 'DEFAULT_SEED' tools/demo-studio-v3/seed_config.py` — value unchanged from `main`

No `QA-Waiver:` accepted on this PR. No Akali/Playwright/Figma artifacts (non-UI branch).

## Open questions

None. Sona's decision log resolved Option A.

## References

- Decision: `agents/sona/memory/decisions/log/2026-04-27-vanilla-cache-arch-fix.md`
- ADR-3 (D1 invariant): `plans/approved/work/2026-04-27-adr-3-default-config-greeting.md`
- Project: `projects/work/active/bring-demo-studio-live-e2e-v1.md`
- Bug surface: stg revision `00040-kgk` manual test (post-#126/#127)

## Orianna approval

- **Date:** 2026-04-27
- **Agent:** Orianna
- **Transition:** proposed → approved
- **Rationale:** QA-plan frontmatter and body checks pass; structure linter passes. Plan has clear owner (karma), concrete surface (specific files and line numbers), and a tight task breakdown with xfail-first discipline (Tasks 1-2 before code in Tasks 3-4). §QA Plan now uses the canonical four sub-heads (Acceptance criteria / Happy path / Failure modes / QA artifacts expected). Decision is resolved (Option A, no flags), invariants are explicit (ADR-3 D1 DEFAULT_SEED untouched), and tests pin both behavioral round-trip and the structural anti-regression. Surgical, no overengineering.
