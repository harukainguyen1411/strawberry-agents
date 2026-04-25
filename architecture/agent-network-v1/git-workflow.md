---
Supersedes: archive/pre-network-v1/git-workflow.md
---

# Git Workflow — v1

## Two-repo model

As of 2026-04-19, the codebase is split across two repositories:

- **`harukainguyen1411/strawberry-agents`** (private) — agent infrastructure: `agents/`, `plans/`, `assessments/`, `architecture/`, `CLAUDE.md`, encrypted secrets. This is the repo you are reading now.
- **`harukainguyen1411/strawberry-app`** (public) — application code: `apps/`, `dashboards/`, `.github/workflows/`, `scripts/`, build config.

The former monorepo **`Duongntd/strawberry`** is the read-only archive (90-day retention through 2026-07-18). Historical commit SHAs prior to 2026-04-19 resolve there.

Agent sessions operate from the `strawberry-agents` checkout at `~/Documents/Personal/strawberry-agents/`. `strawberry-app` is checked out as a sibling at `~/Documents/Personal/strawberry-app/` when agents need to touch code. Sessions are scoped to one repo at a time.

---

## Commit prefix policy (Rule 5)

All commits must carry a conventional prefix scoped to the diff:

| Diff scope | Allowed prefixes |
|---|---|
| Touches `apps/**` | `feat:`, `fix:`, `perf:`, `refactor:`, `chore:`. Breaking change: `feat!:` or `BREAKING CHANGE:` footer. |
| Infra / ops only (deploys, GCP, CI) | `ops:` |
| Everything else (plans, agent defs, scripts outside `apps/**`, docs) | `chore:` |

**Never** use `docs:` / `plan:` or other non-conventional prefixes. The pre-push hook enforces diff-scope ↔ commit-type.

See repo-root `CLAUDE.md` Rule 5 (`#rule-chore-commit-prefix`) for the authoritative definition.

---

## Worktree discipline (Rule 3)

**Never raw `git checkout`.** Use worktrees for any branch work:

```bash
# Add a new worktree on a new branch from origin/main:
bash scripts/worktree-add.sh /path/to/worktree -b my-branch origin/main

# Switch to an existing branch without touching the main working tree:
bash scripts/safe-checkout.sh my-branch
```

`scripts/worktree-add.sh` verifies `core.hooksPath` is set before creating the worktree, ensuring hooks fire in all worktrees. `scripts/safe-checkout.sh` checks for uncommitted work before switching.

**STAGED_SCOPE** — always set `STAGED_SCOPE` immediately before `git commit`. Newline-separated paths (not space-separated). The pre-commit staged-scope guard at `scripts/hooks/pre-commit-staged-scope-guard.sh` parses newlines:

```bash
STAGED_SCOPE=$(printf 'apps/web/src/foo.ts\napps/web/src/foo.test.ts') git commit -m "feat: ..."
```

For acknowledged bulk ops (migrations, memory consolidation, `scripts/install-hooks.sh` re-runs), use `STAGED_SCOPE='*'`.

### Git safety — shared working directory

Never leave work uncommitted. If you create or modify a file, commit it before any git operation that changes the working tree (pull, merge, worktree add). Other agents share this directory — uncommitted work WILL be lost.

---

## Branch strategy

| Prefix | Use |
|---|---|
| `feature/` | New features, capabilities |
| `fix/` | Bug fixes |
| `chore/` | Maintenance, docs, config |

Branch names follow `<prefix>/<slug>`. Agent-owned branches typically use `<agent-name>/<slug>` or `<agent-name>-<partner>/<slug>` for paired work (e.g. `viktor-rakan/dashboard-phase-1`).

---

## Merge policy (Rule 11)

**Never `git rebase`.** Always merge. Never force-push to main.

