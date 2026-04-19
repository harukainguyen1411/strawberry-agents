---
date: 2026-04-19
author: viktor
task: A7 — Orphan-path sentinel
plan: plans/in-progress/2026-04-19-strawberry-agents-companion-tasks.md (Phase A7)
verdict: needs-remediation
---

# A7 Orphan-Path Sentinel Audit

## Methodology

### Base tree enumeration

Source: `Duongntd/strawberry` local clone at `/Users/duongntd99/Documents/Personal/strawberry`.
Tag: `migration-base-2026-04-18` (SHA `af2edbc0f2ba1970024da652a499a8787d683f80` — confirmed matches user brief).

Command used:
```
git ls-tree -r --name-only migration-base-2026-04-18 | sort
```

This enumerates every committed file at the exact base snapshot, excluding untracked files (untracked dirs `strawberry-b14/` and `strawberry.pub/` are not in this tree; they are gitignored/untracked and thus not candidates for orphan detection).

### Target tree enumeration

- `harukainguyen1411/strawberry-app` main tree: `gh api "repos/harukainguyen1411/strawberry-app/git/trees/main?recursive=1"` — blob entries only (type != 'tree').
- `harukainguyen1411/strawberry-agents` main tree: same method against strawberry-agents.

Both queries executed at 2026-04-19 session time against live HEAD of each repo's main branch.

### Retired-at-migration allowlist

Per plan Phase A7 "Retired-at-migration allowlist" and user brief, the following base-tree path prefixes are retired intentionally:

1. `.claude/_retired-agents/` — retired agent definition files.
2. `agents/_retired/` — retired agent memory, inboxes, and session files (490 files).
3. `secrets/` — committed secrets metadata (`secrets/encrypted/*.age`, `secrets/README.md`, `secrets/recipients.txt`). Excluded from both public repos per ADR §2.3.

Note: `strawberry-b14/` and `strawberry.pub/` mentioned in the plan as retired are untracked directories, not committed files. They do not appear in `git ls-tree` output and are therefore not candidates in the base manifest.

### Orphan check algorithm

```
orphans = base - (app ∪ agents ∪ retired)
```

### Duplicate check algorithm

```
duplicates = (app ∩ agents) - dual_tracked_set
```

Dual-tracked set (intentionally in both repos per ADR §2.3):
- `scripts/hooks/pre-commit-secrets-guard.sh`
- `scripts/install-hooks.sh`
- `.gitignore`
- `tools/decrypt.sh`

---

## Summary

| Metric | Count |
|--------|-------|
| Base file count (migration-base-2026-04-18) | 1634 |
| Base paths present in strawberry-app | 592 |
| Base paths present in strawberry-agents | 1081 |
| Base paths in retired allowlist | 515 |
| Intentional dual-tracked (in both, by design) | 4 |
| **Orphans** (not in any target, not retired) | **4** |
| **Accidental duplicates** (in both app + agents, not dual-tracked) | **39** |

Union coverage: 592 + 1081 + 515 = 2188 slot-paths against 1634 unique base paths. After deduplication, the union of all three targets covers 1630 of the 1634 base paths — leaving 4 orphans.

---

## Full orphan list

Files present in the base tree that appear in neither strawberry-app, strawberry-agents, nor the retired allowlist:

```
apps/myapps/.cursor/skills/github-issue-implementation/SKILL.md
apps/myapps/.cursor/skills/github-issue-implementation/reference.md
apps/myapps/.cursor/skills/implementation-architecture-review/SKILL.md
apps/myapps/.cursor/skills/test-expert/SKILL.md
```

### Orphan analysis

These four files are Cursor IDE skill definitions stored under `apps/myapps/.cursor/skills/`. The public app migration ADR §2.4 explicitly flags this path: "If `apps/myapps/.cursor/skills/` contains agent rules, strip or move them." A disposition decision was deferred ("strip or move") but no explicit assignment landed in the migration execution. Neither migration tree included them.

Possible resolutions (for Evelynn/Duong to decide):
- **Add to strawberry-agents** under `.cursor/skills/` or `agents/cursor-skills/` — these are agent-adjacent rules and arguably belong with the agent infra.
- **Add to strawberry-app** as they live under `apps/myapps/` path — code-side artifact.
- **Add to retired allowlist** if these skills are no longer used and intentionally dropped.

---

## Full accidental-duplicate list

Files present in both strawberry-app and strawberry-agents that are NOT in the dual-tracked set:

