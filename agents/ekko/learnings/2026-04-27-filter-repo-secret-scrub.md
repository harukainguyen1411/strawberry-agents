# 2026-04-27 — filter-repo secret scrub + pre-push-resolved-identity blocker

## Task
Post-incident hygiene: scrub 5 secrets from full git history using git-filter-repo,
then force-push main + 4 open-PR branches.

## What filter-repo does to remotes
`git filter-repo --replace-text` strips ALL remotes by design. Must `git remote add origin <url>`
immediately after. The remote-tracking refs (refs/remotes/origin/*) are also wiped.

## Force-push with stale lease ref
After filter-repo, `git push --force-with-lease origin main` fails with "stale info" because
the remote-tracking ref (origin/main) no longer exists locally. Fix:
```
git push --force-with-lease=main:<OLD-REMOTE-SHA> origin main
```
The `--force-with-lease=<ref>:<expected-sha>` form accepts an explicit expected SHA without
needing a local remote-tracking ref.

## pre-push-resolved-identity blocks PR branch force-pushes

### Root cause
filter-repo rewrites ALL commit SHAs (new blobs → new tree → new commit hashes). The local
PR branches now have NEW SHAs for commits that already existed on remote. When force-pushing:

1. git feeds pre-push hook: `<local-ref> <new-local-sha> <remote-ref> <old-remote-sha>`
2. `old-remote-sha` no longer exists in local object store (filter-repo wiped old objects)
3. `git rev-list old-sha..new-sha` — since old-sha is unreachable, walks the full branch history
4. Hook finds pre-existing Orianna-authored commits (plan lifecycle commits) → BLOCKED

The hook has NO bypass mechanism. `--no-verify` is prohibited by Rule 14.

### Affected branches
All 4 open-PR branches (vi/coord-memory-v1-T4a, T7a, viktor/T6b, jayce/T4b) contain
Orianna-authored commits from plan lifecycle operations.

### Resolution needed (Duong-manual)
Two options:
A) Use GitHub web UI to push directly (bypasses local hooks). Since main is already updated,
   Duong can push the rewritten branches via `gh api` with admin token, or push from a
   clone that doesn't have the hook installed.
B) Add a FILTER_REPO_FORCE_PUSH env var bypass to pre-push-resolved-identity.sh, then
   re-run with that env var set.
C) Temporarily rename/disable the hook, push all 4, re-enable. (Manual Duong step.)

Option A is simplest with zero infrastructure change.

## Verification confirmed CLEAN
All 5 secrets verified absent from full history (git log -p --all -G returned empty for all 5).

## SHAs
- Before HEAD (main): 8ca4eaddea99c60751e276eb114f6f7439d450e9
- After HEAD (main): 2b1d0a7ff8f59bafc0710a5463f6fba3915424b1
- Main force-pushed successfully to GitHub.

## Stale branch naming note
Task mentioned: rakan/T3a, rakan/T6a, talon/T2b, viktor/T3b, vi/T2a
Actual remote branches with those approximate labels use different slugs:
rakan/coord-memory-v1-T6a exists; T3a, talon/T2b, viktor/T3b, vi/T2a do NOT exist on origin
with those names. Skip those — no commits beyond origin/main to push.
