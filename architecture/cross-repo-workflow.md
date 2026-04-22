# Cross-Repo Workflow

Documents how the three-repo model works day-to-day. See the approved migration plan at
`plans/approved/2026-04-19-public-app-repo-migration.md` §7 for the origin of these conventions.

---

## The Three Repos

| Repo | Visibility | Purpose | Status |
|------|------------|---------|--------|
| `harukainguyen1411/strawberry-app` | Public | Application code: `apps/`, `dashboards/`, `.github/workflows/`, `scripts/`, build config | Active |
| `harukainguyen1411/strawberry-agents` | Private | Agent infrastructure: `agents/`, `plans/`, `assessments/`, `architecture/`, `CLAUDE.md`, encrypted secrets | Active |
| `Duongntd/strawberry` | Private | Archive of pre-migration monorepo (read-only, 90-day retention through 2026-07-18) | Archive |

---

## Account Roles

| Account | Type | Role |
|---------|------|------|
| `Duongntd` | Agent account | Pushes code commits and PRs to `strawberry-app`; commits agent-infra directly to `strawberry-agents` main |
| `harukainguyen1411` | Human account | Reviews and merges PRs in `strawberry-app`; repo owner of `strawberry-app` and `strawberry-agents` |

Agents open PRs from `Duongntd`. `harukainguyen1411` approves. Per CLAUDE.md rule 18, agents must not
use `--admin` or any branch-protection bypass; every merge requires (a) all required status checks green,
(b) one approving review from an account other than the PR author, and (c) no branch-protection bypass.
An agent may merge its own PR once (a), (b), and (c) are satisfied. `harukainguyen1411` has admin bypass
but this is break-glass only — human Duong action.

---

## Where Plans Live

Plans live in `harukainguyen1411/strawberry-agents` under `plans/` and commit directly to `main` via `scripts/plan-promote.sh`
(never via PR). The private `strawberry-agents` repo is the canonical plan store.

---

## How PRs Link to Plans

Plans reference code PRs via absolute URLs:

```
https://github.com/harukainguyen1411/strawberry-app/pull/<N>
```

PR bodies reference plans via absolute permalink to `strawberry-agents` main:

```
https://github.com/harukainguyen1411/strawberry-agents/blob/main/plans/<status>/<slug>.md
```

No file-level coupling between the two repos. Links are the only cross-repo reference.

---

## How Secrets Flow

Encrypted secrets are stored in `secrets/encrypted/` inside the private `strawberry-agents` repo
(gitignored plaintext stays local; only `.age` blobs are committed). `strawberry-app` CI workflows
need secrets provisioned directly as GitHub Actions secrets on `harukainguyen1411/strawberry-app`.

To add or rotate a secret in `strawberry-app`:
```bash
gh secret set <NAME> --repo harukainguyen1411/strawberry-app --body-file -
```

Decryption of local secrets always uses `tools/decrypt.sh` — never raw `age -d` (CLAUDE.md rule 6).

---

## Git Worktree Convention

Agent sessions are scoped to one repo at a time:

- Plans, memory, learnings, architecture → work in the `strawberry-agents` checkout at
  `~/Documents/Personal/strawberry-agents/`.
- Code changes → work in the `strawberry-app` checkout at
  `~/Documents/Personal/strawberry-app/` (checked out as a sibling worktree).

Never `cd` between the two repos in a single session. Use `git worktree` for branches within each
repo — never raw `git checkout` (CLAUDE.md rule 3, `scripts/safe-checkout.sh`).

---

## Cross-Repo Search

To find where a feature lives — start in plans, then look in code:

1. **Find the plan:** grep `plans/` in `strawberry-agents` for the feature keyword.
2. **Find the implementation:** grep `apps/` or `dashboards/` in `strawberry-app` for the same keyword.
3. **Link from plan to PR:** plan will contain an absolute URL to the `strawberry-app` PR.

Example:
```bash
# In strawberry-agents checkout:
grep -r "bee-worker" plans/

# In strawberry-app checkout:
grep -r "bee-worker" apps/
```

---

## Work-scope Reviewer Anonymity

Work-concern repos live under the `missmp/` GitHub organisation. Duong's MMP teammates can
see every commit message, PR review body, and comment on those repos. Agent-system internals
(agent names, reviewer handles, `*@anthropic.com` emails, `Co-Authored-By: Claude` trailers)
must never appear in work-scope surfaces.

Enforcement is automatic:
- Pre-commit hook scans commit messages when `origin` matches `[:/]missmp/`
- `scripts/reviewer-auth.sh` scans review/comment bodies before posting

Full denylist and guidance: `architecture/pr-rules.md` `#work-scope-anonymity`.

---

## Conventions Summary

1. Plans always in `strawberry-agents`. PRs always in `strawberry-app`.
2. `Duongntd` pushes; `harukainguyen1411` reviews and merges.
3. Secrets for CI go into `strawberry-app` GitHub Actions secrets via `gh secret set`.
4. Encrypted local secrets live in `strawberry-agents`.
5. Sessions are single-repo scoped — use worktrees, not `cd`.
6. Cross-repo references use absolute GitHub URLs only — no relative paths between repos.
