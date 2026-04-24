# PR 104 — auth_exchange raced-claim fidelity review

**Date:** 2026-04-24
**PR:** https://github.com/missmp/company-os/pull/104
**Plan:** `plans/in-progress/work/2026-04-23-demo-studio-auth-exchange-raced-claim.md`
**Verdict:** APPROVE (advisory comment — reviewer-auth gap on missmp/company-os)

## Findings

- Scope clean: two files, `tools/demo-studio-v3/main.py` (+24/-0) and new test file. No adjacent auth code drift.
- Rule 12 satisfied: xfail commit `dce4343` precedes impl commit `121e191`; both tests had `@pytest.mark.xfail` markers on the xfail commit, removed on impl commit.
- Behavioral spec matches plan Recommended fix §1–4 exactly: re-read session, compare uids, 403 with `{reason: raced_claim, sid}`, idempotent self-win falls through.
- Line drift 1952–1976 → 2242 expected; same handler confirmed by hunk context.

## Drift notes (non-blocking)

1. Log field `sid` (plan) vs `session_id` (impl). Impl matches surrounding `auth_exchange_claim_result` log convention — internally consistent but diverges from plan spec. Flag for downstream log-consumer contracts.
2. PR body omits the canonical plan path. Plan reference lives in test file header + impl comment only.

## Pattern reinforced

Line-drift flagged by delegating agent is a standard case — confirm via hunk context (surrounding log/call names), never reject a PR solely on line-number drift when the file grew.

## Reviewer-auth gap

`strawberry-reviewers` still lacks access to `missmp/company-os`. Posted review as advisory comment via Duong identity per delegation directive. Gap has been flagged in previous learnings (2026-04-21-pr57, pr59, 2026-04-22-pr65/66/67) — still unresolved.
