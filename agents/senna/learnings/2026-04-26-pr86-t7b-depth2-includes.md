# PR #86 — T7b depth-2 nested-include impl review

**Date:** 2026-04-26
**Outcome:** APPROVE
**Review URL:** https://github.com/harukainguyen1411/strawberry-agents/pull/86

## What it does
- `sync-shared-rules.sh`: adds `resolve_shared_content()` for depth-2 inline of nested `<!-- include: _shared/*.md -->` markers found inside shared role files. Emits resolved content but NOT the nested marker (idempotency invariant).
- Depth-3 chain → non-zero exit + `§OQ2` reference per plan contract.
- `lint-subagent-rules.sh`: adds `--agents-dir` arg + `check_shared_marker_duplicates()` for §D4.2 single-marker invariant. Uses portable `sort | uniq -d`.

## Verification done
- All 15 bats cases green (`scripts/__tests__/sync-shared-rules.xfail.bats`); cases 10–15 flip from xfail (T7a) to passing here.
- `bash -n` + `shellcheck` clean (only pre-existing info-level SC2016 on `SONNET_REF`/`OPUS_REF`).
- Real-fixture idempotency: full sync of 30 agent defs → second run reports `up-to-date` for every file.
- Depth-3 fixture produces error containing `§OQ2 of plans/approved/personal/2026-04-21-agent-feedback-system.md`.

## Observations to remember
- Current `_shared/*.md` files carry NO nested include markers yet — depth-2 path is forward-compat scaffolding for the feedback-trigger propagation later in the plan. Verify on the actual feedback-trigger rollout PR that nested markers get added to role files.
- Marker parser uses `${line%.md -->}` with strict prefix match `case "<!-- include: _shared/"*`. CRLF or trailing whitespace on the marker line garbles the role name and produces a noisy (but fail-loud) error. Same fragility exists in pre-PR depth-1 parser — not a regression.
- Indented markers are treated as content (column-0 convention).

## Heuristic added to memory
When reviewing depth-2 / nested-resolution refactors of include systems:
1. Run the xfail suite to confirm the predecessor's tests now pass.
2. Run the script against real production fixtures and hash the agent defs across two runs (idempotency).
3. Grep for the `§OQ2`-style plan reference in error messages.
4. Compare marker-parser strictness between depth-1 and depth-2 paths — they should match (consistency > new edge-case handling).
