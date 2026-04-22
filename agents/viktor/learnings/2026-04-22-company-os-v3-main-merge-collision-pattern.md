# company-os v3 main merge — parallel-work collision pattern

Date: 2026-04-22
Context: Merging main (20 commits, PRs #39–#53) into feat/demo-studio-v3 (god branch).

## Finding: parallel work, not renames

At merge base 4cdbd3c, neither `tools/demo-studio-config-mgmt/` nor `tools/demo-config-mgmt/`
existed. Both trees added services independently after the fork:

| main path | v3 path | relationship |
|-----------|---------|-------------|
| tools/demo-studio-config-mgmt/ (Python, 19 files, 17 BDD tests) | tools/demo-config-mgmt/ (Python stub, 5 files) | parallel independent work |
| tools/demo-studio-factory/ (Go microservice, full pkg/ hierarchy) | tools/demo-factory/ (Python agent service) | different languages, different arch |
| tools/demo-studio-verification/ (Go Cloud Run, internal/ hierarchy) | tools/demo-verification/ (Python stub, 5 files) | parallel |
| tools/demo-studio-schema/ (schema.yaml only) | (no equivalent) | additive |

`git merge-tree --write-tree` is the right pre-flight tool — it reveals that because paths don't
overlap, git treats them as additive (both survive). Only .gitignore conflicted.

## Merge execution

1. Created detached worktree at v3 HEAD SHA: `git worktree add --detach ../company-os-v3-sync <sha>`
2. Created local branch in worktree: `git checkout -b local-name`
3. `git merge main --no-commit --no-ff` to inspect before committing
4. Only conflict: `.gitignore` — merged both addition blocks manually
5. Committed and pushed via refspec: `git push origin local-branch:feat/demo-studio-v3`

## CI workflow (ci-demo-config-mgmt.yml)

Points to `tools/demo-studio-config-mgmt/**`. This is correct — it tests main's production
service, which now also exists in v3. v3's stub (tools/demo-config-mgmt/) has no CI yet.
No path update needed.

## Test results post-merge

- demo-factory/tests/: 73 passed
- demo-preview/tests/: 9 passed, 1 xfailed
- demo-studio-config-mgmt/tests/: 54 passed
- demo-studio-v3/tests/: 793 passed, 71 pre-existing failures (in-progress TDD work)

## PR #65 diff display

GitHub's PR diff API can show stale counts after base branch update. The actual git diff
(`git diff origin/base...origin/head --stat`) is authoritative: 8 files, 127 insertions.
GitHub recomputes after a few minutes.
