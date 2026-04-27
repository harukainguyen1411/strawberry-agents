# PR #132 r2 — D5 mirror parity verification

**Date:** 2026-04-28
**PR:** missmp/company-os#132 (`feat/adr-4-dispatch-traceability`, head cb1e847b)
**Verdict:** APPROVE — all r1 findings resolved.

## What r1 had blocked
- B1: `tools/demo-studio-v3/agent_proxy.py` SYSTEM_PROMPT carried legacy "validation warning" framing while `setup_agent.py` had the D5 contract. Since `agent_proxy.py:237` injects its prompt on every `run_turn`, this was the runtime-effective prompt — D5 was nominally landed but wasn't reaching the agent.
- Test-coverage gap: `tests/test_system_prompt.py` only inspected `setup_agent.SYSTEM_PROMPT`, so even fixing `agent_proxy.py` left no CI trip-wire for future drift.

## How r2 resolved it
- Commit 04aeffe rewrote agent_proxy.py rule 2 (was AP rule 2 — different numbering than SA which has D5 at rule 3 due to existing rule-1 divergence) and added rules 6 & 7 verbatim.
- Commit cb1e847 added `TestD5PromptParity` parameterized over both modules via `pytest.fixture(params=["setup_agent", "agent_proxy"])` — 5 tests × 2 = 10 cases.

## Verification I did
1. Independent byte-level comparison of the Hard Rules section between the two prompts (Python diff). Confirmed: rule 6 / 7 byte-equivalent; D5 paragraph (validation_error/errors[].field/errors[].reason) byte-equivalent.
2. Mutation simulation: deleted rule 6 from agent_proxy in-memory, confirmed `'error_code: "malformed_tool_input"'` then absent from prompt → `test_malformed_tool_input_error_code_present[agent_proxy]` would fail.
3. Verified `version` (rule 7's success-signal field) appears ONLY in rule 7 in both files, so the second assertion of `test_rule_7_narration_contract_present` is also drift-tight.
4. Ran full suite: 24 passed, 0 xfailed.

## Patterns / takeaways

### Pattern: numbering divergence ≠ content divergence
The two prompts have different rule numbers for the D5 contract (SA #3 vs AP #2) because of pre-existing rule-1 differences (SA: get_schema-first; AP: full-snapshot contract). Both files also skip rule 5 (existing oddity). When verifying "verbatim parity" claims like Viktor's, walk **content** not **numbering**. Use the canonical phrases (`error_code: "validation_error"`, `errors[].field`, `NEVER narrate save success`) as parity anchors.

### Pattern: parameterized-fixture as drift trip-wire
The pattern `@pytest.fixture(params=["mod_a", "mod_b"])` returning the SYSTEM_PROMPT of each module is a clean way to enforce "this invariant must hold in BOTH copies until they're collapsed." Cheaper than a string-equality test (which would fail on benign whitespace), and the test failure points exactly at which copy drifted. Worth promoting in similar dual-prompt situations (e.g. when a module is being migrated and a temporary mirror exists).

### Pattern: mutation-test as mental simulation
For guardrail tests, don't just confirm "the test passes today" — confirm "the test would FAIL if the invariant broke." In-memory string mutation against the imported constant is a 5-line check that gives high confidence the assertion is tight (not over-broad enough to pass on nonsense).

## Operational note: post-reviewer-comment.sh + gh auth state
`gh auth switch --user X` does NOT persist across separate Bash tool invocations — each call gets a fresh shell. Either chain `gh auth switch && script-call` in a single invocation, or run `gh auth status` to confirm active account before posting. The `Could not resolve to a Repository` error on first attempt was the active account (`Duongntd`) lacking access to `missmp/company-os` — `duongntd99` does have access. Easy diagnostic: `gh api user --jq .login` before posting.

## Comment URL
https://github.com/missmp/company-os/pull/132#issuecomment-4329312807
