# Git Workflow

## Three-Tier Commit Policy

| Tier | Scope | Policy | Prefix |
|---|---|---|---|
| **1 — Agent State** | `agents/*/memory/`, `learnings/`, `journal/` | Direct to main, no PR | `chore:` |
| **2 — Operational Config** | `agents/memory/agent-network.md`, `.mcp.json`, `plans/`, `architecture/`, minor MCP tweaks | Direct to main | `chore:` / `ops:` |
| **3 — Feature Work** | New MCP servers, new tools, breaking changes, GHA workflows, new apps, architecture changes | Feature branch + PR | `feature:` / `fix:` |

### Rule of Thumb

- Changes how agents communicate or adds new capabilities → **PR**
- Updating config, docs, or agent state → **direct to main**

## Branch Naming

| Prefix | Use |
|---|---|
| `feature/` | New features, capabilities |
| `fix/` | Bug fixes |
| `chore/` | Maintenance, cleanup, config |
| `docs/` | Documentation only |

## PR Workflow (Tier 3)

1. Create branch from `main`
2. Commit with clear messages (what + why)
3. Push and create PR
4. Review — Lissandra or Rek'Sai for code changes
5. Merge via PR (squash or merge commit, no rebase)
6. Delete branch after merge

## Hard Rules

- Never force-push. Never rebase. Always merge.
- Never commit secrets, `.env` files
- Agent state belongs on main only — never on feature branches
- Never auto-resolve agent state merge conflicts
- One logical change per commit
- Delete branches after merge
- No AI authoring references in commits
- Avoid shell-unfriendly characters in commit commands
- PRs with significant changes must update relevant READMEs
- **Gitignore-on-first-use:** When creating a new tool or app directory, add its build output patterns to `.gitignore` in the same commit that creates the directory. Build artifacts (`.turbo/`, `dist/`, `lib/`, `node_modules/`, `__pycache__/`) must never appear in `git status`.

## Branch Protection — Required Checks and Review Enforcement

`main` enforces the following gates (configured via `scripts/setup-branch-protection.sh`):

| Gate | Source | Context string (exact) |
|------|--------|------------------------|
| xfail-first | `.github/workflows/tdd-gate.yml` | `xfail-first check` |
| regression-test | `.github/workflows/tdd-gate.yml` | `regression-test check` |
| unit-tests | `.github/workflows/unit-tests.yml` | `unit-tests` |
| E2E | `.github/workflows/e2e.yml` | `Playwright E2E` |
| QA report (UI PRs) | `.github/workflows/pr-lint.yml` | `QA report present (UI PRs)` |

Additionally:
- `strict: true` — branch must be up-to-date with `main` before merge.
- `enforce_admins: true` — admin accounts are subject to the same gates; no bypass.
- One approving review required from an account other than the PR author (`harukainguyen1411` is the designated reviewer account for agent-authored PRs).
- `dismiss_stale_reviews: true` — any new push invalidates prior approvals; re-review required.
- `require_last_push_approval: true` — the approving review must be on the current tip commit.
- `required_conversation_resolution: true` — all reviewer-raised threads must be resolved.

### No self-merge / no `--admin` bypass

Agents must never run `gh pr merge --admin` and must never merge a PR they authored. This applies even when all checks are green. See `CLAUDE.md` rule 18.

### Break-glass procedure (human-only, Duong)

For documented emergencies only (production on fire, required check workflow itself broken):

1. Temporarily disable `enforce_admins`:
   ```bash
   gh api repos/Duongntd/strawberry/branches/main/protection \
     -X PATCH -H "Accept: application/vnd.github+json" \
     --field enforce_admins=false
   ```
2. Perform the emergency merge: `gh pr merge --admin <pr-number>`.
3. Re-enable immediately: `bash scripts/setup-branch-protection.sh`.
4. Write a post-incident note to `assessments/break-glass/YYYY-MM-DD-<slug>.md` covering what broke, why break-glass was the right call, and follow-up to prevent recurrence.

Agents must not execute this procedure under any circumstance.

## Build Artifact Guard (pre-commit hook)

`scripts/hooks/pre-commit-artifact-guard.sh` blocks commits that include build artifact paths. It runs as part of the pre-commit hook dispatcher installed by `scripts/install-hooks.sh`.

To install (if not already active):

```bash
bash scripts/install-hooks.sh
```

Patterns blocked: `node_modules/`, `.turbo/`, `.firebase/`, `__pycache__/`, `apps/functions/lib/`.

## Agent Attribution

Every PR must identify the agent who created it. Include `Author: <agent-name>` in the PR description. This applies to all agents — if Bard opens a PR, the description says `Author: Bard`.

## Review Protocol

Reviewers (Lissandra, Rek'Sai) must verify the documentation checklist in the PR:
- If the PR touches `mcps/`, `architecture/`, or `agents/memory/agent-network.md` — corresponding docs must be updated
- If the PR adds/removes features — `README.md` must reflect the change
- Block the PR if docs are missing for qualifying changes

## Git Safety — Shared Working Directory

**Never leave work uncommitted.** If you create or modify a file, commit it before doing anything else with git (checkout, stash, pull, merge). Uncommitted files in a shared working directory WILL be lost when another agent switches branches.

**Concurrent branch work:** Use `git worktree` instead of `git checkout`:
```bash
git worktree add /tmp/strawberry-feature-xyz feature/xyz
# Work in /tmp/strawberry-feature-xyz — doesn't touch the main working tree
git worktree remove /tmp/strawberry-feature-xyz
```

**Branch switching:** Never use raw `git checkout`. Use `scripts/safe-checkout.sh` instead — it checks for uncommitted changes before switching.

## Operational Files (outside git)

Ephemeral runtime state in `~/.strawberry/ops/` (gitignored):

| Directory | Contents |
|---|---|
| `~/.strawberry/ops/inbox/<agent>/` | Inbox messages |
| `~/.strawberry/ops/conversations/` | Multi-agent conversations |
| `~/.strawberry/ops/health/` | Heartbeats, registry |
| `~/.strawberry/ops/inbox-queue/` | Approval queue |
