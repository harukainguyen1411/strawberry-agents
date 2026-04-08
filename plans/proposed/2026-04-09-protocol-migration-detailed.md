---
title: Protocol Migration — Katarina-Executable Repo Cleanup for Operating Protocol v2
status: proposed
owner: pyke
created: 2026-04-09
supersedes:
cross-refs:
  - assessments/2026-04-08-protocol-leftover-audit.md
  - plans/proposed/2026-04-09-operating-protocol-v2.md
  - plans/proposed/2026-04-09-mcp-restructure-phase-1-detailed.md
  - plans/proposed/2026-04-08-mcp-restructure.md
  - plans/proposed/2026-04-08-evelynn-continuity-and-purity.md
  - plans/proposed/2026-04-08-plan-lifecycle-protocol-v2.md
---

# Protocol Migration — Detailed Execution Spec

> Executor-ready. Every step has a checkbox, an exact file path, an exact git command, and exact text where applicable. No design decisions remain.
>
> **Rule 7 applies to the plan author.** Pyke wrote this; Pyke does not execute it. Evelynn delegates execution after Duong approves.
>
> **Rule 6 / delegation note.** This plan is detailed and mechanical. A Sonnet agent (Katarina) may execute it. The executor is forbidden from changing scope, renaming artifacts, or inventing steps not listed here. If a step is ambiguous, stop and escalate to Evelynn.

## What this plan does

Walks the leftover-audit (`assessments/2026-04-08-protocol-leftover-audit.md`) and the operating-protocol-v2 target (`plans/proposed/2026-04-09-operating-protocol-v2.md`), and produces a mechanical cleanup of the strawberry repo in **ten reversible atomic commits**, each with `chore:` prefix. The cleanup closes Layer 0 (parity) and Layer 1 (roster + retirement) debts, archives the fossils of the old MCP-coordination world, and backfills CLAUDE.md rule numbering to match what the in-flight plans will collectively land.

## Pre-audit reality check — Rule 15 already satisfied at the filesystem level

Operating Protocol v2 contained a note that Task #3 might need to backfill `model:` frontmatter across `.claude/agents/*.md`. Verified 2026-04-09: all 8 existing harness profiles already declare `model:` as of commit `eb6c0a9` ("chore: declare model per agent + rule 15 (no silent Opus inherit)"). No backfill is required. Rule 15 is satisfied at the filesystem level for every wired agent. Future readers: do not re-chase this; the v2 line was predicated on a stale assumption.

## What this plan does NOT do

Strict non-goals. If the executor is tempted to do any of these, STOP:

- Does not touch `mcps/agent-manager/`, `mcps/evelynn/`, `.mcp.json`, or the `agent-manager` tool-name call sites in agent memory/profiles/plans. Those are owned by `plans/proposed/2026-04-09-mcp-restructure-phase-1-detailed.md` Steps 1–7, 10–14. The two plans land independently.
- Does not touch `plans/in-progress/*.md` per Task #3 constraint.
- Does not touch `plans/implemented/*.md` or `plans/archived/*.md`.
- Does not touch agent journals (`agents/*/journal/`), transcripts (`agents/*/transcripts/`), learnings (`agents/*/learnings/`), or individual memory files beyond the roster-consolidation step.
- Does not **create** any `.claude/agents/<name>.md` files that are currently missing. Creating a subagent profile is design work (description, tools, skills, body text) and belongs to Evelynn / the agent's owner. This plan flags the gap explicitly (Step 6) but does not fill it.
- Does not retire Rakan. Rakan's classification is Operating Protocol v2 open question #5 and blocks on Duong.
- Does not delete `strawberry` or `strawberry.pub` at the repo root. These are not tracked by git (verified via `git ls-files`) and are almost certainly Duong's SSH keys. Leave them alone; they are invisible to the repo. Do not touch.
- Does not introduce or modify any skill files. Skill changes belong to the MCP restructure and plan-lifecycle-v2 plans.
- Does not execute the plan-lifecycle-protocol-v2 schema migration (`plans/ready/` directory, `draft-plan`/`detailed-plan` skills, plan-lint, frontmatter backfill). That plan owns its own detailed phase.
- Does not audit `scripts/gh-*`, `scripts/*-bridge.sh`, `scripts/google-oauth-bootstrap.sh`, `scripts/_lib_gdoc.sh`, `scripts/setup-*` for platform assumptions. Operating Protocol v2 Layer 0 debt list notes this as a separate audit pass. This plan moves only scripts that are unambiguously Mac- or Windows-only at their shebang/extension level (`.ps1`, `.bat`, hardcoded `osascript`).

## Platform parity rules the executor MUST respect

Inherited verbatim from `plans/proposed/2026-04-09-mcp-restructure-phase-1-detailed.md` §"Cross-platform parity (first-class)":

1. Every new script is POSIX bash (`#!/usr/bin/env bash`) or explicitly classified as Mac/Windows by directory placement.
2. Filesystem paths constructed from `REPO_ROOT="$(git rev-parse --show-toplevel)"`. No absolute paths, no `~`, no drive letters in committed files.
3. Line endings: LF only. `.gitattributes` already enforces this.
4. This plan creates no new skills, so POSIX-only skill rules do not apply here.
5. Every script this plan moves into `scripts/mac/` or `scripts/windows/` gets a row in `architecture/platform-parity.md` in the same commit (Commit 5).

## Rule-numbering coordination (critical, read before starting)

Multiple in-flight plans all claim to add new CLAUDE.md rules. At the time this plan was written:

- **Rule 15** — already landed (model-tier declaration), committed prior to 2026-04-09.
- **Rules 16, 17** — phase-1-detailed MCP restructure Steps 11a and 11b (MCP-only-for-external, POSIX portability). Phase-1-detailed Step 11 currently calls them "Rule 15 and Rule 16" in its text. That numbering is stale because Duong landed model-tier as Rule 15 first. Phase-1-detailed's numbers shift to **16 and 17**.
- **Rules 18, 19** — operating-protocol-v2 §2.9 and §2.10 (Roster SSOT, Universal parity). operating-protocol-v2 §2.10 already acknowledges this shift.

**This migration plan is intentionally designed to land AFTER phase-1-detailed and operating-protocol-v2 in commit order.** It does not add any new CLAUDE.md rules itself — it only *verifies* that the numbering landed cleanly and *fixes* it if earlier commits got it wrong. See Commit 9 (Step 9) for the verification.

