---
status: proposed
concern: personal
owner: karma
created: 2026-04-21
complexity: quick
orianna_gate_version: 2
tests_required: true
tags: [orianna-gate, plan-lifecycle, scripts, hooks, latency]
related:
  - feedback/2026-04-21-orianna-signing-latency.md
  - feedback/2026-04-21-orianna-signing-followups.md
  - plans/implemented/personal/2026-04-20-orianna-gated-plan-lifecycle.md
  - plans/approved/personal/2026-04-21-plan-prelint-shift-left.md
  - plans/approved/personal/2026-04-21-pre-orianna-plan-archive.md
architecture_changes: [architecture/key-scripts.md, architecture/plan-lifecycle.md]
orianna_signature_approved: "sha256:b372c004abac1146600759d94bd9fb66577044145d62afcedd332628e737d7fa:2026-04-22T07:46:44Z"
---

# Orianna gate speedups — mechanical fixes for signing latency and process failure modes

## 1. Problem & motivation

Sona's two feedback docs (`feedback/2026-04-21-orianna-signing-latency.md`,
`feedback/2026-04-21-orianna-signing-followups.md`) document a ~30-minute
wall-time floor per batched signing session across the work concern and four
distinct mechanical failure modes that cascade into full re-sign cycles.
Worst-case today: a single body edit on a signed plan silently invalidates the
signature, the invalidation is only detected at promotion time, and recovery
requires a full revert-to-proposed + re-sign round trip (~50 min).

