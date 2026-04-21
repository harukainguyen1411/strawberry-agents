---
status: approved
concern: personal
owner: xayah
created: 2026-04-21
complexity: complex
kind: test-plan
orianna_gate_version: 2
tests_required: true
tags: [memory, boot, coordinator, evelynn, sona, shards, testing]
related:
  - plans/approved/personal/2026-04-21-memory-consolidation-redesign.md
  - assessments/personal/2026-04-21-memory-consolidation-redesign.md
---

## Test plan

This document IS the test plan for the memory-consolidation-redesign ADR (`plans/approved/personal/2026-04-21-memory-consolidation-redesign.md`). Sections §1–§10 below enumerate xfail skeletons, integration tests, fault-injection harnesses, migration assertions, and surface-coverage audit. Xfail-first commits X1–X6 land before their implementation commits per CLAUDE.md Rule 12.

# Test plan — memory consolidation redesign (two-layer boot)

**ADR:** `plans/approved/personal/2026-04-21-memory-consolidation-redesign.md`
**Implementer:** Rakan (complex-track test implementer)
**Runners:** Vi / Caitlyn
**Authoring agent:** Xayah

This document turns the ADR's `## Test plan` invariants and §9 test-plan details into concrete, implementable test harnesses. Every test is named, located, and specifies assertions plus Rakan implementation notes. Xfail-first discipline (CLAUDE.md Rule 12) is tracked explicitly per surface.

All prospective script paths below carry `<!-- orianna: ok -->` suppression markers so future Orianna fact-check passes treat them as authored, not broken references.

---

## 0. Cheat sheet — surfaces × tests

| Surface (task prompt) | xfail skeletons | Fault-injection harness | Integration |
|---|---|---|---|
| 1. `memory-consolidate.sh` rewrite (INDEX + archive policy + ref guard) | §2.1, §2.2, §2.3 | §4.1, §4.2, §4.3 | §3.1 |
| 2. `open-threads.md` eager load, tail position, prompt-cache friendliness | §2.4 | — | §3.2 |
| 3. `last-sessions/INDEX.md` eager load, TL;DR shape, newest-first | §2.1, §2.5 | — | §3.2 |
| 4. `/end-session` Step 6b atomicity | §2.6 | §4.4 | §3.3 |
| 5. Lissandra pre-compact parity | §2.7 | §4.4 | §3.4 |
| 6. Skarner on-demand shard retrieval | §2.8 | — | §3.5 |
| 7. Migration (Evelynn + Sona cutover in one PR) | §2.9 | §4.5 | §3.6 |
| 8. Failure injection (interrupt, concurrency, ref-to-missing) | — | §4.1–§4.5 | §3.3 |

---

## 1. Xfail-first commit plan (Rule 12 traceability)

Six xfail-test commits land on the feature branch before implementation. Each references the ADR task it gates.

| Xfail commit | Files | Gates ADR task | Surface covered |
|---|---|---|---|
| X1 | `scripts/test-memory-consolidate-index.sh` | T1 → T2 + T4 | 1, 3 |
| X2 | `scripts/test-memory-consolidate-archive-policy.sh` | T3 → T4 | 1 |
| X3 | `scripts/test-end-session-memory-integration.sh`, `scripts/test-end-session-skill-shape.sh` | T5 → T6 | 4 |
| X4 | `scripts/test-lissandra-precompact-memory.sh` | (new — gates T7) | 5 |
| X5 | `scripts/test-boot-chain-order.sh` | (new — gates T9) | 2, 3 |
| X6 | `scripts/test-migration-smoke.sh` | (new — gates T8) | 7 |

Pre-push TDD hook (`scripts/hooks/pre-push-tdd.sh`) enforces each xfail commit precedes its impl commit on the branch. Rakan MUST NOT combine xfail and impl in a single commit.

**XFAIL stub convention** (matches existing harnesses like `test-orianna-lifecycle-smoke.sh`):

```sh
# --- XFAIL guard: implementation not yet present ---
MISSING=""
[ ! -f "$SCRIPT" ] && MISSING="$MISSING memory-consolidate.sh:--index-only"
if [ -n "$MISSING" ]; then
  printf 'XFAIL (expected — missing:%s)\n' "$MISSING"
  exit 0
fi
# From here on, real assertions; any FAIL exits 1.
```

---

## 2. Unit-level xfail skeletons

### 2.1 INDEX regeneration — `scripts/test-memory-consolidate-index.sh` <!-- orianna: ok -->

**Gates:** ADR T1 → T2 + T4.
**What it asserts (from ADR §9.1):**

