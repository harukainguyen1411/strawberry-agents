---
title: Memory audit — 2026-04-18
status: needs-reconciliation
auditor: orianna
created: 2026-04-18
repos_checked:
  - Duongntd/strawberry@0774d8d
  - harukainguyen1411/strawberry-app@checkout-absent
---

## Summary

- Files scanned: 295 (`agents/*/memory/**`, `agents/*/learnings/**`, `agents/memory/**`; excludes `agents/orianna/prompts/**`).
- Path-shaped claims extracted from backtick spans and fenced blocks: 608.
- Block-severity findings: 15 (active-agent files referencing genuinely-missing paths).
- Warn-severity findings: 53 (50 plan-promotion drift + 2 retired-agent artifacts + 1 cross-repo checkout-absent).
- Info-severity findings: 4 (extraction artifacts + retired-directory pattern notes).

**Cross-repo note:** the `strawberry-app` checkout is absent at
`~/Documents/Personal/strawberry-app/`, so 75 extracted `apps/**`,
`dashboards/**`, and `.github/workflows/**` tokens could not be verified against
`origin/main`. Recorded as a single top-level **warn** (see Warn #1).

**Retired-agent note:** 25 stale path references live under `agents/_retired/*`
(lux-frontend-sonnet, syndra, swain, pyke, shen, reksai, bard, fiora,
lissandra, ornn, katarina, poppy). These files are intentionally frozen
historical artifacts and are reported as **warn**, not block — they are not
load-bearing for any current workflow.

## Block findings

Active-agent memory / learnings files that cite paths which do not exist under
any route in this repo. These are `block` under the strict-default rule
(contract §4) because a downstream reader could act on them.

1. `agents/memory/agents-table.md` — **`agents/akali/`** — anchor attempted: `test -e agents/akali/` → miss. Akali's definition lives at `.claude/agents/akali.md`; no per-agent directory has been scaffolded yet. Proposed fix: update the table to cite `.claude/agents/akali.md`, or create `agents/akali/{memory,learnings}/` skeletons.
2. `agents/camille/learnings/2026-04-18-billing-block-failure-signature.md` — **`architecture/operability.md`** — miss. No `architecture/operability.md` exists. Proposed fix: either land the doc or rewrite the reference to the actual operability source (e.g. the deployment-pipeline plan).
3. `agents/ekko/learnings/2026-04-19-orianna-o4-memory-audit.md` — **`scripts/migrate-hetzner-to-gce.sh`** — miss. Script was never committed. Proposed fix: remove the reference or anchor to the plan that *proposes* the migration (mark as speculative).
4. `agents/orianna/learnings/2026-04-19-o4-tdd-stale-seed.md` — **`scripts/migrate-hetzner-to-gce.sh`** — same as #3.
5. `agents/evelynn/learnings/2026-04-08-roster-vs-harness-reality.md` — **`agents/roster.md`** — miss. The roster lives at `agents/memory/agent-network.md` and `agents/memory/agents-table.md`. Proposed fix: rewrite reference.
6. `agents/evelynn/learnings/2026-04-08-roster-vs-harness-reality.md` — **`.claude/agents/poppy.md`** — miss. Poppy is retired; the file now lives at `.claude/_retired-agents/poppy.md`. Proposed fix: note the retirement inline or update the path.
7. `agents/evelynn/memory/evelynn.md` — **`plans/ready/`** — miss. No `plans/ready/` directory exists in the lifecycle (valid subdirs: `proposed/`, `approved/`, `in-progress/`, `implemented/`, `archived/`). Proposed fix: rewrite as `plans/approved/`.
8. `agents/evelynn/memory/last-sessions/cca80ba9.md` — **`scripts/hooks/check-no-hardcoded-slugs.sh`** — miss.
9. `agents/kayn/learnings/2026-04-19-public-app-repo-migration-tasks.md` — **`scripts/hooks/check-no-hardcoded-slugs.sh`** — miss (same as #8). Proposed fix: if the hook is planned, mark speculative; if landed under a different name, update the path.
10. `agents/evelynn/memory/last-sessions/faa8aa63.md` — **`scripts/deploy/_lib.sh`**, **`scripts/deploy/functions.sh`** — both miss. `scripts/deploy/` is empty or non-existent.
11. `agents/evelynn/memory/sessions/faa8aa63.md` — **`scripts/deploy/_lib.sh`** — same as #10.
12. `agents/lux/learnings/2026-04-18-shared-lib-review-checklist.md` — **`scripts/deploy/_lib.sh`** — same as #10. Proposed fix: consolidate — either land the deploy library, or retarget these three files to cite the actual deployment-pipeline plan instead of a file that does not yet exist.
13. `agents/evelynn/memory/sessions/a8081406.md` — **`architecture/review-policy.md`** — miss. Proposed fix: remove or rewrite to cite the branch-protection plan.
14. `agents/vi/learnings/2026-04-18-orianna-o6-smoke-tests.md` — **`agents/evelynn/memory/MEMORY.md`** — miss. Evelynn's memory file is `agents/evelynn/memory/evelynn.md`. Proposed fix: correct the filename.
15. `agents/yuumi/memory/yuumi.md` — **`scripts/restart-evelynn.ps1`** — miss. No such script. Proposed fix: remove reference or land the Windows restart helper under `scripts/windows/`.

## Warn findings

### 1. Cross-repo checkout absent (top-level)

Could not verify 75 cross-repo claims (`apps/**`, `dashboards/**`,
`.github/workflows/**`) — `strawberry-app` checkout not found at
`~/Documents/Personal/strawberry-app/`. Contract §5 requires emitting this
rather than silently skipping. Reconciliation: either clone
`harukainguyen1411/strawberry-app` to that path, or accept these as
unverifiable for this audit cycle.

### 2. Plan-promotion drift (28 entries)

Memory / learnings files cite plans under `plans/proposed/...` that have since
moved to `approved/`, `in-progress/`, `implemented/`, or `archived/`. The plan
**content still exists** at the new path, so these are warn (stale anchor), not
block. Affected files (file → referenced proposed path, now at):

- `agents/azir/learnings/2026-04-18-public-app-repo-migration-plan.md` → `plans/proposed/2026-04-19-public-app-repo-migration.md` (now `plans/approved/`).
- `agents/azir/learnings/2026-04-19-strawberry-agents-companion-adr.md` → `plans/proposed/2026-04-19-strawberry-agents-companion-migration.md` (now `plans/approved/`).
- `agents/azir/memory/last-session.md` → same as above.
- `agents/azir/memory/MEMORY.md` → `plans/proposed/2026-04-19-public-app-repo-migration.md` and `...strawberry-agents-companion-migration.md` (both now `approved/`).
- `agents/evelynn/memory/last-sessions/a8081406.md` → `plans/proposed/2026-04-19-public-app-repo-migration.md` (now `approved/`).
- `agents/evelynn/memory/sessions/a8081406.md` → same as above.
- `agents/jayce/learnings/2026-04-19-orianna-fact-check-gate.md` → `plans/proposed/2026-04-19-orianna-smoke-bad-plan.md`. **No file found under any subdirectory** — borderline block, but the adjacent `plans/in-progress/2026-04-19-orianna-fact-checker.md` suggests the smoke-bad-plan was a working artifact that was never formally promoted. Flag for human decision.
- `agents/vi/learnings/2026-04-18-orianna-o6-smoke-tests.md` → `plans/approved/2026-04-19-orianna-fact-checker.md` (now `plans/in-progress/`).
- `agents/vi/learnings/2026-04-18-orianna-o6-smoke-tests.md` → `assessments/memory-audits/2026-04-19-memory-audit.md` (future-dated; this report lives at `2026-04-18-memory-audit.md`).
- `agents/rakan/memory/last-session.md` → `plans/2026-04-04-telegram-relay.md` (now `plans/implemented/`).
- `agents/rakan/memory/rakan.md` → same as above.
- `agents/_retired/pyke/memory/last-session.md` → `plans/proposed/2026-04-14-git-hygiene-automation.md` (now `approved/`).
- `agents/_retired/swain/memory/swain.md` → 5 referenced proposed plans, all now under `approved/`, `implemented/`, or renamed (see `plans/approved/2026-04-17-deployment-pipeline.md`).
- `agents/_retired/syndra/memory/syndra.md` + `last-session.md` → 7 referenced proposed plans, all now under `approved/` or `implemented/`.
- `agents/_retired/lux-frontend-sonnet/memory/MEMORY.md` → 8 referenced proposed plans, all promoted.

Reconciliation: update anchors in active-agent files (azir, evelynn, jayce,
vi, rakan) to cite the current path. Retired-agent references (swain, syndra,
pyke, lux-frontend-sonnet) may be left as-is — they are historical snapshots.

### 3. Retired-agent artifact (2 entries)

- `agents/_retired/pyke/learnings/2026-04-04-gitleaks-false-positives.md` — **`scripts/setup-`** — extraction artifact from a trailing hyphen; likely referenced a specific script like `scripts/setup-hooks.sh`. Retired file; not actionable.
- `agents/_retired/shen/memory/last-session.md` — **`architecture/deploy-runbook.md`** — miss. Retired file; historical.

## Info findings

1. `agents/camille/learnings/_migrated-from-pyke/2026-04-04-gitleaks-false-positives.md` — **`scripts/setup-`** — same extraction artifact as the retired-pyke copy (this is a migrated duplicate).
2. `agents/evelynn/learnings/2026-04-11-nested-worktree-permissions.md` — **`.claude/worktrees/agent-XXX/`** — literal `XXX` is a template placeholder, not a real path. Extraction artifact; ignore.
3. Plan lifecycle: the `plans/ready/` reference in `agents/evelynn/memory/evelynn.md` suggests a lifecycle state that was never adopted. Consider whether Evelynn's memory should explicitly list the five valid states (`proposed|approved|in-progress|implemented|archived`) to prevent future drift.
4. Cross-repo verifiability: if `apps/**` claims keep appearing in agent memory (especially Evelynn's session shards), consider documenting a "verify via remote" fallback in the contract — e.g. `gh api repos/harukainguyen1411/strawberry-app/contents/<path>` — so audits remain useful when the local checkout is absent.

## Reconciliation checklist

- [ ] `agents/memory/agents-table.md` — fix `agents/akali/` reference (either scaffold the directory or rewrite to `.claude/agents/akali.md`).
- [ ] `agents/camille/learnings/2026-04-18-billing-block-failure-signature.md` — remove or retarget `architecture/operability.md` reference.
- [ ] `agents/ekko/learnings/2026-04-19-orianna-o4-memory-audit.md` + `agents/orianna/learnings/2026-04-19-o4-tdd-stale-seed.md` — mark `scripts/migrate-hetzner-to-gce.sh` as speculative or remove.
- [ ] `agents/evelynn/learnings/2026-04-08-roster-vs-harness-reality.md` — fix `agents/roster.md` → `agents/memory/agent-network.md`; fix `.claude/agents/poppy.md` → `.claude/_retired-agents/poppy.md`.
- [ ] `agents/evelynn/memory/evelynn.md` — replace `plans/ready/` with `plans/approved/` (or document the state explicitly if intentional).
- [ ] `agents/evelynn/memory/last-sessions/cca80ba9.md` + `agents/kayn/learnings/2026-04-19-public-app-repo-migration-tasks.md` — resolve `scripts/hooks/check-no-hardcoded-slugs.sh` (land the hook or mark speculative).
- [ ] `agents/evelynn/memory/last-sessions/faa8aa63.md` + `agents/evelynn/memory/sessions/faa8aa63.md` + `agents/lux/learnings/2026-04-18-shared-lib-review-checklist.md` — resolve `scripts/deploy/_lib.sh` and `scripts/deploy/functions.sh` (land the library or retarget to the deployment-pipeline plan).
- [ ] `agents/evelynn/memory/sessions/a8081406.md` — remove or rewrite `architecture/review-policy.md`.
- [ ] `agents/vi/learnings/2026-04-18-orianna-o6-smoke-tests.md` — fix three anchors: `agents/evelynn/memory/MEMORY.md` → `evelynn.md`; `plans/approved/2026-04-19-orianna-fact-checker.md` → `plans/in-progress/`; `assessments/memory-audits/2026-04-19-memory-audit.md` → today's date (`2026-04-18`).
- [ ] `agents/yuumi/memory/yuumi.md` — resolve `scripts/restart-evelynn.ps1` (land under `scripts/windows/` or remove).
- [ ] `agents/jayce/learnings/2026-04-19-orianna-fact-check-gate.md` — decide whether `plans/proposed/2026-04-19-orianna-smoke-bad-plan.md` should be promoted or removed from memory.
- [ ] (Optional) Clone `harukainguyen1411/strawberry-app` to `~/Documents/Personal/strawberry-app/` to make cross-repo audits verifiable.
- [ ] (Optional) Batch-update active-agent anchors for plan-promotion drift (azir, evelynn, rakan, vi) — 12 entries across 8 files.
- [ ] (Do not touch) `agents/_retired/*` stale references — historical, left as-is.