If this plan lands *before* phase-1-detailed or operating-protocol-v2 (execution order is Evelynn's call), the executor must STOP at Commit 9, note the mismatch in the commit message body, and escalate. Do not improvise rule numbering.

## Commit inventory (ten atomic commits)

Every commit uses `chore:` prefix, lands directly on main (this is protocol cleanup — per Rule 9, it's not implementation work through a PR, though Evelynn may choose to PR it anyway for reviewability; default is direct-to-main in a single push at the end).

1. **Commit 1** — Retire Irelia (procedure reference implementation for Operating Protocol v2 §1.3).
2. **Commit 2** — Delete Zilean half-scaffold.
3. **Commit 3** — Archive turn-based conversation fossils and delegation JSON fossils.
4. **Commit 4** — Delete empty shared agent-directory scaffolding.
5. **Commit 5** — Classify platform-specific scripts + create `architecture/platform-parity.md`.
6. **Commit 6** — Move per-agent iTerm background blobs out of `agents/<name>/iterm/`.
7. **Commit 7** — Roster consolidation: collapse `agents/roster.md` into `agents/memory/agent-network.md`.
8. **Commit 8** — Delete one-shot migration artifact + collapse duplicate git-workflow doc.
9. **Commit 9** — Rule-numbering verification, stale `plans/proposed/` triage flag, audit cross-reference.
10. **Commit 10** — Post-phase-1 legacy-tool-name drift sweep (catches references added to files after phase-1-detailed's grep baseline).

Each commit is independently revertible. The executor lands them in order. If any commit fails its smoke test, the executor stops and escalates rather than rolling forward into the next commit.

---

## Commit 1 — Retire Irelia

**Scope:** First use of the Operating Protocol v2 §1.3 retirement procedure. Irelia is the canonical example. She is already marked "retired" in `agents/roster.md` but has a full live directory tree.

**Parity check:** Irelia has no platform-specific affordances; her per-agent `iterm/` directory (if any) is addressed in Commit 6 generally.

### Step 1.1 — Confirm preconditions

- [ ] `git status --short` is empty.
- [ ] Current branch is `main`.
- [ ] `ls agents/irelia/` shows `inbox/ journal/ learnings/ memory/ profile.md transcripts/` (or similar; the exact contents don't matter — the directory exists).
- [ ] `.claude/agents/irelia.md` does NOT exist (confirm with `ls .claude/agents/irelia.md 2>/dev/null; echo $?` returns `2` from ls and `0` or `1` from `echo`). Irelia has no harness profile because she was never a subagent.

**Retirement procedure (updated per operating-protocol-v2 commit `5bd1ea3`, Duong's Q4 decision 2026-04-09):** hard `git rm -r`, no `.retired/` archive directory. Git history is the archive. Rationale: archive directories reintroduce the fossil problem the audit is trying to solve.

### Step 1.2 — Hard-delete Irelia's directory

- [ ] Run: `git rm -r agents/irelia`
- [ ] Verify with `git status --short` that every file under `agents/irelia/` shows as `D` (delete).

### Step 1.3 — Delete harness profile if present

- [ ] `.claude/agents/irelia.md` was confirmed absent in Step 1.1. If Step 1.1 somehow saw it as present (state drift), run: `git rm .claude/agents/irelia.md`
- [ ] Otherwise skip.

### Step 1.4 — Update `agents/roster.md` — remove Irelia row, add Retired footnote

- [ ] Edit `agents/roster.md`.
- [ ] Find the exact line:
  ```
  | Irelia (retired) | Former head agent | `irelia/` |
  ```
- [ ] Delete that entire line from the table.
- [ ] Find the section header `## Infrastructure (minions)` and, immediately BEFORE it, add a new section (one-line footnote entry, NOT a table):
  ```
  ## Retired

  - **Irelia** — 2026-04-09 — retired when Evelynn took over as head agent.

  ```
  (Note the blank line after the bullet.)

  Note: this section will be short-lived — `agents/roster.md` itself is deleted in Commit 7 (roster consolidation). Commit 7 carries the Retired footnote forward into `agents/memory/agent-network.md`.

### Step 1.5 — Update `agents/memory/agent-network.md` — confirm Irelia not listed

- [ ] `grep -n "Irelia" agents/memory/agent-network.md` — expect zero matches. If there are matches, stop and escalate (the file drift is larger than expected).

### Step 1.6 — Update `architecture/platform-parity.md` if present

- [ ] `test -f architecture/platform-parity.md && grep -n "Irelia" architecture/platform-parity.md || echo "no parity file or no Irelia row"`
- [ ] If the file exists AND contains an Irelia row, remove that row via `Edit`. Otherwise skip.

### Step 1.7 — Smoke test

- [ ] `ls agents/irelia/ 2>/dev/null; echo $?` — expect non-zero (directory gone).
- [ ] `git ls-files agents/irelia/ | wc -l` — expect `0`.
- [ ] `grep -c "^| Irelia" agents/roster.md || true` — expect `0`.
- [ ] `grep -c "^- \*\*Irelia\*\*" agents/roster.md || true` — expect `1` (the new retired footnote).

### Step 1.8 — Commit

- [ ] Stage: `git add agents/roster.md` (the `git rm -r` in Step 1.2 already staged the deletions).
- [ ] Commit message (exact, via heredoc):
  ```
  chore: retire irelia agent — replaced by Evelynn as head agent

  First use of the Operating Protocol v2 §1.3 retirement procedure
  (hard-delete form, per Duong's Q4 decision in commit 5bd1ea3).

  - git rm -r agents/irelia (git history is the archive).
  - Removed Irelia row from agents/roster.md live table.
  - Added one-line Retired footnote entry to agents/roster.md.

  No .claude/agents/irelia.md existed, so no harness profile deletion
  required. No architecture/platform-parity.md row existed, so no
  parity-file edit required.

  Commit 1 of 9 in the protocol migration sequence.

  Refs: plans/proposed/2026-04-09-protocol-migration-detailed.md commit 1
        plans/proposed/2026-04-09-operating-protocol-v2.md §1.3
  ```
- [ ] Do NOT push yet. Push happens once, at the end, after all nine commits land (Step 10).

---

## Commit 2 — Delete Zilean half-scaffold

**Scope:** `agents/zilean/` exists with `inbox/`, `journal/`, `transcripts/` but NO `profile.md` and NO `memory/<name>.md`. Per Operating Protocol v2 §1.1 roster invariants, this is a non-agent — either scaffold it fully or delete. Zilean is planned to ship when the continuity-and-purity plan lands, at which point the new-agent script will scaffold it correctly. The half-skeleton has no value and confuses readers.

### Step 2.1 — Preflight

- [ ] Confirm `git status --short` is empty (previous commit is clean).
- [ ] Confirm `agents/zilean/` exists and contains NO `profile.md`: `test ! -f agents/zilean/profile.md && echo OK` prints `OK`.
- [ ] Confirm `agents/zilean/` contains NO `memory/` directory: `test ! -d agents/zilean/memory && echo OK` prints `OK`.
- [ ] If either check fails, STOP — Zilean has been scaffolded since the audit and this step's assumption is wrong. Escalate.

### Step 2.2 — Verify tracked contents

- [ ] Run: `git ls-files agents/zilean/`
- [ ] Expect a small set: likely only `.gitkeep` files under `inbox/`, `journal/`, `transcripts/`, or nothing at all. If there is a `profile.md`, `memory/*.md`, or any real content, STOP and escalate.

### Step 2.3 — Delete the directory

- [ ] `git rm -r agents/zilean`
- [ ] If the directory had no tracked files, `git rm` will fail. In that case run `rm -rf agents/zilean` instead; nothing needs to be staged.

### Step 2.4 — Smoke test

- [ ] `ls agents/zilean 2>/dev/null; echo $?` — expect non-zero (directory gone).

### Step 2.5 — Commit

- [ ] If there is anything staged: `git add -A agents/zilean` (captures deletions) then commit. If nothing is staged (empty directory case), skip this commit entirely and note "no-op" in the Step 10 push summary.
- [ ] Commit message:
  ```
  chore: delete zilean half-scaffold (protocol migration commit 2 of 9)

  agents/zilean/ existed with only inbox/journal/transcripts gitkeeps and no
  profile.md or memory/ directory. Per Operating Protocol v2 §1.1, the four
  roster-membership conditions were not met. The directory conveyed false
  roster presence.

  Zilean will be scaffolded properly via scripts/new-agent.sh when the
  continuity-and-purity plan lands.

  Refs: plans/proposed/2026-04-09-protocol-migration-detailed.md commit 2
        plans/proposed/2026-04-08-evelynn-continuity-and-purity.md component B
  ```

---

## Commit 3 — Hard-delete turn-conversation and delegation fossils

**Scope:** 33 `.md` files under `agents/conversations/` (turn-based conversation artifacts from the old MCP tool set) and 6 `d-*.json` files under `agents/delegations/` (old `delegate_task`/`complete_task` MCP state). Both directories are fossils from the pre-Phase-1 coordination model.

**Same rationale as Commit 1's hard-delete retirement:** git history is the archive. `agents/.archive/` would reintroduce the shadow-dir fossil pattern Duong's Q4 decision explicitly retired. Anyone who needs the content can `git log --all --diff-filter=D --name-only` to find the delete commit, or `git show <hash>:<path>` to read a specific file.

**Why both directories must go together (operating-protocol-v2 §3.3 "no parallel channels"):** v2 Layer 3 §3.3 is the load-bearing clause that forbids running the old MCP coordination surface in parallel with the new Teams/subagent/Yuumi stack. Leaving `agents/conversations/` or `agents/delegations/` tracked preserves a readable record of the old workflow next to the new one, which is exactly the parallel-channel pattern §3.3 rules out. Deletion (not archival) is the correct implementation of the §3.3 invariant.

**Phase 1 MCP restructure does NOT delete these directories.** Phase 1 updates the tool-name references in agent memory/profile/plan files but leaves `agents/conversations/` and `agents/delegations/` in place. This migration plan handles the fossils themselves.

**Parity note:** both directories are platform-neutral; no parity concern.

### Step 3.1 — Preflight

- [ ] `git status --short` empty.
- [ ] Confirm `agents/conversations/` exists and contains `.md` files: `ls agents/conversations/*.md 2>/dev/null | head -3` prints at least one file.
- [ ] Confirm `agents/delegations/` exists and contains `d-*.json` files: `ls agents/delegations/d-*.json 2>/dev/null | head -3` prints at least one file.
- [ ] Record counts for the commit body:
  ```
  ls agents/conversations/*.md 2>/dev/null | wc -l
  ls agents/delegations/d-*.json 2>/dev/null | wc -l
  ```

### Step 3.2 — Hard-delete both directories

- [ ] `git rm -r agents/conversations`
- [ ] `git rm -r agents/delegations`

### Step 3.3 — Smoke test

- [ ] `ls agents/conversations 2>/dev/null; echo $?` — expect non-zero.
- [ ] `ls agents/delegations 2>/dev/null; echo $?` — expect non-zero.
- [ ] `git ls-files agents/conversations/ agents/delegations/ | wc -l` — expect `0`.
- [ ] `git status --short` shows only `D` (delete) entries for these paths; no `R` (rename) or `A` (add) entries.

### Step 3.4 — Commit

- [ ] Commit message:
  ```
  chore: delete turn-conversation and delegation fossils — pre-restructure MCP artifacts

  Hard-deleted agents/conversations/ (turn-based conversation transcripts
  from the retired start_turn_conversation / speak_in_turn / pass_turn /
  end_turn_conversation tool set) and agents/delegations/ (delegate_task /
  complete_task / check_delegations state JSONs). Both directories were
  fossils from the pre-Phase-1 MCP coordination model that the restructure
  is retiring.

  Git history is the archive. Anyone who needs the content can reach it via
  git log / git show against this commit.

  No agents/.archive/ shadow directory — that pattern was explicitly
  rejected by Duong's Q4 decision (operating-protocol-v2 commit 5bd1ea3,
  §1.3) because shadow archive directories reintroduce the fossil problem
  the audit is trying to solve.

  Conversation files deleted: <COUNT from Step 3.1>.
  Delegation JSONs deleted: <COUNT from Step 3.1>.

  Commit 3 of 9 in the protocol migration sequence.

  Implements the operating-protocol-v2 §3.3 "no parallel channels" clause:
  keeping these fossil directories tracked would preserve a readable record
  of the retired MCP coordination surface next to the new Teams/subagent/
  Yuumi stack, which is the parallel-channel pattern §3.3 forbids.

  Refs: plans/proposed/2026-04-09-protocol-migration-detailed.md commit 3
        plans/proposed/2026-04-09-operating-protocol-v2.md §1.3, §3.3
        assessments/2026-04-08-protocol-leftover-audit.md §1, §8.4
  ```
  Replace `<COUNT ...>` with the actual numbers from Step 3.1.

---

## Commit 4 — Delete empty shared agent-directory scaffolding

**Scope:** Four tracked `.gitkeep` files at the shared-agent level:

- `agents/inbox/.gitkeep`
- `agents/journal/.gitkeep`
- `agents/learnings/.gitkeep`
- `agents/wip/.gitkeep`

All represent shared-level directories that are empty because the real data lives per-agent (`agents/<name>/inbox/`, etc.). They're leftover scaffolding from an earlier design and confuse new readers.

**Do NOT delete `agents/transcripts/`** — that directory was already empty and has no tracked files, so it's not a git artifact. It may still exist as an untracked filesystem directory; do not rm it because it's out of git's view.

**Do NOT delete `agents/memory/`** — that directory holds the canonical shared memory files (`agent-network.md`, `duong.md`). It is NOT empty scaffolding.

**Do NOT delete `agents/health/`** — heartbeat.sh + registry.json live there, actively used.

### Step 4.1 — Preflight

- [ ] `git status --short` empty.
- [ ] For each of the four files, confirm tracking:
  ```
  git ls-files agents/inbox/.gitkeep agents/journal/.gitkeep agents/learnings/.gitkeep agents/wip/.gitkeep
  ```
  Expect all four lines printed. If any is missing, STOP and escalate.
- [ ] For each of the four directories, confirm they contain ONLY the `.gitkeep` file: `ls -A agents/inbox agents/journal agents/learnings agents/wip` — expect each to print only `.gitkeep`. If any has other contents, STOP and escalate.

### Step 4.2 — Delete

- [ ] `git rm agents/inbox/.gitkeep agents/journal/.gitkeep agents/learnings/.gitkeep agents/wip/.gitkeep`
- [ ] `rmdir agents/inbox agents/journal agents/learnings agents/wip` (filesystem cleanup after git-rm).

### Step 4.3 — Smoke test

- [ ] For each directory: `ls agents/inbox 2>/dev/null; echo $?` — expect non-zero.
- [ ] `git status --short` — expect four `D` entries (deletions).

### Step 4.4 — Commit

- [ ] Commit message:
  ```
  chore: delete empty shared agent-directory scaffolding (protocol migration commit 4 of 9)

  Removed four tracked .gitkeep files at the shared-agent level:

  - agents/inbox/.gitkeep
  - agents/journal/.gitkeep
  - agents/learnings/.gitkeep
  - agents/wip/.gitkeep

  These were leftover scaffolding from an earlier design. The real data for
  inboxes, journals, and learnings lives per-agent under agents/<name>/, so
  the shared-level empty directories served no purpose and confused readers
  about where data lived.

  agents/memory/, agents/health/, and agents/transcripts/ are intentionally
  NOT touched by this commit (see plan §commit 4 notes).

  Refs: plans/proposed/2026-04-09-protocol-migration-detailed.md commit 4
        assessments/2026-04-08-protocol-leftover-audit.md §8.8
  ```

---

## Commit 5 — Classify platform-specific scripts + create `architecture/platform-parity.md`

**Scope:** Move the top-level scripts that are unambiguously Mac- or Windows-only into `scripts/mac/` or `scripts/windows/`, move `windows-mode/` contents under `scripts/windows/`, and delete the stale `agents/launch-agent.sh` and `agents/boot.sh` scripts that point at Irelia or at a wrong path.

**Do NOT create `architecture/platform-parity.md` if phase-1-detailed MCP restructure has already landed and created it.** Check first. If it exists, EDIT it (add rows); if not, CREATE it.

**Files moved by this commit:**

- `scripts/launch-evelynn.sh` → `scripts/mac/launch-evelynn.sh` (clearly Mac-only: recently added for Mac Evelynn launch).
- `scripts/restart-evelynn.ps1` → `scripts/windows/restart-evelynn.ps1` (Windows-only, .ps1 extension).
- `windows-mode/launch-evelynn.bat` → `scripts/windows/launch-evelynn.bat`.
- `windows-mode/launch-evelynn.ps1` → `scripts/windows/launch-evelynn.ps1`.
- `windows-mode/launch-yuumi.bat` → `scripts/windows/launch-yuumi.bat`.
- `windows-mode/README.md` → `scripts/windows/README.md`.

**Files deleted by this commit:**

- `agents/launch-agent.sh` — Mac iTerm launcher with a hardcoded `/Users/duongntd99/Personal/strawberry` path (WRONG — the actual repo lives at `/Users/duongntd99/Documents/Personal/strawberry`). This script has been broken and unused. Delete.
- `agents/boot.sh` — generates an Irelia boot prompt. Irelia is retired (Commit 1). Delete.

**Explicitly NOT moved by this commit** (out of scope — future audit pass):

- `scripts/launch-evelynn.sh` is moved but `scripts/gh-auth-guard.sh`, `scripts/gh-audit-log.sh`, `scripts/setup-agent-git-auth.sh`, `scripts/setup-branch-protection.sh`, `scripts/discord-bot-wrapper.sh`, `scripts/discord-bridge.sh`, `scripts/start-telegram.sh`, `scripts/telegram-bridge.sh`, `scripts/google-oauth-bootstrap.sh`, `scripts/_lib_gdoc.sh`, `scripts/vps-setup.sh`, `scripts/deploy.sh`, `scripts/result-watcher.sh`, `scripts/health-check.sh`, `scripts/migrate-ops.sh` (migrate-ops is deleted in Commit 8), `scripts/safe-checkout.sh`, `scripts/commit-ratio.sh`, `scripts/test_plan_gdoc_offline.sh`, `scripts/plan-*.sh`, `scripts/clean-jsonl.py`, `scripts/pre-commit-secrets-guard.sh` are NOT moved. Most are POSIX-portable in principle; some may use Mac-only affordances that only an audit can surface. Operating Protocol v2 Layer 0 debt list scopes that audit as a separate pass. This commit moves only files whose platform is obvious from extension (`.ps1`, `.bat`) or explicit `osascript` at the top.

### Step 5.1 — Preflight

- [ ] `git status --short` empty.
- [ ] Confirm each source file exists:
  ```
  test -f scripts/launch-evelynn.sh && echo OK1
  test -f scripts/restart-evelynn.ps1 && echo OK2
  test -f windows-mode/launch-evelynn.bat && echo OK3
  test -f windows-mode/launch-evelynn.ps1 && echo OK4
  test -f windows-mode/launch-yuumi.bat && echo OK5
  test -f windows-mode/README.md && echo OK6
  test -f agents/launch-agent.sh && echo OK7
  test -f agents/boot.sh && echo OK8
  ```
  Expect all eight OK lines. If any source is missing, STOP and escalate.
- [ ] Check whether phase-1-detailed has already landed: `test -f architecture/platform-parity.md && echo EXISTS || echo NEW`. Record the result.
- [ ] Check whether `scripts/mac/` and `scripts/windows/` already exist (phase-1-detailed Step 4 creates them): `test -d scripts/mac && echo MAC_EXISTS; test -d scripts/windows && echo WIN_EXISTS`.

### Step 5.2 — Create target directories (idempotent)

- [ ] `mkdir -p scripts/mac scripts/windows`

### Step 5.3 — Move the six files

- [ ] Move, one per line, as `git mv`:
  ```
  git mv scripts/launch-evelynn.sh scripts/mac/launch-evelynn.sh
  git mv scripts/restart-evelynn.ps1 scripts/windows/restart-evelynn.ps1
  git mv windows-mode/launch-evelynn.bat scripts/windows/launch-evelynn.bat
  git mv windows-mode/launch-evelynn.ps1 scripts/windows/launch-evelynn.ps1
  git mv windows-mode/launch-yuumi.bat scripts/windows/launch-yuumi.bat
  git mv windows-mode/README.md scripts/windows/README.md
  ```
- [ ] `rmdir windows-mode` (should be empty now).

### Step 5.4 — Delete the two stale scripts

- [ ] `git rm agents/launch-agent.sh agents/boot.sh`

### Step 5.5 — Create or edit `architecture/platform-parity.md`

**If the file does NOT exist** (phase-1-detailed hasn't landed yet), create it with this exact content:

```markdown
# Platform Parity

Strawberry runs on macOS (primary) and Windows (Git Bash + Claude Code subagents). All skills and scripts are POSIX-portable by default. Platform-specific affordances are listed explicitly here and only here.

## Intent

See `plans/proposed/2026-04-09-operating-protocol-v2.md` Layer 0 for the governance contract. This document is the single source of truth for what is Mac-only, what is Windows-only, and what each platform does in place of the other.

## Skill parity

| skill | macOS | Windows | notes |
|---|---|---|---|
| `/end-session` | supported | supported | POSIX-only body. |
| `/end-subagent-session` | supported | supported | POSIX-only body. |

(Additional skills shipped by in-flight plans will add rows here as they land.)

## Script parity

| script | macOS | Windows | notes |
|---|---|---|---|
| `scripts/mac/launch-evelynn.sh` | supported | NOT SUPPORTED | Mac iTerm launcher for Evelynn. Windows uses Task subagent. |
| `scripts/windows/restart-evelynn.ps1` | NOT SUPPORTED | supported | Windows-only PowerShell restart helper. Marked for deletion under Operating Protocol v2 / MCP restructure D4. |
| `scripts/windows/launch-evelynn.bat` | NOT SUPPORTED | supported | Windows batch launcher. |
| `scripts/windows/launch-evelynn.ps1` | NOT SUPPORTED | supported | Windows PowerShell launcher. |
| `scripts/windows/launch-yuumi.bat` | NOT SUPPORTED | supported | Windows batch launcher for Yuumi. |
| `scripts/safe-checkout.sh` | supported | supported | POSIX. Required by CLAUDE.md Rule 5. |
| `scripts/plan-promote.sh` | supported | supported | POSIX. Required by CLAUDE.md Rule 12. |
| `scripts/plan-publish.sh` | supported | supported | POSIX. Drive mirror publish path. |
| `scripts/plan-unpublish.sh` | supported | supported | POSIX. Drive mirror unpublish path. |
| `scripts/plan-fetch.sh` | supported | supported | POSIX. Drive mirror fetch path. |
| `scripts/clean-jsonl.py` | supported | supported | Python. Used by /end-session. |
| `scripts/pre-commit-secrets-guard.sh` | supported | supported | POSIX. Required by CLAUDE.md Rule 11. |

(Other `scripts/*` files are pending a classification audit. They remain at the top level until the audit confirms portability or moves them.)

## MCP parity

`agent-manager` and `evelynn` MCPs are pending the restructure per `plans/proposed/2026-04-08-mcp-restructure.md`. Both are currently Mac-assumption-heavy; Phase 1 migrates `agent-manager` to `/agent-ops` on both platforms.

## Launcher parity rule

**Windows has no Claude-invoked agent launcher.** Windows agent spawning is via the Claude Code `Task` subagent tool exclusively. The `.bat`/`.ps1` files under `scripts/windows/` are human-invoked (by Duong, from a Windows terminal), NOT Claude-invoked.

## Cross-references

- `plans/proposed/2026-04-09-operating-protocol-v2.md` Layer 0
- `plans/proposed/2026-04-09-mcp-restructure-phase-1-detailed.md`
- `plans/proposed/2026-04-09-protocol-migration-detailed.md` commit 5
- `CLAUDE.md` Rules 16/17/18/19 (once numbered per Commit 9 verification)
```

**If the file DOES exist** (phase-1-detailed landed first), EDIT it:

- [ ] Find the `## Script parity` section.
- [ ] Add the five new rows from the table above (for `scripts/mac/launch-evelynn.sh`, `scripts/windows/restart-evelynn.ps1`, the three `scripts/windows/launch-*` files, and `scripts/windows/launch-yuumi.bat`). Insert them alphabetically or grouped by platform — match the existing file's style.
- [ ] Add an entry in cross-references pointing at `plans/proposed/2026-04-09-protocol-migration-detailed.md commit 5`.
- [ ] Do NOT rewrite any existing rows or sections.

### Step 5.6 — Smoke test

- [ ] Each moved file at its new path:
  ```
  test -f scripts/mac/launch-evelynn.sh && \
  test -f scripts/windows/restart-evelynn.ps1 && \
  test -f scripts/windows/launch-evelynn.bat && \
  test -f scripts/windows/launch-evelynn.ps1 && \
  test -f scripts/windows/launch-yuumi.bat && \
  test -f scripts/windows/README.md && \
  echo OK
  ```
  Expect `OK`.
- [ ] Sources gone: `ls windows-mode agents/launch-agent.sh agents/boot.sh 2>/dev/null; echo $?` — expect non-zero.
- [ ] `test -f architecture/platform-parity.md && echo OK`.
- [ ] `git status --short` shows the moves as renames and any deletions/additions as expected.

### Step 5.7 — Commit

- [ ] `git add architecture/platform-parity.md scripts/mac scripts/windows`
- [ ] Commit message:
  ```
  chore: classify platform-specific scripts (protocol migration commit 5 of 9)

  Moves:
    scripts/launch-evelynn.sh         -> scripts/mac/launch-evelynn.sh
    scripts/restart-evelynn.ps1       -> scripts/windows/restart-evelynn.ps1
    windows-mode/launch-evelynn.bat   -> scripts/windows/launch-evelynn.bat
    windows-mode/launch-evelynn.ps1   -> scripts/windows/launch-evelynn.ps1
    windows-mode/launch-yuumi.bat     -> scripts/windows/launch-yuumi.bat
    windows-mode/README.md            -> scripts/windows/README.md

  Deletes:
    agents/launch-agent.sh  (hardcoded wrong path, unused Mac iTerm launcher)
    agents/boot.sh          (Irelia boot-prompt generator; Irelia retired in commit 1)

  <CREATES or EDITS> architecture/platform-parity.md with classification rows
  for the moved scripts.

  Empty windows-mode/ directory removed.

  Out of scope: scripts/gh-*, scripts/*-bridge.sh, scripts/setup-*,
  scripts/google-oauth-bootstrap.sh, and related helpers remain at the top
  level pending a classification audit (Operating Protocol v2 Layer 0 debt
  list). This commit moves only files whose platform is obvious from
  extension or shebang-level osascript usage.

  Refs: plans/proposed/2026-04-09-protocol-migration-detailed.md commit 5
        plans/proposed/2026-04-09-operating-protocol-v2.md Layer 0
        assessments/2026-04-08-protocol-leftover-audit.md §3, §8.5
  ```
  Replace `<CREATES or EDITS>` with the appropriate verb based on the Step 5.1 result.

---

## Commit 6 — Move per-agent iTerm background blobs

**Scope:** 13 tracked `agents/<name>/iterm/background.jpg` files are per-agent Mac-only affordances committed into per-agent directories. Operating Protocol v2 Layer 0 invariant 3 forbids this: per-agent directories contain no platform state.

**Decision:** consolidate all backgrounds into `scripts/mac/iterm-backgrounds/<name>.jpg` (Mac-only, classified, one location), and delete the per-agent `iterm/` directories.

### Step 6.1 — Preflight

- [ ] `git status --short` empty.
- [ ] Enumerate the 13 tracked files:
  ```
  git ls-files 'agents/*/iterm/background.jpg'
  ```
  Expect exactly these 13 paths (order may vary):
  ```
  agents/bard/iterm/background.jpg
  agents/caitlyn/iterm/background.jpg
  agents/evelynn/iterm/background.jpg
  agents/fiora/iterm/background.jpg
  agents/katarina/iterm/background.jpg
  agents/lissandra/iterm/background.jpg
  agents/neeko/iterm/background.jpg
  agents/ornn/iterm/background.jpg
  agents/pyke/iterm/background.jpg
  agents/reksai/iterm/background.jpg
  agents/swain/iterm/background.jpg
  agents/syndra/iterm/background.jpg
  agents/zoe/iterm/background.jpg
  ```
  If the set differs (more or fewer), adjust the loop below accordingly — but do NOT add new agents or skip listed ones silently.

### Step 6.2 — Create target directory

- [ ] `mkdir -p scripts/mac/iterm-backgrounds`

### Step 6.3 — Move each background

- [ ] For each path in the list, run:
  ```
  git mv agents/<name>/iterm/background.jpg scripts/mac/iterm-backgrounds/<name>.jpg
  ```
  Concretely, the 13 commands:
  ```
  git mv agents/bard/iterm/background.jpg scripts/mac/iterm-backgrounds/bard.jpg
  git mv agents/caitlyn/iterm/background.jpg scripts/mac/iterm-backgrounds/caitlyn.jpg
  git mv agents/evelynn/iterm/background.jpg scripts/mac/iterm-backgrounds/evelynn.jpg
  git mv agents/fiora/iterm/background.jpg scripts/mac/iterm-backgrounds/fiora.jpg
  git mv agents/katarina/iterm/background.jpg scripts/mac/iterm-backgrounds/katarina.jpg
  git mv agents/lissandra/iterm/background.jpg scripts/mac/iterm-backgrounds/lissandra.jpg
  git mv agents/neeko/iterm/background.jpg scripts/mac/iterm-backgrounds/neeko.jpg
  git mv agents/ornn/iterm/background.jpg scripts/mac/iterm-backgrounds/ornn.jpg
  git mv agents/pyke/iterm/background.jpg scripts/mac/iterm-backgrounds/pyke.jpg
  git mv agents/reksai/iterm/background.jpg scripts/mac/iterm-backgrounds/reksai.jpg
  git mv agents/swain/iterm/background.jpg scripts/mac/iterm-backgrounds/swain.jpg
  git mv agents/syndra/iterm/background.jpg scripts/mac/iterm-backgrounds/syndra.jpg
  git mv agents/zoe/iterm/background.jpg scripts/mac/iterm-backgrounds/zoe.jpg
  ```

### Step 6.4 — Remove now-empty per-agent iterm directories

- [ ] For each agent that had an `iterm/` dir: `rmdir agents/<name>/iterm` for all 13. If any `rmdir` fails because the directory is not empty, STOP — there was content other than `background.jpg` the audit didn't see, escalate.
- [ ] Check for a Katarina exception: `ls agents/katarina/iterm 2>/dev/null; echo $?` — non-zero expected. Same for the other 12.

### Step 6.5 — Add platform-parity row

- [ ] Edit `architecture/platform-parity.md`.
- [ ] Under `## Script parity`, add one row:
  ```
  | `scripts/mac/iterm-backgrounds/*.jpg` | supported | NOT SUPPORTED | Per-agent iTerm2 background images. Used by the Mac iTerm launcher. Not relevant on Windows. |
  ```

### Step 6.6 — Smoke test

- [ ] `ls scripts/mac/iterm-backgrounds/*.jpg | wc -l` — expect `13` (or whatever count was found in Step 6.1).
- [ ] `git ls-files 'agents/*/iterm/**' | wc -l` — expect `0`.
- [ ] `git status --short` shows 13 renames.

### Step 6.7 — Commit

- [ ] Commit message:
  ```
  chore: move per-agent iterm backgrounds to scripts/mac/ (protocol migration commit 6 of 9)

  Operating Protocol v2 Layer 0 invariant 3: per-agent directories under
  agents/<name>/ contain no platform-specific state. Moved 13 tracked
  background.jpg files out of agents/<name>/iterm/ into one consolidated
  Mac-only location at scripts/mac/iterm-backgrounds/<name>.jpg. Removed
  the now-empty per-agent iterm/ directories.

  Updated architecture/platform-parity.md with the new row.

  The Mac iTerm launcher (scripts/mac/launch-evelynn.sh and future siblings)
  must update their background-image references in a follow-up plan; this
  commit is a pure file move and does NOT edit any launcher script.

  Refs: plans/proposed/2026-04-09-protocol-migration-detailed.md commit 6
        plans/proposed/2026-04-09-operating-protocol-v2.md Layer 0 invariant 3
        assessments/2026-04-08-protocol-leftover-audit.md §1 (per-agent iterm/ row)
  ```

---

## Commit 7 — Roster consolidation

**Scope:** Operating Protocol v2 §1.1 and new Rule 18 make `agents/memory/agent-network.md` the single roster. `agents/roster.md` is deprecated. Swain's §"Open questions" item 3 leans toward option (a): delete `agents/roster.md` entirely. This plan implements option (a) and adds a stub pointer file if any existing reference would otherwise break.

**Limit of scope:** this commit does NOT rewrite `agents/memory/agent-network.md`'s coordination sections (Communication Tools, Protocol §1-§10, Conversation modes). Those are owned by phase-1-detailed Step 10. This commit only updates the roster portions of both files.

**Shen handling:** CLAUDE.md Rule 15 lists Shen as an active Sonnet agent. He is currently in `agents/roster.md` but NOT in `agents/memory/agent-network.md`. This commit adds him to `agents/memory/agent-network.md`'s roster. It does NOT create `.claude/agents/shen.md` (out of scope per "What this plan does NOT do").

**Rakan handling (updated per Swain 2026-04-09 amendment — v2 Q5 resolved as "aspirational, not wired"):** Rakan stays in `agents/memory/agent-network.md` with an explicit `(aspirational)` status marker so the row is clearly non-invokable. Same treatment applies to Ornn and Fiora, which are currently listed without any status marker but are equally aspirational — neither has a `.claude/agents/<name>.md` harness profile, neither is wired as a subagent, neither is part of the actual Sonnet executor pool (katarina + yuumi per the model-tier memory). Rakan's `agents/rakan/` directory is left alone by this commit (its disposition is a separate question for Duong).

The aspirational marker is a column addition: the table gains a `Status` column. Wired agents get `active`. Ornn, Fiora, and Rakan get `aspirational — not wired`. This is the smallest-blast-radius form of the marker (no row deletion, no body text change).

### Step 7.1 — Preflight

- [ ] `git status --short` empty.
- [ ] Confirm both files exist: `test -f agents/roster.md && test -f agents/memory/agent-network.md && echo OK`.
- [ ] Search for any code or scripts that reference `agents/roster.md` by path:
  ```
  grep -rn "agents/roster.md" --include='*.sh' --include='*.py' --include='*.md' . 2>/dev/null | grep -v '^\./plans/' | grep -v '^\./assessments/'  ```
  Record the result. If there are non-doc references (shell/Python scripts), they need a pointer file; if matches are doc-only, a full delete is fine.

### Step 7.2 — Read current `agent-network.md` roster section

- [ ] Read `agents/memory/agent-network.md` lines 1-30 to confirm the current roster table. The current table (as of audit) lists: Evelynn, Katarina, Ornn, Fiora, Lissandra, Rek'Sai, Pyke, Bard, Syndra, Swain, Neeko, Zoe, Caitlyn, Yuumi, Poppy. Shen is missing.

### Step 7.3 — Add `Status` column to the roster table and backfill every row

- [ ] Read the existing roster table header in `agents/memory/agent-network.md`. It currently has four columns: `Agent | Role | Domain |`.
- [ ] Rewrite the header row to add a `Status` column as the final column:
  ```
  | Agent | Role | Domain | Status |
  |---|---|---|---|
  ```
- [ ] For every existing row, append `| active |` as the trailing cell EXCEPT for the Ornn and Fiora rows, which get `| aspirational — not wired |`. Exact edits:
  - Ornn row: old `| **Ornn** | Fullstack — New Features | Greenfield builds |` → new `| **Ornn** | Fullstack — New Features | Greenfield builds | aspirational — not wired |`
  - Fiora row: old `| **Fiora** | Fullstack — Bugfix & Refactor | Root cause, refactoring |` → new `| **Fiora** | Fullstack — Bugfix & Refactor | Root cause, refactoring | aspirational — not wired |`
  - All other existing rows (Evelynn, Katarina, Lissandra, Rek'Sai, Pyke, Bard, Syndra, Swain, Neeko, Zoe, Caitlyn, Yuumi, Poppy): append `| active |`.
- [ ] Immediately after the Pyke row, insert the new Shen row with the Status column:
  ```
  | **Shen** | Git & IT Security — Implementation | Sonnet executor for Pyke's git/security plans | active |
  ```
- [ ] Add a new Rakan row immediately after the Shen row (Rakan is currently absent from `agent-network.md` entirely; per Swain's v2 Q5 resolution, he belongs in the roster with the aspirational marker so readers know the `agents/rakan/` directory is intentional-but-inert):
  ```
  | **Rakan** | Fullstack — pair partner (planned) | TBD | aspirational — not wired |
  ```
  If Rakan is ALREADY present in `agents/memory/agent-network.md` at the time of execution (state drift since audit), do not insert a duplicate row — instead, append the `aspirational — not wired |` cell to the existing row and skip this step.

### Step 7.4 — Delete `agents/roster.md`

- [ ] If Step 7.1 found ONLY doc references (grep result was empty after the grep filters): `git rm agents/roster.md`.
- [ ] If Step 7.1 found shell/Python references: STOP. Escalate. A pointer file instead of deletion may be needed, but that is a design decision outside this plan's scope.

### Step 7.5 — Smoke test

- [ ] `test ! -f agents/roster.md && echo OK` prints OK.
- [ ] `grep -c "Shen" agents/memory/agent-network.md` — expect at least 1.
- [ ] `grep -c "Irelia" agents/memory/agent-network.md` — expect 0 (Irelia was already absent per Commit 1 Step 1.6).
- [ ] `grep -c "aspirational — not wired" agents/memory/agent-network.md` — expect exactly 3 (Ornn, Fiora, Rakan).
- [ ] `grep -c "| active |" agents/memory/agent-network.md` — expect at least 12 (all other roster rows).

### Step 7.6 — Commit

- [ ] Commit message:
  ```
  chore: consolidate roster into agent-network.md (protocol migration commit 7 of 9)

  Operating Protocol v2 §1.1 and Rule 18 make agents/memory/agent-network.md
  the single source of truth for the agent roster. Implementing Swain's
  leaned option (a): delete agents/roster.md entirely.

  - Added Shen row to agents/memory/agent-network.md (active Sonnet tier per
    CLAUDE.md Rule 15; he was missing from agent-network.md before).
  - Deleted agents/roster.md.

  Scope limits:
  - This commit does NOT rewrite the Communication Tools, Protocol §1-§10,
    or Conversation modes sections of agent-network.md. Those belong to the
    phase-1 MCP restructure Step 10.
  - This commit does NOT create .claude/agents/shen.md. Creating a subagent
    profile is design work owned by Evelynn and/or the agent's lead.
  - Added a Status column to the roster table. All wired agents are marked
    "active"; Ornn, Fiora, and Rakan are marked "aspirational — not wired"
    per Swain's v2 Q5 resolution on 2026-04-09 (they stay in the roster as
    intentional-but-inert rows so readers know the agents/<name>/ directories
    are not bugs but deferred work). agents/rakan/ directory itself is
    untouched by this commit.

  Refs: plans/proposed/2026-04-09-protocol-migration-detailed.md commit 7
        plans/proposed/2026-04-09-operating-protocol-v2.md §1.1, §2.9
        assessments/2026-04-08-protocol-leftover-audit.md §1, §8.2, §8.3
  ```

---

## Commit 8 — Delete one-shot migration artifact + collapse duplicate git-workflow doc

**Scope:**

- Delete `scripts/migrate-ops.sh` — one-shot migration script, already executed weeks ago, no longer needed.
- Collapse `GIT_WORKFLOW.md` (repo root) + `architecture/git-workflow.md` into one file at `architecture/git-workflow.md`. The root-level one is older; the architecture/ one is newer. Keep the architecture/ version and delete the root.

**Parity note:** `migrate-ops.sh` is POSIX bash, so the delete is platform-neutral. The git-workflow doc merge is doc-only, also platform-neutral.

### Step 8.1 — Preflight

- [ ] `git status --short` empty.
- [ ] Confirm targets: `test -f scripts/migrate-ops.sh && test -f GIT_WORKFLOW.md && test -f architecture/git-workflow.md && echo OK`.
- [ ] Compare the two git-workflow files to confirm `architecture/git-workflow.md` is complete (not a stub):
  ```
  wc -l GIT_WORKFLOW.md architecture/git-workflow.md
  ```
  Record the line counts. If `architecture/git-workflow.md` is shorter than `GIT_WORKFLOW.md`, STOP and escalate — the assumption that architecture/ is the newer/complete one is wrong.

### Step 8.2 — Diff the two files and capture root-only content

- [ ] `diff GIT_WORKFLOW.md architecture/git-workflow.md > /tmp/gitworkflow.diff || true`
- [ ] Read `/tmp/gitworkflow.diff`. If the root file contains sections the architecture/ file does NOT have, copy those sections into `architecture/git-workflow.md` via `Edit`, preserving surrounding formatting. Do NOT delete any content from `architecture/git-workflow.md`.
- [ ] If the diff is empty or the root file is a strict subset of the architecture/ file, no edit is needed.
- [ ] Delete `/tmp/gitworkflow.diff` after use.

### Step 8.3 — Delete the two targets

- [ ] `git rm scripts/migrate-ops.sh GIT_WORKFLOW.md`

### Step 8.4 — Check for references to the deleted paths

- [ ] `grep -rn "GIT_WORKFLOW.md\|scripts/migrate-ops.sh" --include='*.md' --include='*.sh' . 2>/dev/null | grep -v '^\./agents/.archive/' | grep -v '^\./plans/implemented/' | grep -v '^\./plans/archived/' | grep -v '^\./assessments/'`
- [ ] If there are matches under agent memory files, active plans, or architecture docs, edit each to point at `architecture/git-workflow.md` instead (for GIT_WORKFLOW.md) or remove the reference entirely (for migrate-ops.sh). Use `Edit` per file.

### Step 8.5 — Smoke test

- [ ] `test ! -f GIT_WORKFLOW.md && test ! -f scripts/migrate-ops.sh && test -f architecture/git-workflow.md && echo OK`.
- [ ] `grep -rn "GIT_WORKFLOW.md" --include='*.md' --include='*.sh' . 2>/dev/null | grep -v '^\./agents/.archive/' | grep -v '^\./plans/implemented/' | grep -v '^\./plans/archived/' | grep -v '^\./assessments/'` — expect empty output.

### Step 8.6 — Commit

- [ ] Commit message:
  ```
  chore: delete stale migration script + collapse duplicate git-workflow doc (protocol migration commit 8 of 9)

  - Deleted scripts/migrate-ops.sh — one-shot migration script from the ops
    separation work weeks ago. Already executed, no remaining purpose.
  - Deleted GIT_WORKFLOW.md from repo root; architecture/git-workflow.md is
    the canonical location. Merged any root-only content into the
    architecture/ version first.
  - Updated N references (list per-file if any) to point at
    architecture/git-workflow.md.

  Refs: plans/proposed/2026-04-09-protocol-migration-detailed.md commit 8
        assessments/2026-04-08-protocol-leftover-audit.md §3, §6
  ```
  Replace `N` with the actual count from Step 8.4.

---

## Commit 9 — Rule-numbering verification, stale plan triage flag, audit cross-reference

**Scope:** The final commit is primarily documentation: verify CLAUDE.md rule numbering is consistent with what the in-flight plans collectively described, flag the four stale `plans/proposed/` entries for Duong's triage, and add a pointer from `architecture/platform-parity.md` to this migration plan.

**No destructive actions.** Only reads, one edit, and one commit.

### Step 9.1 — Verify CLAUDE.md rule numbering

- [ ] Read `CLAUDE.md` and locate every "Critical Rules" numbered entry.
- [ ] Record the current highest rule number. Expected scenarios:

  **Scenario A — This plan lands LAST** (after phase-1-detailed and operating-protocol-v2 have both committed):
  - Expected rules 15 through 19 in this order:
    - 15: model-tier declaration (already landed)
    - 16: MCP-only-for-external (from phase-1-detailed Step 11)
    - 17: POSIX portability (from phase-1-detailed Step 11)
    - 18: Roster single source of truth (from operating-protocol-v2 §2.9)
    - 19: Universal cross-platform parity (from operating-protocol-v2 §2.10)
  - Verify each rule number matches the expected content. If 16/17/18/19 are present and correct, do nothing.

  **Scenario B — This plan lands FIRST or MIDDLE** (phase-1-detailed or operating-protocol-v2 has not committed yet):
  - The highest rule is 15 or the numbering is incomplete.
  - STOP. Do NOT attempt to backfill the missing rules in this commit — those rules are owned by their source plans.
  - Add a note to Commit 9's body (Step 9.5) stating which rules were missing and that Commit 9 landed in a pre-convergence state.

- [ ] If the numbering is *wrong* (e.g., phase-1-detailed landed with rules 15/16 instead of 16/17, ignoring the already-landed Rule 15), STOP and escalate. Do not rewrite rule numbers in this migration plan — that is a governance decision for Evelynn.

### Step 9.2 — Flag stale `plans/proposed/` entries

Four plans from 2026-04-03 to 2026-04-05 are sitting in `plans/proposed/` with no movement. They need triage (either promote or archive), but triage is a Duong decision, not a migration action.

- [ ] Enumerate the stale files:
  ```
  plans/proposed/2026-04-03-discord-cli-integration.md
  plans/proposed/2026-04-05-gh-auth-lockdown.md
  plans/proposed/2026-04-05-launch-verification.md
  plans/proposed/2026-04-05-plan-viewer.md
  ```
- [ ] For each, confirm the file still exists (`test -f ... && echo OK`). If any were already moved out of proposed/, drop them from the list.
- [ ] Do NOT edit, move, or archive any of these files. They are flagged in the Commit 9 body and in the Step 10 push message for Duong.
- [ ] Also flag: `plans/proposed/2026-04-08-end-session-skill.md` may be a duplicate of work that already landed (commit `dc638bb` enabled `/end-session` model invocation, implying Phase 1 is implemented). Do NOT move this file either; flag it for Duong.

### Step 9.3 — Add cross-reference row to `architecture/platform-parity.md`

- [ ] Edit `architecture/platform-parity.md`.
- [ ] Find the `## Cross-references` section.
- [ ] If a line for `plans/proposed/2026-04-09-protocol-migration-detailed.md commit 5` already exists (added in Commit 5 or Commit 6), append a new line for `commit 6` and `commit 9` so all three commits this plan adds to the file are referenced.
- [ ] Exact text to add if not already present:
  ```
  - `plans/proposed/2026-04-09-protocol-migration-detailed.md` (commits 5, 6, 9)
  ```

### Step 9.4 — Smoke test

- [ ] `grep -c "protocol-migration-detailed" architecture/platform-parity.md` — expect at least 1.
- [ ] `git status --short` shows only `architecture/platform-parity.md` as modified.

### Step 9.5 — Commit

- [ ] Commit message:
  ```
  chore: protocol migration verification + stale-plan flags (protocol migration commit 9 of 9)

  Rule numbering verification:
    CLAUDE.md highest rule: <N>
    Expected after convergence: 19
    Status: <CONVERGED | PARTIAL — missing rules X, Y | WRONG-ORDER — see escalation>

  Stale plans/proposed/ entries flagged for Duong's triage (no action taken):
    - plans/proposed/2026-04-03-discord-cli-integration.md
    - plans/proposed/2026-04-05-gh-auth-lockdown.md
    - plans/proposed/2026-04-05-launch-verification.md
    - plans/proposed/2026-04-05-plan-viewer.md
    - plans/proposed/2026-04-08-end-session-skill.md (possibly duplicate of
      already-landed end-session work — verify before promotion)

  Added cross-reference row to architecture/platform-parity.md linking to
  this migration plan.

  This commit is the verification gate before Commit 10 (post-phase-1
  drift sweep).

  Outstanding work after this plan lands:
    1. Rakan classification (Operating Protocol v2 §open-questions item 5).
    2. Script classification audit for scripts/gh-*, scripts/*-bridge.sh,
       scripts/setup-*, scripts/google-oauth-bootstrap.sh, scripts/_lib_gdoc.sh,
       scripts/vps-setup.sh, scripts/deploy.sh, scripts/result-watcher.sh,
       scripts/health-check.sh. (Operating Protocol v2 Layer 0 debt list.)
    3. Creation of .claude/agents/<name>.md files for the 7 agents not yet
       in the harness roster (evelynn, ornn, fiora, reksai, neeko, zoe,
       caitlyn, shen) — design work, owned by Evelynn.
    4. Stale plan triage per the flags above.
    5. Two health surfaces: scripts/health-check.sh vs agents/health/heartbeat.sh
       still unconsolidated.
    6. strawberry and strawberry.pub (repo-root files) are untouched; they
       are not git-tracked and appear to be SSH keys. Leave alone.
    7. scripts/test_plan_gdoc_offline.sh location review.
    8. Duplicate-plan check for plans/proposed/2026-04-08-end-session-skill.md.

  Refs: plans/proposed/2026-04-09-protocol-migration-detailed.md commit 9
        plans/proposed/2026-04-09-operating-protocol-v2.md
        assessments/2026-04-08-protocol-leftover-audit.md
  ```
  Replace `<N>` and the `<CONVERGED ...>` line with the actual values from Step 9.1.

---

## Commit 10 — Post-phase-1 legacy-tool-name drift sweep

**Scope:** Phase-1-detailed MCP restructure Step 6/7 performs a repo-wide grep for the legacy `agent-manager` MCP tool names and replaces them with `/agent-ops` skill forms or the Teams/subagent vocabulary. That sweep has a baseline of ~53 files enumerated at the time Bard wrote phase-1. But any file *added or modified* after Bard's baseline — including the operating-protocol-v2 plan itself, evelynn-continuity-and-purity, this migration plan, any new agent profiles under `.claude/agents/`, and any learnings written during the transition window — can quietly reintroduce legacy tool names. Swain flagged this on 2026-04-09: the retirement of the legacy surface is absolute (v2 §3.3 "no parallel channels"), so a second sweep scoped to the drift window is required.

**Why this is a separate commit, not an extension of phase-1 Step 7:** phase-1 Step 7 lands together with the MCP deregistration in a single atomic commit (per phase-1 Step 14 ordering guarantee). This migration plan lands *after* phase-1. Any drift that slipped in between phase-1's grep and this plan's execution is by definition invisible to phase-1 Step 7 and can only be caught by a second sweep done at *this* plan's execution time. The sweep is informational/cleanup, not part of the phase-1 atomic bundle.

**Relationship to v2 §3.3:** v2 Layer 3 §3.3 "no parallel channels" is the load-bearing clause. This commit is the enforcement arm for §3.3 against drift: every caught reference is either a documentation fossil (replaced with the new vocabulary) or an intentional historical citation in a plan body (left alone with an inline `(retired, see v2 §3.2)` annotation). The executor does NOT invent new replacement text — use the exact replacement table from phase-1 Step 7.

**Scope boundary — do NOT touch:**

- `plans/implemented/`, `plans/archived/` — historical record, out of Task #3 scope.
- `agents/*/journal/`, `agents/*/transcripts/`, `agents/*/learnings/*` older than 2026-04-08 — historical record.
- `mcps/agent-manager/` — the archived MCP source itself; its own tool names are expected.
- `plans/proposed/2026-04-09-operating-protocol-v2.md` §3.2 — that section is the *definitional* retirement list; its use of the tool names is the point, not a leak. Leave every occurrence in §3.2 alone.
- Any occurrence inside a fenced code block that is quoting a historical tool call for illustration (pattern: preceded by "e.g.", "previously:", "retired:", or similar). Leave alone with an inline annotation if the context isn't already clear.

### Step 10.1 — Preflight

- [ ] `git status --short` empty (Commit 9 just landed).
- [ ] Confirm phase-1-detailed has landed (Scenario A from Commit 9 Step 9.1). If it has NOT, STOP — this sweep is meaningless before phase-1's own sweep. Escalate to Evelynn.
- [ ] Record the current HEAD commit: `git rev-parse HEAD`.

### Step 10.2 — Run the drift sweep

- [ ] Run the same grep set phase-1 Step 6 uses, but scoped explicitly to files that are candidates for drift (added or modified since phase-1's grep baseline). Use a file-list-then-grep two-step so the executor can see which files are candidates first:
  ```
  # Files changed since 2026-04-09 (the phase-1 landing date — executor adjusts if needed)
  git log --since=2026-04-09 --name-only --format= | sort -u > /tmp/drift-candidates.txt
  # Filter to documentation-class files only
  grep -E '\.(md|MD)$' /tmp/drift-candidates.txt > /tmp/drift-candidates-docs.txt
  ```
- [ ] Grep those candidates for every deprecated tool name (exact list from operating-protocol-v2 §3.2):
  ```
  xargs -a /tmp/drift-candidates-docs.txt grep -nE '\b(list_agents|get_agent|create_agent|launch_agent|message_agent|start_turn_conversation|speak_in_turn|pass_turn|end_turn_conversation|read_new_messages|get_turn_status|invite_to_conversation|escalate_conversation|resolve_escalation|delegate_task|complete_task|check_delegations|report_context_health)\b' 2>/dev/null > /tmp/drift-hits.txt
  ```
- [ ] Additionally, grep the full `plans/proposed/`, `.claude/agents/`, `agents/memory/`, and `agents/*/learnings/` trees unconditionally — these are the locations most likely to have drift regardless of modification date:
  ```
  grep -rnE '\b(list_agents|get_agent|create_agent|launch_agent|message_agent|start_turn_conversation|speak_in_turn|pass_turn|end_turn_conversation|read_new_messages|get_turn_status|invite_to_conversation|escalate_conversation|resolve_escalation|delegate_task|complete_task|check_delegations|report_context_health)\b' plans/proposed/ .claude/agents/ agents/memory/ 2>/dev/null >> /tmp/drift-hits.txt
  ```
- [ ] De-duplicate: `sort -u /tmp/drift-hits.txt > /tmp/drift-hits-unique.txt`.
- [ ] Read `/tmp/drift-hits-unique.txt`. For every line:
  - Determine whether the file is in the do-not-touch list above. If so, skip.
  - Determine whether the match is inside operating-protocol-v2 §3.2 specifically. If so, skip.
  - Determine whether the match is in a historical citation / illustration (fenced code block preceded by "retired:", "e.g.", "previously:", "was:", or in an explicit `##` heading named "Deprecated" or "Retired"). If so, leave the tool name but, if the annotation is missing, insert an inline `(retired, see v2 §3.2)` immediately after the tool name via `Edit`.
  - Otherwise, it is a live reference. Replace it using the exact replacement table from phase-1-detailed Step 7 (do NOT invent new replacement text).

### Step 10.3 — Expected match set (pre-execution sanity check)

At the time this plan was written, the known-drift files and counts were:

- `plans/proposed/2026-04-09-operating-protocol-v2.md` — 4 references, all inside §3.2's deprecation list. Expected to be SKIPPED by Step 10.2's §3.2 filter.
- `plans/proposed/2026-04-08-evelynn-continuity-and-purity.md` — 0 references (verified 2026-04-09).
- `plans/proposed/2026-04-09-protocol-migration-detailed.md` (this plan) — this plan itself references the tool names only in Commit 10's own text and in this sanity check. Those occurrences are historical / meta and should be SKIPPED by the "illustration" filter; no edits to this plan needed.
- `.claude/agents/*.md` — 0 references (none of the 8 existing harness profiles reference legacy MCP tool names).
- `agents/memory/agent-network.md` — this file was already rewritten by phase-1 Step 10, so any remaining references are expected to be in the **Phase 1 deferral note** about delegation tracking, which is intentional. SKIP if the match is inside the phase-1-authored deferral block.

If the actual grep output substantially exceeds this expected set (more than ~5 unexpected live references), STOP and escalate. A large drift count means either phase-1 didn't land cleanly or new plans/profiles were written without following v2 §3.3 — both are governance issues for Evelynn, not mechanical edits for the executor.

### Step 10.4 — Smoke test

- [ ] Re-run the grep from Step 10.2. Remaining hits must all be in the allowlist (do-not-touch list, §3.2, annotated historical citations).
- [ ] `git status --short` — list of modified files must match the set the executor edited in Step 10.2. No unexpected modifications.

### Step 10.5 — Commit

- [ ] Stage only the files modified by this step: `git add <paths>` (do NOT `git add -A`).
- [ ] Commit message:
  ```
  chore: post-phase-1 legacy-tool drift sweep (protocol migration commit 10 of 10)

  Second grep pass for legacy agent-manager MCP tool names, scoped to files
  added or modified after Bard's phase-1-detailed grep baseline. Enforces
  the operating-protocol-v2 §3.3 "no parallel channels" clause against any
  drift that slipped in during the transition window.

  Files swept: <N> documentation files (git-log-since-2026-04-09 filter +
  unconditional sweep of plans/proposed/, .claude/agents/, agents/memory/).

  Live references replaced: <M>
  Historical citations annotated with "(retired, see v2 §3.2)": <K>
  Allowlisted skips (v2 §3.2 deprecation list, phase-1 deferral blocks,
  illustration blocks): <L>

  No new CLAUDE.md rules added. This commit is enforcement of v2 §3.3,
  not a new governance surface.

  Commit 10 of 10 in the protocol migration sequence. Closes the sequence.

  Refs: plans/proposed/2026-04-09-protocol-migration-detailed.md commit 10
        plans/proposed/2026-04-09-operating-protocol-v2.md §3.2, §3.3
        plans/proposed/2026-04-09-mcp-restructure-phase-1-detailed.md Step 6, Step 7
  ```
  Replace `<N>`, `<M>`, `<K>`, `<L>` with actual counts.

---

## Step 11 — Final push + report

After all ten commits have landed locally:

- [ ] `git log --oneline -n 12` — verify the ten commits are present in the expected order and each uses `chore:` prefix.
- [ ] `git push origin main` — single push for the whole sequence. If the push fails (pre-push hook rejects `chore:` prefix check, branch-protection block, etc.), STOP and escalate — do NOT force-push or amend.
- [ ] Report to Evelynn via SendMessage. Include:
  - The ten commit hashes (from `git log --oneline -n 10 --format='%h %s'`).
  - The counts captured during smoke tests: conversation-file delete count (Commit 3 Step 3.1), delegation JSON delete count, iterm background move count (Commit 6 Step 6.1), drift-sweep counts (Commit 10 Step 10.5).
  - The Scenario (A or B) result from Step 9.1.
  - The list of outstanding items from Commit 9's body (as a checklist for Evelynn to route).
  - Any deviations from this plan.
- [ ] Do NOT end your session. Per Rule 13, wait for Evelynn's acknowledgment.

## Rollback

Each commit is independently revertible by `git revert <hash>` because each commit is atomic over its own scope. To roll back the entire ten-commit sequence, revert commits in **reverse order**: 10, 9, 8, 7, 6, 5, 4, 3, 2, 1. Each revert produces its own `chore: revert ...` commit; do not force-push.

Partial rollback is safe because the commits are independent:
- Commit 1 (Irelia retire) does not depend on any other commit.
- Commit 2 (Zilean delete) does not depend on any other.
- Commit 3 (fossils archive) does not depend on any other.
- Commit 4 (shared scaffolding delete) does not depend on any other.
- Commit 5 (script classification) creates `architecture/platform-parity.md` or edits it. Commits 6 and 9 edit the same file — reverting 5 without reverting 6 and 9 leaves `architecture/platform-parity.md` in an inconsistent state. If reverting 5, revert 6 and 9 first.
- Commit 6 (iterm backgrounds) depends on Commit 5 only for the `architecture/platform-parity.md` row edit. The file moves are independent.
- Commit 7 (roster consolidation) is independent.
- Commit 8 (git-workflow merge) is independent.
- Commit 9 (verification) is documentation-only and always safe to revert alone.
- Commit 10 (drift sweep) is documentation-only (tool-name replacements in markdown files); safe to revert alone, though reverting without reverting phase-1-detailed leaves the repo in a consistent state (phase-1 Step 7's replacements remain in effect).

## Open questions for Duong

None. Every design question was either resolved by the operating-protocol-v2 rough plan, Rule 15, or explicitly flagged as out-of-scope ("no action taken, flagged for Duong's later triage") in Commit 9. If the executor encounters a situation this plan does not cover, the rule is: **stop, escalate to Evelynn, do not improvise.**

## Supersession

This plan is a one-shot cleanup. It does not supersede any other plan. It lands in `plans/implemented/` as `2026-04-09-protocol-migration-detailed.md` when Step 10 completes and Evelynn confirms. It does not modify, retire, or replace any of the four cross-referenced plans — it just executes against their target state.
