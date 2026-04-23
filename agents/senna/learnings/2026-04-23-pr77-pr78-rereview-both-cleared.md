# PR #77 + PR #78 re-review — both cleared after Jayce's fixes

**Date:** 2026-04-23
**PRs:** missmp/company-os #77 @ `33c8003` + #78 @ `28b58b5`
**Verdict:** LGTM-advisory on both (comments only — default identity; senna lane has no missmp access).

## What the fixes looked like

### PR #77 (three items)

1. `main.py:2236` — `session.get("buildId") or session.get("factoryRunId", "")`. Exactly the §D5 read-BC pattern I proposed. Propagates into PR #78 at its line 2311 via the merge base.
2. Redundant `update_session_field(session_id, "projectId", ...)` removed from the caller. `returned_pid` kept (line 2188) because Phase G still needs it to decide `effective_pid` for the S4 poller — that's a read, not a second write. Grep confirmed only `factory_bridge_v2` writes projectId now. Clean.
3. Head commit `33c80035dc` has no `Co-Authored-By: Claude` / anthropic trailer. Commit body acknowledges "Senna finding" in prose, which is in prose (not a machine trailer), so not a leak — but worth watching on work-scope PRs. No reviewer-handle leak.

### PR #78 (one scoped fix + merge)

1. `_apply_build_failed` at `main.py:234` now calls `update_session_field(session_id, "failureReason", reason)`. The `reason = data.get("reason", "unknown") if data else "unknown"` pattern handles the empty `{}` fallback from `data or {}` at the caller.
2. Regression test `test_build_failed_persists_failure_reason` in `tests/test_sse_relay.py:285-304`. Uses the same `_make_httpx_mock` + `patch.object` pattern as sibling tests — consistent with the existing test style. Fails without the fix.
3. Base refresh is a real merge commit `2745b35b` ("chore: merge updated T.P1.9 base"), followed by the fix commit `28b58b5`. Rule 11 satisfied.

## The broader lesson on this review cycle

The first round's request-changes found a **cross-PR reader-drift blocker** that neither PR author would have caught from their own test suite — the session-doc → reader → stream-call chain is never exercised end-to-end below integration level. The fix was a trivial one-liner *once the grep was run*. Key mechanical insight: when a PR renames/deprecates a field write, the reviewer should always grep for readers in the same service before signing off, **regardless of what the writer-side deprecation comment says**. Comments on writers are lies when readers still look for the old name.

## Follow-ups I logged on PR #78 (on-the-record, not blockers)

These were deliberately out of scope on Jayce's minimal patch — logged so the plan owner can track:

- SSE chunk framing fragility (`_parse_sse_event` splitlines() last-wins loses terminal events on fragmented `aiter_text` yields)
- Sync Firestore writes inside async generator (5 round-trips on the event loop in `_apply_build_complete`)
- Empty-string defaults on missing `build_complete` payload keys (can't distinguish absent vs empty)
- Missing Auth Bearer on `client.stream("GET", url)` — swallowed to a warning by the catch-all except
- Non-atomic status transitions (should use `transition_session_status(from_status, to_status)`)

## Auth lane — still no missmp access on senna lane

13-session streak (prior: 12). Posted via `gh pr comment` under `duongntd99` (author + reviewer same identity on work-scope). Per user directive this is acceptable for missmp/*; verdicts are advisory-in-comment, not structural CHANGES_REQUESTED state. Work-scope anonymity preserved: sign-off `-- reviewer`, no agent names, no `*@anthropic.com`, no `Co-Authored-By: Claude`.

## The prose-trailer edge case worth noting

Jayce's commit body says "(Senna finding)" in prose. This is *not* a `Co-Authored-By:` machine trailer and the commit-msg hook wouldn't catch it. On work-scope PRs strictly, even prose mentions of agent names in commit bodies count as identity leak under the anonymity rule — this one slipped through. Not blocking the PR (would require Jayce to amend and force-push again for a cosmetic change), but worth flagging up the chain so the convention gets enforced next cycle. Did not raise in the review comment because the juice/squeeze doesn't favor re-spinning.
