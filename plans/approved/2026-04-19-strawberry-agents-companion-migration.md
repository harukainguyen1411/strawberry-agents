---
status: approved
owner: azir
date: 2026-04-19
title: Companion ADR — strawberry-agents private infra-repo split (parallel to strawberry-app)
links:
  - plans/approved/2026-04-19-public-app-repo-migration.md
  - plans/approved/2026-04-17-branch-protection-enforcement.md
  - architecture/git-workflow.md
  - architecture/security-debt.md
---

# Companion ADR — strawberry-agents split

## 1. Context and decision summary

The strawberry-app migration (`plans/approved/2026-04-19-public-app-repo-migration.md`) peels code out of `Duongntd/strawberry` into a new public repo. This companion plan peels **the remaining agent-infra half** out into `harukainguyen1411/strawberry-agents` (private, new). The two splits together drain `Duongntd/strawberry` to zero, after which it archives.

**Decision:** three-repo end state.

| Repo | Owner | Visibility | Role |
|------|-------|-----------|------|
| `harukainguyen1411/strawberry-app` | harukainguyen1411 | Public | Code: apps, dashboards, workflows, deploy scripts |
| `harukainguyen1411/strawberry-agents` | harukainguyen1411 | **Private** | Agent brain: agents/, plans/, assessments/, CLAUDE.md, tasklist/, incidents/, design/, mcps/, secrets/encrypted/, agent-infra scripts/tools, private architecture subset |
| `Duongntd/strawberry` | Duongntd | Private (existing) | Archive-only after cutover; read-only observation for 7 days, then archived/renamed |

**Why a second split, not "keep infra where it is":** leaving infra on `Duongntd/strawberry` permanently bifurcates the identity (code lives under `harukainguyen1411`, brain under `Duongntd`). Unified agent-account identity under `harukainguyen1411` is the cleaner long-term posture: one account owns one product, one agent system, one PAT scope surface, one billing relationship. It also lets Duong archive/delete the original repo without a forwarding-address problem.

**What this plan is not:** not a re-architecture of the agent system. No file inside `agents/`, `plans/`, `assessments/`, `CLAUDE.md`, or the private `architecture/` subset changes semantically. Only the origin URL moves. The complement of the strawberry-app scope table (§2.3 of the app plan) is what moves here. See §2 for the symmetric check.

---

## 2. Scope — symmetric with strawberry-app plan

This section is written as the **complement** of `plans/approved/2026-04-19-public-app-repo-migration.md` §2. Together, the two plans are collectively exhaustive over `Duongntd/strawberry` main as of the cutover commit. Nothing is orphaned; nothing is duplicated except the deliberately dual-tracked items in §2.3.

### 2.1 Moves to `harukainguyen1411/strawberry-agents` (private)

Equivalent to strawberry-app plan §2.3 "Stays in private strawberry," restated as moves:

| Path | Notes |
|------|-------|
| `agents/**` | Full tree: profiles, memory, journals, learnings, inboxes, transcripts |
| `plans/**` | `proposed/`, `approved/`, `in-progress/`, `implemented/`, `archived/` |
| `assessments/**` | Internal analyses, QA reports, evaluations |
| `CLAUDE.md` (root) | Agent invariants |
| `agents/evelynn/CLAUDE.md` | Coordinator protocol |
| `.claude/agents/**` | All agent definition files with model frontmatter |
| `tasklist/**` | Internal task queue |
| `incidents/**` | Ops postmortems |
| `design/**` | Figma mirrors, design artifacts |
| `mcps/**` | MCP server configs |
| `secrets/encrypted/**` | Age-encrypted secret blobs. Filenames alone leak signal about what is stored — private-only per strawberry-app plan §2.3. |
| `architecture/` private subset | `agent-network.md`, `agent-system.md`, `claude-billing-comparison.md`, `claude-runlock.md`, `infrastructure.md`, `mcp-servers.md`, `plugins.md`, `plan-gdoc-mirror.md`, `security-debt.md`, `discord-relay.md`, `telegram-relay.md`. Matches the "Private" default in strawberry-app plan §2.5. |
| Agent-infra scripts under `scripts/` | `plan-promote.sh`, `plan-publish.sh`, `plan-unpublish.sh`, `plan-fetch.sh`, `_lib_gdoc.sh`, `safe-checkout.sh`, `evelynn-memory-consolidate.sh`, `list-agents.sh`, `new-agent.sh`, `lint-subagent-rules.sh`, `strip-skill-body-retroactive.py`, `hookify-gen.js`, `google-oauth-bootstrap.sh`, `setup-agent-git-auth.sh`. Matches strawberry-app plan §2.2 "Private repo only" rows. |
| Agent-infra hooks | `scripts/hooks/plan-gdoc-mirror.sh`, `scripts/hooks/heartbeat.sh`, `scripts/hooks/evelynn-memory-consolidate.sh`, and any other hook that operates on `agents/`, `plans/`, `assessments/` paths. |
| Agent-infra tools under `tools/` | `tools/decrypt.sh` source of truth stays here. (See §2.3 — the app repo keeps a runtime copy without the key.) |
| `secrets/age-key.txt` | **Gitignored in both repos.** Lives on disk in the agent-infra worktree only — never committed. Called out explicitly because D6 in §6 confirms it. |
| Session-closing skill/infra | `/end-session`, `/end-subagent-session` skill definitions, transcript-archive scripts. |

