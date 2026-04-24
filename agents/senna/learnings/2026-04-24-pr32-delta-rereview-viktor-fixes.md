---
date: 2026-04-24
concern: work
pr: missmp/company-os#32
commit: 6d3c15b
prior_review: 64eb362 (request-changes)
verdict: LGTM
---

# PR #32 delta re-review — Viktor's fixes to Senna's three findings

## Outcome

Comment-only LGTM posted as duongntd99 (work repo unreachable via
`strawberry-reviewers-2` lane — org doesn't have that identity as a collaborator).
Signed `-- reviewer`.

## Findings verified

1. **sys.path shadow** — `sys.path.append` (not insert) means demo-studio-v3's
   own package dir (earlier on sys.path) wins for both-defined modules like
   `config_mgmt_client`. demo-factory-only names (`project`, `factory_build`)
   resolve from the appended entry. `factory/rebrand.py` legitimately needs
   demo-factory's `project` module so the append is intended behavior.

2. **_mem_store autouse reset** — autouse fixture uses `.clear()` on the module-
   level dict (correct — rebinding would orphan references held by other
   modules). Mirrors existing `_clear_managed_sessions_cache` pattern.

3. **create_session required kwargs** — grep'd all 20+ call sites. Only session.py
   `create_session` is affected (session_store.py has a separately-named version).
   All callers pass owner_uid/owner_email explicitly. main.py:2077 still passes
   empty strings but that's Phase-A legacy behavior not a Viktor regression
   (deleted in W3).

## Methodology notes

- **Regression-vs-pre-existing check:** ran failing test on 64eb362 by
  `git checkout 64eb362 -- <files>` in main worktree, then restored with
  `git checkout HEAD -- <files>`. Confirmed failure was pre-existing, not
  Viktor-introduced. This is a cheap and reliable way to distinguish new
  from legacy regressions on a re-review.

- **Identity routing:** `scripts/reviewer-auth.sh --lane senna gh pr comment`
  failed with "Could not resolve to a Repository" for missmp/company-os. The
  `strawberry-reviewers-2` identity is not a collaborator on that org's repos.
  For work-scope PR reviews, use `duongntd99` identity (default gh) with
  `gh pr comment` per the task's explicit protocol. For personal-scope PRs,
  reviewer-auth.sh with `--lane senna` is still the correct path.

## Cross-concern observation

The task correctly anticipated this with "Switch to `duongntd99`. `gh pr comment`
(not review), sign `-- reviewer`." This pattern — comment-only review by the
author identity with generic `-- reviewer` signature — is the work-scope
anonymity invariant in action when the reviewer lane can't reach the repo.
