# PR #129 fidelity review — vanilla-cache drop

Plan: `plans/approved/work/2026-04-27-demo-studio-v3-drop-vanilla-cache.md` (tier:quick).
Verdict: REQUEST CHANGES (BLOCKER on Axis F + Axis G).

## What happened

Branch was cut from `feat/demo-studio-v3` after PR #128 (ADR-3 fail-loud + rollback) had landed at `e3ab15b` — base is post-#128, not pre. But the impl commit (`146063d`) actively reverts ADR-3 D3:

- Deletes `_SeedFailedError` class, removes `raise` arms in `_seed_s2_config`, downgrades `logger.error` → `logger.warning`.
- Removes the entire `try/except _SeedFailedError → mark_creation_failed → HTTPException(502)` block in `create_new_session_ui`.
- Deletes `mark_creation_failed` from `session.py`.
- Deletes the 612-line `tests/integration/test_session_create_seed.py` (TX1/TX2 of ADR-3).
- Inverts `test_w1_seed_on_session_create.py::test_session_fails_loud_on_s2_5xx` from asserting 502 to asserting 201.

The PR body claims "`_seed_s2_config` and `create_new_session_ui` ... unchanged (zero diff on those functions)" — false against the actual base.

## What clean

xfail-first ordering correct (xfail → impl → flip across three commits). Commit prefix `chore:` correct. No AI attribution. `seed_config.py` and `tool_dispatch.py` truly byte-identical. SYSTEM_PROMPT contract paragraph carries the three required clauses.

## Lesson

When reviewing a PR cut from a fast-moving feature branch, always pull the merge-base SHA from `gh pr view --json baseRefOid` and diff against that, not against `origin/<base-branch>` (which may have moved). Initial diff against tip showed massive collateral that turned out to also be diff against the actual base — the collateral was real, not a base-drift artifact.

Comment URL: https://github.com/missmp/company-os/pull/129#issuecomment-4328441176