Pre-lint shift-left (`plans/approved/personal/2026-04-21-plan-prelint-shift-left.md`,
PRs #12/#15) already ships Sona's option (b) and partial §D3 enforcement at
commit-time. The pre-Orianna plan archive (`plans/approved/personal/2026-04-21-pre-orianna-plan-archive.md`,
PR #14) decluttered grandfathered plans. Remaining gaps are all mechanical and
are the scope of this plan.

## 2. Decision

Ship six independent fixes to the scripts, hooks, and agent-definition directories.
Five are mechanical process fixes; one is Orianna prompt tuning. All POSIX-portable
per Rule 10 except the prompt-tuning tasks which modify a markdown agent definition.

1. **Body-hash pre-commit guard** — new hook `scripts/hooks/pre-commit-orianna-body-hash-guard.sh` <!-- orianna: ok -- new file created by T2 -->
   that re-computes the body hash for every staged plan file carrying any
   `orianna_signature_*` frontmatter field and fails loud on mismatch. The
   error message IS the recovery runbook.
2. **Signed-fix commit shape** — extend `scripts/hooks/pre-commit-orianna-signature-guard.sh`
   to accept shape B (atomic body + signature commit) when the commit message
   carries a `Signed-Fix: <phase>` trailer AND the post-diff body hash equals
   the hash embedded in the new signature line. Halves commit ceremony per
   fix iteration.
3. **Stale git index lock auto-recovery** — at start of `scripts/orianna-sign.sh` <!-- orianna: ok -- existing script, updated by T7 -->
   and `scripts/plan-promote.sh`, detect a stale `.git/index.lock` <!-- orianna: ok -- git internals path, not a repo file --> file whose mtime is >60s old
   and which no live process holds (`lsof` empty); auto-clear with a loud
   audit line. Scope bounded to these two scripts.
4. **Batch-fix pre-pass** — new `scripts/orianna-pre-fix.sh` <!-- orianna: ok -- new file created by T9 --> that applies the
   three known-safe mechanical rewrites against a plan (or set of plans)
   before the first Orianna invocation:
   - bare `tools/demo-studio-v3/<rest>` rewritten to the workspace-prefixed form <!-- orianna: ok -- placeholder path pattern, not a real file ref -->
     (work-concern whitelist only)
   - URL-token suppressor insertion for well-known prose hosts like claude-platform docs
   - `?`-marker detection in §10/§11 (report-only; humans resolve)
5. **Auto-requalify folded into sign** — invoke the new pre-fix script
   from `scripts/orianna-sign.sh` under a `--pre-fix` flag
   (default on for `concern: work`, off for `concern: personal`) before the
   first `claude` call. This is the permanent form of #4; the standalone
   script remains available for manual batch runs over multiple ADRs.
6. **Orianna prompt tuning** (Sona latency option (c)) — patch `.claude/_script-only-agents/orianna.md` <!-- orianna: ok -- existing file, updated by T-prompt-2 -->
   and its plan-check prompt to reduce false-positive citation noise and improve
   throughput. Three sub-goals: (a) reduce over-citation on prose-mode path tokens
   (e.g. bare filenames like `main.py` <!-- orianna: ok -- illustrative prose token, not a file claim --> in narrative sentences flagged as unresolvable
   paths); (b) batch anchor greps so one Orianna pass handles N claims rather than
   N sequential grep calls; (c) cache claim-contract resolution across iterations of
   the same plan so a re-sign after a minor body fix does not re-verify unchanged claims.
   Target file: `.claude/_script-only-agents/orianna.md`. <!-- orianna: ok -- same file ref as above -->
   See T-prompt-1/2/3.

### Body-hash reproducibility — shared dependency for #1 and #2

`scripts/orianna-hash-body.sh` already canonicalizes:
- strips YAML frontmatter (content between the first two `---` delimiters)
- normalizes CRLF → LF
- strips trailing whitespace from each line
- SHA-256s via `sha256sum` or `shasum -a 256`

No YAML key-order canonicalization, no BOM handling, no Unicode normalization.
For items #1 and #2 to be sound, the hash must be reproducible across
pre-commit, post-commit, and promotion-time contexts. The existing function is
deterministic for our corpus (all plan files are UTF-8, no BOM, standard LF or
CRLF line endings). **No canonicalization work is required before items #1 and
#2 can ship.** If a future plan introduces BOM or NFD/NFC ambiguity, revisit.

### Ordering

Items #1 and #2 both consume the hash-body script. Per the audit above, no
pre-work is needed — they can ship in parallel. Items #3, #4, #5 have no
dependency on the hash pipeline and can ship in any order relative to #1/#2.

### Scope — out

- New suppression-governance policy (full) — count cap, audit trail, and expiry review
  acknowledged in Sona's latency doc §Governance as a separate concern; not in this plan.
  Minimal reason-required enforcement is folded in as T11.c (see §Tasks).
- Sibling `-tasks.md` enforcement (Sona followup #4) — already addressed by
  pre-lint shift-left (PR #15); this plan does not re-touch it.

## Tasks

Inlined per D1A. Each task is a single checkbox entry with fields inline.
Tasks fronted with `kind: test` produce xfail tests committed before their
paired implementation task (Rule 12).

- [ ] **T1** — Write xfail tests for the body-hash pre-commit guard covering four fixture cases: signed plan with unchanged body (pass), signed plan with one-char body edit (fail with runbook error), plan with no signature (pass), plan with two signatures where only one stale hash is present (fail, name the stale phase). kind: test. estimate_minutes: 15. Files: `scripts/hooks/tests/test-pre-commit-orianna-body-hash-guard.sh` (new). DoD: all four cases fail because the guard script does not yet exist; committed before T2 per Rule 12. <!-- orianna: ok -- new test file created by T1 -->
- [ ] **T2** — Create the body-hash pre-commit guard script which, for every staged plan markdown file, extracts each `orianna_signature_<phase>` frontmatter field from the staged blob, computes the body hash via the hash-body helper, and exits 1 on mismatch with the self-documenting runbook error from the followups feedback doc §1. Wire into the install-hooks script. POSIX sh only. kind: implementation. estimate_minutes: 30. Files: `scripts/hooks/pre-commit-orianna-body-hash-guard.sh` (new), `scripts/install-hooks.sh` (updated). DoD: T1 tests pass; new hook runs in the installed chain; manual edit-then-commit on a signed plan reproduces the runbook message verbatim; admin `Orianna-Bypass:` trailer still works. <!-- orianna: ok -- new script file, created by this task -->
- [ ] **T3** — Write xfail tests for the extended signature guard covering four cases: case 1 shape A sig-only commit still passes; case 2 shape B commit with `Signed-Fix: approved` trailer and hash match passes; case 3 shape B commit with trailer but mismatched body hash fails; case 4 shape B commit touching two files fails. kind: test. estimate_minutes: 15. Files: `scripts/hooks/tests/test-pre-commit-orianna-signature-guard-signed-fix.sh` (new). DoD: cases 2 through 4 fail against the unchanged guard; committed before T4 per Rule 12. <!-- orianna: ok -- new test file created by T3 -->
- [ ] **T4** — Extend the existing signature guard at `scripts/hooks/pre-commit-orianna-signature-guard.sh` to accept shape B: when `COMMIT_EDITMSG` carries a `Signed-Fix: <phase>` trailer, skip the no-other-added-content check and instead require that the hash-body helper on the staged plan blob equals the hash parsed from the newly added `+orianna_signature_<phase>:` line. Preserve the one-file-scope check. Require `Signed-phase` to match `Signed-Fix`. kind: implementation. estimate_minutes: 45. Files: `scripts/hooks/pre-commit-orianna-signature-guard.sh` (updated). DoD: T3 tests pass; the existing signature-guard test suite still passes unmodified.
- [ ] **T5** — Teach the existing sign script at `scripts/orianna-sign.sh` to emit shape B commits when pre-fix rewrites were applied in the same invocation. Combine body edit plus signature insertion into a single `git add` / `git commit` carrying a `Signed-Fix: <phase>` trailer ahead of the existing Signed-by / Signed-phase / Signed-hash trailers. Preserve shape A when no pre-fix edits occurred. Update the `COMMIT_EDITMSG` write so the guard can see the trailer. kind: implementation. estimate_minutes: 20. Files: `scripts/orianna-sign.sh` (updated). DoD: manual smoke on a work-concern plan with a legacy workspace-style reference produces a single atomic commit containing both the rewrite and the signature, and passes the guard from T4.
- [ ] **T6** — Write xfail tests for the stale-lock helper covering three cases: stale lock older than 60s with no holder is cleared with the expected audit line; fresh lock younger than 60s is NOT cleared; lock held by a live `flock` holder is NOT cleared (skip gracefully when `flock` is unavailable). kind: test. estimate_minutes: 15. Files: `scripts/test-orianna-stale-lock-recovery.sh` (new). DoD: all three cases fail because the stale-lock helper does not yet exist; committed before T7 per Rule 12. <!-- orianna: ok -- new test file created by T6 -->
- [ ] **T7** — Implement the stale-lock helper at `scripts/_lib_stale_lock.sh` exposing `maybe_clear_stale_lock` and source it from `scripts/orianna-sign.sh` and `scripts/plan-promote.sh` at startup. Compute lock age via `stat -f %m` on macOS / `stat -c %Y` on Linux with a portable fallback; only clear when age exceeds 60 seconds AND `lsof .git/index.lock` returns no holder; treat a missing `lsof` as cannot-verify and refuse to clear. Emit the audit line from the followups feedback doc §3 to stderr on clear. kind: implementation. estimate_minutes: 30. Files: `scripts/_lib_stale_lock.sh` (new), `scripts/orianna-sign.sh` (updated), `scripts/plan-promote.sh` (updated). DoD: T6 tests pass; happy-path sign and promote runs unaffected; synthetic stale lock on a live repo is cleared exactly once with audit output. <!-- orianna: ok -- new file created by T7 -->
- [ ] **T8** — Write xfail tests for the pre-fix script covering four fixtures: a bare legacy workspace-prefixed token in a work-concern plan is rewritten to the requalified form; a backticked prose-host URL token gains a `<!-- orianna: ok -->` suppressor on the same line; a question-mark marker inside §10 or §11 produces a stderr warning with exit 0 and zero file change; a plan with none of these patterns is idempotent. Personal-concern fixture must NOT receive the workspace rewrite. kind: test. estimate_minutes: 20. Files: `scripts/test-orianna-pre-fix.sh` (new). DoD: all four cases fail because the pre-fix script does not yet exist; committed before T9 per Rule 12. <!-- orianna: ok -- new test file created by T8 -->
- [ ] **T9** — Implement the pre-fix script at `scripts/orianna-pre-fix.sh` accepting a plan path and optional concern flag. Infer concern from frontmatter if the flag is absent. Apply rewrites in three passes: pass A is concern-scoped legacy-prefix rewriting only on lines that lack the workspace prefix already; pass B appends `<!-- orianna: ok -->` to lines carrying backticked tokens in a small allowlist (the claude platform docs host, the anthropic docs host, and github); pass C reports question-mark markers in §10 or §11 to stderr without mutating the file. Exit 0 unless invocation error. Emit a rewrites summary to stdout for the caller to capture. kind: implementation. estimate_minutes: 45. Files: `scripts/orianna-pre-fix.sh` (new). DoD: T8 tests pass; a second invocation on the same file produces a zero-diff no-op. <!-- orianna: ok -- new file created by T9 -->
- [ ] **T10** — Add `--pre-fix` and `--no-pre-fix` flags to `scripts/orianna-sign.sh`. Default ON when plan frontmatter carries `concern: work`; default OFF otherwise. When ON, invoke the pre-fix script before the `claude` call and, if any body edits were produced, mark the run for the shape B commit path from T5. When OFF, preserve today's control flow byte-for-byte. kind: implementation. estimate_minutes: 20. Files: `scripts/orianna-sign.sh` (updated). DoD: manual smoke on a work-concern plan emits one atomic shape B commit; manual smoke on a personal-concern plan emits the unchanged shape A commit.
- [ ] **T11** — Update `architecture/key-scripts.md` with one paragraph each for the body-hash guard, the pre-fix script, the shape B commit contract, and the stale-lock helper. Update `architecture/plan-lifecycle.md` §D1.2 and §D7.3 to cross-reference the shape B clause and the body-hash guard. kind: docs. estimate_minutes: 15. Files: `architecture/key-scripts.md` (updated), `architecture/plan-lifecycle.md` (updated). DoD: both docs reflect shipped behavior and link back to this plan.
- [ ] **T11.b** — Grep past fact-check reports under `assessments/plan-fact-checks` <!-- orianna: ok -- existing directory, not a specific file --> for URL-shaped tokens Orianna flagged in the last 30 days. Produce a ranked top-5 hosts table at `assessments/orianna-url-host-frequency-2026-04-21.md`. <!-- orianna: ok -- new file created by T11.b --> Output is evidence for a v2 allowlist expansion PR, not a code change in this plan. kind: research. estimate_minutes: 20. Files: `assessments/orianna-url-host-frequency-2026-04-21.md` <!-- orianna: ok -- same new file ref as above --> (new). DoD: top-5 table produced with raw count per host; any host already in the T9 allowlist noted as confirmed.
- [ ] **T11.c** — Require reason text on `<!-- orianna: ok -->` suppression markers. Extend `scripts/hooks/pre-commit-zz-plan-structure.sh` to reject any new `<!-- orianna: ok -->` marker that lacks a `-- <reason>` suffix. Pattern enforced: `<!-- orianna: ok -- <non-empty reason> -->`. xfail-first: add a plan-fixture test that stages a bare `<!-- orianna: ok -->` and asserts the hook rejects it. Update T9 (batch-fix pre-pass) to emit canned reasons like `-- URL-shaped prose token (claude.com)` when auto-inserting suppressors. kind: implementation. estimate_minutes: 15. Files: `scripts/hooks/pre-commit-zz-plan-structure.sh` (updated), `scripts/orianna-pre-fix.sh` <!-- orianna: ok -- created by T9 --> (updated per T9). DoD: bare marker on a newly staged plan line is rejected at commit time; markers with a reason pass; existing bare markers in already-committed files are not retroactively flagged (only staged lines are checked).
- [ ] **T-prompt-1** — Audit Orianna prompt for over-citation patterns. Read `.claude/_script-only-agents/orianna.md`, <!-- orianna: ok -- existing agent def file --> sample the last 10 fact-check reports under `assessments/plan-fact-checks/`, <!-- orianna: ok -- existing directory, not a specific file --> categorize false-positive patterns (prose-mode path tokens, URL-tokens, inline code like `main.py` in narrative sentences). Produce a short findings doc at `assessments/orianna-prompt-audit-2026-04-21.md`. <!-- orianna: ok -- new file to be created --> No prompt edit yet. kind: research. estimate_minutes: 45. Files: `assessments/orianna-prompt-audit-2026-04-21.md` (new). DoD: findings doc lists at least three false-positive categories with example claims from real reports; recommended prompt patches are listed but not applied.
- [ ] **T-prompt-2** — Implement prompt-tuning patch based on T-prompt-1 audit. Update `.claude/_script-only-agents/orianna.md` <!-- orianna: ok -- existing agent def, updated by this task --> to apply recommendations: tightened claim-extraction rules, anchor-batch lookup instruction, claim-contract caching instruction. xfail-first: a test plan fixture that asserts a prose-mode `main.py` is NOT flagged. Pairs with T-prompt-1. kind: implementation. estimate_minutes: 60. Files: `.claude/_script-only-agents/orianna.md` (updated). <!-- orianna: ok -- same file ref as above --> DoD: the xfail fixture now passes; at least one false-positive category from T-prompt-1 is eliminated in a manual spot-check; existing Orianna signing smoke test is unaffected.
- [ ] **T-prompt-3** — Regression-verify prompt changes against past plans. Re-run Orianna sign on 3 recently-signed plans (pick from `plans/implemented/` last 7 days) and diff findings against the original fact-check reports. Expect: fewer false positives, same true positives. Commit the regression report at `assessments/orianna-prompt-regression-2026-04-21.md`. <!-- orianna: ok -- new file to be created by T-prompt-3 --> kind: verification. estimate_minutes: 30. Files: `assessments/orianna-prompt-regression-2026-04-21.md` (new). DoD: regression report shows no new false negatives introduced; false-positive count equal or lower than baseline on all three plans.

**Total: 16 tasks, 440 estimate_minutes.**

## Test plan

Invariants to protect:

1. **Body-edit-after-sign never lands silently.** Covered by T1. Regression
   risk: a developer touches a signed plan and commits — must be blocked
   at commit time, not at promotion time. Bypass is only the documented
   admin `Orianna-Bypass:` trailer.
2. **Shape A sig-only commits still pass.** Covered by the existing
   signature-guard test file (see scripts/hooks/tests/ directory); T3 must
   not regress it.
3. **Shape B commits require cryptographic body-hash match, not merely
   line-count match.** Covered by T3 case 3.
4. **Stale lock clearing is conservative.** Covered by T6 cases 2 and 3:
   fresh locks and locks with live holders must never be cleared.
5. **Pre-fix rewrites are idempotent.** Covered by T8: re-running pre-fix
   on an already-fixed plan produces no diff.
6. **Pre-fix is concern-scoped.** Covered by T8: personal-concern plans
   never receive the workspace rewrite.
7. **Signing a plan with no pre-fix needed is unchanged.** Covered by T10
   manual smoke; the default-off path for personal must be byte-identical
   to today's sign-script output.

All new tests live beside the existing shell-test conventions in the
scripts tree (hooks tests beside the hooks, top-level sign/promote tests
beside their scripts).

## Test results

T1–T11 (inclusive) landed in PR #19 (squash merge 98d310c). CI green:

- xfail-first check: PASS — https://github.com/harukainguyen1411/strawberry-agents/actions/runs/24765785979/job/72459578493
- regression-test check: PASS — https://github.com/harukainguyen1411/strawberry-agents/actions/runs/24765785979/job/72459578606

T-prompt-1 (audit research), T-prompt-2 (prompt-tuning implementation), and T-prompt-3 (regression verification) were deferred. T-prompt-2 and T-prompt-3 are subsumed into `plans/in-progress/personal/2026-04-22-orianna-substance-vs-format-rescope.md`. T-prompt-1 may be picked up by that plan or a follow-on.

## 5. Migration & rollback

- Each task lands in its own commit on its own branch via the safe-checkout
  helper.
- The body-hash guard (T2) is opt-in only in the sense that the install-hooks
  script must be re-run. Agents already re-run this on refresh; document in T11.
- Rollback: remove the new hook from the install-hooks script and delete the
  new script files. No schema changes, no data migration, no plan-file
  mutations at install time.

## 6. Success criteria

- A body edit on a signed plan is blocked at commit time (T2).
- A `Signed-Fix:` atomic commit passes the guard (T4).
- A stale lock from a dead agent is auto-cleared on next sign/promote (T7).
- A work-concern plan with a legacy workspace-prefixed reference signs clean
  on the first try (T9 + T10).
- Median sign iterations per ADR drops from ~3 to ~1 on the next batched
  signing session; commits per iteration drop from 2 to 1 for pre-fix cases.
- Median Orianna single-pass fact-check time drops by ≥25%, or if not,
  the T-prompt-1 audit doc explains why and defers the target.

## 10. Open questions

1. **Orianna prompt tuning (Sona latency (c)).** If the mechanical fixes don't bring
   median sign-time under 5 min per ADR, a prompt-level intervention is needed
   (over-citation reduction, anchor-batch lookups, claim-contract caching). —
   IN SCOPE — see T-prompt-1/2/3.
2. **URL-token allowlist scope.** T9 enumerates three well-known prose hosts
   (the claude platform docs, the anthropic docs, and the github host). Are
   there others that have fired in past fact-check reports that should seed
   the initial list? — LOCKED to this trio for v1. Expansion path defined:
   T11.b produces host-frequency evidence; a v2 allowlist expansion PR follows
   with that data.
3. **`lsof` absence on Git Bash Windows.** T7 treats missing `lsof` as
   "cannot verify — do not clear." On Windows this means stale locks are
   never auto-cleared. Accept this for v1; Windows usage of these scripts
   is rare and manual clearing remains available. Strawberry-agents is
   macOS-primary (Duong's laptops); Windows support is not a goal for this
   script. — LOCKED.
4. **Suppression-governance policy.** Sona's latency doc §Governance flags
   that suppression markers have no audit / count cap / reason
   requirement, and T9 will add more of them. — Minimal reason-required
   enforcement folded in as T11.c. Full governance (count cap, audit trail,
   expiry review) remains DEFERRED to a separate plan.

## 11. References

- `feedback/2026-04-21-orianna-signing-latency.md`
- `feedback/2026-04-21-orianna-signing-followups.md`
- `plans/implemented/personal/2026-04-20-orianna-gated-plan-lifecycle.md` §D1.2, §D7.3, §D9.4
- `plans/approved/personal/2026-04-21-plan-prelint-shift-left.md`
- `scripts/orianna-sign.sh`, `scripts/orianna-verify-signature.sh`,
  `scripts/orianna-hash-body.sh`, `scripts/plan-promote.sh`
- `scripts/hooks/pre-commit-orianna-signature-guard.sh`
- `architecture/plan-lifecycle.md`, `architecture/key-scripts.md`
