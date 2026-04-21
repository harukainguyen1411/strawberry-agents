---
status: approved
concern: personal
owner: aphelios
created: 2026-04-21
parent_plan: plans/approved/personal/2026-04-21-memory-consolidation-redesign.md
orianna_gate_version: 2
tests_required: true
tags: [task-breakdown, memory, coordinator, two-layer-boot]
---

# Task breakdown — memory consolidation redesign (two-layer boot)

Companion breakdown for `plans/approved/personal/2026-04-21-memory-consolidation-redesign.md`. Twelve tasks (T1–T12) executed by a complex-track pair on a single feature branch, single PR.

---

## 1. Team composition

| Role | Agent | Track | Model | Responsibilities |
|---|---|---|---|---|
| Complex-track builder | **Viktor** | complex | opus | Script implementation (T2, T4), skill + agent-def rewrites (T6, T7, T9, T10, T11), bootstrap curation (T8), dogfood evidence (T12). |
| Complex-track test implementer | **Rakan** | complex | opus | xfail test authorship (T1, T3, T5). Lands each test commit on the branch **before** the matching implementation commit. |

**No concurrent-repo rule.** Viktor and Rakan share the one feature branch; serialize via phase gates (G1–G5 below). No parallel work on the same files across sessions. If both need to push simultaneously, the later session rebases-via-merge (never `git rebase`).

---

## 2. Branching strategy

**Single feature branch, single PR.**

- Branch name: `feat/coordinator-memory-two-layer-boot`
- Base: `main`
- Creation: `bash scripts/safe-checkout.sh feat/coordinator-memory-two-layer-boot` (Rule 3 — worktree, never raw `git checkout`).
- Commit discipline: one commit per task (12 commits total), subjects prefixed per Rule 5 (all `chore:` — no `apps/**` touched).
- Merge strategy: merge commit into `main` after PR green (Rule 11 — never rebase).

### Rule 12 — xfail-before-impl ordering on the branch

These three test commits MUST land before their paired implementation commits on the **same branch**. The pre-push TDD hook (`scripts/hooks/pre-push-tdd.sh`) and CI (`tdd-gate.yml`) enforce this.

| xfail commit (Rakan) | Covers | Must land before impl commit(s) (Viktor) |
|---|---|---|
| **T1** `scripts/test-memory-consolidate-index.sh` | §9.1 INDEX regen | T2 (`_lib_last_sessions_index.sh`) and T4 (`memory-consolidate.sh` rewrite). |
| **T3** `scripts/test-memory-consolidate-archive-policy.sh` | §9.2 archive policy | T4 (`memory-consolidate.sh` rewrite). |
| **T5** `scripts/test-end-session-memory-integration.sh` + `scripts/test-end-session-skill-shape.sh` | §9.3 + §9.5 | T6 (`end-session` SKILL.md) and T7 (Lissandra). |

Each xfail commit must reference the parent plan's ADR file path and the task ID in the commit body so the TDD gate can map test → plan.

---

## 3. Duong-in-loop blockers

| ID | Blocker | Task | Expected turnaround |
|---|---|---|---|
| D-memory-1 | Review hand-seeded `agents/evelynn/memory/open-threads.md` for completeness (curation, not mechanical — §8.1 DoD). | T8 | 10–15 min — before T8 commit push. |
| D-memory-2 | Review `agents/sona/memory/open-threads.md` seed (lower volume, §8.2). | T8 | 5 min — same session as D-memory-1. |
| D-memory-3 | Approve PR — this is a coordinator-boot change affecting both Evelynn and Sona; Duong is the only valid non-author reviewer + Senna/Lucian (see §7). | PR review | same-day. |

**Default resolution** for OQ1/OQ2/OQ3 from the ADR (§Open questions) is already baked in — Viktor executes against the defaults unless Duong surfaces a preference at D-memory-1 review time.

---

## 4. Per-task detail

All paths absolute-from-repo-root. DoD = Definition of Done.

### T1 — xfail: INDEX regeneration tests

