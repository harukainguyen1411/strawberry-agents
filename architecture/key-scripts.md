# Key Scripts

Reference table for operational scripts. See `architecture/platform-parity.md` for platform coverage.

## Core Lifecycle Scripts

| Script | Usage | Purpose |
|--------|-------|---------|
| `scripts/plan-promote.sh <file> <stage>` | `bash scripts/plan-promote.sh plans/proposed/foo.md approved` | Move a plan out of `proposed/` — unpublishes Drive doc, moves file, rewrites `status:`, commits, pushes. Valid stages: `approved`, `in-progress`, `implemented`, `archived`. Never use raw `git mv` for this. |
| `scripts/safe-checkout.sh <branch>` | `bash scripts/safe-checkout.sh my-branch` | Safe branch switch via git worktree — never use raw `git checkout` |
| `tools/decrypt.sh` | Called internally by scripts needing secrets | Decrypt age-encrypted secrets; keeps plaintext in child process env only. Never call `age -d` directly. |

## Plan Publishing Scripts

| Script | Usage | Purpose |
|--------|-------|---------|
| `scripts/plan-publish.sh <file>` | `bash scripts/plan-publish.sh plans/proposed/foo.md` | Publish a proposed plan to Google Drive (proposed-only; refuses anything outside `plans/proposed/`) |
| `scripts/plan-fetch.sh <file>` | `bash scripts/plan-fetch.sh plans/proposed/foo.md` | Fetch latest content from Drive back to local |
| `scripts/plan-unpublish.sh <file>` | `bash scripts/plan-unpublish.sh plans/proposed/foo.md` | Unpublish (trash) Drive doc for a plan |

## Quality / Security Scripts

| Script | Usage | Purpose |
|--------|-------|---------|
| `scripts/hooks/pre-commit-secrets-guard.sh` | Installed via `scripts/install-hooks.sh` dispatcher | Guards: `BEGIN AGE` outside encrypted/, raw `age -d` outside helper, bearer-token shapes, decrypt-and-scan staged files |
| `scripts/lint-subagent-rules.sh` | `bash scripts/lint-subagent-rules.sh` | Diff canonical inline rule blocks in `.claude/agents/*.md` against Sonnet-executor and Opus-planner reference sets, reporting drift |
| `scripts/list-agents.sh` | Via `/agent-ops list` | List all agents (TSV or JSON) |
| `scripts/new-agent.sh <name>` | Via `/agent-ops new <name>` | Scaffold a new agent directory |

## Notes

- Scripts in `scripts/` (outside `scripts/mac/` and `scripts/windows/`) must be POSIX-portable bash — runnable on both macOS and Git Bash on Windows.
- Platform-specific scripts live under `scripts/mac/` (iTerm, launchd) and `scripts/windows/` (Task Scheduler, PowerShell wrappers).
- Full platform matrix: `architecture/platform-parity.md`.
