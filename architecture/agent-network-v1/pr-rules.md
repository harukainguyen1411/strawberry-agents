---
Supersedes: archive/pre-network-v1/pr-rules.md
---

# PR Rules — v1

All pull requests in `harukainguyen1411/strawberry-app` (code) follow these rules. Plans commit directly to `harukainguyen1411/strawberry-agents` main — never via PR (Rule 4).

## Required fields

- **Author line** — include `Author: <agent-name>` in the PR description body (not the title). Identifies which agent did the implementation.
- **QA-Report or QA-Waiver** — required for UI and user-flow PRs; see [QA gate (Rule 16)](#qa-gate-rule-16) below.
- **Documentation checklist** — check the PR template documentation checklist before submitting.

## Documentation updates

If your change touches any of the following, update the relevant docs in the same PR:

- `architecture/agent-network-v1/` — canonical system docs
- `.claude/agents/*.md` — subagent definitions
- `scripts/` — key scripts table at `architecture/agent-network-v1/key-scripts.md`
- Plugins — update `architecture/agent-network-v1/plugins.md` if plugins are added or removed
- Features or integrations — update the relevant `README.md`

## Branch and PR flow

- Use `scripts/worktree-add.sh <path> -b <branch> origin/main` to create a branch (never raw `git checkout -b`).
- Use `git worktree` for isolation. See `git-workflow.md` for full branch strategy.
- Never `git rebase` — always merge (Rule 11).
- Never push `--force` to main.

## Commit prefix

All commits use a conventional prefix scoped by diff. See `git-workflow.md` §Commit prefix policy (Rule 5). The pre-push hook enforces this on push. See also `CLAUDE.md` Rule 5 (`#rule-chore-commit-prefix`).

## Account roles (Rule 18)

| Account | Role |
|---|---|
| `Duongntd` | Executor — opens PRs, pushes commits, manages branches |
| `strawberry-reviewers` | Reviewer — Lucian uses this identity to post approvals on personal-concern PRs (`scripts/reviewer-auth.sh`) |
| `strawberry-reviewers-2` | Reviewer — Senna uses this identity to post approvals on personal-concern PRs (`scripts/reviewer-auth.sh --lane senna`) |
| `harukainguyen1411` | Human owner — break-glass merges and admin only |

Every PR merge requires:

**(a)** All required status checks green (xfail-first, regression-test, unit-tests, E2E, QA report if UI).

**(b)** One approving review from an account other than the PR author. For personal-concern PRs, Senna and Lucian post approvals via `strawberry-reviewers{,-2}` — structurally distinct from `Duongntd`, so GitHub's author-cannot-approve-own-PR check passes without human intervention.

Agents must NOT use `gh pr merge --admin` or any branch-protection bypass. See `CLAUDE.md` Rule 18 (`#rule-no-admin-merge`).

## Review cycle

Senna (code quality + security) and Lucian (plan/ADR fidelity) both review every PR before merge.

**Standard loop:**
1. Implementer opens PR, posts link to Evelynn.
2. Evelynn dispatches Senna and Lucian to review concurrently.
3. Senna and Lucian each post a `gh pr review` verdict (APPROVE or REQUEST_CHANGES + comment body).
4. If either requests changes: implementer pushes fixes, re-pings reviewers.
5. Once both approve: Evelynn (or the implementer) runs `gh pr merge`.

Reviewer agents use `scripts/reviewer-auth.sh` (personal concern) or `scripts/post-reviewer-comment.sh` (work concern). Executor agents (`Jayce`, `Viktor`, `Ekko`, `Seraphine`, `Yuumi`, `Vi`, `Akali`, `Skarner`) MUST NOT source `reviewer-auth.sh` — they authenticate as `Duongntd` only.

## QA gate (Rule 16)

Before opening a UI or user-flow PR, **Akali** (`.claude/agents/akali.md`) must run the full Playwright MCP flow (`mcp__plugin_playwright_playwright__*` tool family) with video + screenshots and diff against the Figma design.

- Report lives under `assessments/qa-reports/` and is linked in the PR body via a `QA-Report: <path-or-url>` line.
- A `QA-Waiver: <reason>` line is accepted in lieu when Akali cannot run (e.g. no running staging environment).
- Enforced by `.github/workflows/pr-lint.yml` — PR cannot merge with a missing marker on UI/user-flow PRs.
- Non-UI and non-user-flow PRs are exempt.

_User-flow_ definition: new routes, new forms, state-transition changes, auth flows, session lifecycle changes — even when there is no visual pixel delta.

See `CLAUDE.md` Rule 16 (`#rule-qa-agent-pre-pr`) for the authoritative definition.

## xfail-first (Rule 12) and regression tests (Rule 13)

- Every implementation commit on a TDD-enabled service must be preceded by a commit adding an xfail test on the same branch (Rule 12). Enforced by pre-push hook and CI `tdd-gate.yml`.
- Every bug-fix commit (tagged bug/bugfix/regression/hotfix) must include or be preceded by a regression test in the same branch (Rule 13). Enforced by pre-push hook, CI, and the PR template.

Agents may never bypass these gates.

See `CLAUDE.md` Rules 12 (`#rule-xfail-first`) and 13 (`#rule-regression-test`).

## E2E required (Rule 15)

PR creation triggers Playwright E2E (`e2e.yml`). PR cannot merge red. Agents may never merge a red PR.

See `CLAUDE.md` Rule 15 (`#rule-e2e-required`).

## Post-deploy smoke tests (Rule 17)

Smoke tests run on stg and prod after deploy. Prod smoke failures trigger auto-revert. No bypass for prod. (Rollback script is a future deliverable — not yet in repo.)

See `CLAUDE.md` Rule 17 (`#rule-smoke-tests`).

## No AI attribution (Rule 21)

No commit body, PR title, PR description, or PR comment may contain AI attribution markers (`Claude`, `Anthropic`, `Sonnet`, `Opus`, `Haiku`, `AI-generated`, `claude.com`, etc.) or `Co-Authored-By:` trailers pointing to an AI identity.

Override for all three enforcement layers: include `Human-Verified: yes` trailer in the commit message or PR body.

See `CLAUDE.md` Rule 21 for the authoritative three-layer defense (prompt, hook, CI).

## Work-scope anonymity

Work-concern PRs land on repos under the `missmp/` GitHub organisation, where Duong's teammates can see every review body and commit message. Agent-system internals must never leak into those surfaces.

A repo is **work-scope** when `git remote get-url origin` matches the regex `[:/]missmp/`. Personal-concern repos are unaffected.

Blocked tokens on work-scope surfaces:

| Category | Examples |
|---|---|
| Agent first-names | Senna, Lucian, Evelynn, Sona, Viktor, Jayce, Azir, Swain, Orianna, Karma, Talon, Ekko, Heimerdinger, Syndra, Akali, Ahri, Ori |
| GitHub handles | `strawberry-reviewers`, `strawberry-reviewers-2`, `harukainguyen1411`, `duongntd99` |
| Email domain | `*@anthropic.com` |
| AI attribution trailer | `Co-Authored-By: Claude` |

The denylist is the single source of truth in `scripts/hooks/_lib_reviewer_anonymity.sh`. Enforcement:

1. **Pre-commit hook** (`scripts/hooks/pre-commit-reviewer-anonymity.sh`) — scans `.git/COMMIT_EDITMSG`. Hit → exit 1, commit blocked.
2. **`scripts/reviewer-auth.sh` pre-submit scan** — if the PR repo matches `missmp/`, scans the `--body` value before posting. Hit → exit 3, request not posted.

Sign reviews with a generic role tag (e.g. `-- reviewer`) rather than an agent name on work-scope surfaces.

See also `cross-repo.md` for the multi-repo context.

## Merge

An agent may merge its own PR once (a) and (b) above are satisfied. Never merge before both gates clear. See the full gate table in `git-workflow.md` §Branch protection.
