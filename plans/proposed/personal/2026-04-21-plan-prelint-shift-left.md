---
status: proposed
concern: personal
owner: karma
created: 2026-04-21
orianna_gate_version: 2
tests_required: true
complexity: quick
tags: [orianna, hooks, plan-lifecycle, shift-left]
related:
  - plans/approved/personal/2026-04-20-plan-structure-prelint.md
  - architecture/plan-lifecycle.md
  - scripts/hooks/pre-commit-t-plan-structure.sh
orianna_signature_approved: "sha256:7347316a9dcc3cd6f760e580039dafa85dbb43b66d8e1a923a438fb97f455857:2026-04-21T04:38:24Z"
---

# Plan pre-lint: shift all of Orianna's deterministic structural checks left

## 1. Problem & motivation

The existing pre-commit hook (`scripts/hooks/pre-commit-t-plan-structure.sh`) catches frontmatter, `## Tasks` / `## N. Tasks` structure, and `estimate_minutes:` per task. But several of Orianna's sign-time checks are also purely deterministic and are still only enforced at sign/promote time, costing planners hours of cycle time when findings surface. Today's inbox alone has three plans blocked on things a 200ms awk pass could have caught at `git commit`.

Specifically, Orianna rejects plans for these deterministic reasons that the commit hook does NOT currently catch:

1. **Literal `## Tasks` heading** — variants like `## Task breakdown (Aphelios)` are rejected. (The current hook accepts `## Tasks` or `## N. Tasks`, but does not flag a plan that has only the variant heading and no `## Tasks`.)
2. **Per-task `estimate_minutes: <int in [1,60]>` as a key:value** on the task line — not just a table column. (Already enforced — keep parity; add tests.)
3. **Test-task title qualifier** — any task under `## Tasks` whose first title word is one of {xfail, test, regression} MUST either (a) have its title begin with one of {Write, Add, Create, Update}, or (b) carry a `kind: test` metadata token on the task line.
4. **Cited backtick-paths must exist on disk** — any `` `path/like/this.ext` `` cited in the body must resolve relative to the repo root, UNLESS the line carries a `<!-- orianna: ok -->` suppression marker.
5. **Forward self-reference** — a plan citing its own future promoted path (e.g. a plan in `plans/proposed/` citing `plans/approved/.../<same-slug>.md`) requires `<!-- orianna: ok -->`.

