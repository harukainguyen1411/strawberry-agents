# PR 104 — demo-studio-v3 auth_exchange raced-claim TOCTOU fix

**Repo:** missmp/company-os (work-scope, anonymized review).
**Branch:** fix/demo-studio-v3-auth-exchange-raced-claim → feat/demo-studio-v3.
**Verdict:** LGTM advisory with 3 non-blocking findings.
**Review posted as:** PR comment (reviewer-auth lane lacked repo access; fallback protocol).

## What the fix does
After `set_session_owner` returns `False` (transactional claim lost), re-read session via `get_session`. If `winner_uid != caller_uid` raise 403 `{reason: raced_claim, sid}`; else fall through to existing 303 redirect (idempotent self-claim). Emits `auth_exchange_raced_claim` WARNING structured log (server-side only, no response-body leakage).

## Race-analysis pattern worth remembering

When reviewing TOCTOU fixes on Firestore transactions, verify the loser-branch re-read is **consistent with the transaction's guard field**. Here `set_session_owner` returns False for two reasons:
1. `current_owner is not None` (already owned)
2. `not snap.exists` (doc missing)

The re-read only discriminates case 1 correctly. Case 2 leaves `winner_uid=None` which falls through to a 303 redirect to a non-existent session — benign (downstream 404s) but observability-noise. Flag as suggestion, not blocker, unless the plan explicitly covers doc-deletion races.

**Key insight:** Firestore's own-doc-write guard (`if current_owner is not None: return False`) makes `ownerUid` effectively immutable after first claim. The loser's re-read therefore cannot see a later overwriter — closing the race without needing a second transaction on the re-read path. That's a meaningful simplicity win.

## Response-body leakage check

Detail body = `{"reason": "raced_claim", "sid": sid}`. No `winner_uid` in response. Server-side WARNING log includes `winner_uid` but that's consistent with pre-existing INFO log `auth_exchange_claim_result` at same scope. Pattern: **compare new log fields against adjacent existing logs in the same handler** — don't treat "uid in log" as novel PII when the codebase already logs uids at INFO routinely.

## Test hygiene — xfail constant lifecycle

Saw a pattern worth tracking: xfail test commit defines `_XFAIL_REASON` module constants and applies `@pytest.mark.xfail(reason=..., strict=...)`. Impl commit correctly removes the decorators but leaves the unused constants. These are dead strings, harmless but clutter. Flag as suggestion.

Lifecycle is otherwise correct: `strict=True` on the "must fix" test, `strict=False` on the "don't regress" idempotent test. Good discipline.

## Reviewer-auth fallback for work repos

`missmp/company-os` is not in `strawberry-reviewers-2`'s ACL. Preflight returned "Could not resolve repository". Fallback: `gh pr comment` from the `duongntd99` (author) identity, clearly labeled advisory, signed `-- reviewer` for work-scope anonymity. Never use `gh pr review --approve` from author identity (GitHub rejects; Rule 18 prohibits same-identity approval).

Work-scope anonymity was enforced throughout: no agent names, no anthropic.com refs, no reviewer-handle mentions, signed `-- reviewer`.

## Top findings by severity
- None critical.
- Suggestion 1: `winner_uid is None` fall-through on doc-deleted race.
- Suggestion 2: detail-shape asymmetry with pre-existing foreign-owner 403.
- Nit: unused `_XFAIL_REASON*` constants in test module.

## Review URL
https://github.com/missmp/company-os/pull/104#issuecomment-4310289142
