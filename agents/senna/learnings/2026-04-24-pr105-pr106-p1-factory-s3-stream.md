# PR #105 + #106 — P1 factory S3 real-build + fault-injection fixture

**Date:** 2026-04-24
**Repo:** missmp/company-os (work concern)
**Verdicts:** #105 comment (3 important findings); #106 comment (1 process issue + mechanical merge-order coordination)
**Review URLs:**
- https://github.com/missmp/company-os/pull/105#issuecomment-4310356113
- https://github.com/missmp/company-os/pull/106#issuecomment-4310356312

## Key findings that showed up in actual diffs

1. **Import-fallback class-to-None anti-pattern**: `main.py` had `try: from factory_build import BuildFailed except ImportError: BuildFailed = None`, then later used `except BuildFailed as exc:`. On the ImportError path this raises `TypeError: catching classes that do not inherit from BaseException`. Correct pattern: define a stub class (`class BuildFailed(Exception): pass`) in the fallback branch, not `None`. Generalise: any module-level name used in an `except` clause must remain a BaseException subclass on every import path.

2. **Sync-handler-then-bg-task double-work**: handler fetches S2 config + creates WS project synchronously (for real `projectId` in the 200 response), then the background `_run_build_job` fetches S2 config again and calls `run_build_from_config` which short-circuits `create_project` when `project_id` is truthy. Net: S2 hit twice per real build. Separately, the sync branch persists a synthetic `proj-<hex12>` record to Firestore on `except Exception` before the bg task has a chance to fail properly — leaves zombie records. Lesson: when splitting work between a request handler and a bg task, be explicit about which owns the side-effect writes on the failure path.

3. **Redundant `except (Specific, Specific, Exception)` tuples**: saw this twice in PR #105. Always collapses to `except Exception`. On import-fallback paths where the specifics are aliased to `Exception`, all three slots become the same class.

4. **Catch-all in a `_step` helper converts all non-WSError exceptions to `ws_api_failed` regardless of actual cause**: TypeError from malformed content becomes "ws_api_failed, detail=apply_ios_template". The plan's §D6 taxonomy has an `unexpected` bucket specifically for this — the helper should only convert `WSError`, let everything else bubble to the outer handler which maps it to `unexpected`. Design tension: plan says §D6 has five reasons; implementation collapses two into one for convenience.

5. **Strict-xfail-marker coordination across chained PRs**: the same `test_build.py` lives in both PRs; PR #105 relaxed `P1_XFAIL` to `strict=False` to survive merge-order where #106 lands after. PR #106 kept `strict=True` and removed the decorator from the now-passing test. If #105 lands first, #106 conflicts mechanically. If #106 lands first, #105's change to `strict=False` + re-adding `@P1_XFAIL` turns a passing test into silent xpass. Neither is broken but either way a follow-up cleanup is needed. Flagged in both reviews. Lesson: when two chained PRs both touch an xfail marker on the same test, coordinate the merge order or have one PR own the test-marker change entirely.

6. **AI co-author trailer on work-scope commit**: PR #106's fixture commit had `Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>`. My review body signed `-- reviewer` with no agent names (work-scope anonymity rule). The trailer itself is the PR author's problem to scrub; I only flagged it.

## Reviewer-auth cross-repo gap

Confirmed again: `strawberry-reviewers-2` (my `--lane senna` identity) gets 404 on `missmp/company-os/pulls/105`. Fallback: post advisory comments as `duongntd99` (default gh identity) signed generically. Until the gap is closed I cannot submit actual APPROVE / REQUEST-CHANGES reviews on work-concern PRs — only plain comments.

## Process notes

- Work-scope anonymity rule applies even in advisory-comment mode: no agent names, no `strawberry-reviewers*`/Claude/anthropic references in the body. Signed `-- reviewer`.
- `scripts/reviewer-auth.sh --lane senna` preflight identity check passed (`strawberry-reviewers-2`); the 404 is an access gap, not an auth gap.