- **Owner**: Rakan
- **Inputs**: ADR §4.3 (helper contract), §9.1 (assertions list).
- **Outputs**: `scripts/test-memory-consolidate-index.sh` (new, executable).
- **Commands**: `chmod +x scripts/test-memory-consolidate-index.sh`; script must exit non-zero under the xfail convention (`set -e` + explicit "not implemented" sentinel, or marker file under `scripts/.xfail-markers/` — match whatever `scripts/hooks/pre-push-tdd.sh` already recognises; check the hook once).
- **Test anchors**: every assertion in ADR §9.1 — row count, mtime-descending order, UUID+date+TL;DR verbatim, fallback-to-prose when no `TL;DR:` anchor, "(no summary extractable)" fallback, archived-section presence, idempotency.
- **Commit subject**: `chore: xfail T1 — memory-consolidate index regen tests (ADR 2026-04-21-memory-consolidation-redesign)`
- **Rule 12**: must land before T2 and T4 on the branch.
- **Dependencies**: none (first commit on the branch after creation).
- **Estimate**: 40 min.
- **Acceptance gate**: G1.

### T2 — impl: `scripts/_lib_last_sessions_index.sh` helper

- **Owner**: Viktor
- **Inputs**: ADR §4.3 (public function contract), T1 test fixtures.
- **Outputs**: `scripts/_lib_last_sessions_index.sh` (new, **no shebang** — sourced-only).
- **Functions to implement**:
  - `extract_shard_tldr <shard_path>` — ADR §4.3 rules a/b/c in order.
  - `render_index_row <shard_path> <mtime_epoch>` — one markdown row, greppable by UUID.
  - `regenerate_index <last_sessions_dir> <output_file>` — newest-first walk + `## Archived` pointer section.
