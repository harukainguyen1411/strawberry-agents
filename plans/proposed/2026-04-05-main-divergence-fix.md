---
title: Fix Main Branch Divergence on PR Merge
status: proposed
owner: pyke
created: 2026-04-05
---

# Fix Main Branch Divergence on PR Merge

## Problem

Every PR merge requires manual conflict resolution because main diverges from the PR branch during the PR's lifetime. The root cause: agents commit directly to main (plans, agent state, memory) while PRs also target main. By the time a PR is ready to merge, main has 5-20 new commits the PR branch doesn't have.

## Root Cause Analysis

Current commit flow to main (direct, no PR):
- Agent state updates (`chore: update agent state`)
- Plan files (`plans/proposed/`, `plans/approved/`, etc.)
- Agent memory/journals/learnings
- CLAUDE.md and config changes

These direct-to-main commits mean every open PR branch diverges immediately. GitHub shows "This branch is X commits behind main" and merge requires reconciliation.

## Solution: Auto-Rebase Before Merge

### Option A: Pre-Merge Rebase Hook (Recommended)

Add a GitHub Actions workflow that automatically rebases PR branches onto main before merge. This keeps the merge clean without changing the direct-to-main policy for agent state.

**Workflow:** `.github/workflows/auto-rebase.yml`

```yaml
name: Auto-rebase PR
on:
  pull_request:
    types: [opened, synchronize]
  push:
    branches: [main]

jobs:
  rebase:
    if: github.event_name == 'push'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
          token: ${{ secrets.AGENT_GITHUB_TOKEN }}
      - name: Rebase open PRs
        run: |
          for pr in $(gh pr list --json number --jq '.[].number'); do
            branch=$(gh pr view "$pr" --json headRefName --jq '.headRefName')
            git fetch origin "$branch"
            git checkout "$branch"
            if git rebase origin/main; then
              git push --force-with-lease origin "$branch"
            else
              git rebase --abort
              echo "PR #$pr ($branch) has real conflicts — skip"
            fi
          done
        env:
          GH_TOKEN: ${{ secrets.AGENT_GITHUB_TOKEN }}
```

**Pros:** Fully automatic. No workflow change for agents. PRs stay up-to-date.
**Cons:** Force-pushes PR branches (safe with --force-with-lease). Adds CI minutes.

### Option B: Merge Commit Policy (Simpler)

Change GitHub repo setting to allow merge commits (not squash-only). Merge commits handle divergence natively — Git merges the histories without requiring the PR branch to be up-to-date.

**Steps:**
1. In repo Settings → General → Pull Requests, enable "Allow merge commits"
2. Optionally disable "Require branches to be up to date" in branch protection

**Pros:** Zero infrastructure. Works immediately.
**Cons:** Merge commits make history noisier. Doesn't prevent the "behind main" warning.

### Option C: Reduce Direct-to-Main Commits

Move some categories of direct commits to a separate branch or reduce frequency:
- Batch agent state commits (e.g., once per session close instead of per-agent)
- Move plan files to PRs (contradicts current CLAUDE.md rule 9)

**Pros:** Reduces divergence at the source.
**Cons:** Changes established workflow. Plans-via-PR adds friction for no review value.

## Recommendation

**Option B first** (immediate fix) + **Option A** (automation for clean history).

Option B is a 30-second settings change that eliminates the immediate pain. Option A runs in the background to keep PR branches fresh, reducing merge noise over time.

## Implementation Steps

1. Disable "Require branches to be up to date before merging" in branch protection rules
2. Enable "Allow merge commits" in repo settings (if not already enabled)
3. Create `.github/workflows/auto-rebase.yml` workflow
4. Test: create a PR, commit directly to main, verify auto-rebase runs
5. Update CLAUDE.md with guidance: "If your PR branch is behind main, pull/rebase before pushing"

## Risk Assessment

Low risk. Option B is a settings toggle. Option A uses --force-with-lease (safe) and aborts on real conflicts. Neither changes how agents work day-to-day.