### 2.2 Stays out of strawberry-agents

The strawberry-app plan §2.1 table enumerates everything that moves to the public repo. By construction, none of those paths are in scope here. Explicit non-moves worth calling out because they sit close to the boundary:

| Path | Where it goes | Why |
|------|---------------|-----|
| `apps/**` (including `apps/private-apps/bee-worker`) | strawberry-app | Per strawberry-app plan §8 decision 6 |
| `dashboards/**` | strawberry-app | |
| `.github/workflows/**`, `.github/branch-protection.json`, `.github/dependabot.yml`, `.github/pull_request_template.md`, `.github/scripts/**` | strawberry-app | **Exception:** strawberry-agents gets its own minimal `.github/` — at minimum a `pull_request_template.md` (light, private-infra flavored) and any agent-memory-consolidation GitHub Action if one exists today. Enumerated in §3 R-agents-4. |
| Deploy/ops scripts (`scripts/deploy/**`, `scripts/composite-deploy.sh`, `scripts/scaffold-app.sh`, `scripts/seed-app-registry.sh`, `scripts/health-check.sh`, `scripts/migrate-firestore-paths.sh`, `scripts/vps-setup.sh`, `scripts/deploy-discord-relay-vps.sh`, `scripts/gce/**`, `scripts/mac/**`, `scripts/windows/**`) | strawberry-app | |
| Repo-setup scripts (`scripts/setup-branch-protection.sh`, `scripts/verify-branch-protection.sh`, `scripts/setup-github-labels.sh`, `scripts/setup-discord-channels.sh`, `scripts/gh-audit-log.sh`, `scripts/gh-auth-guard.sh`) | strawberry-app | Note: the strawberry-agents side needs **its own** branch-protection tooling (see §3 R-agents-4 and §7.3) — duplicated script copies, not shared. |
| Top-level build config (`package.json`, `tsconfig.json`, `turbo.json`, `eslint*`, `firestore.rules`, `firestore.indexes.json`, `release-please-config.json`, `ecosystem.config.js`) | strawberry-app | strawberry-agents has no build — no `package.json` at root. |

### 2.3 Dual-tracked (deliberately duplicated)

Parallels strawberry-app plan §2.4, extended:

| Path | Treatment |
|------|-----------|
| `scripts/hooks/pre-commit-secrets-guard.sh` | Source of truth in strawberry-agents. strawberry-app copies on each hook refresh. Matches strawberry-app plan §2.2. |
| `scripts/install-hooks.sh` | Both repos. Each installs its own hook bundle — strawberry-agents installs plan-gdoc-mirror / heartbeat / memory-consolidate; strawberry-app installs pre-commit-unit-tests / pre-push-tdd / pre-commit-artifact-guard. Common bundle: secrets-guard + commit-prefix linter. |
| `.gitignore` | Two tuned copies — strawberry-agents retains agent-oriented ignores; strawberry-app retains build-oriented ignores. |
| `tools/decrypt.sh` | Source of truth in strawberry-agents. strawberry-app carries a runtime copy **without** `secrets/age-key.txt`. Matches strawberry-app plan §2.1 row. |
| Commit-prefix linter | Shared code-path, different allowed-prefix table per repo (see §5). |

---

## 3. Risk register (agent-infra-specific)

