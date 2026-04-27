# 2026-04-27 — PR #128 ADR-3 fail-loud seed review

## What I reviewed

PR #128 (`missmp/company-os`): ADR-3 D3 implementation — replace silent-swallow seed-failure with fail-loud (HTTP 502 + Firestore session-doc rollback `status=creation_failed` + `failureReason` audit trail).

Head: `989bc3b`. Verdict: **Comment** (1 IMPORTANT, 2 NITs, 1 cross-lane scalability note). No blockers.

URL: https://github.com/missmp/company-os/pull/128#issuecomment-4328321230

## Key findings

1. **IMPORTANT — unprotected rollback writes.** `update_session_status` + `update_session_field` in the rollback path have no try/except. If Firestore is degraded alongside S2 (common — shared GCP failure domain), the rollback writes raise and the contracted 502 never fires — user gets generic 500, doc stays in `configuring` (the orphan-doc problem the ADR set out to fix returns). Recommended fix: wrap rollback in its own try/except, log distinct event, still raise 502.

2. **NIT — non-atomic two-write rollback.** `set(status)` + `set(failureReason)` are two separate Firestore writes. A reader could observe `status=creation_failed` without `failureReason`. Suggested cleanup: introduce a `mark_creation_failed(session_id, reason)` helper that does both fields in one merge-write.

3. **NIT — `repr(exc)` reaches a user-visible field.** `failureReason` is read by SSE/UI. Today's typed exceptions (`ValidationError`, `NetworkError`, `ServiceUnavailableError`) don't carry credentials, but `NetworkError(str(e))` from `requests` can include URLs. Future-proofing: store stable error-code in `failureReason`, full `repr(exc)` only in server-side log.

4. **Cross-lane scalability — pre-existing.** `requests.post` in `config_mgmt_client.snapshot_config` has no `timeout=`. Pre-ADR-3 a hung S2 was masked by the soft-fail swallow; under fail-loud, a hung S2 blocks the FastAPI thread pool. Pre-existing risk made operationally relevant by the new contract.

## Things confirmed clean

- `_SeedFailedError` sentinel: file-scoped, underscore-prefixed, single producer, single consumer. Clean.
- Doc-existence invariant for rollback: `create_session` writes the doc BEFORE `_seed_s2_config` runs. The "what if doc never written" path cannot occur.
- Idempotency: rollback uses `.set(..., merge=True)` — re-runnable.
- Existing test mocks: scoped via `with patch(...)` context managers, no global pollution.
- Widened TX2 assertion (`set` OR `update` OR `delete`): genuinely contract-aligned, not papering. `update_session_status` chose `.set(..., merge=True)` at `session.py:171`; semantically equivalent to `.update()` for the D3 invariant.
- xfail-first ordering: 848e79a (xfail) → f422212 (impl) → 989bc3b (de-xfail). Rule 12 honored.
- 502 is the canonical FastAPI status for "upstream service failed."

## Process learnings

- The work-scope anonymity scan in `scripts/post-reviewer-comment.sh` catches agent names — including in suggested escalation tags like `[escalate: azir]`. When writing review bodies for work-scope, use generic phrasing ("architecture-track follow-up") instead of agent-name escalation tags. The personal-scope `reviewer-auth.sh` path allows agent names but the work-scope path does not.
- The de-xfail commit (`989bc3b`) bundled assertion-widening with the marker removal. The widening is justified (different mock method, same contract) — but couples two changes in one commit. Future xfail-flip commits should separate "remove markers" from "adjust assertions" if both are needed, so the diff reviewer can see them as distinct concerns.