When a PR goes behind main, run `gh pr update-branch <num>` to merge main into the PR branch. This replaced the former auto-rebase workflow (removed strawberry-app PR #51) which violated Rule 11 and caused O(N × workflows) CI cascades.

---

## Branch protection (main)

`main` enforces the following gates (configured via `scripts/setup-branch-protection.sh`):

| Gate | Source | Context string |
|---|---|---|
| xfail-first | `.github/workflows/tdd-gate.yml` | `xfail-first check` |
| regression-test | `.github/workflows/tdd-gate.yml` | `regression-test check` |
| unit-tests | `.github/workflows/unit-tests.yml` | `unit-tests` |
| E2E | `.github/workflows/e2e.yml` | `Playwright E2E` |
| QA report (UI PRs) | `.github/workflows/pr-lint.yml` | `QA report present (UI PRs)` |

Additionally:
- `strict: true` — branch must be up-to-date with main before merge.
- `enforce_admins: true` — admin accounts are subject to the same gates; no bypass.
- One approving review required from an account other than the PR author.
- `dismiss_stale_reviews: true` — any new push invalidates prior approvals.
- `require_last_push_approval: true` — the approving review must be on the current tip commit.
- `required_conversation_resolution: true` — all reviewer-raised threads must be resolved.

### No `--admin` bypass (Rule 18)

Agents must never run `gh pr merge --admin`. An agent may merge its own PR once (a) all required checks are green and (b) one non-author approving review is in place. See `CLAUDE.md` Rule 18 (`#rule-no-admin-merge`).

### Break-glass procedure (human-only, Duong)

For documented emergencies only (production on fire, required check workflow itself broken):

1. Temporarily disable `enforce_admins`:
   ```bash
   gh api repos/harukainguyen1411/strawberry-agents/branches/main/protection/enforce_admins \
     -X DELETE -H "Accept: application/vnd.github+json"
   ```
2. Perform the emergency merge: `gh pr merge --admin <pr-number>`.
3. Re-enable immediately: `bash scripts/setup-branch-protection.sh`.
4. Write a post-incident note to `assessments/break-glass/YYYY-MM-DD-<slug>.md`.

Agents must not execute this procedure under any circumstance.

---

## Lock-Bypass contract (§Q6 — canonical-v1 lock)

During **measurement-week** (while `architecture/canonical-v1.md` is active), any commit that modifies a file pinned inside `architecture/agent-network-v1/` MUST carry a `Lock-Bypass:` trailer with a stated reason:

```
chore: update taxonomy — add new agent

Lock-Bypass: taxonomy.md reflects Lux being added to the network per plan 2026-05-01-lux-addition.md
```

### Lock-Bypass audit log

Every Lock-Bypass commit MUST also create or append a log entry at:

```
architecture/canonical-v1-bypasses.md
```

Log entry format (one entry per bypass, append-only):

```
## <ISO-8601 timestamp>

- **File:** `architecture/agent-network-v1/<filename>`
- **Commit:** `<sha>`
- **Reason:** <same text as the Lock-Bypass trailer>
- **Author:** <agent-name or human>
```

### Scope of the lock

The lock covers files recursively under `architecture/agent-network-v1/`. It does NOT cover `architecture/apps/`, `architecture/archive/`, or the root `architecture/README.md` (those are outside the canonical heart).

### Ban on `--no-verify` during measurement-week

Per Rule 14, `--no-verify` is prohibited on commit hooks. During canonical-v1 measurement-week, attempting `--no-verify` against locked files is treated as a Lock-Bypass event requiring the `Lock-Bypass:` trailer and a log entry in `architecture/canonical-v1-bypasses.md`. Hook-side enforcement of this specific measurement-week rule is a follow-up deliverable (W3).

---

## Build artifact guard

`scripts/hooks/pre-commit-artifact-guard.sh` blocks commits that include build artifact paths. Patterns blocked: `node_modules/`, `.turbo/`, `.firebase/`, `__pycache__/`, `apps/functions/lib/`.

---

## Operational files (outside git)

Ephemeral runtime state in `~/.strawberry/ops/` (gitignored):

| Directory | Contents |
|---|---|
| `~/.strawberry/ops/inbox/<agent>/` | Inbox messages |
| `~/.strawberry/ops/conversations/` | Multi-agent conversations |
| `~/.strawberry/ops/health/` | Heartbeats, registry |
| `~/.strawberry/ops/inbox-queue/` | Approval queue |