| # | Assertion | Rakan note |
|---|---|---|
| A1 | INDEX row count equals fixture shard count (`.gitkeep` and `INDEX.md` itself excluded). | Use `grep -c` on a UUID pattern; do not count lines. |
| A2 | Row ordering is mtime-descending. | Fixture: create 5 shards with `touch -t <stamp>`; read back UUID column and assert lexicographic match vs the known-sorted list. |
| A3 | Each row contains shard UUID, date (YYYY-MM-DD), and first 3 TL;DR lines verbatim. | For each fixture shard, write a known TL;DR block; grep the row for each of the 3 lines. |
| A4 | Shards with no `TL;DR:` anchor fall back to first 3 prose lines under H1. | Fixture shard B: omit `TL;DR:`, include `# Title\n\npara 1\npara 2\npara 3`. Expect rows. |
| A5 | Shards with neither anchor nor prose produce "(no summary extractable)". | Fixture shard C: only `# Title`, no body. |
| A6 | Archived shards appear in a distinct `## Archived` section, one-line pointer each. | Place a file in `archive/`, assert INDEX has an `## Archived` heading and a line containing its UUID. |
| A7 | Idempotency — running `--index-only` twice produces byte-identical output. | `diff` two successive runs. Assert exit 0. |
| A8 | INDEX is UTF-8 safe (unicode TL;DR content round-trips). | Fixture shard D: TL;DR contains `é` and `→`. |
| A9 | `--index-only` exit code 0 on clean run, non-zero if `last-sessions/` missing. | Negative case: point at nonexistent dir. |

**Rakan implementation notes:**
- Fixture dir lives under `$(mktemp -d)`; populate with handcrafted shards; never touch `agents/evelynn/memory/` during unit tests.
- Stub `git` if the script tries to stage; use `GIT_DIR=/dev/null` + fake `PATH` shim.
- Assert assertions even when fixture contains zero shards: INDEX should still be valid with an empty body (A1 → 0 rows, file exists).

### 2.2 Archive policy — `scripts/test-memory-consolidate-archive-policy.sh` <!-- orianna: ok -->

**Gates:** ADR T3 → T4.
**What it asserts (from ADR §9.2):**

| # | Assertion | Rakan note |
|---|---|---|
| B1 | Shards with mtime > 14d ago move to `archive/`. | Fixture: 3 shards aged 15d via `touch -t`; assert post-run they are under `archive/`. |
| B2 | Shards at newest-first positions 21+ move to `archive/` regardless of age. | Fixture: 25 shards all aged < 14d; assert shards 21–25 move. |
| B3 | The 20 newest within 14d stay in `last-sessions/`. | Same fixture as B2; assert positions 1–20 are untouched. |
| B4 | A shard whose UUID appears in `open-threads.md` is NOT moved even if policy triggers. | Fixture: 1 shard aged 30d; fake `open-threads.md` contains its UUID. Assert shard stays. |
| B5 | Skipping a referenced shard emits a stderr warning containing the UUID. | Capture stderr, grep for UUID + `warning`. |
| B6 | `git mv` is used (not `mv`), so shard history is preserved. | Init a scratch repo in the fixture, commit shards, run the archive step, assert `git log --follow archive/<uuid>.md` shows pre-move commits. |
| B7 | UUID collision in `archive/` is suffixed `-2`, `-3`, … up to `-100` before failing. | Pre-populate `archive/<uuid>.md` and `archive/<uuid>-2.md`; expect new shard renamed `<uuid>-3.md`. |
| B8 | INDEX regenerated after archive move correctly surfaces moved shards under `## Archived`. | Chained assertion: after archive step, run `--index-only` and grep the `## Archived` section for the moved UUIDs. |
| B9 | OR semantics — shards aged > 14d that are ALSO at positions 1–20 still move (age clause wins). | Fixture: position 3 shard is 20d old. Assert it moves. |
| B10 | Tie-breaking — shards with identical mtime order by filename ascending. | Fixture: 3 shards, same `touch -t`; assert order is deterministic filename-ascending. |

**Rakan implementation notes:**
- Use a scratch git repo inside `$(mktemp -d)` for B6 / B7.
- For B4 / B5: the `open-threads.md` parse must be UUID-substring based (short-uuid is the first 8 hex chars of the shard filename stem). Assert BOTH long-form UUID and short-form references are detected.
- Run each assertion in an independent fixture to avoid cross-test pollution.

### 2.3 INDEX↔archive consistency — `scripts/test-memory-consolidate-consistency.sh` <!-- orianna: ok -->

**Gates:** T4 (post-impl regression guard; not on the xfail gate path).
**What it asserts:**

| # | Assertion |
|---|---|
| C1 | After a full `memory-consolidate.sh <name>` run, every file in `last-sessions/` has a matching INDEX row, and every file in `archive/` has a `## Archived` pointer. |
| C2 | No INDEX row points at a shard that doesn't exist on disk. |
| C3 | Total active (non-archived) rows ≤ 20. |
| C4 | No shard appears both in `last-sessions/` and `archive/`. |
| C5 | Pre-boot validator fails loud if `<!-- sessions:auto-below` sentinel is missing from `<coordinator>.md`. |

**Rakan implementation notes:**
- This is a "property" suite — it can run against the real Evelynn memory (read-only copy into temp) after migration to catch drift.
- Guard all filesystem checks with `set -euo pipefail`.

