---
date: 2026-04-23
created: 2026-04-23
concern: work
status: implemented
author: karma
owner: karma
complexity: quick
orianna_gate_version: 2
tests_required: true
---

# auth_exchange raced-claim — misleading log, unhelpful 403 one hop later

## Context

Senna's re-review on PR #75 (demo-studio-v3) flagged a TOCTOU window in `auth_exchange`
in `tools/demo-studio-v3/main.py` around lines 1952-1976. When two Slack visitors race <!-- orianna: ok -- cross-repo path in missmp/company-os -->
on `set_session_owner` for the same session id, the loser's call returns `claimed=False`
— but the handler still logs `auth_exchange_ok` and issues a `RedirectResponse` to
`/session/{sid}`. The loser's cookie is a non-matching Firebase session, so
`require_session_owner` 403s one hop later with no hint of why.

Not a security hole: the transactional `set_session_owner` holds the storage-layer
invariant, and the race has always existed. But (a) the `auth_exchange_ok` log line is
actively misleading when the exchange actually lost the race, and (b) the user-facing
403 carries no diagnosable reason. The race window widens materially once Loop 2d drops
the legacy cookie fallback — fix before that ships.

## Recommended fix

On `set_session_owner(..., claimed=False)`:

1. Re-read the session document.
2. Confirm `ownerUid != caller_uid` (i.e. a different identity genuinely won the claim;
   otherwise treat as idempotent success and continue as today).
3. Raise `HTTPException(status_code=403, detail={"reason": "raced_claim", "sid": sid})`
   from the `auth_exchange` handler itself — do not emit `auth_exchange_ok` and do not
   issue the redirect.
4. Emit a distinct `auth_exchange_raced_claim` structured log line at WARN with
   `sid`, `caller_uid`, `winner_uid`.

## Anchors

- `tools/demo-studio-v3/main.py:1952-1976` — `auth_exchange` handler (claim + redirect path). <!-- orianna: ok -- cross-repo path in missmp/company-os -->
- `tools/demo-studio-v3/main.py` `set_session_owner` call site — returns `(claimed, ...)` tuple; current code ignores the false branch. <!-- orianna: ok -- cross-repo path in missmp/company-os -->
- `tools/demo-studio-v3/main.py` `require_session_owner` dependency — source of the downstream 403 that currently masks the root cause. <!-- orianna: ok -- cross-repo path in missmp/company-os -->

## Tasks

1. **xfail test — raced_claim path.** Add `tests/test_auth_exchange_raced_claim.py` with <!-- orianna: ok -- new test file created by this plan -->
   a test that seeds an existing owner on a session, invokes `auth_exchange` with a
   different caller identity, and asserts the response is `403` with
   `detail["reason"] == "raced_claim"` and no redirect. Mark `@pytest.mark.xfail` with a
   reference to this plan. Files: `tools/demo-studio-v3/tests/test_auth_exchange_raced_claim.py` (new). <!-- orianna: ok -- cross-repo path in missmp/company-os -->
   kind: test. estimate_minutes: 20. DoD: xfail test commit lands on branch before
   implementation commit (Rule 12).
2. **xfail test — idempotent re-exchange.** Second test in the same file: same caller
   identity re-runs `auth_exchange` after already owning the session; asserts 302
   redirect to `/session/{sid}` (idempotent success, not 403). Ensures the fix does not
   regress the legitimate re-visit case. Files:
   `tools/demo-studio-v3/tests/test_auth_exchange_raced_claim.py`. <!-- orianna: ok -- cross-repo path in missmp/company-os -->
   kind: test. estimate_minutes: 10. DoD: xfail marker present, same commit as task 1.
3. **Implement raced-claim branch.** Modify `auth_exchange` at
   `tools/demo-studio-v3/main.py:1952-1976` per Recommended fix above. Remove xfail <!-- orianna: ok -- cross-repo path in missmp/company-os -->
   markers after green. Files: `tools/demo-studio-v3/main.py`. kind: code. <!-- orianna: ok -- cross-repo path in missmp/company-os -->
   estimate_minutes: 25. DoD: both tests pass without xfail; manual curl against a
   local server shows 403 JSON on raced claim and 302 on idempotent re-exchange.
