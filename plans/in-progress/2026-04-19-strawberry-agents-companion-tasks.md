---
status: in-progress
owner: aphelios
date: 2026-04-19
title: Strawberry-agents companion migration — Task Breakdown
parent_adr: plans/approved/2026-04-19-strawberry-agents-companion-migration.md
sibling_tasks: plans/in-progress/2026-04-19-public-app-repo-migration-tasks.md
acceptance_gates: assessments/2026-04-18-migration-acceptance-gates.md
---

# Strawberry-agents companion migration — Task Breakdown

Executable task list for the approved companion ADR
(`plans/approved/2026-04-19-strawberry-agents-companion-migration.md`). Six
numbered phases match ADR §4 (Phase A0 preflight through Phase A6 at
T+90 days). Each task has an ID of the form `A<phase>.<step>`, a goal,
an owner, inputs/outputs, acceptance gate (tied to the extended
acceptance-criteria checklist at
`assessments/2026-04-18-migration-acceptance-gates.md` — AG-series gate
IDs of the form `A<phase>-G<n>` appended as the "strawberry-agents
companion gates" section at cutover-session), rollback point reference
(ADR §4.N rollback bullets), and prerequisite task IDs.

Repo shorthand used throughout:
- **strawberry** = `Duongntd/strawberry` (current canonical repo; becomes
  archive-only at cutover, renames to `strawberry-archive` at T+90 days per
  D5).
- **strawberry-app** = `harukainguyen1411/strawberry-app` (new public code
  repo; Kayn's sibling plan).
- **strawberry-agents** = `harukainguyen1411/strawberry-agents` (new
  **private** agent-infra repo — this plan's target).

---

## Team composition (coordinated with Kayn's sibling breakdown)

Owner assignments here are chosen to avoid double-booking any agent
against Kayn's strawberry-app tasks. Kayn's plan already has:
- **Ekko** — Phase 0 → Phase 4 + Phase 1/2 grep-sweep on strawberry-app
  (dual-green queue, squash filter, PR replay).
- **Viktor** — Phase 2 parametrization (Window B), Phase 3 push +
  secrets + branch-protection, Phase 5 agent-memory rewrites, Phase 6
  purge in strawberry-app.
- **Duong** — P0.0 preflight (D1-D5), P3.2 secret entry (D6), P3.7
  Firebase binding (D8), P3.8 red/green sign-off (D7), P6.0 7-day
  window (D9), P0.2 admin-merge sign-off if needed (D10).

To preserve serial discipline (one executor, one scratch clone, one
repo at a time) and to match each task's profile, this plan assigns:

- **Ekko** — owns Phases A1 and A4 (history filter via
  `git filter-repo --invert-paths` on a **separate** scratch clone at
  `/tmp/strawberry-agents-filter.git`; working-tree swap on Duong's
  machine). Ekko is the history-rewrite specialist in both plans; her
  A1/A4 slots are scheduled **after** her strawberry-app Phase 4 so the
  two scratch clones do not coexist in her session.
- **Viktor** — owns Phases A2, A3, and A5 (reference rewrite across
  the filtered tree; push + minimal branch protection + hook install;
  agent-memory MEMORY.md footer injection +
  `architecture/cross-repo-workflow.md` authoring). Matches his
  strawberry-app profile (refactor, push-provision, doc authoring).
  His A2/A3/A5 slots are scheduled **after** his strawberry-app Phase
  5/6 so he is serial across repos.
- **Duong** — owns Phase A0 preflight (D-agents-1 and D-agents-2 in §
  "Duong-blocking prerequisites" below), Phase A6 archive at T+90
  days, and any PAT re-mint / Firebase Console actions if surfaced.
- **Reviewers** — **Kayn** and **Jhin** on every PR across both
  repos. (Plans commit direct to main per Rule 4; the push to
  strawberry-agents main in A3.1 is not a PR but **is** reviewed by
  Kayn via post-push inspection.)

Azir's §8 handoff named Ekko + Caitlyn; Caitlyn is already busy with
the acceptance-gate checklist and its amendments, so Viktor picks up
the A2/A3/A5 workload.

**Formal TDD skipped for this migration** (parallel to strawberry-app ADR
§8 decision). Acceptance-criteria gates replace xfail tests. Every task's
"Acceptance gate" field names which AG-series gate in the amended
`assessments/2026-04-18-migration-acceptance-gates.md` it must satisfy.

---

## Duong-blocking prerequisites (summary)

These must be done by Duong before the dependent tasks can proceed.
Numbered `D-agents-N` to avoid collision with Kayn's D1-D10.

| Ref | Blocker | Blocks | Phase |
|-----|---------|--------|-------|
| D-agents-1 | Create empty **private** repo `harukainguyen1411/strawberry-agents` (no README/LICENSE/.gitignore initialized) — Console action per ADR §4.0 step 1. **Bundle with strawberry-app creation in the same Console session per D4** — both repos created in one sitting. | A3.1 | A0 |
| D-agents-2 | Confirm the fine-grained PAT minted in strawberry-app P3.3 has read/write scope **extended** to `harukainguyen1411/strawberry-agents` (same account owns both repos). If the existing PAT cannot be extended post-mint, Duong re-mints with both repos in scope. | A3.1 | A0 |
| D-agents-3 | Freeze plan-promote operations — no `proposed/` → `approved/` transitions until A5.5 commit lands. R-agents-6 mitigation. Duong announces freeze in Evelynn coordinator channel. | A1.1 | A0 |
| D-agents-4 | Sign off on the base SHA tag name (`migration-base-2026-04-19`) and confirm the strawberry-app migration Phase 0 has completed (P0.3 `git -C ... rev-parse origin/main` recorded in Caitlyn's journal). | A0.1 | A0 |
| D-agents-5 | After A4.2 fresh clone, confirm `secrets/age-key.txt` is copied from the archived local tree and agent session migrated to `~/Documents/Personal/strawberry-agents/`. | A4.3 | A4 |
| D-agents-6 | At T+90 days, decide whether to rename `Duongntd/strawberry` → `strawberry-archive` or delete entirely. ADR §6 D5. | A6.1 | A6 |

---

## Phase A0 — Preflight and base-SHA tag

Exit criterion: a single immutable base SHA on `Duongntd/strawberry` main is
tagged `migration-base-2026-04-19`; both scratch clones (strawberry-app's
and strawberry-agents's) derive from it. Plan-promote frozen.

### A0.1 — Capture and tag the migration base SHA

- **Owner:** Ekko (same agent who finishes strawberry-app P0.3 — she
  already has the frozen SHA in scope).
- **Inputs:** strawberry-app P0.3 output — the "frozen" strawberry main
  SHA recorded in the PR queue file + Caitlyn's journal; strawberry-app
  plan §4 Phase 0 cut-line.
- **Outputs:** lightweight (non-annotated) git tag
  `migration-base-2026-04-19` created locally and pushed to
  `origin` on `Duongntd/strawberry`:
  ```
  git -C /Users/duongntd99/Documents/Personal/strawberry tag \
      migration-base-2026-04-19 <FROZEN_SHA>
  git -C /Users/duongntd99/Documents/Personal/strawberry push \
      origin migration-base-2026-04-19
  ```
  `<FROZEN_SHA>` equals the value recorded in strawberry-app P0.3 —
  **not** a fresh `git rev-parse origin/main` (that could drift if
  anything slipped in between). Tag value is logged in Ekko's journal.
- **Acceptance gate:** satisfies **AG0-G1** — tag exists on origin;
  `git -C <repo> rev-parse migration-base-2026-04-19` returns the same
  SHA recorded in strawberry-app P0.3 / Caitlyn's journal. Precondition
  to **AG1-G1** (scratch clone from tagged SHA).
- **Rollback point:** ADR §4.1 "Rollback point: discard ..." — delete the
  tag locally and from origin; re-tag at a different SHA if Phase 0 is
  re-run. No downstream damage.
- **Blockers:** strawberry-app **P0.3** complete; D-agents-4.
- **Duong-in-loop:** confirms SHA via D-agents-4.

### A0.2 — Announce plan-promote freeze

- **Owner:** Ekko.
- **Inputs:** D-agents-3 Duong go-ahead.
- **Outputs:** message in Evelynn coordinator channel: "plan-promote
  frozen for strawberry-agents migration window; no proposed→approved
  transitions until A5.5 commit lands." Freeze window documented in
  `agents/ekko/journal/2026-04-*.md`.
- **Acceptance gate:** satisfies **AG0-G2** — freeze announcement
  timestamp in journal precedes A1.1 start time. Mitigates R-agents-6.
- **Rollback point:** none — announcement only; lift freeze in A5.5
  completion note.
- **Blockers:** D-agents-3.
- **Duong-in-loop:** acknowledges announcement.

---

## Phase A1 — History filter (fresh scratch clone, --invert-paths)

Exit criterion: a local `/tmp/strawberry-agents` checkout exists with
**preserved** history rooted at `migration-base-2026-04-19`, every public
path dropped via `git filter-repo --invert-paths`, gitleaks clean,
`secrets/encrypted/` byte-identical to pre-filter tree.

### A1.1 — Bare clone strawberry into a separate scratch path

- **Owner:** Ekko.
- **Inputs:** post-A0.1 tagged base SHA.
- **Outputs:** bare clone at **`/tmp/strawberry-agents-filter.git`**
  (distinct from strawberry-app's `/tmp/strawberry-filter.git` or
  `/tmp/strawberry-app-filter.git` — R-agents-5). Working checkout at
  `/tmp/strawberry-agents` derived from it. Both clones fetched from
  tag: `git clone --bare --branch main
  https://github.com/Duongntd/strawberry.git /tmp/strawberry-agents-filter.git`
  then `git -C /tmp/strawberry-agents-filter.git fetch origin
  refs/tags/migration-base-2026-04-19:refs/tags/migration-base-2026-04-19`.
  Working checkout reset to the tag to guarantee identical base.
- **Acceptance gate:** satisfies **AG1-G1** — `test -d
  /tmp/strawberry-agents-filter.git` succeeds; `git -C
  /tmp/strawberry-agents rev-parse HEAD` equals
  `migration-base-2026-04-19`. Agent `pwd` during this phase is **not**
  `/Users/duongntd99/Documents/Personal/strawberry` (R-agents-5 — the
  scratch-clone path-separation invariant).
- **Rollback point:** ADR §4.1 "discard `/tmp/strawberry-agents`, no
  remote changes".
- **Blockers:** A0.1, A0.2; **strawberry-app Phase 0 complete** (shared
  base SHA prerequisite).
- **Duong-in-loop:** no.

### A1.2 — Confirm `git-filter-repo` on PATH

- **Owner:** Ekko.
- **Inputs:** macOS host; `brew` (same binary used in strawberry-app
  P1.2).
- **Outputs:** `git filter-repo --version` succeeds; version ≥ 2.38.
  If strawberry-app P1.2 already installed it in the same session, this
  is a no-op smoke.
- **Acceptance gate:** satisfies **AG1-G2** — version print is ≥ 2.38.
- **Rollback point:** none (environmental).
- **Blockers:** A1.1.
- **Duong-in-loop:** no.

### A1.3 — Run `git filter-repo --invert-paths` to drop public paths

- **Owner:** Ekko.
- **Inputs:** `/tmp/strawberry-agents` checkout; ADR §2.1 moves table and
  §2.2 stays-out table; §4.1 step 3 filter-repo invocation.
- **Outputs:** filtered history produced by:
  ```
  cd /tmp/strawberry-agents && \
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
    --path scripts/windows/ \
    --path scripts/composite-deploy.sh \
    --path scripts/scaffold-app.sh \
    --path scripts/seed-app-registry.sh \
    --path scripts/health-check.sh \
    --path scripts/migrate-firestore-paths.sh \
    --path scripts/vps-setup.sh \
    --path scripts/deploy-discord-relay-vps.sh \
    --path scripts/setup-branch-protection.sh \
    --path scripts/verify-branch-protection.sh \
    --path scripts/setup-github-labels.sh \
    --path scripts/setup-discord-channels.sh \
    --path scripts/gh-audit-log.sh \
    --path scripts/gh-auth-guard.sh \
    --path scripts/hooks/pre-commit-unit-tests.sh \
    --path scripts/hooks/pre-push-tdd.sh \
    --path scripts/hooks/pre-commit-artifact-guard.sh
  ```
  History is **preserved**, not squashed (ADR §6 D2). Commits that
  were entirely in dropped paths are elided by filter-repo; commits
  that straddle kept/dropped content are retained with only the kept
  hunks. **Note:** filter-repo **rewrites SHAs of every touched
  commit** — expected and accepted (R-agents-1); mitigation is the
  90-day archive (D5) + A5.4 MEMORY.md footer.
- **Acceptance gate:** satisfies **AG1-G3** (no public paths remain in
  the scratch tree — same "LEAK:" loop-check as P1-G2 but over the
  public-side list); **AG1-G4** (history preserved — `git rev-list
  --count HEAD` in `/tmp/strawberry-agents` is **≫ 1** and traces
  back to repo genesis or to a clean-cut starting commit noted in
  Ekko's journal); **AG1-G5** (kept paths untouched — `scripts/
  plan-promote.sh`, `tools/decrypt.sh`, `CLAUDE.md`, `agents/`,
  `plans/`, `assessments/`, `secrets/encrypted/`, etc. all present).
- **Rollback point:** ADR §4.1 — discard `/tmp/strawberry-agents`, re-clone.
- **Blockers:** A1.2.
- **Duong-in-loop:** no.

### A1.4 — Verify `secrets/encrypted/` byte-identical to pre-filter

- **Owner:** Ekko.
- **Inputs:** `/tmp/strawberry-agents/secrets/encrypted/` and a
  reference tree from a fresh non-filtered clone at the tagged SHA
  (e.g. `/tmp/strawberry-agents-reference/secrets/encrypted/` obtained
  via `git clone ... --depth 1 --branch migration-base-2026-04-19
  /tmp/strawberry-agents-reference`).
- **Outputs:** `diff -r /tmp/strawberry-agents/secrets/encrypted/
  /tmp/strawberry-agents-reference/secrets/encrypted/` → empty output.
  Any diff is a filter-repo rename/drift bug (R-agents-2) — STOP and
  escalate.
- **Acceptance gate:** satisfies **AG1-G6** — diff output empty, byte-for-
  byte parity. Mitigates R-agents-2.
- **Rollback point:** ADR §4.1 — discard.
- **Blockers:** A1.3.
- **Duong-in-loop:** on-exception (if diff nonempty, Duong pages Evelynn).

### A1.5 — `tools/decrypt.sh` filepath-resolution smoke

- **Owner:** Ekko.
- **Inputs:** `/tmp/strawberry-agents` checkout; the known set of
  secret names (enumerated from `ls secrets/encrypted/*.age | sed
  's|.*/||; s|\.age$||'`).
- **Outputs:** for each secret `NAME`, invoke `tools/decrypt.sh NAME`
  in **path-resolution mode only** (do not actually decrypt — pass
  `--dry-run` if supported, else stop just before the `age -d`
  invocation). Every filepath under `secrets/encrypted/` referenced by
  `tools/decrypt.sh` resolves. No actual plaintext is read into context
  (Rule 6).
- **Acceptance gate:** satisfies **AG1-G7** — path resolution succeeds
  for every known secret name; ADR §7 criterion "tools/decrypt.sh
  <NAME> successfully resolves the filepath for every known secret
  name" ticks green.
- **Rollback point:** ADR §4.1 — discard.
- **Blockers:** A1.4.
- **Duong-in-loop:** no.

### A1.6 — Gitleaks on filtered full history

- **Owner:** Ekko.
- **Inputs:** `/tmp/strawberry-agents` after A1.3; pre-existing
  allowlist from
  `agents/camille/learnings/_migrated-from-pyke/2026-04-04-gitleaks-false-positives.md`.
- **Outputs:**
  ```
  gitleaks detect --source=/tmp/strawberry-agents \
    --log-opts="--all" --redact \
    --report-path=/tmp/gitleaks-agents.json
  ```
  `jq 'length' /tmp/gitleaks-agents.json` returns `0` (or only
  allowlisted entries). Agent memory sometimes pastes token-shaped
  strings as examples (ADR §4.1 step 4) — any real finding → STOP,
  rotate, amend filter.
- **Acceptance gate:** satisfies **AG1-G8** — `jq 'length'` returns `0`
  after allowlist filter. On exception, escalate to Evelynn + Duong.
- **Rollback point:** ADR §4.1 — discard.
- **Blockers:** A1.5.
- **Duong-in-loop:** on-exception.

---

## Phase A2 — Rewrite repo references inside the filtered tree

Exit criterion: every `Duongntd/strawberry` reference inside the kept
paths has been retargeted to the appropriate new repo (strawberry-agents
for agent-infra contexts, strawberry-app for code-PR contexts). One
atomic commit lands on top of the filtered history.

### A2.1 — Grep sweep in the filtered tree

- **Owner:** Viktor.
- **Inputs:** `/tmp/strawberry-agents` (post-A1.6); ADR §4.2 step 2
  expected-hits list.
- **Outputs:** complete grep report saved to
  `/tmp/migration-agents-ref-audit.md` — path + line number + snippet
  + category per hit. Categories:
  - `agent-infra-url` — retarget to `harukainguyen1411/strawberry-agents`
    (e.g. `CLAUDE.md`, `agents/evelynn/CLAUDE.md`, Drive-mirror
    back-references in `scripts/plan-publish.sh`, `scripts/_lib_gdoc.sh`,
    `architecture/plan-gdoc-mirror.md`, `architecture/git-workflow.md`).
  - `code-pr-url` — retarget to `harukainguyen1411/strawberry-app`
    (e.g. post-migration PR links in `agents/*/memory/MEMORY.md` that
    Kayn's P5.1 will also sweep on the strawberry side; here we only
    care about files that land in strawberry-agents).
  - `archive-permalink` — leave untouched (historical SHA permalink to
    `Duongntd/strawberry/commit/<sha>`; ADR §5 convention 3 keeps these
    as-is because post-migration they still resolve to the archive).
  - `transcript-historical` — leave untouched (transcripts under
    `agents/*/transcripts/` are records per ADR §2 — Kayn's P5.1 also
    leaves them alone).
  - `quoted-example` — illustrative block that names the repo on
    purpose; decide in-session whether to rewrite.
  Extensions covered: `*.sh`, `*.py`, `*.js`, `*.md`, `*.txt`, `*.yml`,
  `*.yaml`, `*.json`.
- **Acceptance gate:** satisfies **AG2-G1** — report exists and
  categorises every hit. Precondition to **AG2-G2** (post-rewrite
  grep-zero in `agent-infra-url` + `code-pr-url` categories).
- **Rollback point:** ADR §4.2 — discard report.
- **Blockers:** A1.6.
- **Duong-in-loop:** no.

### A2.2 — Rewrite agent-infra-URL references → strawberry-agents

- **Owner:** Viktor.
- **Inputs:** A2.1 report rows tagged `agent-infra-url`.
- **Outputs:** per-hit rewrite:
  `Duongntd/strawberry` → `harukainguyen1411/strawberry-agents` **only
  in agent-infra contexts** (Drive mirror, plan-publish, evelynn
  coordinator rule text). Expected files:
  - `CLAUDE.md` (root)
  - `agents/evelynn/CLAUDE.md`
  - `scripts/plan-publish.sh`
  - `scripts/plan-unpublish.sh`
  - `scripts/plan-fetch.sh`
  - `scripts/_lib_gdoc.sh`
  - `architecture/git-workflow.md`
  - `architecture/plan-gdoc-mirror.md`
  - any `agents/*/memory/MEMORY.md` entry in category `agent-infra-url`
    (rare — most memory entries are commit-SHA context which stays)
- **Acceptance gate:** satisfies **AG2-G2** (partial — zero hits for
  `Duongntd/strawberry` in files categorized `agent-infra-url`). Final
  A2-G2 closure happens after A2.3.
- **Rollback point:** ADR §4.2 — `git reset --hard HEAD` (not yet
  committed — see A2.4).
- **Blockers:** A2.1.
- **Duong-in-loop:** no.

### A2.3 — Rewrite code-PR references → strawberry-app

- **Owner:** Viktor.
- **Inputs:** A2.1 report rows tagged `code-pr-url`.
- **Outputs:** `github.com/Duongntd/strawberry/pull/<N>` →
  `github.com/harukainguyen1411/strawberry-app/pull/<N>` for every PR
  number that was opened post-base-SHA (i.e. during or after the
  strawberry-app migration). Pre-base-SHA PRs (historical) resolve
  against the archive — **leave untouched** (ADR §5 convention 3).
  **Coordination with Kayn:** Kayn's P5.1 does the same sweep on the
  **private strawberry** working tree; we do it on the filtered
  **strawberry-agents** tree. Since the base SHA is shared, the two
  sweeps operate on identical file content — outputs must agree.
- **Acceptance gate:** satisfies **AG2-G2** (complete — combined with
  A2.2, zero hits for `Duongntd/strawberry` across `agent-infra-url`
  and `code-pr-url` categories). `archive-permalink` + `transcript-
  historical` hits remain by design.
- **Rollback point:** ADR §4.2 — `git reset --hard HEAD`.
- **Blockers:** A2.1, A2.2.
- **Duong-in-loop:** no.

### A2.4 — Commit the retarget diff

- **Owner:** Viktor.
- **Inputs:** staged changes from A2.2 + A2.3.
- **Outputs:** single commit on `/tmp/strawberry-agents` main:
  `chore: retarget repo references to strawberry-agents and strawberry-app`.
  Commit body enumerates the files touched and links back to this
  task file.
- **Acceptance gate:** satisfies **AG2-G3** — `git -C
  /tmp/strawberry-agents log --oneline --grep="retarget"` returns ≥ 1
  commit; the commit sits on top of the filtered history (not within
  it — no history-edit surgery in A2).
- **Rollback point:** ADR §4.2 — `git reset --hard HEAD~1`, redo.
- **Blockers:** A2.3.
- **Duong-in-loop:** no.

---

## Phase A3 — Push, protect, install hooks

Exit criterion: `harukainguyen1411/strawberry-agents` is live and private
on GitHub, with minimal branch protection matching ADR §7.3, and the
agent-infra hook bundle installed locally.

### A3.1 — Push filtered tree to `harukainguyen1411/strawberry-agents`

- **Owner:** Viktor.
- **Inputs:** post-A2.4 scratch tree; empty remote at
  `github.com/harukainguyen1411/strawberry-agents` (D-agents-1);
  PAT with scope extended to both repos (D-agents-2).
- **Outputs:**
  ```
  cd /tmp/strawberry-agents && \
  git remote add origin https://github.com/harukainguyen1411/strawberry-agents.git && \
  git push -u origin main
  ```
  Remote `main` SHA matches local HEAD. Push uses the new PAT (never
  raw `age -d` — Rule 6); token resolution via `tools/decrypt.sh
  github-triage-pat` in a child process.
- **Acceptance gate:** satisfies **AG3-G1** (`gh repo view
  harukainguyen1411/strawberry-agents --json visibility,isPrivate`
  returns `"visibility":"PRIVATE"`, `"isPrivate":true`); **AG3-G2**
  (`gh api repos/harukainguyen1411/strawberry-agents/commits/main
  --jq .sha` equals `git -C /tmp/strawberry-agents rev-parse HEAD`);
  **AG3-G3** (history preserved — `gh api
  repos/harukainguyen1411/strawberry-agents/commits --paginate
  --jq 'length'` returns the same count as local `git rev-list
  --count HEAD`).
- **Rollback point:** ADR §4.3 — delete the remote repo via Console
  (Duong action); no downstream bindings to revert.
- **Blockers:** A2.4, D-agents-1, D-agents-2.
- **Duong-in-loop:** only for rollback.

### A3.2 — GitHub Actions audit on strawberry-agents

- **Owner:** Viktor.
- **Inputs:** ADR §4.3 step 2 — "audit in session; if heartbeat /
  memory-consolidate hooks run as GitHub Actions, provision
  `AGENT_GITHUB_TOKEN` only".
- **Outputs:** inventory of `.github/` content that survived the
  filter in A1.3 (private-infra workflows if any existed; most
  workflows were filtered out). If any surviving workflow requires a
  secret, provision only the minimal set (e.g. `AGENT_GITHUB_TOKEN`)
  via `gh secret set --repo harukainguyen1411/strawberry-agents`.
  Result logged in Viktor's journal.
- **Acceptance gate:** satisfies **AG3-G4** — either `gh secret list
  --repo harukainguyen1411/strawberry-agents --json name | jq
  'length'` equals `0` (no secrets needed — ADR §4.3 step 2 default
  case) **or** the provisioned set is exactly the audited-required
  set (no extras). D10 (`plan-frontmatter-lint`) is **DEFERRED** per
  ADR §6 — no provisioning needed.
- **Rollback point:** ADR §4.3 — delete the secrets via `gh secret
  delete`; harmless.
- **Blockers:** A3.1.
- **Duong-in-loop:** no.

### A3.3 — Apply minimal private-infra branch protection

- **Owner:** Viktor.
- **Inputs:** ADR §7.3 JSON profile (repeated here for convenience):
  ```json
  {
    "required_status_checks": null,
    "enforce_admins": false,
    "required_pull_request_reviews": null,
    "restrictions": null,
    "allow_force_pushes": false,
    "allow_deletions": false
  }
  ```
  Per ADR §6 D10, `plan-frontmatter-lint` is deferred — set
  `required_status_checks: null` at cutover.
- **Outputs:** branch protection applied to
  `harukainguyen1411/strawberry-agents` main via
  `gh api -X PUT /repos/harukainguyen1411/strawberry-agents/branches/main/protection
  --input <(cat <<'JSON' ... JSON)`. Verified by reading back:
  `gh api /repos/harukainguyen1411/strawberry-agents/branches/main/protection
  --jq '{force: .allow_force_pushes.enabled, delete:
  .allow_deletions.enabled}'` returns `{"force": false, "delete":
  false}`.
- **Acceptance gate:** satisfies **AG3-G5** — live rule matches §7.3
  minimal profile (no force-push, no delete, zero review requirement,
  zero required checks). The non-negotiable floor per ADR §7.3 last
  paragraph.
- **Rollback point:** ADR §4.3 — remove protection via `gh api -X DELETE`.
- **Blockers:** A3.1.
- **Duong-in-loop:** no.

### A3.4 — Smoke: `scripts/install-hooks.sh` in a scratch worktree

- **Owner:** Viktor.
- **Inputs:** `/tmp/strawberry-agents` checkout.
- **Outputs:** run `scripts/install-hooks.sh` — installs the
  agent-infra hook bundle (plan-gdoc-mirror, heartbeat,
  memory-consolidate, plus the dual-tracked secrets-guard +
  commit-prefix linter per ADR §2.3). Then stage a synthetic secrets
  violation (write a fake `AWS_SECRET_ACCESS_KEY=AKIA...` into a tmp
  file, `git add`, attempt `git commit`) — commit MUST be blocked by
  `pre-commit-secrets-guard.sh`. Clean up the synthetic file.
- **Acceptance gate:** satisfies **AG3-G6** — synthetic-violation
  commit fails with the secrets-guard error; non-violation commit
  succeeds. Feeds **AGM-G8** (secrets-guard dual-tracked
  byte-identical).
- **Rollback point:** none — smoke test in a discardable worktree.
- **Blockers:** A3.1.
- **Duong-in-loop:** no.

---

## Phase A4 — Working-tree swap (Duong's machine)

Exit criterion: `~/Documents/Personal/strawberry-agents/` is the active
agent-infra working tree; `~/Documents/Personal/strawberry/` is renamed
to `~/Documents/Personal/strawberry-archive-local/` (or deleted per
Duong's choice); `secrets/age-key.txt` carried forward.

### A4.1 — Archive the current local strawberry working tree

- **Owner:** Ekko (on Duong's machine, with Duong present).
- **Inputs:** `~/Documents/Personal/strawberry/` current state.
  **Precondition:** no uncommitted work anywhere under that tree
  (check `git status` across all worktrees; Rule 1 — never leave
  work uncommitted).
- **Outputs:** `mv ~/Documents/Personal/strawberry
  ~/Documents/Personal/strawberry-archive-local` (recommended default
  — 7-day grace period) **or** `rm -rf` if Duong prefers and has
  confirmed no uncommitted work remains. Record choice in Ekko's
  journal.
- **Acceptance gate:** satisfies **AG4-G1** — either the archive-
  local directory exists and is intact, or it has been deleted with a
  journal note; `~/Documents/Personal/strawberry/` no longer
  contains a git repo (`git -C ~/Documents/Personal/strawberry rev-
  parse HEAD` fails).
- **Rollback point:** ADR §4.4 — if the rename path was taken, `mv`
  back; if deletion, restore from Time Machine / cloud backup.
- **Blockers:** A3.4, D-agents-5 (Duong confirms readiness).
- **Duong-in-loop:** YES (supervises).

### A4.2 — Fresh clone strawberry-agents to canonical local path

- **Owner:** Ekko.
- **Inputs:** pushed `harukainguyen1411/strawberry-agents` from A3.1.
- **Outputs:**
  ```
  git clone https://github.com/harukainguyen1411/strawberry-agents.git \
      ~/Documents/Personal/strawberry-agents
  cd ~/Documents/Personal/strawberry-agents && \
      scripts/install-hooks.sh
  ```
  Fresh working tree; hooks installed (agent-infra bundle per A3.4).
- **Acceptance gate:** satisfies **AG4-G2** — `git -C
  ~/Documents/Personal/strawberry-agents remote get-url origin`
  returns the strawberry-agents URL; `ls
  ~/Documents/Personal/strawberry-agents/.git/hooks/pre-commit`
  shows the installed hook.
- **Rollback point:** ADR §4.4 — `rm -rf
  ~/Documents/Personal/strawberry-agents`; restore archive-local as
  canonical.
- **Blockers:** A4.1.
- **Duong-in-loop:** no.

### A4.3 — Copy `secrets/age-key.txt` to new checkout

- **Owner:** Ekko (supervises Duong's cp).
- **Inputs:** `~/Documents/Personal/strawberry-archive-local/secrets/age-key.txt`
  (if rename path was taken in A4.1) **or** Duong's backup copy.
- **Outputs:** `cp
  ~/Documents/Personal/strawberry-archive-local/secrets/age-key.txt
  ~/Documents/Personal/strawberry-agents/secrets/age-key.txt`. Verify
  gitignore matches:
  `grep -F 'secrets/age-key.txt'
  ~/Documents/Personal/strawberry-agents/.gitignore` returns a hit.
  **Never `cat` / `tools/decrypt.sh`-read the key into context** —
  Rule 6.
- **Acceptance gate:** satisfies **AG4-G3** — file exists at the new
  location (`test -f
  ~/Documents/Personal/strawberry-agents/secrets/age-key.txt`); `git
  status` inside the new checkout shows no untracked
  `secrets/age-key.txt` (gitignore intact). Smoke:
  `tools/decrypt.sh github-triage-pat` executes in a child process
  and returns non-empty (value never logged; Rule 6).
- **Rollback point:** ADR §4.4 — if copy fails, source is still in
  archive-local; retry.
- **Blockers:** A4.2; D-agents-5 Duong confirmation.
- **Duong-in-loop:** YES (cp is a local user action).

### A4.4 — Smoke: `scripts/plan-promote.sh` end-to-end dry-run

- **Owner:** Viktor.
- **Inputs:** post-A4.3 fresh checkout.
- **Outputs:** create a throwaway `plans/proposed/TEST-migration-
  smoke.md` (minimal YAML frontmatter); run `scripts/plan-promote.sh
  --to approved TEST-migration-smoke`. The script (a) unpublishes
  Drive doc, (b) moves file to `plans/approved/`, (c) rewrites
  `status: approved`, (d) commits, (e) pushes to
  `harukainguyen1411/strawberry-agents` main. Then revert the commit
  (`git revert HEAD`) and delete the test plan. No Drive-mirror
  crumbs left behind.
- **Acceptance gate:** satisfies **AG4-G4** — the end-to-end promote
  succeeds; revert succeeds; final `git status` is clean. Also
  satisfies ADR §7 criterion "A test plan can be promoted via
  scripts/plan-promote.sh in the new checkout without error".
- **Rollback point:** `git revert HEAD` (already in the procedure);
  plus Drive API retry if unpublish fails.
- **Blockers:** A4.3.
- **Duong-in-loop:** no.

---

## Phase A5 — Agent-memory + cross-repo doc update

Exit criterion: every active agent's `MEMORY.md` carries the pre-2026-04-
19-SHA footer; `CLAUDE.md` (root), `agents/evelynn/CLAUDE.md`,
`architecture/git-workflow.md`, `architecture/cross-repo-workflow.md`
name the three-repo relationship; `agent-network.md` references
`harukainguyen1411/strawberry-agents` as the new canonical agent-infra
origin.

Works on **strawberry-agents** (the new repo, now canonical). Runs in
parallel with Kayn's P5 on strawberry-app post-cutover, but each owner
touches disjoint repos — no coordination needed beyond a heads-up in
the coordinator channel.

### A5.1 — Rewrite post-migration PR links + coordinate with Kayn P5.1

- **Owner:** Viktor.
- **Inputs:** strawberry-agents main (A4.4 state); ADR §4.5 step 3.
- **Outputs:** across all `agents/*/memory/MEMORY.md` in
  strawberry-agents:
  - `github.com/Duongntd/strawberry/pull/<N>` → `github.com/
    harukainguyen1411/strawberry-app/pull/<N>` **only** for
    post-base-SHA PR numbers (same rule as A2.3 + Kayn's P5.1).
  - Pre-base-SHA PR links resolve against the archive; leave
    untouched.
  Transcripts under `agents/*/transcripts/` are NOT touched
  (historical records).
- **Acceptance gate:** satisfies **AG5-G1** (no post-migration
  `github.com/Duongntd/strawberry/pull/` references in `MEMORY.md`
  files) and **AG5-G2** (code-context slugs already handled in A2.2/
  A2.3; no regression here).
- **Rollback point:** ADR §4.5 — `git revert`.
- **Blockers:** A4.4.
- **Duong-in-loop:** no.

### A5.2 — Update core CLAUDE.md + architecture docs (three-repo)

- **Owner:** Viktor.
- **Inputs:** root `CLAUDE.md`, `agents/evelynn/CLAUDE.md`,
  `architecture/git-workflow.md`; ADR §5 conventions.
- **Outputs:** each file explicitly names all three repos and their
  roles:
  - `strawberry-agents` (private, agent brain, **current repo**) —
    plans, agents, assessments.
  - `strawberry-app` (public, code) — PRs, workflows, deploys.
  - `Duongntd/strawberry` (archive, 90-day retention, rename at
    T+90d per D5).
  Relationship is described with enough detail that a new agent
  reading CLAUDE.md understands which repo owns which artefact. No
  functional rule changes — §7.3 branch-protection, the dual-
  tracked items (§2.3), the plan-direct-to-main invariant (Rule 4)
  all stay as-is.
- **Acceptance gate:** satisfies **AG5-G3** — each of the three
  files mentions `strawberry-agents`, `strawberry-app`, and
  `strawberry` (archive) ≥ 1 time; role distinction present in each.
- **Rollback point:** ADR §4.5 — `git revert`.
- **Blockers:** A5.1.
- **Duong-in-loop:** no.

### A5.3 — Author / extend `architecture/cross-repo-workflow.md`

- **Owner:** Viktor.
- **Inputs:** ADR §5 nine conventions; Kayn's P5.3 output if landed on
  strawberry (note: Kayn's version lives on strawberry and
  documents a two-repo model; this version on strawberry-agents
  documents the **three-repo** model and supersedes).
- **Outputs:** `architecture/cross-repo-workflow.md` in
  strawberry-agents (either new file if filter dropped it, or an
  extension of the file Kayn authored on strawberry — confirmed in-
  session). Contents:
  1. Plans live in `strawberry-agents`. PRs live in
     `strawberry-app`. Permalinks both directions.
  2. Commit-prefix rules (unchanged).
  3. Gitleaks ruleset source-of-truth in strawberry-agents.
  4. Agent sessions run from
     `~/Documents/Personal/strawberry-agents/`; sibling
     `~/Documents/Personal/strawberry-app/` is separate — no `cd`
     between them per session.
  5. `plan-promote.sh` lives in strawberry-agents.
  6. Discord relay files issues in strawberry-app.
  7. Archive (`Duongntd/strawberry`) references: §5 convention 3 —
     90-day window, then `strawberry-archive` indefinitely.
  8. Pinned archive README (A5.6) linking to both new repos.
- **Acceptance gate:** satisfies **AG5-G4** — file exists; `grep -c
  'strawberry-agents' architecture/cross-repo-workflow.md` ≥ 5;
  `grep -c 'strawberry-app' architecture/cross-repo-workflow.md` ≥
  5; `grep -c 'archive\|Duongntd/strawberry'
  architecture/cross-repo-workflow.md` ≥ 1.
- **Rollback point:** ADR §4.5 — `git revert`.
- **Blockers:** A5.2.
- **Duong-in-loop:** no.

### A5.4 — Inject pre-2026-04-19-SHA footer into all MEMORY.md files

- **Owner:** Viktor.
- **Inputs:** `agents/*/memory/MEMORY.md` across every active agent
  directory (excludes `agents/_retired/**`).
- **Outputs:** append the following footer to each active MEMORY.md
  (idempotent — skip files that already carry the footer):
  ```markdown
  ---

  > Commit SHAs prior to 2026-04-19 resolve against
  > `https://github.com/Duongntd/strawberry` (archive, 90-day
  > retention; after 2026-07-18 renamed to `strawberry-archive`).
  ```
  List of active agents to footer (per
  `ls agents/ | grep -vE '_retired|memory|transcripts|health'`): see
  §"Agent-assignment map" below (same enumeration).
- **Acceptance gate:** satisfies **AG5-G5** — for every active agent
  `<A>`, `grep -c '2026-04-19'
  agents/<A>/memory/MEMORY.md` ≥ 1 AND `grep -c 'Duongntd/strawberry'
  agents/<A>/memory/MEMORY.md` ≥ 1 (both constraints from the
  footer). Mitigates R-agents-1.
- **Rollback point:** ADR §4.5 — `git revert` (one commit carries
  all footers — see A5.7).
- **Blockers:** A5.3.
- **Duong-in-loop:** no.

### A5.5 — Update `agents/memory/agent-network.md` + core MEMORY indexes

- **Owner:** Viktor.
- **Inputs:** `agents/memory/agent-network.md`, any other shared
  memory indexes that cite the canonical repo URL.
- **Outputs:** references to "the Strawberry repo" /
  "Duongntd/strawberry" as the canonical agent-infra origin are
  retargeted to `harukainguyen1411/strawberry-agents`. Historical
  citations (transcripts, closed-out learnings) are not touched.
- **Acceptance gate:** satisfies **AG5-G6** — `grep -c
  'harukainguyen1411/strawberry-agents'
  agents/memory/agent-network.md` ≥ 1; no active (non-historical)
  `Duongntd/strawberry` mention remains as "canonical origin"
  language in shared memory files. Also lifts the D-agents-3
  plan-promote freeze — announce in coordinator channel.
- **Rollback point:** ADR §4.5 — `git revert`.
- **Blockers:** A5.4.
- **Duong-in-loop:** no.

### A5.6 — Add pinned README to `Duongntd/strawberry` archive

- **Owner:** Duong (single-file commit; agents assist with text).
- **Inputs:** Duong's `Duongntd/strawberry` (still the live origin
  until Phase A6). This task is an exception to Rule 11 only in
  that the commit lands on a repo the agent system is migrating
  away from — still follows `chore:` prefix; no rebase; direct to
  main per Rule 4.
- **Outputs:** top-level `README.md` on `Duongntd/strawberry` main
  replaced (or created if absent) with a short pinned message:
  > # Strawberry (archive)
  >
  > This repository has migrated. Active work lives at:
  > - **Code:** https://github.com/harukainguyen1411/strawberry-app
  >   (public)
  > - **Agent brain:** https://github.com/harukainguyen1411/strawberry-agents
  >   (private)
  >
  > `Duongntd/strawberry` is retained in read-only mode for
  > 90 days (through 2026-07-18). After that it will be renamed
  > to `strawberry-archive` and archived.
  >
  > Agent memory files cite commit SHAs against this repo —
  > those references continue to resolve here through the
  > 90-day window and against the renamed archive thereafter.
  Commit: `chore: aphelios migration — pin archive README with
  redirect to strawberry-app and strawberry-agents`.
- **Acceptance gate:** satisfies **AG5-G7** — `gh api
  repos/Duongntd/strawberry/contents/README.md --jq .content |
  base64 -d | grep -c 'strawberry-app'` ≥ 1 AND `... | grep -c
  'strawberry-agents'` ≥ 1 AND `... | grep -c '90 days\|2026-07-
  18'` ≥ 1.
- **Rollback point:** revert the commit on `Duongntd/strawberry`
  main (still writable during the 90-day window).
- **Blockers:** A5.5.
- **Duong-in-loop:** YES (repo is under Duong's account).

### A5.7 — Commit the migration batch to strawberry-agents

- **Owner:** Viktor.
- **Inputs:** A5.1 + A5.2 + A5.3 + A5.4 + A5.5 staged.
- **Outputs:** single commit on strawberry-agents main:
  `chore: aphelios migration — update agent memory and architecture
  docs for three-repo split`. Direct push to main per Rule 4 (plans
  commit direct; this is doc-only, same treatment). Kayn reviews
  the commit post-push.
- **Acceptance gate:** satisfies **AG5-G8** — `git -C
  ~/Documents/Personal/strawberry-agents log --oneline
  --grep="aphelios migration — update agent memory"` returns ≥ 1
  commit dated on/after 2026-04-19.
- **Rollback point:** ADR §4.5 — `git revert`.
- **Blockers:** A5.1, A5.2, A5.3, A5.4, A5.5.
- **Duong-in-loop:** no.

---

## Phase A6 — Archive (T+90 days, Duong action)

Exit criterion: `Duongntd/strawberry` is renamed and archived; no active
agent origin points at it.

### A6.1 — 90-day stability watch

- **Owner:** Duong (Evelynn maintains a lightweight calendar entry).
- **Inputs:** A5.7 timestamp (cutover + 90 days =
  2026-07-18).
- **Outputs:** 90-day watch during which strawberry-agents operates as
  the canonical agent-infra repo with no reverts, no
  unrecoverable memory corruption, and no detectable dependency on
  Duongntd/strawberry for non-archive reads. Optional lightweight
  status checkpoints at T+30, T+60.
- **Acceptance gate:** satisfies **AG6-G1** — `date -u +%s` minus
  A5.7 cutover timestamp ≥ `90 * 86400` seconds; no reverts of
  A5.7 recorded; no incident reports filed against
  strawberry-agents during window.
- **Rollback point:** ADR §4.6 — un-archive (GitHub allows); rename
  back. Phase A6 is the only pseudo-irreversible step.
- **Blockers:** A5.7; D-agents-6 90-day sign-off.
- **Duong-in-loop:** YES.

### A6.2 — Rename `Duongntd/strawberry` → `strawberry-archive` + archive flag

- **Owner:** Duong (Console action).
- **Inputs:** `github.com/Duongntd/strawberry/settings`.
- **Outputs:** (1) rename repo to `strawberry-archive` via
  Settings → Rename. (2) apply Archive flag via Settings → Archive
  this repository. (3) confirm all MEMORY.md footers (from A5.4)
  still read correctly — GitHub auto-redirects old URLs to the
  renamed repo, so pre-footer SHAs continue resolving.
- **Acceptance gate:** satisfies **AG6-G2** — `gh api
  /repos/Duongntd/strawberry-archive --jq '.archived'` returns
  `true` (Console may redirect the URL); `gh api
  /repos/Duongntd/strawberry --jq .message` returns a rename-
  redirect notice or 404-equivalent; no agent session has
  `Duongntd/strawberry.git` as `origin` (spot-check via a grep over
  live agent working trees).
- **Rollback point:** ADR §4.6 — rename back + un-archive within
  GitHub's retention window.
- **Blockers:** A6.1.
- **Duong-in-loop:** YES.

---

## Phase A7 — Orphan-path sentinel (final cross-check)

Exit criterion: every file that existed at `Duongntd/strawberry`@
`migration-base-2026-04-19` is accounted for in **exactly one** of
strawberry-app, strawberry-agents, or the explicit retired-at-migration
list. No orphans; no duplicates outside §2.3 dual-tracked items.

### A7.1 — Build the three-way manifest

- **Owner:** Viktor.
- **Inputs:**
  - `migration-base-2026-04-19` tree from a reference clone.
  - `harukainguyen1411/strawberry-app` main tree (post-P6.1
    purge — "code at rest" state).
  - `harukainguyen1411/strawberry-agents` main tree (post-A5.7 —
    "agent brain at rest" state).
- **Outputs:** three manifest files under
  `/tmp/migration-orphan-check/`:
  ```
  /tmp/migration-orphan-check/base.txt          # git ls-tree -r migration-base-2026-04-19
  /tmp/migration-orphan-check/app.txt           # gh api .../git/trees/main?recursive=1 over strawberry-app
  /tmp/migration-orphan-check/agents.txt        # same over strawberry-agents
  /tmp/migration-orphan-check/retired.txt       # explicit allowlist — files dropped in §2.2 stay-out AND §2.2 public-only scripts that Kayn's P1.5 pruned; see §"Retired-at-migration allowlist" below
  ```
  Sorted, deduped.
- **Acceptance gate:** satisfies **AG7-G1** — all four manifest files
  exist; each is non-empty; base.txt line count equals `git ls-tree
  -r migration-base-2026-04-19 | wc -l`.
- **Rollback point:** re-run; idempotent.
- **Blockers:** A5.7, strawberry-app P6.1.
- **Duong-in-loop:** no.

### A7.2 — Orphan sentinel diff

- **Owner:** Viktor.
- **Inputs:** A7.1 manifests.
- **Outputs:** for each path `p` in base.txt, verify:
  - `p` appears in `app.txt` XOR `p` appears in `agents.txt`, OR
  - `p` is listed in `retired.txt`, OR
  - `p` is one of the §2.3 dual-tracked entries (`scripts/hooks/pre-
    commit-secrets-guard.sh`, `scripts/install-hooks.sh`,
    `.gitignore`, `tools/decrypt.sh`, commit-prefix linter) — **these
    MAY appear in both, by design**.
  Script:
  ```
  comm -23 /tmp/migration-orphan-check/base.txt \
           <(sort -u /tmp/migration-orphan-check/app.txt \
                    /tmp/migration-orphan-check/agents.txt \
                    /tmp/migration-orphan-check/retired.txt)
  ```
  Output must be empty (every base-tree path accounted for). Also
  verify no-duplicate:
  ```
  comm -12 /tmp/migration-orphan-check/app.txt \
           /tmp/migration-orphan-check/agents.txt \
  | grep -vFf <(echo -e \
    "scripts/hooks/pre-commit-secrets-guard.sh\nscripts/install-hooks.sh\n.gitignore\ntools/decrypt.sh")
  ```
  Output must be empty (no accidental duplicates outside the
  dual-tracked set).
- **Acceptance gate:** satisfies **AG7-G2** — both `comm` commands
  return empty output. Any nonempty output is an orphan or illicit
  duplicate — STOP and file an incident, do not proceed to A6 until
  resolved. This is the **final migration-complete gate** across
  both plans.
- **Rollback point:** if orphans surface, the fix is surgical — add
  the missing path to whichever repo should own it, via a targeted
  commit. The migration does not unwind.
- **Blockers:** A7.1.
- **Duong-in-loop:** on-exception.

#### Retired-at-migration allowlist

Entries expected in `/tmp/migration-orphan-check/retired.txt`
(contributing to AG7-G2 completeness). Populated by Viktor at A7.1
runtime from ADR §2.2 cross-reference + Kayn's P1.5 prune list:

- `strawberry-b14/` (entire subtree — pre-existing untracked dir per
  `git status` at session start; retired intentionally)
- `strawberry.pub/` (pre-existing untracked dir; retired)
- `apps/private-apps/` **except** `apps/private-apps/bee-worker`
  (retired sibling apps that didn't move per strawberry-app ADR §8
  decision 6)
- Any ADR §2.2-noted path that neither plan kept (finalized in-
  session — the list is short; expect < 10 entries).

---

## Agent-assignment map

| Task | Owner | Repo in play | Duration est. |
|------|-------|--------------|---------------|
| A0.1 | Ekko | Duongntd/strawberry | 5 min |
| A0.2 | Ekko | — (coordinator channel) | 2 min |
| A1.1 | Ekko | /tmp/strawberry-agents | 5 min |
| A1.2 | Ekko | local env | 2 min |
| A1.3 | Ekko | /tmp/strawberry-agents | 15 min |
| A1.4 | Ekko | /tmp/strawberry-agents | 5 min |
| A1.5 | Ekko | /tmp/strawberry-agents | 5 min |
| A1.6 | Ekko | /tmp/strawberry-agents | 10 min |
| A2.1 | Viktor | /tmp/strawberry-agents | 10 min |
| A2.2 | Viktor | /tmp/strawberry-agents | 10 min |
| A2.3 | Viktor | /tmp/strawberry-agents | 10 min |
| A2.4 | Viktor | /tmp/strawberry-agents | 3 min |
| A3.1 | Viktor | strawberry-agents | 5 min |
| A3.2 | Viktor | strawberry-agents | 5 min |
| A3.3 | Viktor | strawberry-agents | 5 min |
| A3.4 | Viktor | /tmp/strawberry-agents | 10 min |
| A4.1 | Ekko + Duong | local Duong machine | 5 min |
| A4.2 | Ekko | local Duong machine | 5 min |
| A4.3 | Ekko + Duong | local Duong machine | 3 min |
| A4.4 | Viktor | ~/Documents/Personal/strawberry-agents | 10 min |
| A5.1 | Viktor | strawberry-agents | 10 min |
| A5.2 | Viktor | strawberry-agents | 10 min |
| A5.3 | Viktor | strawberry-agents | 15 min |
| A5.4 | Viktor | strawberry-agents | 15 min |
| A5.5 | Viktor | strawberry-agents | 5 min |
| A5.6 | Duong | Duongntd/strawberry (archive) | 5 min |
| A5.7 | Viktor | strawberry-agents | 3 min |
| A6.1 | Duong | — (calendar watch, 90 days) | 90d |
| A6.2 | Duong | Duongntd/strawberry (Console) | 5 min |
| A7.1 | Viktor | cross-repo | 10 min |
| A7.2 | Viktor | cross-repo | 10 min |

Active-agent footer-injection list (for A5.4): `aphelios`, `azir`,
`caitlyn`, `camille`, `ekko`, `evelynn`, `heimerdinger`, `irelia`,
`jayce`, `jhin`, `kayn`, `lissandra`, `lulu`, `lux`, `neeko`, `pyke`,
`rakan`, `seraphine`, `shen`, `skarner`, `vex`, `vi`, `viktor`,
`yuumi`. Exclude `_retired`, `memory` (shared index dir),
`transcripts` (shared archive), `health` (non-agent). 24 active
agents — Viktor confirms final list in-session against
`ls /Users/duongntd99/Documents/Personal/strawberry/agents/` at the
time A5.4 runs.

**Reviewers:** Kayn + Jhin on every PR and every post-push inspection
across both migrations. This plan produces **no PRs** in
strawberry-agents (plans commit direct to main per Rule 4); Kayn +
Jhin review the direct-to-main commits post-push.

---

## Dispatch order — parallelism and critical path

### Strictly sequential spine (critical path)

```
[Kayn sibling plan's P0 complete — base SHA frozen]
        ↓
A0.1 → A0.2
        ↓
A1.1 → A1.2 → A1.3 → A1.4 → A1.5 → A1.6
        ↓
A2.1 → { A2.2, A2.3 } (parallelisable — Window A) → A2.4
        ↓
A3.1 → { A3.2, A3.3, A3.4 } (parallelisable — Window B)
        ↓
A4.1 → A4.2 → A4.3 → A4.4
        ↓
A5.1 → A5.2 → A5.3 → A5.4 → A5.5 → A5.6 → A5.7
        ↓
A7.1 → A7.2    (also awaits Kayn P6.1)
        ↓
[T+90 days]
        ↓
A6.1 → A6.2
```

### Parallel windows

**Window A — Phase A2 reference rewrites (after A2.1 report lands):**
- `A2.2` — agent-infra-URL rewrites (CLAUDE.md, plan-publish.sh,
  etc.)
- `A2.3` — code-PR URL rewrites (post-migration PR links)

Both owned by Viktor, touching disjoint file subsets; can land as
two separate staged edits before the single A2.4 commit.

**Window B — Phase A3 push + protect + hooks (after A3.1 succeeds):**
- `A3.2` — secrets audit + optional provisioning
- `A3.3` — branch protection
- `A3.4` — hook install smoke

All three touch different GitHub/filesystem surfaces and are
independent once the remote exists. Viktor fans out in a single
session.

### Not parallelisable — hard serial points

- **strawberry-app Phase 0 → A0.1** is hard serial: the base SHA is
  the shared input to both filters (ADR §4 piggyback-decision).
- **Ekko's strawberry-app Phase 4 completion → A1.1** is hard serial:
  R-agents-5 forbids concurrent filter-repo runs on overlapping
  scratch state, and Ekko is the single executor — she finishes her
  strawberry-app Window A/Phase 4 before launching A1 here. Viktor's
  strawberry-app Phase 5 + 6 work runs **before** his A2/A3/A5 slots
  here.
- **A1.3 → A1.4 → A1.6** is hard serial: byte-identity check
  precedes gitleaks (because if A1.4 fails, A1.6's scan is
  meaningless).
- **A2.4 → A3.1** is hard serial: the retarget commit must land in
  scratch before the push, otherwise the first remote main carries
  stale references.
- **A3.4 → A4.1** is hard serial: hook install must succeed in a
  scratch worktree before Duong's canonical local tree is swapped.
- **A4.3 → A4.4** is hard serial: plan-promote smoke requires the
  age-key in place.
- **A5.7 → A7.1** is hard serial: the orphan sentinel runs against
  the post-A5.7 agent tree (otherwise A5.2/A5.3 additions register
  as false orphans).
- **Kayn P6.1 → A7.1** is hard serial (cross-plan): the sentinel
  compares against strawberry-app's post-purge state; if purge
  hasn't run, apps/dashboards/workflows surface as double-presence
  rather than single-presence, breaking AG7-G2.
- **A7.2 → A6.1** is hard serial: the 90-day watch doesn't start
  until orphan sentinel is green.

### Owner-concurrent schedule (happy path)

Runs **after** strawberry-app Phases 0-6 on Duong's session timeline.
"T_app_end" = strawberry-app P3.9 green prod deploy completion
(sibling plan's T4 + 30m). `T0_agents` = T_app_end for the A0-A5
burst; A6 is a 90-day-later event; A7 sits between A5.7 and the
90-day wait.

| Clock (from T0_agents) | Ekko | Viktor | Duong |
|------------------------|------|--------|-------|
| T0 − 20m (overlap w/ Kayn P4/P5) | standby | standby | D-agents-1/2/3 preflight |
| T0 | A0.1 → A0.2 | standby | — |
| T0 + 10m | A1.1 → A1.6 | standby | on-exception |
| T0 + 50m | standby | A2.1 → A2.4 | — |
| T0 + 90m | standby | A3.1 → A3.4 (Window B) | — |
| T0 + 115m | A4.1 → A4.3 | standby | supervises A4 |
| T0 + 130m | standby | A4.4 | — |
| T0 + 140m | standby | A5.1 → A5.5 | — |
| T0 + 200m | standby | A5.7 (after A5.6) | A5.6 pinned README |
| T0 + 215m | standby | A7.1 → A7.2 (needs Kayn P6.1 — likely T+7d later) | — |
| T0 + 7d | standby | A7.1 → A7.2 executes when P6.1 lands | — |
| T0 + 90d | — | — | A6.1 → A6.2 |

Note: Phase A7 **gates on Kayn's P6.1** (strawberry-app purge). Kayn's
P6.0 is a 7-day stability window that precedes P6.1; A7 therefore
realistically runs 7 days after cutover, not immediately after A5.7.
A5.7 itself can close out on cutover day (leaving A7 as a scheduled
follow-up), and the migration is **functionally** complete at A5.7.
A7 is the **final correctness gate**.

---

## Acceptance-gate cross-reference

The strawberry-agents companion gates (AG-series) are appended to
`assessments/2026-04-18-migration-acceptance-gates.md` under a new
section `## strawberry-agents companion gates (AG-series)` —
amendment committed alongside this task file per session protocol.
This table maps each task ID to the gates it must satisfy on success
(✓ = primary satisfier; F = feeds a migration-complete gate (AGM-*);
— = no dedicated gate, precondition for a downstream one).

| Task | Gates satisfied | Feeds |
|------|-----------------|-------|
| A0.1 | AG0-G1 ✓ | |
| A0.2 | AG0-G2 ✓ | |
| A1.1 | AG1-G1 ✓ | |
| A1.2 | AG1-G2 ✓ | |
| A1.3 | AG1-G3 ✓, AG1-G4 ✓, AG1-G5 ✓ | AGM-G3 |
| A1.4 | AG1-G6 ✓ | |
| A1.5 | AG1-G7 ✓ | AGM-G5 |
| A1.6 | AG1-G8 ✓ | AGM-G4 |
| A2.1 | precondition to AG2-G1, AG2-G2 | |
| A2.2 | contributes to AG2-G2 (agent-infra URL subset) | |
| A2.3 | contributes to AG2-G2 (code-PR URL subset) | |
| A2.4 | AG2-G3 ✓ | |
| A3.1 | AG3-G1 ✓, AG3-G2 ✓, AG3-G3 ✓ | AGM-G1, AGM-G2 |
| A3.2 | AG3-G4 ✓ | |
| A3.3 | AG3-G5 ✓ | AGM-G6 |
| A3.4 | AG3-G6 ✓ | AGM-G8 |
| A4.1 | AG4-G1 ✓ | |
| A4.2 | AG4-G2 ✓ | |
| A4.3 | AG4-G3 ✓ | |
| A4.4 | AG4-G4 ✓ | AGM-G9 |
| A5.1 | AG5-G1 ✓, AG5-G2 ✓ | |
| A5.2 | AG5-G3 ✓ | AGM-G7 |
| A5.3 | AG5-G4 ✓ | AGM-G7 |
| A5.4 | AG5-G5 ✓ | |
| A5.5 | AG5-G6 ✓ | |
| A5.6 | AG5-G7 ✓ | |
| A5.7 | AG5-G8 ✓ | |
| A6.1 | AG6-G1 ✓ | |
| A6.2 | AG6-G2 ✓ | |
| A7.1 | AG7-G1 ✓ | |
| A7.2 | AG7-G2 ✓ | AGM-G10 |

---

## Rollback summary

ADR §4 per-phase rollback points, condensed. A migration that
red-flags before **A3.1 push** can be fully discarded (no remote
changes). After A3.1, rollback is surgical (delete remote repo via
Console) but still clean. After A4.1 (local tree archived or
deleted), rollback requires restoring from archive-local. After A5.7,
the migration is functionally complete; rollback becomes "operate on
the new repo, revert specific commits" rather than "undo the
migration". A6 is pseudo-irreversible beyond GitHub's rename/archive
retention window.

| Phase | Remote surface to undo | Local surface to undo |
|-------|------------------------|----------------------|
| A0 | Delete tag from origin | — |
| A1 | — (scratch only) | `rm -rf /tmp/strawberry-agents*` |
| A2 | — (scratch only) | `git reset --hard HEAD~N` |
| A3 | Delete `harukainguyen1411/strawberry-agents` via Console | — |
| A4 | Delete remote repo | Restore archive-local to `~/Documents/Personal/strawberry` |
| A5 | `git revert` A5.7 commit | — |
| A6 | Un-archive + rename back (within GitHub retention) | — |
| A7 | surgical per-path fix commit | — |

---

## Blockers carried forward (open items to resolve at dispatch)

1. **Does the existing strawberry-app PAT extend to strawberry-agents?**
   — D-agents-2 expects yes (same account, one mint); confirm at
   A0 preflight; if no, Duong re-mints and Viktor re-encrypts at
   `secrets/encrypted/github-triage-pat.txt.age` in strawberry-agents
   (Kayn's P3.3 encrypted-blob path on the private repo side).
2. **Will Kayn's P5.3 author `cross-repo-workflow.md` in a two-repo
   flavour first?** — A5.3 expects either to supersede that file or
   to merge into it; Viktor confirms in-session which repo hosts the
   doc at A5.3 start. Per ADR §5 convention 9, the canonical copy
   lives in strawberry-agents.
3. **Any `.github/workflows/` surviving the filter?** — A3.2
   expects the answer to be "none that need secrets". If the audit
   surfaces a heartbeat / memory-consolidate GitHub Action that
   *does* need `AGENT_GITHUB_TOKEN`, provision at A3.2; otherwise no
   secrets on strawberry-agents.
4. **Retired-at-migration allowlist finalization** — A7.2 depends on
   the explicit list; Viktor confirms at A7.1 runtime against both
   ADRs' §2.2 cross-references and Kayn's P1.5 prune log.

These open items are **non-blocking at plan time** — all have
in-session resolutions. The migration proceeds along the happy-path
sequence above; blockers are handled by their named owners as they
surface.