### 2.4 Boot-chain ordering — `scripts/test-boot-chain-order.sh` <!-- orianna: ok -->

**Gates:** ADR T9 (agent-def rewrite).
**What it asserts:**

| # | Assertion | Rakan note |
|---|---|---|
| D1 | `.claude/agents/evelynn.md` `initialPrompt` reads files in the exact order of ADR §7 table. | Extract the numbered list via regex; assert each line matches. |
| D2 | `open-threads.md` is position 7, `INDEX.md` is position 8 (last two). | Parse numbered list; assert len == 8 AND tail-2 == the expected entries. |
| D3 | No mention of `filter-last-sessions.sh` anywhere in the boot prompt. | `! grep filter-last-sessions`. |
| D4 | `.claude/agents/sona.md` symmetric to Evelynn (names swapped). | Same assertions, parameterised on coordinator name. |
| D5 | `agents/evelynn/CLAUDE.md` §Startup Sequence matches the boot prompt's file order (single-source-of-truth symmetry). | Parse the `## Startup Sequence` section; compare against `.claude/agents/evelynn.md`. |
| D6 | `agents/sona/CLAUDE.md` has a `## Startup Sequence` section (new per ADR §6.3). | Assert heading exists. |
| D7 | `agents/memory/agent-network.md` contains a `## Memory Consumption` section describing the two-layer pattern. | Grep for the heading and for `open-threads.md` + `INDEX.md` + `Skarner`. |

**Rakan implementation notes:**
- This is a pure grep-based shape assertion; no fixtures needed.
- Parse `initialPrompt` as YAML-in-markdown; tolerate blockquote `>` prefixes on numbered lines.

### 2.5 INDEX shape — `scripts/test-index-format.sh` <!-- orianna: ok -->

**Gates:** T4 regression guard (runs after T4 impl). Enforces TL;DR extraction contract so downstream consumers (Skarner, coordinator boot read) can rely on stable format.
**What it asserts:**

| # | Assertion |
|---|---|
| E1 | INDEX starts with a generated-by header comment (`<!-- generated by memory-consolidate.sh -->`). |
| E2 | Each active row matches regex `^YYYY-MM-DD · [0-9a-f]{8} · .*$` or the markdown-table equivalent (whichever §4.3 finalises). |
| E3 | Archived-section pointer lines contain the shard UUID and the archived-date. |
| E4 | No row exceeds 240 chars (keeps INDEX scannable; guards against TL;DR runaway). |
| E5 | TL;DR text is sanitized: no raw backticks that would break markdown rendering at boot. |

**Rakan implementation notes:**
- The exact row format finalises in T2. This test LOCKS it once finalised — if T2 picks markdown-table over dot-separated, update E2's regex during the xfail commit to match the finalised shape.

### 2.6 `/end-session` skill shape + Step 6b ordering — `scripts/test-end-session-skill-shape.sh` <!-- orianna: ok -->

**Gates:** ADR T5 → T6 (paired with §3.3 integration test).
**What it asserts (from ADR §9.5, extended):**

| # | Assertion |
|---|---|
| F1 | `.claude/skills/end-session/SKILL.md` contains a `Step 6b` heading. |
| F2 | Step 6b body references `open-threads.md`. |
| F3 | Step 6b body references `INDEX.md` regeneration. |
| F4 | Ordering is documented: text asserts Step 6 before 6b, 6b before Step 9. |
| F5 | Step 6b marked as no-op for non-coordinator agents (explicit `evelynn` OR `sona` guard). |
| F6 | Exact command `scripts/memory-consolidate.sh --index-only <coordinator>` appears literally in Step 6b. |
| F7 | `git add agents/<coordinator>/memory/open-threads.md` and the INDEX add line both appear. |

### 2.7 Lissandra pre-compact skill shape — `scripts/test-lissandra-precompact-memory.sh` <!-- orianna: ok -->

**Gates:** ADR T7.
**What it asserts:**

| # | Assertion |
|---|---|
| G1 | `.claude/agents/lissandra.md` includes a Step-6b-equivalent protocol section. |
| G2 | Section parses the shard's `## Open threads into next session` block. |
| G3 | Writes into `agents/<coordinator>/memory/open-threads.md` (both `evelynn` AND `sona` mentioned). |
| G4 | Regenerates INDEX via `memory-consolidate.sh --index-only <coordinator>`. |
| G5 | Stages all three artifacts (shard + open-threads + INDEX) before commit. |
| G6 | `.claude/skills/pre-compact-save/SKILL.md` carries a one-line note confirming Lissandra updates `open-threads.md` + INDEX. |
| G7 | `agents/lissandra/profile.md` matches G1–G5 (secondary source of truth). |

**Rakan implementation notes:**
- Two source files to check (`.claude/agents/lissandra.md` + `agents/lissandra/profile.md`) — assert BOTH.
- Parallel to §2.6 — reuse grep helpers.