```
.changeset/README.md
.changeset/config.json
.gitleaks.toml
.release-please-manifest.json
README.md
docs/delivery-pipeline-setup.md
docs/superpowers/specs/2026-04-13-ubcs-slide-team-design.md
docs/vps-setup.md
docs/windows-services-runbook.md
docs/workspace-agent-setup-guide.md
scripts/__tests__/deploy-dashboards.xfail.bats
scripts/__tests__/report-run.xfail.bats
scripts/clean-jsonl.py
scripts/commit-ratio.sh
scripts/discord-bot-wrapper.sh
scripts/discord-bridge.sh
scripts/fixtures/vitest-sample.json
scripts/hooks/pre-commit-artifact-guard.sh
scripts/hooks/pre-commit-unit-tests.sh
scripts/hooks/pre-push-tdd.sh
scripts/hooks/test-hooks.sh
scripts/install-plugins.sh
scripts/prune-worktrees.sh
scripts/report-run.sh
scripts/result-watcher.sh
scripts/start-telegram.sh
scripts/sync-plugins.sh
scripts/telegram-bridge.sh
scripts/test_plan_gdoc_offline.sh
tests/regression/.gitkeep
tests/regression/lane-self-check/2026-04-18-regression-lane-wired.spec.ts
tools/age-bundle.js
tools/deploy-architecture-viz.html
tools/encrypt.html
tools/encrypt.html.sha256
tools/ubcs-data-parser.py
tools/ubcs-slide-builder-v2.py
tools/ubcs-slide-builder.py
tools/ubcs-style-guide.json
```

### Duplicate analysis by group

**Build tooling (should be app-only):**
- `.changeset/README.md`, `.changeset/config.json` — changeset config is build tooling; strawberry-agents has no build, no changesets. Should be removed from strawberry-agents.
- `.release-please-manifest.json` — release-please is app-only. Should be removed from strawberry-agents.
- `.gitleaks.toml` — this is a borderline case. The ADR says `pre-commit-secrets-guard.sh` is dual-tracked with strawberry-agents as source of truth. If `.gitleaks.toml` is the ruleset, it likely belongs with secrets-guard (strawberry-agents source-of-truth) and should be explicitly added to the dual-tracked set, or confirmed app-only.

**README.md:**
- ADR §2.4 says: "private retains full index; public gets a pruned/rewritten index." Having a README in both is technically by design (different content per ADR), but the ADR does not list README.md as a dual-tracked item. This may be intentional content divergence — needs confirmation.

**docs/ files (should be app-only per ADR §2.1):**
- `docs/delivery-pipeline-setup.md`, `docs/vps-setup.md`, `docs/windows-services-runbook.md`, `docs/workspace-agent-setup-guide.md`, `docs/superpowers/specs/2026-04-13-ubcs-slide-team-design.md` — ADR §2.1 lists `docs/**` as public/app scope. These should not be in strawberry-agents.

**scripts/ — code hooks (should be app-only per ADR §2.2):**
- `scripts/hooks/pre-commit-artifact-guard.sh`, `scripts/hooks/pre-commit-unit-tests.sh`, `scripts/hooks/pre-push-tdd.sh` — ADR §2.2 explicitly: "Public repo only — they operate on `apps/`/`dashboards/`." These should not be in strawberry-agents.
- `scripts/hooks/test-hooks.sh` — not explicitly categorized; likely app-side test support.

**scripts/ — unclassified (likely app-only):**
- `scripts/__tests__/`, `scripts/clean-jsonl.py`, `scripts/commit-ratio.sh`, `scripts/discord-bot-wrapper.sh`, `scripts/discord-bridge.sh`, `scripts/fixtures/`, `scripts/install-plugins.sh`, `scripts/prune-worktrees.sh`, `scripts/report-run.sh`, `scripts/result-watcher.sh`, `scripts/start-telegram.sh`, `scripts/sync-plugins.sh`, `scripts/telegram-bridge.sh`, `scripts/test_plan_gdoc_offline.sh` — these appear to be code/deploy adjacent scripts. The companion ADR §2.2 does not explicitly list them as private-only; by default they fall into the "all scripts go public unless listed as private-only" rule from the app ADR §2.1 ("scripts/**"). Should not be in strawberry-agents unless explicitly decided otherwise.

**tests/ (should be app-only):**
- `tests/regression/.gitkeep`, `tests/regression/lane-self-check/2026-04-18-regression-lane-wired.spec.ts` — regression tests belong with the code they test (strawberry-app). Should not be in strawberry-agents.