The strawberry-app plan §3 risks R1-R15 apply primarily to the public split and are not restated here. These are additive risks specific to the private split. Naming: `R-agents-N` to avoid collision.

| # | Risk | Severity | Mitigation |
|---|------|----------|------------|
| R-agents-1 | **Agent-memory commit-SHA references break under `git filter-repo --invert-paths`.** Agent memory files (`agents/*/memory/MEMORY.md`, `learnings/**`, transcripts) cite commit SHAs like `c1a0311` or `3c0dc77`. `filter-repo` **rewrites SHAs of every commit it touches** — a commit that originally had SHA X becomes X'. SHAs quoted in agent memory point at the **old** repo history, which after cutover lives only in the `Duongntd/strawberry` archive. | High | (a) Preserve `Duongntd/strawberry` as read-only archive for 90 days minimum (extends strawberry-app plan Phase 6's 7-day window for agent-memory lookups). (b) **Do not rewrite existing SHAs in agent memory files.** They point to the archive — that's fine. (c) After cutover, all new commits in strawberry-agents get fresh SHAs; memory going forward references only those. (d) Optional Phase 5-equivalent: add a one-line footer to MEMORY.md files noting "SHAs prior to YYYY-MM-DD resolve against `Duongntd/strawberry` (archive)." |
| R-agents-2 | **`secrets/encrypted/` filename stability under `filter-repo`.** Path rename/reorganization during history surgery could desynchronize age-encrypted blob filenames from their lookup references in scripts (`tools/decrypt.sh SECRET_NAME` expects `secrets/encrypted/SECRET_NAME.age`). | Medium | No path rewriting during filter — `filter-repo --invert-paths` drops paths wholesale and leaves kept paths verbatim. Verify with a post-filter `diff -r` of the `secrets/encrypted/` tree against the pre-filter working tree. Add an acceptance check: `tools/decrypt.sh` resolves every known secret name against the new repo. |
| R-agents-3 | **Agent sessions don't know the new repo URL.** Running agents with cached `origin` remotes, or skills/scripts that hardcode `Duongntd/strawberry` for plan lookups (e.g., `plan-publish.sh`, Drive mirror), will push to the wrong place. | High | Phase 2 grep sweep (symmetric to strawberry-app plan §6.2) for `Duongntd/strawberry` inside the kept paths. Expected hits: plan-gdoc mirror scripts, any `agents/*/memory/MEMORY.md` that cites a repo URL (not SHA), `architecture/git-workflow.md`, `CLAUDE.md`. Rewrite in an atomic commit. All active agent sessions restart after cutover — stale checkouts are garbage-collected via a fresh `git clone` into `~/Documents/Personal/strawberry-agents/` (replaces the old working dir). |
| R-agents-4 | **Branch protection on private infra repo — what should it even be?** The strawberry-app plan §1 of branch-protection-enforcement.md enumerates 5 required contexts tuned to code (tdd-gate, unit-tests, e2e, qa, validate-scope). None of those apply to a plan-only / memory-only repo. Leaving strawberry-agents wide open invites accidental force-push or unreviewed memory corruption. | Medium | Define a minimal private-infra protection profile: require 1 approving review **from self-or-agent-co-author** (Duong will often be sole committer, so this downgrades to `enforce_admins: false` + `required_approving_review_count: 0` + **no force-push**, **no branch deletion**). Document as §7.3 below. The one required status check: a lightweight `plan-frontmatter-lint` workflow that validates YAML frontmatter on plan commits. Write as a sibling ADR only if this minimal profile proves insufficient. |
| R-agents-5 | **Concurrent filter-repo runs on the same bare clone will corrupt.** Ekko/Viktor's strawberry-app Phase 1-2 uses `/tmp/strawberry-filter.git`. If this plan reuses the same bare clone path, the two filter-repo runs race. | Low | Use distinct scratch paths: strawberry-app uses `/tmp/strawberry-app-filter.git` (rename from the app plan's `/tmp/strawberry-filter.git`), strawberry-agents uses `/tmp/strawberry-agents-filter.git`. Both fresh-clone from the same `Duongntd/strawberry` base SHA (see §4.1). |
| R-agents-6 | **Plan-gdoc mirror breaks mid-migration.** `scripts/plan-publish.sh` pushes proposed plans to Drive; the Drive doc's back-reference to GitHub hardcodes the repo slug. Mid-migration, a plan-promote will try to unpublish against the old repo while proposing against the new. | Low | Freeze plan-promote operations for the migration window (call it out in §4 Phase 0). No proposed→approved transitions while the scratch clone is active. If a plan must be promoted urgently, do it before Phase 1 starts or after Phase 5 completes. |
| R-agents-7 | **`Duongntd/strawberry` archive is still the canonical origin for agent identity references** (e.g., agent-network.md commit history, historical transcripts). Deleting the archive orphans them. | Medium | Phase 6 of strawberry-app plan already delays purge by 7 days. This plan extends that: **do not rename or delete `Duongntd/strawberry` for 90 days** after strawberry-agents cutover. After 90 days, rename to `strawberry-archive` (per Duong decision at cutover — see D5). |
| R-agents-8 | **Self-referential invariant: strawberry-agents is where this very plan lives after cutover.** Committing the plan to `Duongntd/strawberry` and then migrating means the plan's permalink URL changes mid-execution. | Low | Accept. Any link to this plan that predates cutover resolves against `Duongntd/strawberry` (archive). Post-cutover permalinks point at `harukainguyen1411/strawberry-agents/blob/main/plans/...`. Phase 2 grep sweep rewrites the permalink in any agent memory that cites this plan. |

