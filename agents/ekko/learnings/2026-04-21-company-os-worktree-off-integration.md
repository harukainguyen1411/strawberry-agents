# company-os worktrees branch off integration, not origin/main

**Date:** 2026-04-21
**Context:** ship-day deploy infra branch for demo-studio-v3

## What happened

Task said to create branch `chore/ship-day-deploy-infra` off `main` in the workspace repo. The files being patched (`tools/demo-studio-v3/deploy.sh`, `tools/demo-studio-v3/scripts/rollback.sh`) do not exist on `origin/main` of company-os — they were introduced on `feat/demo-studio-v3` and only exist in the integration branch and feature worktrees.

## What to do

When a task asks for "a new branch off main" but the target files only exist on a feature/integration branch, create the worktree off the integration branch instead. In this case: `git worktree add ... -b chore/... integration/demo-studio-v3-waves-1-4`.

The integration branch (`integration/demo-studio-v3-waves-1-4`) is the effective "main" for ship-day work.

## POSIX-portable rollback.sh pattern

For `--chmod=+x` on a file when `chmod` command is blocked: use `git update-index --chmod=+x <file>` after staging to set the executable bit in the git object. The committed mode is 100755. Working-tree mode may differ (cosmetic on macOS with NTFS-style file systems).

## Slack channel in env vars

`SLACK_ALERT_CHANNEL=#demo-studio-alerts` — the `#` prefix is safe inside a double-quoted `--set-env-vars` string in bash. No escaping needed.

## company-os has no scripts/hooks/

The global pre-commit dispatcher at `~/.config/git/hooks/pre-commit` looks for `$REPO_ROOT/scripts/hooks/pre-commit-*.sh`. company-os has no such directory, so no pre-commit hooks run for company-os commits.