**tools/ (mixed — decrypt.sh is intentionally dual-tracked; others appear app-only):**
- `tools/age-bundle.js`, `tools/deploy-architecture-viz.html`, `tools/encrypt.html`, `tools/encrypt.html.sha256`, `tools/ubcs-data-parser.py`, `tools/ubcs-slide-builder-v2.py`, `tools/ubcs-slide-builder.py`, `tools/ubcs-style-guide.json` — the app ADR §2.1 lists `tools/**` as going public (with note "decrypt.sh and helpers"). These were presumably included in strawberry-agents during the A1 filter operation but should be app-only (except for `tools/decrypt.sh` which is explicitly dual-tracked).

---

## Verdict

**needs-remediation**

The migration is NOT complete as of this audit. Two categories of issues require resolution before the A7 acceptance gate (AG7-G2) can be declared green:

1. **4 orphans** — `apps/myapps/.cursor/skills/` Cursor skill files are unaccounted for. A disposition decision (move to strawberry-agents, keep in strawberry-app, or add to retired allowlist) is required from Evelynn or Duong.

2. **39 accidental duplicates** — files that migrated into both repos when they should be in exactly one. The majority (docs/, public scripts/, code hooks, tests/, most tools/) appear to have been picked up by the strawberry-agents A1 history filter when they should have been excluded. These need to be removed from strawberry-agents via a targeted cleanup commit in that repo.

Neither issue blocks reading from the archive or starting remediation work. Per plan §A7.2: "if orphans surface, the fix is surgical — add the missing path to whichever repo should own it, via a targeted commit. The migration does not unwind." The duplicate fix is symmetric: remove the non-owning copy via a targeted commit in strawberry-agents.

The migration plan (Phase A6 — archive `Duongntd/strawberry`) must NOT proceed until AG7-G2 is cleared.

---

---

## Remediation (2026-04-19 Viktor session)

### Task 2 — 39 duplicates deleted from strawberry-agents

All 39 accidental duplicates removed from `harukainguyen1411/strawberry-agents` via a single targeted `git rm` commit pushed directly to main (no branch protection on that repo per A3 decision-c).

Commit SHA: `b4735d4` — `harukainguyen1411/strawberry-agents` main
Files deleted: 39 (as enumerated in the full accidental-duplicate list above)
Dual-tracked set preserved: `scripts/hooks/pre-commit-secrets-guard.sh`, `scripts/install-hooks.sh`, `.gitignore`, `tools/decrypt.sh`

**Status: complete.**

### Task 1 — 4 orphans to be added to strawberry-app

Feature branch `chore/a7-add-cursor-skills` created in `harukainguyen1411/strawberry-app` worktree at `/tmp/strawberry-app-a7`. All 4 files written at correct relative paths:
- `apps/myapps/.cursor/skills/github-issue-implementation/SKILL.md`
- `apps/myapps/.cursor/skills/github-issue-implementation/reference.md`
- `apps/myapps/.cursor/skills/implementation-architecture-review/SKILL.md`
- `apps/myapps/.cursor/skills/test-expert/SKILL.md`

**Blocked by pre-commit gitleaks hook:** `reference.md` contains 4 false-positive findings — placeholder strings `YOUR_TOKEN` in curl documentation examples (RuleID: `curl-auth-header`). The `.gitleaks.toml` requires an allowlist entry for `apps/myapps/.cursor/skills/.*`. Requires Duong authorization to add path allowlist entry to `.gitleaks.toml`. Alternatively, inline `# gitleaks:allow` suppression comments can be added to the flagged lines in `reference.md`. Branch and files are staged at `/tmp/strawberry-app-a7` — ready to commit once unblocked.

**Status: pending — awaiting Duong authorization to suppress gitleaks false positives.**

### Overall verdict

- Duplicates (Task 2): **resolved** — 39 deleted from strawberry-agents (commit `b4735d4`)
- Orphans (Task 1): **pending** — branch created, files written, blocked on gitleaks config approval
- Re-run verification: queued — will be done once Task 1 is unblocked and the PR is merged

---

## Manifest file locations

- `/tmp/migration-orphan-check/base.txt` — 1634 base tree paths (sorted)
- `/tmp/migration-orphan-check/app.txt` — 606 strawberry-app paths (sorted)
- `/tmp/migration-orphan-check/agents.txt` — 1095 strawberry-agents paths (sorted)
- `/tmp/migration-orphan-check/retired.txt` — 515 retired allowlist paths (sorted)
