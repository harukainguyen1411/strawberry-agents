---
date: 2026-04-17
topic: Dependabot Phase 2 surgical lockfile patterns
batches: B4c, B4d, B4e, B4f, B4g, B4h, B9
---

## Key patterns discovered

### Major version bumps require team-lead approval
@tootallnate/once 2→3 had no 2.x patch — only fix was major bump. Deferred to own batch (B9) per team-lead. Rule: if `npm view <pkg> versions` shows no patch in current major, flag before patching.

### Nested scoped lockfile entries
vitest hoists its own vite copy under `node_modules/vitest/node_modules/vite` when the top-level vite is a different major. Surgical patch on nested entry is independent of top-level entry — different alerts, different keys, no conflict with B8.

### Multi-major glob alerts are not all closeable by one patch
minimatch has alerts across 3.x/5.x/6.x/9.x/10.x. Patching 9.x closes the 9.x alerts only; older major entries are pinned by upstream parents. Jhin caught overclaim in PR description — always scope alert closure to the exact major present in lockfile.

### Alert dismissal requires direct user authorization
PreToolUse hook blocks `gh api` PATCH on Dependabot alerts when authorization came from another agent. Dismissals must be executed by Duong directly or via a Bash tool call approved in session. Pattern: flag for Duong, provide exact command.

### B4g is code-change class — needs plan
vite 5→6 in bee-worker requires vitest 2→3 simultaneously (vitest 2.x pins `vite ^5`). Cannot be done as a pure lockfile surgical patch. Needs approved plan before execution.

### npm ci package count drift is normal
After major version bump (@tootallnate/once 2→3), `npm ci` reported +3 packages vs prior installs. Lockfile diff was still clean (3 fields only) — count drift is from npm rebuilding node_modules from scratch each run, not from lockfile changes.

### Worktree commit PATH issue
`git commit` failed silently (exit 1, no output) when bash 3.2 was on PATH and secrets-guard hook required bash 4+. Fix: `brew install bash` + ensure `/opt/homebrew/bin` is on PATH. Subsequent runs worked without explicit PATH override — hooks auto-detect.