### 2.8 Skarner on-demand retrieval contract — `scripts/test-skarner-on-demand.sh` <!-- orianna: ok -->

**Gates:** new (ADR §6.4 + §11 — Skarner is referenced as the search-delegation target; must continue to work against the new layout).
**What it asserts:**

| # | Assertion | Rakan note |
|---|---|---|
| H1 | Skarner's profile (`agents/skarner/profile.md` or `.claude/agents/skarner.md`) documents reading `last-sessions/<uuid>.md` and `last-sessions/archive/<uuid>.md` as valid lookup paths. | Grep. |
| H2 | Skarner does NOT eagerly load all shards at its own boot (lazy contract honored). | Grep the boot prompt; assert absence of a wildcard read under `last-sessions/`. |
| H3 | Skarner's search path tolerates INDEX absence (falls through to direct-file grep). | Grep prose; document as behavioral contract. |
| H4 | Skarner profile updated to drop the retired `filter-last-sessions.sh` reference, if any. | `! grep filter-last-sessions agents/skarner/** .claude/agents/skarner.md`. |

**Rakan implementation notes:**
- This is a documentation-shape check, not a behavior test. Skarner is an agent definition, not a script — so assertions are grep-based.
- If `agents/skarner/` does not exist yet (unlikely — check), stub the test with an XFAIL that skips cleanly.

### 2.9 Migration-only assertions — see §3.6 smoke test for runnable migration checks.

---

## 3. Integration tests (cross-boundary)

### 3.1 Full `memory-consolidate.sh` end-to-end — `scripts/test-memory-consolidate-e2e.sh` <!-- orianna: ok -->

**Gates:** T4 post-impl.
**Scope:** runs `scripts/memory-consolidate.sh evelynn` (or a test-double coordinator) against a controlled fixture that exercises ALL branches in one call: sessions-fold + INDEX regen + archive policy + commit/push simulation.

**Assertions:**

| # | Assertion |
|---|---|
| I1 | Existing `sessions/*.md` → `<coordinator>.md ## Sessions` behavior is byte-identical to the pre-ADR `memory-consolidate.sh` (captured snapshot for regression). |
| I2 | INDEX regenerates even when `last-sessions/` is empty (produces a header-only file). |
| I3 | Commit message exactly matches `chore: <coordinator> memory consolidation YYYY-MM-DD`. |
| I4 | Both `last-sessions/INDEX.md` and any moved `archive/<uuid>.md` files are staged in the same commit as the `sessions/` fold. |
| I5 | `flock`/noclobber lock is held during the run (concurrent second invocation exits as no-op — see §4.3). |
| I6 | Script honors `--index-only` as a short-circuit: sessions-fold is skipped, archive is skipped, commit+push are skipped. |
| I7 | Script is POSIX-portable bash (Rakan: run under `bash --posix` + `dash` quick smoke; warn-only, not hard assert). |

**Rakan implementation notes:**
- Use a scratch repo under `$(mktemp -d)`; copy the real `scripts/memory-consolidate.sh` into it and point the script at the scratch `agents/` tree via a `STRAWBERRY_MEMORY_ROOT` env shim (Rakan may need to add this shim to the script itself during T4 impl — call out in the PR).
- Snapshot golden files under `scripts/fixtures/memory-consolidate-e2e/` (create via git, not gitignored).

### 3.2 Boot simulation — `scripts/test-coordinator-boot-simulation.sh` <!-- orianna: ok -->

**Gates:** T8 (after bootstrap) + T9 (after agent-def rewrite).
**Scope:** simulates a coordinator's boot by reading the files in order from `initialPrompt` and measuring the outcome.

**Assertions:**

| # | Assertion | Rakan note |
|---|---|---|
| J1 | Boot reads exactly 8 files (ADR §7 table), in the documented order. | Parse via regex; assert list length + entries. |
| J2 | Positions 7–8 are `open-threads.md` + `INDEX.md`. | (Dup of D2, but enforced at runtime rather than from agent-def text; catches drift between doc and reality.) |
| J3 | Combined bytes of positions 7–8 < 8 KB for Evelynn post-bootstrap. | `wc -c`; hard assert. |
| J4 | Combined bytes of positions 1–8 for Evelynn < 20 KB (generous ceiling — recommendation target is ~4–5k tokens ≈ 16 KB). | Soft assert with a clear message. |
| J5 | No `last-sessions/<uuid>.md` shard (non-INDEX) is read during simulated boot. | Read-tracing via `strace -f` is overkill; simpler: verify `initialPrompt` itself doesn't reference any `<uuid>.md` filename. |
| J6 | Boot simulation for Sona produces symmetric results. | Parameterise on coordinator name. |
| J7 | Prompt-cache stability — static prefix (positions 1–6) byte-identical across two consecutive simulated boots. Dynamic tail (7–8) may differ. | Hash positions 1–6; assert hash equal between runs. Hash positions 7–8 to record, not assert. |