Body-hash carry-forward freshness (Orianna's sixth sign-time check) is NOT implementable at commit time — the signature is appended *after* the body is committed by definition. It stays Orianna's job; explicitly out of scope here.

## 2. Decision

Extend `scripts/hooks/pre-commit-t-plan-structure.sh` (and its sourced lib if one exists, or inline in the awk pass) with checks 1, 3, 4, 5. Keep 2's existing coverage and pin it with one additional regression test. Every new rule emits a `[lib-plan-structure] BLOCK: ...` message identical in shape to what Orianna prints, so planners see the same error in both places. TDD per Rule 12: xfail test first, impl second, on the same branch, in one PR.

Migration — grandfather. The hook only runs on staged diffs, so untouched existing plans stay unaffected until next edit (same pattern the existing hook already uses). No retro-fix sweep; document the grandfathering in `architecture/plan-lifecycle.md`. Plans currently in the inbox with findings are unblocked by their authors making a targeted fix commit that now goes green first try.

## 3. Design

### Rule mappings (Orianna contract → hook enforcement)

| # | Orianna rule | Hook detection |
|---|---|---|
| 1 | Literal `## Tasks` or `## <N>. Tasks` required | Post-frontmatter scan: if file contains `## Task breakdown` or `## Tasks (`  but no `^## Tasks[[:space:]]*$` / `^## [0-9]+\. Tasks[[:space:]]*$`, BLOCK with message `no canonical '## Tasks' heading found (variant '<matched>' is not accepted)` |
| 3 | Test task title qualifier | In `in_tasks` scope, when task line matches `^- \[[ xX]\] \*\*[A-Z0-9]+\*\* — (xfail\|test\|regression)\b` (case-insensitive on the qualifier word), require either the line also contains `kind: test` token OR the FIRST WORD after the em-dash/hyphen is in {Write, Add, Create, Update}. BLOCK otherwise |
| 4 | Cited backtick paths exist | Scan body (non-frontmatter, non-code-fence) for `` `X` `` tokens where X matches `^[a-zA-Z0-9_./-]+\.[a-zA-Z0-9]+$` OR contains a `/` AND does not start with `http`. For each, check `test -e "$REPO_ROOT/$X"`. Skip line if it contains `<!-- orianna: ok -->`. BLOCK missing with `cited path does not exist: <X> (add <!-- orianna: ok --> to suppress for prospective paths)` |
| 5 | Forward self-reference | If any backtick path matches the plan's own slug but a different phase directory than the plan's current phase (derived from file path), require `<!-- orianna: ok -->` on the line. BLOCK otherwise |
| 2 | Per-task estimate_minutes | Already enforced — add one regression test covering the table-column-only anti-pattern |

### Implementation shape

Single awk pass (extend the existing state machine in the hook). Add per-file state:
- `has_task_breakdown_variant`, `has_canonical_tasks` — for rule 1.
- `plan_slug`, `plan_phase` — derived from `FILENAME` in `reset_file()`.
- In-loop path-extraction from backtick spans with suppression-marker check.

Code-fence tracking: a line starting with ```` ``` ```` toggles `in_code_fence`; suppress checks inside fences.

Suppression marker format: `<!-- orianna: ok -->` — matches Orianna's existing contract. Per-line scope.

### POSIX constraints

Rule 10 — keep POSIX `sh` + POSIX awk. No `ENDFILE`, no gawk extensions. Sub-second on 10+ staged plans stays the target.

## Tasks

- [ ] **T1** — Write regression tests (xfail-first per Rule 12). kind: test. estimate_minutes: 40. Files: `scripts/hooks/test-pre-commit-plan-structure.sh` <!-- orianna: ok -->. DoD: test cases added for each of the 5 rules above — (1a) plan with only `## Task breakdown (Foo)` heading → BLOCK, (1b) plan with both variant and canonical → PASS, (2) task row in a markdown table with estimate column but no `estimate_minutes:` key on the line → BLOCK, (3a) test task titled `**T1** — xfail hook behaviour` → BLOCK, (3b) same task with `kind: test` on line → PASS, (3c) task titled `**T1** — Write xfail for hook` → PASS, (4a) plan citing `scripts/does-not-exist.sh` without suppression → BLOCK, (4b) same with `<!-- orianna: ok -->` on same line → PASS, (5a) plan in `plans/proposed/personal/2026-04-21-foo.md` citing `plans/approved/personal/2026-04-21-foo.md` without suppression → BLOCK, (5b) same with suppression → PASS. All tests initially fail against current hook (xfail). Test file carries `orianna: ok` suppression for its own intentionally-broken fixture paths.
- [ ] **T2** — Implement rules 1, 3, 4, 5 in the hook. estimate_minutes: 55. Files: `scripts/hooks/pre-commit-t-plan-structure.sh` <!-- orianna: ok -->. DoD: all T1 tests pass; existing `scripts/hooks/test-pre-commit-plan-structure.sh` suite still green; `scripts/hooks/test-hooks.sh` overall still green; hook runs in < 200ms on 10 staged plans (benchmark captured in commit message); POSIX — no gawk extensions. Commit follows T1 on the same branch per Rule 12.
- [ ] **T3** — Migration check. estimate_minutes: 15. Files: `agents/karma/memory/karma.md` <!-- orianna: ok -->. DoD: run the extended hook against every plan under `plans/proposed/**` and `plans/approved/**`; document which would fail the new rules; confirm grandfathering (hook only runs on staged diffs) covers the quiet cases; flag for Talon any plan that needs a targeted fix-commit to re-pass.
- [ ] **T4** — Docs. estimate_minutes: 20. Files: `architecture/plan-lifecycle.md` <!-- orianna: ok -->, `architecture/key-scripts.md` <!-- orianna: ok -->. DoD: pre-commit structural lint section in `plan-lifecycle.md` lists all five rules with Orianna-parity framing; `key-scripts.md` entry for `pre-commit-t-plan-structure.sh` updated to enumerate rules 1–5; grandfathering policy explicitly stated.

Total estimate: 130 minutes. Single PR, reviewers Senna + Lucian. Talon picks up execution after approve.

## Test plan

The xfail test file `scripts/hooks/test-pre-commit-plan-structure.sh` (extended in T1) is the regression contract. Invariants protected:

- **Canonical heading invariant** — only literal `## Tasks` / `## <N>. Tasks` satisfies the structure check; variant spellings are loudly rejected at commit.
- **Test-task qualifier invariant** — test tasks must either begin with an approved action verb (Write/Add/Create/Update) or carry `kind: test`; enforced at commit so Orianna never sees this class of finding again.
- **Path existence invariant** — every cited backtick path in a plan body either resolves on disk or carries `<!-- orianna: ok -->` suppression; prospective paths stay explicit.
- **Forward-reference invariant** — a plan cannot silently cite its own promoted future location; the suppression marker makes forward references a conscious, reviewable act.
- **Estimate invariant (regression pin)** — table-column-only estimates stay rejected; every task must carry `estimate_minutes:` as a key on its own task line.
- **Grandfather invariant** — the hook only inspects staged diffs; quiet-on-disk plans are not retroactively blocked.

Test harness runs via `scripts/hooks/test-hooks.sh` and the pre-push TDD gate enforces xfail-before-impl on the branch.

## 4. Dogfooding

This plan file itself must pass the extended hook:
- Canonical `## Tasks` heading — present.
- Every task carries `estimate_minutes: <1-60>`. Verified: T1=40, T2=55, T3=15, T4=20.
- T1's title begins with `Write` (rule 3 pass); T2 with `Implement` — NOT in the approved verb set, so it carries `kind: test`? No — T2 is an impl task, not a test task, so rule 3 doesn't apply. Rule 3 only gates tasks whose title qualifier is `xfail`/`test`/`regression`. T1's qualifier is covered by starting with `Write`.
- Every cited prospective path carries `<!-- orianna: ok -->`. Verified inline.
- No forward self-reference (this plan in `proposed/` does not cite an `approved/` path with its own slug).

## 5. Rollback

Revert the T1+T2 commits (merge, not rebase — Rule 11). Hook falls back to current behaviour. No schema or data migration, no remote side-effect.

## 6. Open questions

- **OQ1** — Rule 4 false-positive risk on exotic backtick tokens (command snippets like `` `git log --oneline` ``). Mitigation: the path-detection regex requires a `.` extension OR a `/`, so flag snippets are skipped. Re-evaluate in T2 smoke.
- **OQ2** — Rule 5 slug derivation — should `YYYY-MM-DD-` prefix variations be normalised? Current recommendation: exact-slug match (post-date). Flag if a plan is renamed mid-flight.