- **Constraints**: POSIX-portable bash (Rule 10); python3 usage OK (already a dep of `memory-consolidate.sh`); no external binaries beyond `git`, `date`, `stat`, `python3`, `awk`, `sed`, `grep`.
- **Commands**: run `bash scripts/test-memory-consolidate-index.sh` locally — must pass (converts T1's xfail to pass).
- **Commit subject**: `chore: T2 — add _lib_last_sessions_index.sh helper (shard TL;DR + index row + regen)`
- **Dependencies**: T1 committed.
- **Estimate**: 45 min.
- **Acceptance gate**: G1.

### T3 — xfail: archive policy tests

- **Owner**: Rakan
- **Inputs**: ADR §4.2 (archive rules), §9.2 (assertions list).
- **Outputs**: `scripts/test-memory-consolidate-archive-policy.sh` (new, executable).
- **Test anchors**: mtime > 14d → archive; position > 20 (newest-first) → archive; 20 newest within 14d stay; `open-threads.md` UUID-reference skip-guard (with warn-log); `git mv` used (shard git history preserved — assert via `git log --follow`); UUID collision suffix loop up to `-100`; INDEX regen post-archive surfaces moved shards in `## Archived`.
- **Commit subject**: `chore: xfail T3 — memory-consolidate archive policy tests (ADR 2026-04-21-memory-consolidation-redesign)`
- **Rule 12**: must land before T4 on the branch.
- **Dependencies**: T2 landed (test fixture generator reuses `_lib` helpers if convenient, but hard dep is only T1 → fixtures; T2 → fixtures is a soft convenience).
- **Estimate**: 35 min.
- **Acceptance gate**: G2.

### T4 — impl: rewrite `scripts/memory-consolidate.sh`

- **Owner**: Viktor
- **Inputs**: ADR §4.2, existing `scripts/memory-consolidate.sh` (preserve sessions-fold, UUID collision loop, flock/noclobber lock, commit message template, push-with-retry), ADR §5.1 (`--index-only` flag contract).
- **Outputs**: `scripts/memory-consolidate.sh` (rewritten in place).
- **Additive responsibilities** (ADR §4.2):
  1. INDEX regeneration pass — sources `_lib_last_sessions_index.sh`.
  2. Archive policy — 14d OR position > 20, newest-first; pre-archive open-threads UUID-reference guard; `git mv`; UUID-collision suffix loop (reuse existing).
  3. Pre-boot validator — moved from `filter-last-sessions.sh`: sentinel `<!-- sessions:auto-below` appears exactly once in `<coordinator>.md`; `last-sessions/` exists; shard counts to stderr.
  4. `--index-only` flag — runs **only** the INDEX regen pass, no archive move, no sessions-fold, no commit/push; respects flock (no-op if lock held, per ADR §10 failure mode #8); target < 1s on a 25-shard fixture.
- **Preserve**: sessions-fold path, UUID collision loop, lock handling, commit prefix `chore: <secretary> memory consolidation YYYY-MM-DD`, push-with-retry, POSIX bash.
- **Commands**:
  - `bash scripts/test-memory-consolidate-index.sh` → passes.
  - `bash scripts/test-memory-consolidate-archive-policy.sh` → passes.
  - Smoke: dry-run on Evelynn's current memory — confirm `## Sessions` block in `agents/evelynn/memory/evelynn.md` is **byte-identical** pre/post modulo the INDEX additions (grep-diff to verify).
  - Timing: `time bash scripts/memory-consolidate.sh evelynn --index-only` < 1s.
- **Commit subject**: `chore: T4 — rewrite memory-consolidate.sh with INDEX regen + archive policy + --index-only`
- **Dependencies**: T1, T2, T3 all landed.
- **Estimate**: 60 min.
- **Acceptance gate**: G2.

### T5 — xfail: `/end-session` integration + skill-shape tests

- **Owner**: Rakan
- **Inputs**: ADR §9.3 (integration assertions), §9.5 (shape assertions), §5.1 (Step 6b contract).
- **Outputs**:
  - `scripts/test-end-session-memory-integration.sh` (new, executable). Stubs `clean-jsonl.py` + git; drives `/end-session` flow for a synthetic coordinator; asserts atomic commit of shard + `open-threads.md` + `INDEX.md`.
  - `scripts/test-end-session-skill-shape.sh` (new, executable). Grep-based: `"Step 6b"`, `"open-threads.md"`, `"INDEX.md"`, ordering "Step 6 before 6b, 6b before Step 9".
- **Commit subject**: `chore: xfail T5 — /end-session memory-integration + skill-shape tests (ADR 2026-04-21-memory-consolidation-redesign)`
- **Rule 12**: must land before T6 and T7 on the branch.
- **Dependencies**: T4 landed (integration test invokes the rewritten script).
- **Estimate**: 40 min.
- **Acceptance gate**: G3.

### T6 — impl: `.claude/skills/end-session/SKILL.md` — inject Step 6b

- **Owner**: Viktor
- **Inputs**: ADR §5.1 (full Step 6b shape).
- **Outputs**: `.claude/skills/end-session/SKILL.md` (edited in place).
- **Edits**:
  - Insert **Step 6b** between existing Step 6 and Step 7 of the coordinator branch (agent == evelynn OR sona). Step 6b content per ADR §5.1 items 1–5 verbatim (parse shard Open-threads section → apply deltas to `open-threads.md` → stage → run `bash scripts/memory-consolidate.sh <coordinator> --index-only` → stage `INDEX.md`).
  - Document the ordering invariant explicitly: "Step 6 MUST complete before 6b; Step 6b MUST complete before Step 9 (commit+push)."
  - Add explicit no-op clause for non-coordinator agents (Sonnet subagents via `/end-subagent-session`).
  - Include the recovery note: "If Step 6b fails partway, the shard write already landed. Recover by running `bash scripts/memory-consolidate.sh <coordinator> --index-only` and re-staging `open-threads.md` + `INDEX.md` before next commit."
- **Commands**: `bash scripts/test-end-session-skill-shape.sh` → passes (T5 shape xfail flips to pass).
- **Commit subject**: `chore: T6 — add /end-session Step 6b (open-threads update + INDEX regen)`
- **Dependencies**: T5 landed.
- **Estimate**: 30 min.
- **Acceptance gate**: G3.

### T7 — impl: Lissandra Step 6b parity

- **Owner**: Viktor
- **Inputs**: ADR §5.2.
- **Outputs**:
  - `.claude/agents/lissandra.md` (edited) — Step 6b inserted into Lissandra's coordinator-close protocol, identical sequence to T6 but in Lissandra's voice.
  - `agents/lissandra/profile.md` (edited) — mirror the protocol update (same ordering invariant, same recovery note).
  - `.claude/skills/pre-compact-save/SKILL.md` (edited) — one-line note: "Lissandra updates `open-threads.md` and regenerates `INDEX.md` as part of the coordinator shard write, same as `/end-session` Step 6b."
- **Commands**: dry-run `pre-compact-save` on a test session (synthetic coordinator memory dir) — confirm `open-threads.md` and `INDEX.md` update identically to `/end-session` output.
- **Commit subject**: `chore: T7 — Lissandra pre-compact Step 6b parity with /end-session`
- **Dependencies**: T5, T6 landed.
- **Estimate**: 25 min.
- **Acceptance gate**: G3.

### T8 — bootstrap: seed `open-threads.md` + initial `INDEX.md` for both coordinators

- **Owner**: Viktor (curation) + Duong (review gate D-memory-1, D-memory-2)
- **Inputs**: ADR §8.1 (Evelynn seed method), §8.2 (Sona seed method), §9.4 (migration smoke steps).
- **Outputs**:
  - `agents/evelynn/memory/open-threads.md` (new, hand-curated).
  - `agents/sona/memory/open-threads.md` (new, hand-curated).
  - `agents/evelynn/memory/last-sessions/INDEX.md` (new, generated).
  - `agents/sona/memory/last-sessions/INDEX.md` (new, generated).
- **Method (Evelynn)**:
  1. `cp -r agents/evelynn/memory agents/evelynn/memory.backup-$(date +%s)` (local only, not committed).
  2. Read each of the 26 shards currently in `agents/evelynn/memory/last-sessions/` (ADR says 23 — count may have drifted by commit time; use actual count).
  3. Parse each shard's `## Open threads into next session` section.
  4. De-dup threads across shards; keep most recent status per thread.
  5. For each surviving thread, write `## <thread>` section into `open-threads.md` with status one-liner + shard-UUID pointers + next action.
  6. Duong review (D-memory-1) — no thread silently dropped; curation quality OK.
  7. `bash scripts/memory-consolidate.sh evelynn --index-only` → writes `last-sessions/INDEX.md`.
- **Method (Sona)**: same shape, lower volume (2 shards + `sona.md` Paused-work entries).
- **Smoke test (ADR §9.4)**:
  - Diff seeded `open-threads.md` against union of shards' Open-threads sections — no thread lost.
  - `wc -c agents/evelynn/memory/open-threads.md agents/evelynn/memory/last-sessions/INDEX.md` → combined < 8 KB.
  - Delete `agents/evelynn/memory.backup-*` after smoke passes.
- **Commit subject**: `chore: T8 — bootstrap open-threads.md + INDEX.md for Evelynn and Sona`
- **Dependencies**: T4 landed (needs `--index-only`); T7 landed (so skill+Lissandra are ready; bootstrap + skill land together).
- **Estimate**: 55 min (+ 10–15 min Duong review latency).
- **Acceptance gate**: G4.

### T9 — impl: rewrite Evelynn + Sona boot scripts; delete `filter-last-sessions.sh`

- **Owner**: Viktor
- **Inputs**: ADR §6.1, §7 (boot order table).
- **Outputs**:
  - `.claude/agents/evelynn.md` (edited) — `initialPrompt` rewritten per ADR §6.1; boot order positions 1–8 match §7 table; no reference to `filter-last-sessions.sh`.
  - `.claude/agents/sona.md` (edited) — same shape, names swapped.
  - `scripts/filter-last-sessions.sh` — **deleted** via `git rm`.
- **Commands**:
  - `git rm scripts/filter-last-sessions.sh`
  - Grep guard: `grep -rn "filter-last-sessions" .` → returns zero hits (enforce in commit message or fail the commit).
- **Commit subject**: `chore: T9 — rewrite coordinator boot scripts; delete filter-last-sessions.sh`
- **Dependencies**: T8 landed (seed files must exist before boot scripts reference them).
- **Estimate**: 25 min.
- **Acceptance gate**: G5.

### T10 — impl: CLAUDE.md + agent-network.md edits

- **Owner**: Viktor
- **Inputs**: ADR §6.2 (Evelynn CLAUDE.md), §6.3 (new Sona section), §6.4 (agent-network.md Memory Consumption).
- **Outputs**:
  - `agents/evelynn/CLAUDE.md` (edited) — Startup Sequence step 3 rewritten; "Do NOT load" clause amended; subsequent entries renumbered.
  - `agents/sona/CLAUDE.md` (edited) — new `## Startup Sequence` section mirroring Evelynn's.
  - `agents/memory/agent-network.md` (edited) — new `## Memory Consumption` section (≤ 20 lines) per §6.4 bullet list.
- **Commands**: post-edit grep check — `grep -n "last-sessions" agents/evelynn/CLAUDE.md agents/sona/CLAUDE.md agents/memory/agent-network.md` returns only the intended references.
- **Commit subject**: `chore: T10 — update CLAUDE.md startup sequences + agent-network memory consumption doc`
- **Dependencies**: T9 landed.
- **Estimate**: 30 min.
- **Acceptance gate**: G5.

### T11 — impl: `architecture/coordinator-memory.md`

- **Owner**: Viktor
- **Inputs**: ADR §3 (file layout), §5 (write-side flow), §6 (read-side flow), §7 (boot order), §10 (failure modes).
- **Outputs**: `architecture/coordinator-memory.md` (new).
- **Required sections**:
  - File layout (copy ADR §3 tree + table).
  - Write-side flow — `/end-session` Step 6 → 6b → 9 + `pre-compact-save` via Lissandra.
  - Read-side flow — boot order (§7 table) + on-demand shard pull path.
  - Retention policy — 14d OR 20-shards + 30d archive prune.
  - Failure modes — copy ADR §10 table.
  - Cross-references: link from `agents/evelynn/CLAUDE.md` and `agents/sona/CLAUDE.md` (add the link in the Startup Sequence sections from T10 — coordinate with that commit if T10 not yet in).
- **Commit subject**: `chore: T11 — add architecture/coordinator-memory.md (two-layer boot doc)`
- **Dependencies**: T10 landed (CLAUDE.md cross-refs).
- **Estimate**: 35 min.
- **Acceptance gate**: G5.

### T12 — dogfood + evidence

- **Owner**: Viktor
- **Inputs**: merged branch (or a local dogfood session on the branch tip).
- **Outputs**: no new files; evidence captured in PR body or the T12 commit message.
- **Procedure**:
  1. In a fresh coordinator session (Evelynn or Sona), run the new boot path end-to-end.
  2. Confirm no reference to `filter-last-sessions.sh` in the boot transcript.
  3. Confirm `open-threads.md` loads; `INDEX.md` loads.
  4. Pull one sample shard on-demand (simulate a Duong prompt touching a known thread).
  5. Measure boot-token count for positions 7+8 (tail) — capture output of `wc -c <open-threads.md> <INDEX.md>`; target combined < 8 KB.
  6. Record evidence in the PR body under a "Dogfood" heading.
- **Commit subject**: `chore: T12 — dogfood two-layer boot, evidence in PR body`
- **Dependencies**: T11 landed.
- **Estimate**: 20 min.
- **Acceptance gate**: G5 (closes phase).

---

## 5. Execution order + phase gates

Five sequential phase gates. Viktor and Rakan can work in parallel across gates only where noted.

```
G1 — scripts lib ready
  T1 (Rakan, xfail) -> T2 (Viktor, impl)

G2 — consolidator rewritten
  T3 (Rakan, xfail) -> T4 (Viktor, impl)

G3 — skill + Lissandra ready
  T5 (Rakan, xfail) -> T6 (Viktor) -> T7 (Viktor)

G4 — bootstrap landed
  T8 (Viktor + Duong review D-memory-1, D-memory-2)

G5 — cutover + docs
  T9 (Viktor) -> T10 (Viktor) -> T11 (Viktor) -> T12 (Viktor, dogfood)
```

### Parallel windows (safe)

- **Window P1** (G1 → G2 transition): Rakan authoring T3 can start as soon as T1 is committed, even while Viktor is mid-T2. The two xfail-tests have disjoint assertion surfaces and no file collisions.
- **Window P2** (during G3): Rakan can draft T5's two test files in parallel with Viktor finishing T4. Merge must be coordinated — Rakan pushes T5 only after T4 is in so the integration test can invoke the rewritten script.
- **Window P3** (during G4 → G5): Viktor can draft T10 and T11 edits locally while waiting on Duong's T8 review, but cannot commit them until T9 is in.

### Hard-serial points

- T2 depends on T1 (Rule 12).
- T4 depends on T3 (Rule 12) and T2 (sources `_lib`).
- T6 depends on T5 (Rule 12).
- T7 depends on T6 (skill must exist before Lissandra mirrors it).
- T8 depends on T4 + T7 (needs `--index-only` flag + mirrored close protocol).
- T9 depends on T8 (boot scripts reference seeded files).
- T10 depends on T9 (CLAUDE.md cross-references renumbered entries).
- T11 depends on T10 (adds cross-refs back to CLAUDE.md).
- T12 depends on T11 (dogfood against final state).

### Owner-concurrent schedule

| Clock | Viktor | Rakan |
|---|---|---|
| 0–40 min | idle | T1 xfail |
| 40–85 min | T2 impl | T3 xfail (parallel, window P1) |
| 85–145 min | T4 impl | idle / begin T5 draft (window P2) |
| 145–185 min | idle | T5 xfail |
| 185–215 min | T6 impl | idle |
| 215–240 min | T7 impl | idle |
| 240–295 min | T8 bootstrap + Duong D-memory-1/2 | idle |
| 295–320 min | T9 impl | idle |
| 320–350 min | T10 impl | idle |
| 350–385 min | T11 impl | idle |
| 385–405 min | T12 dogfood | idle |

Total wall-clock (serialized on Viktor's path after G3): ~405 min (ADR estimate 440 min — the 35 min saving comes from P1/P2 parallel windows for Rakan's xfail work).

---

## 6. Acceptance-gate cross-reference

| Gate | Task(s) | Invariant satisfied (ADR §Test plan) |
|---|---|---|
| **G1** | T1, T2 | INDEX freshness (regen correctness); Rule 12 xfail-before-impl for T1→T2. |
| **G2** | T3, T4 | Archive policy invariant; no-orphan guard (open-threads UUID skip); Rule 12 T3→T4; preserves existing sessions-fold behaviour (smoke-diff). |
| **G3** | T5, T6, T7 | Atomicity invariant (shard + open-threads + INDEX in one commit); Ordering invariant (Step 6 → 6b → 9); Rule 12 T5→T6/T7; Lissandra parity. |
| **G4** | T8 | Bootstrap-completeness invariant (no thread silently dropped); Boot token invariant (< 8 KB combined). |
| **G5** | T9, T10, T11, T12 | No-orphan invariant (`filter-last-sessions.sh` deletion, grep-clean); Boot-order invariant (§7 table); Dogfood evidence. |

---

## 7. PR metadata

- **Branch**: `feat/coordinator-memory-two-layer-boot`
- **Base**: `main`
- **Title**: `Coordinator memory: two-layer boot (open-threads + last-sessions INDEX)`
- **Reviewers**: Senna (code review, single-repo PR review) + Lucian (architecture guard). Duong is the non-author approver required by Rule 18.
- **Body shell**:

```markdown
## Summary
Replaces 48h-mtime eager shard load with a two-layer coordinator memory shape:
- `open-threads.md` (eager, hand-maintained live state)
- `last-sessions/INDEX.md` (eager, auto-regenerated 3-line TL;DR manifest)
- `last-sessions/<uuid>.md` (lazy, on-demand) + `last-sessions/archive/` (14d OR >20 shards)

Migrates Evelynn and Sona simultaneously. Deletes `scripts/filter-last-sessions.sh`.

Plan: plans/approved/personal/2026-04-21-memory-consolidation-redesign.md
Breakdown: plans/approved/personal/2026-04-21-memory-consolidation-redesign-tasks.md

## Changes (12 commits)
- T1 (xfail) → T2 — `_lib_last_sessions_index.sh`
- T3 (xfail) → T4 — `memory-consolidate.sh` rewrite
- T5 (xfail) → T6 — `/end-session` Step 6b
- T7 — Lissandra Step 6b parity
- T8 — bootstrap `open-threads.md` + INDEX for both coordinators
- T9 — boot scripts rewrite + delete `filter-last-sessions.sh`
- T10 — CLAUDE.md startup + agent-network memory-consumption doc
- T11 — `architecture/coordinator-memory.md`
- T12 — dogfood evidence

## Test plan
- [ ] `bash scripts/test-memory-consolidate-index.sh` passes
- [ ] `bash scripts/test-memory-consolidate-archive-policy.sh` passes
- [ ] `bash scripts/test-end-session-memory-integration.sh` passes
- [ ] `bash scripts/test-end-session-skill-shape.sh` passes
- [ ] Evelynn dogfood boot — no `filter-last-sessions.sh` reference
- [ ] Sona dogfood boot — same
- [ ] Combined `open-threads.md` + `INDEX.md` size < 8 KB per coordinator
- [ ] `grep -rn "filter-last-sessions" .` returns zero hits

## Dogfood
<evidence from T12 pasted here — boot transcript excerpt, token count, sample shard pull>
```

- **Required checks (must go green)**:
  - `tdd-gate` (CI `tdd-gate.yml`) — enforces Rule 12 xfail-before-impl on branch.
  - Pre-push hooks (local): secrets scan, commit-prefix check, TDD gate, pre-commit unit tests.
  - Non-UI PR — QA/E2E/Playwright gates (Rules 15, 16) do not apply (no `apps/**` touched). PR body linter should see the Test plan checklist as sufficient.
  - Branch protection: one approving review from an account other than author (Rule 18).

- **Merge**: merge commit (not rebase — Rule 11). Non-author merger (not Viktor — Rakan or Duong). No `--admin` (Rule 18).

---

## 8. Rollback summary

ADR §Rollback applies verbatim. Short form:

1. `git revert` the 12 commits in reverse order (T12 → T1). Merge, never rebase.
2. Restore `scripts/filter-last-sessions.sh` from git history: `git show <pre-T9-SHA>:scripts/filter-last-sessions.sh > scripts/filter-last-sessions.sh && chmod +x scripts/filter-last-sessions.sh`.
3. Next coordinator boot falls back to 48h-mtime path.

No data loss risk — bootstrap outputs (`open-threads.md`, `INDEX.md`) are additive; reverting removes the files and leaves prior shards intact.

---

## 9. Open questions / unresolved

None block execution. Viktor executes against ADR §Open-questions defaults (OQ1 optional `TL;DR:` anchor; OQ2 Lissandra-writes-in-coordinator-voice; OQ3 Evelynn-driven bootstrap with Duong review) unless Duong flags at D-memory-1.

**OQ-K1** (breakdown-level, new): The ADR says "23 shards" for Evelynn (§1), but `ls agents/evelynn/memory/last-sessions/` at breakdown time shows 26 shards. Drift is expected (new sessions since ADR authorship). T8 bootstrap uses the live count at T8 execution time, not the ADR figure. Flagging only for traceability — no action needed.

**OQ-K2** (breakdown-level, new): The xfail-marker convention used by `scripts/hooks/pre-push-tdd.sh` is not specified in the ADR. Rakan must read the hook once at the start of T1 and match whatever sentinel format the hook already recognises (explicit "not implemented" string, `.xfail-markers/` file, or annotation in the test body). If the hook's convention is unclear, surface to Duong before T1 lands.
