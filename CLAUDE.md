# Strawberry — Personal Agent System

## For Evelynn Sessions

**If you are Evelynn (the top-level coordinator session — no greeting given), also read `agents/evelynn/CLAUDE.md` immediately after this file.**

## Scope

Personal system only. Work tasks go through `~/Documents/Work/mmp/workspace/agents/`.

## Agent Routing

If you receive a greeting like **"Hey <Name>"**, you are that agent. See `agents/memory/agent-network.md` for the full list.

**If no greeting is given**, you are **Evelynn** by default.

## Critical Rules — Universal Invariants

<!-- #rule-no-uncommitted-work -->
1. **Never leave work uncommitted** — commit before any git operation that changes the working tree. (Other agents share this working directory — uncommitted work WILL be lost.)

<!-- #rule-no-secrets-in-commits -->
2. **Never write secrets into committed files** — use `secrets/` (gitignored) or env vars.

<!-- #rule-git-worktree -->
3. **Use `git worktree` for branches** — never raw `git checkout`. Use `scripts/safe-checkout.sh`.

<!-- #rule-plans-direct-to-main -->
4. **Plans go directly to main, never via PR** — Commit plan files directly to main. Only implementation work goes through a PR.

<!-- #rule-chore-commit-prefix -->
5. **Use `chore:` prefix for all commits** — All commits must use `chore:` or `ops:` prefix. Never use `fix:`, `feat:`, `docs:`, `plan:` or other prefixes. The pre-push hook enforces this on main.

<!-- #rule-no-raw-age-d -->
6. **Never run raw `age -d` or read decrypted secret values into context** — Use `tools/decrypt.sh` exclusively; it keeps plaintext in the child process env only. Never `cat`/`type`/pipe `secrets/age-key.txt`. The pre-commit hook blocks violations.

<!-- #rule-plan-promote-sh -->
7. **Use `scripts/plan-promote.sh` to move plans out of `plans/proposed/`** — never raw `git mv` for plans leaving `proposed/`. The Drive mirror is proposed-only; `plan-promote.sh` unpublishes the Drive doc, moves the file, rewrites `status:`, commits, and pushes. Raw `git mv` leaves orphan Drive docs.

<!-- #rule-end-session-skill -->
8. **Always invoke `/end-session` before closing any session** — no agent may terminate a session by any other mechanism. Top-level sessions use `/end-session` (disable-model-invocation: true — Duong or Evelynn must explicitly trigger it). Sonnet subagent sessions use `/end-subagent-session`, which subagents invoke themselves at session end. Both skills produce the handoff note, memory refresh, learnings, and commit; `/end-session` additionally produces a cleaned-transcript archive.

<!-- #rule-agent-model-declaration -->
9. **Every agent definition must declare its model** — every `.claude/agents/<name>.md` MUST include a `model:` frontmatter field. Use `opus` for planners, `sonnet` for executors/reviewers, `haiku` for minions. Use short alias names, not pinned version IDs.

<!-- #rule-posix-portable-scripts -->
10. **Scripts in `scripts/` (outside `scripts/mac/` and `scripts/windows/`) MUST be POSIX-portable bash** — runnable on both macOS and Git Bash on Windows. Platform-specific affordances live under `scripts/mac/` or `scripts/windows/`.

<!-- #rule-never-rebase -->
11. **Never use `git rebase`** — always merge.

## File Structure

| Path | Purpose |
|------|---------|
| `architecture/` | System docs — source of truth for how the system works |
| `plans/` | Execution plans (`YYYY-MM-DD-<slug>.md`, YAML frontmatter). Subdirs: `proposed/`, `approved/`, `in-progress/`, `implemented/`, `archived/` |
| `assessments/` | Analyses, recommendations, evaluations |
| `agents/` | Profiles, memory, journals, learnings per agent |
| `scripts/` | POSIX-portable shell scripts — see `architecture/key-scripts.md` |
| `tools/` | Helper binaries (e.g. `tools/decrypt.sh` for secret decryption) |
| `secrets/` | Gitignored local secrets — never committed |
| `.claude/agents/` | Agent definition files (`.md` with frontmatter) |
| `agents/<name>/learnings/` | Session learnings per agent, named `YYYY-MM-DD-<topic>.md` |
