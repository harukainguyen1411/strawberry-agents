# Cross-Repo Workflow

Documents how the three-repo model works day-to-day. See the approved migration plan at
`plans/approved/2026-04-19-public-app-repo-migration.md` §7 for the origin of these conventions.

---

## The Three Repos

| Repo | Visibility | Purpose | Status |
|------|------------|---------|--------|
| `harukainguyen1411/strawberry-app` | Public | Application code: `apps/`, `dashboards/`, `.github/workflows/`, `scripts/`, build config | Active |
| `Duongntd/strawberry` | Private | Agent infrastructure: `agents/`, `plans/`, `assessments/`, `architecture/`, `CLAUDE.md`, encrypted secrets | Active (archive candidate in 90 days post strawberry-agents migration) |
| `harukainguyen1411/strawberry-agents` | Private | Long-term home for agent infrastructure (pending migration from `Duongntd/strawberry`) | Proposed — see `plans/approved/2026-04-19-strawberry-agents-companion-migration.md` |

---

## Account Roles

| Account | Type | Role |
|---------|------|------|
| `Duongntd` | Agent account | Pushes code commits and PRs to `strawberry-app`; commits agent-infra directly to `strawberry` main |
| `harukainguyen1411` | Human account | Reviews and merges PRs in `strawberry-app`; repo owner of `strawberry-app` and `strawberry-agents` |

Agents open PRs from `Duongntd`. `harukainguyen1411` approves. Agents must never merge their own PRs
(CLAUDE.md rule 18). `harukainguyen1411` has admin bypass but this is break-glass only — human Duong action.

---

## Where Plans Live

Plans live in `Duongntd/strawberry` under `plans/` and commit directly to `main` via `scripts/plan-promote.sh`
(never via PR). After the strawberry-agents migration completes, plans will move to
`harukainguyen1411/strawberry-agents`. Until then, the private `strawberry` repo is the canonical plan store.

---

## How PRs Link to Plans

Plans reference code PRs via absolute URLs:

```
https://github.com/harukainguyen1411/strawberry-app/pull/<N>
```

PR bodies reference plans via absolute permalink to `strawberry` main:

```
https://github.com/Duongntd/strawberry/blob/main/plans/<status>/<slug>.md
```

No file-level coupling between the two repos. Links are the only cross-repo reference.

---

## How Secrets Flow

Encrypted secrets are stored in `secrets/encrypted/` inside the private `strawberry` repo
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

- Plans, memory, learnings, architecture → work in the `strawberry` checkout at
  `~/Documents/Personal/strawberry/`.
- Code changes → work in the `strawberry-app` checkout at
  `~/Documents/Personal/strawberry-app/` (checked out as a sibling worktree).

Never `cd` between the two repos in a single session. Use `git worktree` for branches within each
repo — never raw `git checkout` (CLAUDE.md rule 3, `scripts/safe-checkout.sh`).

---

## Cross-Repo Search

To find where a feature lives — start in plans, then look in code:

1. **Find the plan:** grep `plans/` in `strawberry` for the feature keyword.
2. **Find the implementation:** grep `apps/` or `dashboards/` in `strawberry-app` for the same keyword.
3. **Link from plan to PR:** plan will contain an absolute URL to the `strawberry-app` PR.

Example:
```bash
# In strawberry checkout:
grep -r "bee-worker" plans/

# In strawberry-app checkout:
grep -r "bee-worker" apps/
```

---

## Conventions Summary

1. Plans always in `strawberry` (and eventually `strawberry-agents`). PRs always in `strawberry-app`.
2. `Duongntd` pushes; `harukainguyen1411` reviews and merges.
3. Secrets for CI go into `strawberry-app` GitHub Actions secrets via `gh secret set`.
4. Encrypted local secrets live in `strawberry` (or `strawberry-agents` post-migration).
5. Sessions are single-repo scoped — use worktrees, not `cd`.
6. Cross-repo references use absolute GitHub URLs only — no relative paths between repos.