4. **Structured log line.** Add `auth_exchange_raced_claim` WARN log with fields
   `sid`, `caller_uid`, `winner_uid`. Remove or demote the misleading
   `auth_exchange_ok` emission on the false-claim branch. Files:
   `tools/demo-studio-v3/main.py`. kind: code. estimate_minutes: 10. DoD: grep for <!-- orianna: ok -- cross-repo path in missmp/company-os -->
   `auth_exchange_ok` shows it only on the true-claim and idempotent branches.

## Test plan

Invariants the xfails protect:

- **Raced-claim produces diagnosable 403.** Loser of `set_session_owner` must receive a
  403 with `reason="raced_claim"` directly from `auth_exchange`, not a downstream 403
  from `require_session_owner` after a redirect.
- **Idempotent re-exchange still succeeds.** Same caller identity re-running
  `auth_exchange` after already owning the session must 302 to `/session/{sid}`; the
  new branch must distinguish "someone else won" from "I already own this".
- **Log line accuracy.** `auth_exchange_ok` must not be emitted on the raced-loss path.

## Out of scope

- Loop 2d legacy fallback removal (separate plan; this fix must land first).
- Changing the `set_session_owner` transactional contract.
- Slack visitor UX on the 403 page (frontend work, separate).

## Branching

Target branch: `fix/demo-studio-v3-auth-exchange-raced-claim` off `feat/demo-studio-v3` <!-- orianna: ok -- prospective branch names, not filesystem paths -->
(or its successor after PR #75 merges). Single PR, dual-reviewed.

## Orianna approval

- **Date:** 2026-04-24
- **Agent:** Orianna
- **Transition:** proposed → approved
- **Rationale:** Plan has a clear author (Karma) and a confirmed owner for execution (Vi, per Duong's semantic approval today). The TOCTOU context is concrete with line-anchored references in `tools/demo-studio-v3/main.py:1952-1976` <!-- orianna: ok -- cross-repo path in missmp/company-os -->, and the recommended fix is fully specified (re-read, compare uids, raise 403 with `raced_claim` reason, distinct WARN log). Tasks are actionable with estimates and DoDs, and `tests_required: true` is satisfied by two xfail tests sequenced ahead of the implementation commit per Rule 12. Test-plan invariants match the fix's behavioral claims. No TBD/TODO/decision-pending markers in any gating section.

## Orianna approval

- **Date:** 2026-04-24
- **Agent:** Orianna
- **Transition:** approved → in-progress
- **Rationale:** Owner confirmed as Vi by the work-concern coordinator; Vi dispatch follows this push. Tasks remain actionable with clear files, estimates, and DoDs; the two xfail tests are correctly sequenced ahead of the implementation commit to satisfy Rule 12 for this `tests_required: true` plan. Fix scope is narrow and anchored to `tools/demo-studio-v3/main.py:1952-1976` <!-- orianna: ok -- cross-repo path in missmp/company-os --> with explicit out-of-scope fences. Ready for execution.

## Orianna approval

- **Date:** 2026-04-24
- **Agent:** Orianna
- **Transition:** in-progress → implemented
- **Rationale:** PR #104 (`feat/demo-studio-v3-auth-raced-claim`) merged into `feat/demo-studio-v3` with the specified behavioral changes: `auth_exchange` in `tools/demo-studio-v3/main.py` now re-reads the session after `set_session_owner`, compares `winner_uid` against `caller_uid`, and raises `HTTPException(403, detail={"reason": "raced_claim"})` directly instead of redirecting — matching Task 3 and the Recommended fix. The distinct `auth_exchange_raced_claim` WARN log with `sid`/`caller_uid`/`winner_uid` satisfies Task 4 and the log-accuracy invariant. Tests in `tests/test_auth_exchange_raced_claim.py` (Tasks 1 and 2) are green post-implementation, and Akali Playwright QA ran during review. Implementation evidence is plausible and the work described is done.
