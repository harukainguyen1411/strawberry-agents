---
date: 2026-04-19
agent: viktor
topic: A7 remediation execution — duplicates deleted, orphans blocked
---

# A7 Remediation Execution Learnings

## What worked

### Task 2 — 39 duplicates from strawberry-agents
- `git ls-files -- <paths>` to verify all 39 files exist before issuing `git rm` — essential pre-check.
- Single `git rm` call with all 39 paths at once is clean; git handles the diff correctly.
- strawberry-agents at `/tmp/strawberry-agents-migration` was still clean from the A7 audit session — reusing the existing clone rather than fresh-cloning saved time. Always check the clean state first.
- Pre-commit gitleaks hook on strawberry-agents only scans the diff for secrets in *added* content; a pure deletion commit (`git rm`) scans ~0 bytes and passes immediately.

## What was blocked

### Task 1 — 4 orphans to strawberry-app
- `apps/myapps/.cursor/skills/github-issue-implementation/reference.md` contains 4 `# gitleaks:allow`-needing lines: curl documentation with `YOUR_TOKEN` placeholder strings.
- The gitleaks `curl-auth-header` rule fires on `Authorization: token YOUR_TOKEN` even though `YOUR_TOKEN` is a literal placeholder with entropy 3.12 (barely above threshold).
- Path-based suppression in `.gitleaks.toml` is the cleanest fix. Inline `# gitleaks:allow` comments on each flagged line in reference.md also work without touching global config.
- Permission system blocked modifying `.gitleaks.toml` without Duong authorization — correct behavior. Always flag to the user before modifying security config.

## Pattern: worktree for strawberry-app feature branches
- `git -C /path/to/main-repo worktree add /tmp/worktree-path -b branch-name` creates the worktree and branch in one step.
- Write files directly into the worktree path, then `git -C /tmp/worktree-path add` and commit.
- The worktree uses the main repo's hooks, so gitleaks fires on commit just as in the main checkout.

## Gitleaks false-positive pattern for documentation files
When adding documentation files (SKILL.md, reference.md) that contain code examples with placeholder secrets:
1. Run `gitleaks detect --no-git -v` in the worktree first to preview findings.
2. If all findings are false positives (placeholders, examples, non-secrets), choose between:
   a. Add path to `.gitleaks.toml` `[allowlist] paths` — cleanest, but requires authorization for security config changes.
   b. Add `# gitleaks:allow` inline on each flagged line — surgical, doesn't change global config, may be acceptable without security-config authorization.
3. Never bypass with `--no-verify` per project rules.