**Rakan implementation notes:**
- This test is the single most load-bearing check that the ADR's stated savings actually materialise. Do not skip it.
- J7 is the prompt-cache invariant. If it fails, either the static block churned (bug) or the dynamic block bled into static (bug).

### 3.3 `/end-session` Step 6b atomic commit — `scripts/test-end-session-memory-integration.sh` <!-- orianna: ok -->

**Gates:** T5 → T6.
**Scope:** drives a synthetic coordinator session through the full end-session flow; asserts atomic commit and failure-partial recoverability.

**Assertions (from ADR §9.3, extended):**

| # | Assertion | Rakan note |
|---|---|---|
| K1 | On successful run: shard + `open-threads.md` + `INDEX.md` all present in the final commit. | `git show --stat HEAD` grep. |
| K2 | Step 6 completes before Step 6b (enforced by ordering). | Inject a tracing hook around each step; assert timestamp order. |
| K3 | Step 6b completes before Step 9 (commit/push). | Same technique. |
| K4 | If Step 6b fails partway (inject `false` into INDEX regen): shard write still exists on disk, staged but not committed. | Force failure; assert `git status` shows the shard staged but no HEAD commit. |
| K5 | Manual recovery works: run `memory-consolidate.sh --index-only` + re-stage + commit; no data loss. | Scripted recovery sequence; assert final `git log --stat` is correct. |
| K6 | Pre-push hook passes (correct commit prefix, no secrets, TDD gate green). | Run the hook against the scratch commit. |
| K7 | Commit message matches the end-session template (first line contains coordinator name + "session close"). | Regex match. |
| K8 | On interrupt (SIGINT during Step 6b): working tree is consistent — either pre-6 state or post-6b state, never mid-6b. | See §4.4 for fault-injection technique. |

**Rakan implementation notes:**
- This is the richest integration test. Budget ~45–60 min.
- Stub `clean-jsonl.py` so the test doesn't need a real transcript.
- K4 is the key recoverability check — without it the soft-fail mitigation in ADR §10 #1 is unproven.

### 3.4 Lissandra pre-compact atomic write — `scripts/test-lissandra-precompact-integration.sh` <!-- orianna: ok -->

**Gates:** T7.
**Scope:** mirrors §3.3 but runs the Lissandra pre-compact path instead of `/end-session`. Symmetry is the point: whatever `/end-session` produces, Lissandra must produce identical artifacts.

**Assertions:**

| # | Assertion |
|---|---|
| L1 | Lissandra shard + updated `open-threads.md` + regen INDEX appear in one commit. |
| L2 | Diff between a `/end-session` artifact set and a Lissandra artifact set (same synthetic input) is empty modulo timestamp and UUID. |
| L3 | Interrupting Lissandra mid-run leaves recoverable state (see §4.4). |
| L4 | Works for `concern: personal` (Evelynn dispatch) AND `concern: work` (Sona dispatch). |

**Rakan implementation notes:**
- L2 is the symmetry check. Without it, drift between the two write paths is invisible.
- Drive Lissandra via its profile rather than a live SDK call — synthesize the input transcript, run the Step-6b shell sequence by hand, compare.

### 3.5 Skarner search path works post-cutover — `scripts/test-skarner-integration.sh` <!-- orianna: ok -->

**Gates:** post-T9.
**Scope:** given a prompt of the form "find the thread about X in historical shards", assert Skarner (invoked via Agent tool or simulated shell equivalent) reads from `last-sessions/<uuid>.md` and `last-sessions/archive/<uuid>.md` — and NOT from the removed `filter-last-sessions.sh` path.

**Assertions:**

| # | Assertion |
|---|---|
| M1 | Skarner profile contains no reference to `filter-last-sessions.sh`. |
| M2 | Skarner can resolve a `<uuid>` mentioned in INDEX to the on-disk shard in either `last-sessions/` or `archive/`. |
| M3 | Skarner does NOT attempt to mass-load all shards at start-of-task (verifies lazy contract). |

**Rakan implementation notes:**
- Simulate Skarner's file reads by recording the list of files the agent profile instructs it to open (grep of profile prose, not live Agent tool call — keep it cheap).

### 3.6 Migration smoke — `scripts/test-migration-smoke.sh` <!-- orianna: ok -->

**Gates:** T8.
**Scope:** exercises the one-shot bootstrap for Evelynn + Sona and validates the before/after boot shape.

**Assertions (from ADR §9.4, extended):**

