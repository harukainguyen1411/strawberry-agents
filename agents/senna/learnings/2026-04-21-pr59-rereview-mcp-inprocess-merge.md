# PR #59 re-review — company-os mcp-inprocess-merge (Talon follow-up)

**Date:** 2026-04-21 (S29, continuation of S27)
**Repo:** missmp/company-os
**Branch:** feat/mcp-inprocess-merge @ 8ec9bfc
**Verdict:** would-approve (posted as `--comment` under duongntd99 — PR-author identity; reviewer lane not provisioned on missmp/*, confirmed S27 gap)

## Round-1 findings verification (all four addressed)

### C1 — session_id path-traversal injection (critical)
Fix commit `2d3f0b5` adds module-level `_SESSION_ID_RE = re.compile(r"^[a-zA-Z0-9_-]{1,128}$")` mirroring `server.ts:151` zod regex byte-for-byte. Validation applied BOTH at `@mcp.tool` wrapper layer AND at inner `_handle_*` functions — defense in depth. Correctly omits `get_schema` because TS reference passes `{}` (empty input schema) — the task brief saying "all 4 handlers" was imprecise.

Test quality: 4 new `TestSessionIdValidation` cases use `mock_fetch.assert_not_called()` / `mock_cls.assert_not_called()` — asserting the **downstream call is never made**, not just error-text matching. This is the correct invariant to assert because C1 was a data-flow concern (untrusted session_id reaching DEMO_STUDIO_URL), not a UX concern.

Non-blocking: error-string parity imperfect — Python "Invalid session_id" vs TS zod "session_id must be 1-128 alphanumeric...". Not a security concern.

### I1 — auth middleware length-guard timing leak
Fix removes `len(provided) == len(expected_padded) and` pre-check at `mcp_app.py:68`. Only `hmac.compare_digest(provided, self._expected)` remains. `hmac.compare_digest` handles unequal lengths in constant time internally (pads shorter, returns False). No residual length branching.

### I2 — xfail strict=False markers
All four `@pytest.mark.xfail(reason=..., strict=False)` decorators removed from `test_xfail_*` tests in `test_mcp_tools.py`. Functions renamed to drop `xfail_` prefix. Grep confirms zero `strict=False` remains. No XPASS silently swallowing future regressions.

### Lucian #3 — runbook secret-name
Fix commit `8ec9bfc` changes `docs/deploy-runbook.md:15` from `DS_STUDIO_MCP_TOKEN` to `demo_studio_mcp_token` (Secret Manager name). Grep confirms zero residual `DS_STUDIO_MCP_TOKEN` in the runbook. Note: the old name still appears in setup_agent.py/.env.example/deploy.sh — those are pre-existing external-TS-service token wiring, **correctly out of scope** for this PR. Broader rename would be a separate chore.

## Bisect bundle concern

Task asked whether bundling 3 fixes in `2d3f0b5` is acceptable. Verdict: yes — all three target the same 2 files (mcp_app.py, test_mcp_tools.py), are causally coupled (removing xfails without C1 passing would fail suite), and commit message enumerates them explicitly. 158-line diff, small defensively-scoped module. Bisect blast radius acceptable.

## Pattern reaffirmed

For re-reviews of critical-security fixes, the strongest test-quality signal is **asserting the downstream side-effect doesn't occur** (`mock.assert_not_called()`) rather than asserting error-text content. Text can be wrong in many ways and still "pass" a text-contains assertion; a not-called assertion is binary — either the unsafe call happened or it didn't. Talon's tests did this correctly on all three handlers.

## Operational confirmation

PR author on missmp/* is my default `gh` identity (`duongntd99`) — same situation as S27 and S28. `strawberry-reviewers-2` lane not provisioned on work-concern org. Must post `--comment` only; formal APPROVED state requires Lucian's approval or a separately provisioned reviewer. Flagged to Sona previously (S27 memory entry); still pending.

## Files touched in my review session

- `/Users/duongntd99/Documents/Work/mmp/workspace/company-os-mcp-merge/tools/demo-studio-v3/mcp_app.py` (read only)
- `/Users/duongntd99/Documents/Work/mmp/workspace/company-os-mcp-merge/tools/demo-studio-v3/tests/test_mcp_tools.py` (read only)
- `/Users/duongntd99/Documents/Work/mmp/workspace/company-os-mcp-merge/tools/demo-studio-v3/docs/deploy-runbook.md` (read only)
- `/Users/duongntd99/Documents/Work/mmp/workspace/company-os-mcp-merge/tools/demo-studio-mcp/src/server.ts` (reference, read only)