---

## 4. Execution sequence

Total budget: 90-120 min additional on top of the strawberry-app migration. Single executor: **Ekko** owns history filter + push. **Caitlyn** handles branch-protection and agent-memory URL rewrites (Phase 5 symmetric to app plan). No Duong-actionable preflight beyond §4.0.

**Piggyback decision (answers the brief's §4 question):** this plan gets **its own scratch clone at `/tmp/strawberry-agents-filter.git`**, not a piggyback on Ekko's strawberry-app scratch. Reasons: (a) filter-repo invocations differ (`--invert-paths` for this plan vs. the strawberry-app plan's squash-and-rebuild); (b) concurrent filter-repo on one bare clone is unsafe (R-agents-5); (c) independent rollback surface — if strawberry-app cutover aborts, strawberry-agents clone remains valid for retry without re-cloning. **Both scratch clones derive from the same base SHA on `Duongntd/strawberry` main** (captured at Phase 0 of the strawberry-app plan — the post-dual-green-merge tip).

### 4.0 Preflight — Duong actions (~10 min)

1. Create empty private repo: https://github.com/new → owner `harukainguyen1411`, name `strawberry-agents`, visibility **Private**. Do not initialize with README/LICENSE/.gitignore.
2. Confirm the same fine-grained PAT minted for strawberry-app (per app plan §4.4 step 3) has read/write scope extended to `harukainguyen1411/strawberry-agents`. Same account owns both repos, so one PAT covers both.
3. Freeze plan-promote operations — no proposed→approved transitions until Phase 5 completes (R-agents-6).

### 4.1 Phase A1 — History filter (Ekko, fresh scratch clone) — 30 min

1. `git clone --bare https://github.com/Duongntd/strawberry.git /tmp/strawberry-agents-filter.git` — **same base SHA** as strawberry-app scratch (post-Phase-0 of that plan).
2. `git clone /tmp/strawberry-agents-filter.git /tmp/strawberry-agents && cd /tmp/strawberry-agents`.
3. **Preserve history via `git filter-repo --invert-paths`.** Drop public paths:
   ```
   git filter-repo \
     --invert-paths \
     --path apps/ \
     --path dashboards/ \
     --path .github/workflows/ \
     --path .github/branch-protection.json \
     --path .github/dependabot.yml \
     --path .github/pull_request_template.md \
     --path .github/scripts/ \
     --path-glob 'package*.json' \
     --path-glob 'tsconfig*.json' \
     --path turbo.json \
     --path firestore.rules \
     --path firestore.indexes.json \
     --path release-please-config.json \
     --path ecosystem.config.js \
     --path scripts/deploy/ \
     --path scripts/gce/ \
     --path scripts/mac/ \
     --path scripts/windows/
   ```
   (The scripts-level granularity — keep `scripts/plan-promote.sh` etc., drop `scripts/deploy/**` etc. — may require a second pass with `--path-glob` rules. Exact invocation tuned in session; the above is the shape.)
4. Run gitleaks on the **full filtered history**: `gitleaks detect --source=. --log-opts="--all" --redact --report-path=/tmp/gitleaks-agents.json`. Plan-text is lower-risk than code, but agent memory files sometimes paste token-shaped strings as examples. Any real finding → STOP, rotate, amend.
5. Post-filter diff check: `diff -r /tmp/strawberry-agents/secrets/encrypted/ <pre-filter-working-tree>/secrets/encrypted/` — enforces R-agents-2.
6. Post-filter sanity: `tools/decrypt.sh` dry-runs against each known secret name (no actual decryption — just resolves the filepath).

Rollback point: discard `/tmp/strawberry-agents`, no remote changes.

### 4.2 Phase A2 — Rewrite repo references (Ekko) — 20 min

Symmetric to strawberry-app plan §4.3 but for the agent-infra side.

1. Grep sweep in `/tmp/strawberry-agents`:
   ```
   grep -rln 'Duongntd/strawberry' . --include='*.sh' --include='*.py' --include='*.js' --include='*.md' --include='*.txt'
   ```
2. Expected hits (verify in session):
   - `CLAUDE.md` (root) — agent invariants mentioning the repo.
   - `agents/evelynn/CLAUDE.md`.
   - `scripts/plan-publish.sh`, `scripts/plan-unpublish.sh`, `scripts/_lib_gdoc.sh` — Drive-mirror back-references.
   - `architecture/git-workflow.md`, `architecture/plan-gdoc-mirror.md`.
   - `agents/*/memory/MEMORY.md` entries that cite repo URLs (not SHAs — see R-agents-1).
3. Rewrite: `Duongntd/strawberry` → `harukainguyen1411/strawberry-agents` **only in agent-infra contexts**. For references to code PRs, rewrite to `harukainguyen1411/strawberry-app` (matches strawberry-app plan §7). In-session judgment required per hit.
4. Commit as `chore: retarget repo references to strawberry-agents and strawberry-app`.

Rollback point: discard the commit, redo.

### 4.3 Phase A3 — Push + protect (Caitlyn) — 20 min

1. `git remote add origin https://github.com/harukainguyen1411/strawberry-agents.git && git push -u origin main`.
2. No GitHub secrets to provision — private infra repo has no workflows that need cloud deploy credentials. (If the heartbeat / memory-consolidate hooks run as GitHub Actions — audit in session; if yes, provision `AGENT_GITHUB_TOKEN` only.)
3. Apply minimal private-infra branch protection (§7.3 below): no force-push, no branch deletion, `required_approving_review_count: 0`, `enforce_admins: false`. Add `plan-frontmatter-lint` as the single required status check once that workflow exists (non-blocking for initial push).
4. Install hooks locally via `scripts/install-hooks.sh` in the new working tree. Confirm `pre-commit-secrets-guard.sh` functions identically to the pre-migration state.

Rollback point: delete `harukainguyen1411/strawberry-agents` repo (Duong action). No downstream bindings to revert.

### 4.4 Phase A4 — Working-tree swap (Ekko + Caitlyn) — 10 min

1. Archive or delete `~/Documents/Personal/strawberry/` (the local working dir tied to `Duongntd/strawberry`). Duong chooses — recommended: rename to `~/Documents/Personal/strawberry-archive-local/` for a 7-day grace period.
2. Fresh `git clone https://github.com/harukainguyen1411/strawberry-agents.git ~/Documents/Personal/strawberry-agents/`.
3. Run `scripts/install-hooks.sh` in the new checkout.
4. Copy `secrets/age-key.txt` from the archived local tree to the new checkout's `secrets/` (gitignored).
5. All subsequent agent sessions launch from `~/Documents/Personal/strawberry-agents/`.

Rollback point: keep using the archived local tree; remote remains `Duongntd/strawberry`. No data loss.

### 4.5 Phase A5 — Agent-memory cross-repo update (Caitlyn) — 20 min

Symmetric to strawberry-app plan §4.6, but updates in **both directions**:

1. In `harukainguyen1411/strawberry-agents`, update `CLAUDE.md` (root) and `agents/evelynn/CLAUDE.md` to name the three-repo relationship: `strawberry-agents` (private, agent brain, current repo), `strawberry-app` (public, code), `Duongntd/strawberry` (archive).
2. Update `architecture/git-workflow.md` and create/update `architecture/cross-repo-workflow.md` (or extend the file created in strawberry-app plan §4.6) with the three-repo shape per §5 below.
3. Sweep `agents/*/memory/MEMORY.md` for any `Duongntd/strawberry/pull/N` link that cites a post-migration PR — rewrite to `harukainguyen1411/strawberry-app/pull/N`. Pre-migration PR links resolve against the archive — leave untouched.
4. Add one-line footer to each active agent's `MEMORY.md`: "Commit SHAs prior to 2026-04-19 resolve against `Duongntd/strawberry` (archive, 90-day retention)." (R-agents-1, R-agents-7.)
5. Commit: `chore: azir migration — update agent memory and CLAUDE.md for three-repo split`.

### 4.6 Phase A6 — Archive (Duong action, T+90 days)

After 90 days of stable operation (longer than strawberry-app plan §4.7's 7-day window — see R-agents-7):

1. Rename `Duongntd/strawberry` → `strawberry-archive` (github.com → Settings → rename).
2. Apply archive flag (Settings → Archive this repository).
3. Agent memory file footers can remain as-is — they still resolve, just against an archived repo.

Rollback point: un-archive (GitHub allows). Rename is reversible. Only irreversible step is if Duong later deletes the archive entirely — explicitly not in scope of this plan.

---

## 5. Cross-repo conventions update

Extends strawberry-app plan §7 from two-repo to three-repo. §7 of that plan should be **amended** (not re-written from scratch) after both migrations complete. Proposed amendments:

1. **Plans live in `strawberry-agents`.** (Was "in strawberry.") Code PRs in `strawberry-app` link via permalink: `https://github.com/harukainguyen1411/strawberry-agents/blob/main/plans/approved/<slug>.md`.
2. **PRs live in `strawberry-app`.** (Unchanged.)
3. **Archive references are explicit.** Any link to a pre-2026-04-19 commit SHA resolves against `github.com/Duongntd/strawberry` (archive) for 90 days, then against `github.com/Duongntd/strawberry-archive` indefinitely. Agents must not assume any Duongntd/strawberry URL is live.
4. **Shared commit-prefix rules** — unchanged. Both active repos use `chore:` / `ops:` for non-code; strawberry-app additionally uses `feat:` / `fix:` / etc.
5. **Same gitleaks ruleset dual-tracked** — source of truth in `strawberry-agents` (moved from `strawberry`), copy in `strawberry-app`. (Unchanged in spirit, new origin.)
6. **Agent sessions run from `~/Documents/Personal/strawberry-agents/`.** (Was `~/Documents/Personal/strawberry/`.) The sibling checkout of `strawberry-app` at `~/Documents/Personal/strawberry-app/` is unchanged. Per §4.4, agents do not `cd` between the two — each session scopes to one or the other.
7. **Plan promotion (`plan-promote.sh`) lives in `strawberry-agents`** and does not touch `strawberry-app`. (Same logic as app plan §7.6, new origin.)
8. **Discord relay** files issues in `strawberry-app` (unchanged).
9. **`architecture/cross-repo-workflow.md`** lives in `strawberry-agents` and documents all three repos. Created in strawberry-app plan Phase 5; extended in this plan's Phase A5.

### 7.3 Minimal private-infra branch protection profile

Referenced from R-agents-4. For `harukainguyen1411/strawberry-agents` main:

```json
{
  "required_status_checks": { "strict": false, "contexts": ["plan-frontmatter-lint"] },
  "enforce_admins": false,
  "required_pull_request_reviews": null,
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false
}
```

- Plans commit directly to main per CLAUDE.md rule 4 — no PR requirement.
- `plan-frontmatter-lint` is a lightweight CI workflow (to be added separately — **not in scope of this ADR**) that validates YAML frontmatter on files under `plans/`. If the workflow doesn't exist at cutover, leave `required_status_checks: null` and add it later.
- `allow_force_pushes: false` and `allow_deletions: false` are the non-negotiable floor. Everything else is recoverable.

---

## 6. Decisions (captured 2026-04-18 — yes to all Azir recommendations)

- **D1 Visibility:** Private.
- **D2 History strategy:** Preserve via `git filter-repo --invert-paths`. Caveat R-agents-1 accepted: SHAs in memory that reference dual-touch commits will rewrite; mitigated by 90-day archive (D5) + MEMORY.md footer.
- **D3 Owner account:** harukainguyen1411.
- **D4 Timing:** Back-to-back with strawberry-app migration, same session. strawberry-app Phase 0 completes first; both migrations branch from that base SHA snapshot.
- **D5 Duongntd/strawberry retention:** 90 days post-cutover, then archived (rename to `strawberry-archive` or delete — Duong decides at day-90 gate).
- **D6 Secrets:** `secrets/age-key.txt` local-only (gitignored). `secrets/encrypted/*.age` migrates to strawberry-agents.
- **D7 Hooks:** split by concern. Agent-infra hooks (secrets-guard, plan-gdoc-mirror if present, heartbeat invocations, memory-consolidate) to strawberry-agents. Code hooks (pre-push-tdd, pre-commit-unit-tests, pre-commit-artifact-guard) to strawberry-app. `pre-commit-secrets-guard.sh` + `install-hooks.sh` dual-tracked; strawberry-agents is source-of-truth for secrets-guard.
- **D8 Cross-repo convention:** 3-repo model. Plans in strawberry-agents, PRs in strawberry-app. Absolute URL permalinks both ways. Duongntd/strawberry archive gets a pinned README linking both active repos. Agent sessions scoped to one repo per session.
- **D9 Branch protection:** minimal for strawberry-agents — no force-push, no delete, zero review requirement, zero required checks. Plans commit direct to main per CLAUDE.md Rule 4.
- **D10 plan-frontmatter-lint:** DEFERRED. Not in migration scope. Ship strawberry-agents without it; add in a follow-up plan post-migration.

---

## 7. Acceptance criteria

Migration is complete when all are true:

- [ ] `harukainguyen1411/strawberry-agents` exists, is **private**, and has strawberry's agent-infra subtree at its tip.
- [ ] `git log --oneline` shows filtered history back to repo genesis (or, if `--invert-paths` surfaced too many empty merge commits, a clean-cut starting point noted in the migration commit message).
- [ ] `gitleaks detect --log-opts="--all"` on strawberry-agents shows zero real findings.
- [ ] Every file under `secrets/encrypted/` matches the pre-migration tree byte-for-byte (R-agents-2 check).
- [ ] `tools/decrypt.sh <NAME>` successfully resolves the filepath for every known secret name in the new checkout (no actual decryption required — path resolution only).
- [ ] Branch protection on strawberry-agents main matches §7.3 minimal profile.
- [ ] `CLAUDE.md` (root), `agents/evelynn/CLAUDE.md`, `architecture/git-workflow.md`, and `architecture/cross-repo-workflow.md` name the three-repo relationship.
- [ ] All active agents' `MEMORY.md` files have the pre-2026-04-19-SHA footer.
- [ ] A test plan can be promoted via `scripts/plan-promote.sh` in the new checkout without error (Drive mirror ping; `proposed/` → `approved/` move).
- [ ] `scripts/install-hooks.sh` installs the agent-infra hook bundle and secrets-guard fires on a synthetic violation.
- [ ] `Duongntd/strawberry` is read-only (archived or renamed) and no agent session uses it as origin.
- [ ] No orphan paths: every path that existed in `Duongntd/strawberry` as of the base SHA now lives in either `strawberry-agents` or `strawberry-app`, but not both (except §2.3 dual-tracked items).
- [ ] Strawberry-app plan §7 has been amended to reflect the three-repo model (not two).

After 90 days stable: Phase A6 executes, `Duongntd/strawberry` renamed to `strawberry-archive`.

---

## 8. Handoff notes

- **Ekko:** owns Phases A1-A2 and A4 (history filter, reference rewrite, working-tree swap). Run **after** the strawberry-app migration completes, or in parallel with its Phase 3-4 if Duong prefers — both require **separate scratch clones** (R-agents-5, D4).
- **Caitlyn:** owns Phases A3 and A5 (push, branch protection, agent-memory update).
- **Duong actions** (not delegable): §4.0 preflight repo creation; D1-D10 decisions captured before Phase A1; Phase A6 archive at T+90 days.
- **Azir (this session):** ADR only; no implementation. Follow-up ADR may be needed for `plan-frontmatter-lint` (D10) or for a richer branch-protection profile if D9 surfaces issues.
- **Cannot start until strawberry-app plan's Phase 0 completes** — both migrations share the same base SHA (post-dual-green-merge tip of `Duongntd/strawberry` main).
- **Task breakdown:** once Duong confirms D1-D10, hand to Kayn for task gates. Kayn's existing strawberry-app breakdown (in-progress) should be cross-referenced so that the two migrations don't duplicate executor assignments.