| # | Assertion | Rakan note |
|---|---|---|
| N1 | `cp -r agents/evelynn/memory agents/evelynn/memory.backup-$(date +%s)` runs cleanly; backup dir is NOT committed (gitignored or `rm -rf`'d at end). | Ensure `.gitignore` entry exists OR the test cleans up in a trap. |
| N2 | Hand-seeded `open-threads.md` for Evelynn: every thread present in the union of the 23 shards' `## Open threads into next session` sections appears in `open-threads.md` (no silent drops). | Diff script: parse each shard's section, dedup, compare against `open-threads.md`. |
| N3 | Same N2 check for Sona (2 shards + `## Sessions` "Paused work (to resume)" entries). | Parameterise. |
| N4 | Initial INDEX generated: row count equals shard count in `last-sessions/`. | Call `--index-only`, count rows. |
| N5 | Combined `open-threads.md` + `INDEX.md` < 8 KB for Evelynn. | `wc -c`; hard assert. |
| N6 | Combined < 4 KB for Sona (lower volume). | `wc -c`; soft assert. |
| N7 | `scripts/filter-last-sessions.sh` is removed; no remaining references in tree. | `! test -f` + `! grep -r filter-last-sessions .claude/ scripts/ agents/`. |
| N8 | First simulated post-cutover boot (reuse §3.2) completes cleanly with the new files. | Chained. |
| N9 | No shard file lost during migration (pre-migration shard UUIDs still exist on disk — either in `last-sessions/` or `archive/`). | Snapshot pre-migration UUID list; verify post-migration membership. |
| N10 | `git log --follow <shard>` still works for each migrated shard (history preserved via `git mv`). | Spot-check 3 shards. |

**Rakan implementation notes:**
- Runs once at T8 time; the CI mode can run a read-only variant that skips the actual copy-out.
- N9 is the "no data loss" invariant. Most important assertion in the whole plan. Do not weaken.

---

## 4. Fault-injection harnesses

### 4.1 Interrupted write during consolidation — `scripts/test-faultinject-consolidate-interrupt.sh` <!-- orianna: ok -->

**Scope:** mid-consolidation interrupts must not corrupt state.

**Scenarios:**

| # | Injection point | Expected |
|---|---|---|
| P1 | SIGINT during `sessions/` → `<coordinator>.md` fold (pre-INDEX). | Sessions-fold rolled back OR committed; never mid-state. INDEX unchanged. |
| P2 | SIGINT during INDEX regen (between read-shards and write-INDEX). | INDEX either unchanged-from-previous OR new-complete. No partial/truncated INDEX. |
| P3 | SIGINT during archive move (between `git mv` calls for shards N and N+1). | All already-moved shards recorded in INDEX on next run; no orphan — shard either fully in `last-sessions/` or fully in `archive/`. |
| P4 | SIGKILL during the commit step. | Next `memory-consolidate.sh` run detects the uncommitted state and either completes or errors loud. |
| P5 | Disk-full simulation (`ulimit -f 0` or a tiny tmpfs). | Script fails loud; INDEX not truncated. |
| P6 | Permission denied on `archive/` dir. | Script fails loud; original `last-sessions/<uuid>.md` preserved. |

**Rakan implementation notes:**
- Use a background `( memory-consolidate.sh; ) & PID=$!; sleep 0.05; kill -INT $PID` pattern.
- Because the script is fast, injection is timing-sensitive — add a debug env var (`STRAWBERRY_SLEEP_BEFORE_STEP=<N>`) to the T4 impl so tests can synchronize deterministically. Call this out in Rakan's impl PR.
- Assertions after each injection: run `git status` + walk `last-sessions/` + read INDEX; confirm no truncation (file-size > 0 OR absent, never ½-written).

### 4.2 Concurrent `/end-session` invocations — `scripts/test-faultinject-concurrent-endsession.sh` <!-- orianna: ok -->

**Scope:** two parallel coordinator sessions race on `open-threads.md` and `INDEX.md`.

**Scenarios:**

| # | Injection | Expected |
|---|---|---|
| Q1 | Two `/end-session` flows spawn simultaneously; both hit Step 6b at the same time. | `flock`/noclobber serializes them OR second exits as no-op with a clear message. Either outcome acceptable; silent corruption is not. |
| Q2 | Two flows produce conflicting `open-threads.md` edits. | Git merge conflict surfaces at push-time. Asserts: pre-push detects conflict, blocks push. |
| Q3 | One flow runs `--index-only` while the other runs the full consolidation. | Lock held by full run; `--index-only` exits no-op per ADR §10 #8. |
| Q4 | Both flows write distinct shards (different UUIDs) — INDEX must end up containing both. | After both settle (conflict resolved), INDEX row count == 2 shard rows. |

**Rakan implementation notes:**
- Use `( flow1 & ) ; ( flow2 & ) ; wait`.
- Q2's conflict resolution is out-of-test scope; the test only verifies that the conflict IS detected (i.e. git surfaces it), not that it auto-resolves.
- Budget ~30 min.

### 4.3 Advisory lock — `scripts/test-faultinject-lock.sh` <!-- orianna: ok -->

**Scope:** verifies flock/noclobber behavior of `memory-consolidate.sh`.

**Scenarios:**

| # | Injection | Expected |
|---|---|---|
| R1 | Pre-acquire the lock file via `flock -x <lockfile> sleep 30 &`, then invoke the script. | Script exits quickly with lock-held message, non-zero exit code. |
| R2 | Stale lock file (lockfile present but holder process dead). | Script acquires lock and runs (flock handles PID-liveness automatically). |
| R3 | Lock held across `--index-only` invocation. | Exits no-op per ADR §10 #8. |

### 4.4 Interrupted `/end-session` Step 6b — `scripts/test-faultinject-endsession-interrupt.sh` <!-- orianna: ok -->

**Scope:** Step 6b atomicity under interrupt.

**Scenarios:**

| # | Injection point | Expected |
|---|---|---|
| S1 | SIGINT between Step 6 (shard write) and Step 6b-start. | Shard file exists on disk, staged. Recovery via rerunning Step 6b manually is documented and works. |
| S2 | SIGINT mid-Step-6b (after `open-threads.md` write, before INDEX regen). | `open-threads.md` update staged; INDEX stale. Running `memory-consolidate.sh --index-only` on recovery produces correct INDEX. |
| S3 | SIGINT during commit step. | Either nothing committed (re-runnable) OR commit completed atomically (Rakan: git commits are atomic at the OS level). |
| S4 | Identical scenarios S1–S3 via Lissandra's pre-compact path (symmetry with §3.4). | Same outcomes. |

### 4.5 Shard-missing reference in `open-threads.md` — `scripts/test-faultinject-missing-shard-ref.sh` <!-- orianna: ok -->

**Scope:** the pre-archive ref-guard relies on reading `open-threads.md` and matching UUIDs. What if `open-threads.md` references a UUID that doesn't exist on disk (stale pointer)?

**Scenarios:**

| # | Injection | Expected |
|---|---|---|
| T1 | `open-threads.md` cites UUID `abc12345`; no `last-sessions/abc12345.md` exists (maybe archived long ago or hand-deleted). | `memory-consolidate.sh` logs a warning ("open-threads references missing shard") but does NOT crash. Consolidation completes. |
| T2 | `open-threads.md` cites an archived UUID. | Reference guard recognises archive path; still blocks re-archiving if somehow re-added. |
| T3 | `open-threads.md` is missing entirely (first bootstrap case). | Script treats it as empty — no references, no shards skipped. |
| T4 | `open-threads.md` is present but empty. | Same as T3 — no references. |
| T5 | `open-threads.md` contains a UUID that's a substring of another valid UUID. | Reference guard does WORD-boundary match, not substring match. Assert only exact-UUID matches are blocked. |

**Rakan implementation notes:**
- T5 is the nastiest bug class — a naive `grep -F <uuid>` will trigger false positives. Build the parser with regex word-boundary anchors.
- Fixture UUIDs must be crafted to exercise the substring case: e.g. `abc12345` and `abc123456789`.

---

## 5. Migration assertions (before/after boot comparison) — `scripts/test-migration-before-after.sh` <!-- orianna: ok -->

**Gates:** T8 + T12 (dogfood).
**Scope:** most-load-bearing test in the plan — proves the ADR's claimed token savings.

**Procedure:**

1. **Before:** with pre-migration tree (use a git ref `main^N` of the feature branch before T8), simulate Evelynn boot. Measure:
   - Number of files read at boot.
   - Total bytes of files read at boot.
   - Tokens (approx bytes/4) for the boot prefix.
2. **After:** with post-migration tree (tip of feature branch after T9), simulate Evelynn boot. Measure same.

**Assertions:**

| # | Assertion |
|---|---|
| U1 | After-boot file count == 8 (ADR §7 table). |
| U2 | Before-boot file count was ≥ 10 (5 static + ≥5 shards typical). |
| U3 | After-boot total bytes < Before-boot total bytes by at least 20 KB (recommendation §Token budget estimate: 40 KB saved from 23-shard load alone). |
| U4 | After-boot tail (positions 7–8) < 8 KB. |
| U5 | Static prefix (positions 1–6) identical-or-smaller between before and after (no new static docs added at boot). |
| U6 | Every shard UUID readable pre-migration is readable post-migration (via `last-sessions/` OR `archive/`). |
| U7 | Symmetric test for Sona. |

**Rakan implementation notes:**
- Checkout the "before" tree via `git worktree add` (never raw `git checkout` — CLAUDE.md Rule 3).
- Report results in the T12 commit evidence.

---

## 6. Test-runner integration

**Pre-push hook chain** (`scripts/hooks/pre-push.sh`) must invoke, in order:
1. Existing hooks (secret-scan, commit-prefix, TDD gate).
2. `scripts/test-memory-consolidate-index.sh` — cheap, always run.
3. `scripts/test-memory-consolidate-archive-policy.sh` — cheap, always run.
4. `scripts/test-end-session-skill-shape.sh` — cheap, grep-only.
5. `scripts/test-boot-chain-order.sh` — cheap, grep-only.

Heavier tests (§3, §4, §5) run on demand (Rakan's impl PR CI job) but NOT on every pre-push. Rakan to wire a GitHub Actions job `.github/workflows/memory-redesign-tests.yml` that runs the full suite on PRs touching `scripts/memory-consolidate.sh`, `scripts/_lib_last_sessions_index.sh`, `.claude/skills/end-session/SKILL.md`, `.claude/agents/evelynn.md`, `.claude/agents/sona.md`, `.claude/agents/lissandra.md`, or `agents/lissandra/**`. <!-- orianna: ok -->

**CI entrypoint** — `scripts/test-memory-redesign-all.sh` <!-- orianna: ok -->: a single script that invokes every test in §2–§5 in order. Exit 0 only if every sub-test returns 0 or XFAIL-expected. Print a summary line at the end (`PASS: N  FAIL: M  XFAIL: K`).

---

## 7. Surface-coverage audit (task-prompt surfaces → tests)

| Surface (from Sona's task prompt) | Tests |
|---|---|
| 1. `memory-consolidate.sh` rewrite: INDEX regen correctness, archive policy 14d OR 20, reference-check guard | §2.1 A1–A9, §2.2 B1–B10, §2.3 C1–C5, §3.1 I1–I7, §4.1 P1–P6, §4.3 R1–R3, §4.5 T1–T5 |
| 2. `open-threads.md` eager load at boot, tail position, prompt-cache stability | §2.4 D1–D7, §3.2 J1–J7 |
| 3. `last-sessions/INDEX.md` eager load, TL;DR shape, newest-first | §2.1 A2/A3/A4/A5/A8, §2.5 E1–E5, §3.2 J1–J3 |
| 4. `/end-session` Step 6b atomicity | §2.6 F1–F7, §3.3 K1–K8, §4.4 S1–S3 |
| 5. Lissandra pre-compact parity | §2.7 G1–G7, §3.4 L1–L4, §4.4 S4 |
| 6. Skarner on-demand retrieval | §2.8 H1–H4, §3.5 M1–M3 |
| 7. Migration — both coordinators in one PR, shards get INDEX entries retroactively, filter-last-sessions.sh removed | §3.6 N1–N10, §5 U1–U7 |
| 8. Failure injection: interrupted writes, concurrency, missing-shard refs | §4.1 P1–P6, §4.2 Q1–Q4, §4.3 R1–R3, §4.4 S1–S4, §4.5 T1–T5 |

Every surface has at least one unit-level + one integration-or-fault-injection check.

---

## 8. Rakan implementation order (recommended)

1. X1 (§2.1) — xfail commit for INDEX regen.
2. X2 (§2.2) — xfail commit for archive policy.
3. T2 + T4 (scripts) — impl; X1 + X2 go green.
4. Add §2.3 + §2.5 regression guards (post-impl).
5. X3 (§2.6 + §3.3) — xfail commits for end-session.
6. T5 + T6 — impl; X3 goes green.
7. X4 (§2.7) — xfail commit for Lissandra.
8. T7 — impl; X4 goes green.
9. X5 (§2.4) — xfail commit for boot-chain order.
10. T9 + T10 — impl; X5 goes green.
11. X6 (§3.6 + §5) — xfail commit for migration.
12. T8 — bootstrap; X6 goes green.
13. Fault-injection suites (§4.1–§4.5) — commit post-impl as regression guards.
14. CI wiring (`scripts/test-memory-redesign-all.sh` + GitHub Actions workflow).
15. T12 — dogfood + commit evidence.

---

## 9. Blocking questions for Duong / Swain

**None blocking implementation.** Three low-stakes clarifications Rakan may hit — pre-answered with defaults so he can proceed:

1. **Exact INDEX row format** (table vs dot-separated) — Rakan picks during T2 impl; §2.5 E2 regex updates during the X1 xfail commit to match.
2. **`STRAWBERRY_MEMORY_ROOT` env shim** for testability (§3.1 I1) — Rakan adds this to the T4 impl; if Xayah-the-reviewer disagrees, raise at impl-PR review.
3. **`STRAWBERRY_SLEEP_BEFORE_STEP` debug hook** for deterministic fault injection (§4.1) — Rakan adds behind an env-gate so production runs are unaffected.

If any of these three surprise Swain or Duong at review time, raise in the impl PR thread, not here.

---

## 10. Handoff summary

- **Xfail-first commits:** X1–X6 (six commits, each on the feature branch before its impl).
- **Test scripts to create:** 15 new `scripts/test-*.sh` files (§2.1–§2.8, §3.1–§3.6, §4.1–§4.5, §5, §6 CI entrypoint).
- **Test scripts to modify:** `scripts/hooks/pre-push.sh` (wire the cheap tests).
- **New workflow file:** `.github/workflows/memory-redesign-tests.yml`.
- **Invariants protected:** boot-token, INDEX-freshness, archive-policy, atomicity, ordering, no-orphan, bootstrap-completeness, prompt-cache stability, migration-lossless.
- **Rakan authors; Vi/Caitlyn run.** Xayah reviews the impl PR for coverage gaps before merge.
