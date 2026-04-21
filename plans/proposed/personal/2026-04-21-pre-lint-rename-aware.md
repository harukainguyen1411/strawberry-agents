---
status: proposed
concern: personal
owner: karma
created: 2026-04-21
orianna_gate_version: 2
complexity: quick
tests_required: true
tags: [hooks, pre-commit, plan-lifecycle, bugfix]
related:
  - plans/approved/personal/2026-04-21-plan-prelint-shift-left.md
---

# Rename-aware Rule 4 in the plan-structure pre-commit hook

## Context

PR #15 (commit `7b3a3f3`) scoped Rule 4 (cited-path existence) to lines that
appear in the staged diff so legacy plans with cross-repo prose citations no
longer block modern commits. The scoping works for regular edits — one or
more small hunks — but breaks on `git mv` renames.

When `scripts/plan-promote.sh` moves a plan with `git mv`, git's staged
diff reports the file as `R<sim>` (rename) and, when similarity is less
than 100%, renders the entire new-side body as a single additions-only hunk.
The per-line `staged[]` map built in the hook therefore marks every line as
staged, and Rule 4 flags every path-shaped backtick token in the full plan
body. Ekko #65 spent roughly two hours (218 tool turns) mass-suppressing
tokens with `<!-- orianna: ok -->` during a single routine `proposed →
in-progress` promotion of
`plans/in-progress/personal/2026-04-21-memory-consolidation-redesign.md`
<!-- orianna: ok -->. This is the default path through plan-promote, so
every promotion hits it.

Fix: detect renames in the hook, and for renames compute a true
blob-to-blob diff (old file content vs new file content) rather than
relying on the `diff --cached --unified=0` output (which git renders as
additions-only). Feed that narrower added-line set to the existing Rule 4
scoping machinery. Rules 1, 2, 3, and 5 continue to inspect the full file —
they are integrity rules, not new-content rules. Pure renames with no
content change (`R100`) yield an empty added-line set and Rule 4 becomes a
no-op. Pure adds (new files, `A`) and pure modifies (`M`) keep their
current behavior unchanged. Very low-similarity renames that git downgrades
to `D`+`A` already take the `A` path (full body checked), which matches
today's behavior for genuinely new plans.

`scripts/fact-check-plan.sh` operates on plan files directly (no
staged-diff parsing), so it is unaffected by this change. The sibling
`scripts/hooks/pre-commit-t-plan-structure.sh` is the legacy/superseded
hook and is not in the invocation path post-PR-#15; we leave it alone.
The change is small enough to live inline in the existing
`scripts/hooks/pre-commit-zz-plan-structure.sh`; no new helper needed.
`scripts/_lib_plan_structure.sh` does not do staged-diff scoping today,
so it is not touched.

## Tasks

- [ ] **T1** — Write xfail regression tests for three rename scenarios (pure R100 rename, rename+frontmatter edit, genuinely new plan baseline). estimate_minutes: 25. Files: `scripts/hooks/test-pre-commit-plan-structure.sh` (updated). DoD: three new test cases committed and failing against the current hook (TDD gate). kind: test.

- [ ] **T2** — Replace the staged-plans collector with a rename-aware `git diff --cached --name-status --diff-filter=ACMR` loop that records `<status>\t<old>\t<new>` for renames and `<status>\t<path>` for A/C/M; preserve existing filters (template, archived, pre-orianna, spaces). estimate_minutes: 15. Files: `scripts/hooks/pre-commit-zz-plan-structure.sh` (updated). DoD: A/M cases collect identical target paths to today; T1(a) still fails for the correct reason.

- [ ] **T3** — Extend the staged-lines builder to branch on rename status: for R entries compute added lines via `git show :<old> > tmp_old` then `git diff --no-index --unified=0 -- tmp_old <new_abs>`; A/M keep today's path. estimate_minutes: 20. Files: `scripts/hooks/pre-commit-zz-plan-structure.sh` (updated). DoD: T1(a) and T1(b) now pass; T1(c) still passes (no regression).

- [ ] **T4** — Add defensive fallback: if the rename-mode blob diff fails (missing ref, etc.), emit a WARN and mark the file as fully-staged so behavior matches today's overzealous-but-safe baseline rather than silently passing. estimate_minutes: 10. Files: `scripts/hooks/pre-commit-zz-plan-structure.sh` (updated). DoD: fallback branch documented in a code comment; induced-failure synthetic test optional.

- [ ] **T5** — Run `scripts/hooks/test-pre-commit-plan-structure.sh` green; smoke-test by staging a real plan-promote-style `git mv` on a throwaway fixture and verifying zero Rule 4 BLOCK lines. estimate_minutes: 10. Files: none (validation). DoD: suite exits 0; smoke rename produces no Rule 4 findings.

- [ ] **T6** — Open PR (not direct-to-main) with commit prefix `chore:` (touches hook scripts, not application code). Request Senna + Lucian review. Use path-scoped commits (`git commit -m ... -- <hook-paths>`) to avoid sweeping foreign staged state. estimate_minutes: 10. Files: none (git ops). DoD: PR open, two reviewers assigned, CI green; no `--no-verify`, no pushed-commit amend, no AI coauthor trailer.

Total estimate: 90 minutes.

## Test plan

Three regression tests in `scripts/hooks/test-pre-commit-plan-structure.sh`
protect the invariant that Rule 4 only validates paths cited on lines
actually introduced by the commit:

1. **Pure rename, no content change** — stage `R100` from
   `plans/proposed/personal/fake-plan.md` <!-- orianna: ok --> to
   `plans/approved/personal/fake-plan.md` <!-- orianna: ok -->. Body
   cites `scripts/imaginary.sh` <!-- orianna: ok --> (nonexistent).
   Expected: hook exits 0, zero BLOCK findings. Protects: "renaming a
   plan must not re-validate prose that was already on disk before the
   move."

2. **Rename + frontmatter edit** — same rename as (1), plus flipping
   `status: proposed` → `status: approved` on line 2. Body still cites
   `scripts/imaginary.sh` <!-- orianna: ok -->. Expected: hook exits 0
   on Rule 4 (the imaginary citation is not on a changed line); Rules
   1–3, 5 still inspect the full file and find nothing. Protects:
   "partial-rename hunks must scope Rule 4 to actually-added lines,
   not the full body."

3. **Brand-new plan with bad citation** — `A` (not `R`) staging of a
   new plan at `plans/proposed/personal/regression-new.md`
   <!-- orianna: ok --> whose body cites `scripts/imaginary.sh`
   <!-- orianna: ok -->. Expected: hook exits 1 with a Rule 4 BLOCK.
   Protects: PR #15's original guarantee — genuinely new plans still
   get full-body Rule 4 coverage.

The suite already uses a git-sandbox harness; new tests slot in
alongside the existing "rename is picked up by `--diff-filter=ACMR`"
case near line 983 of the test script.

## Rollback

Single-commit revert via `git revert <sha>`. The change is additive
within one hook file plus test additions; no data migration, no
frontmatter schema change, no effect on already-committed plans.
Reverting restores PR #15 behavior (overzealous on renames, correct on
edits).

## Open questions

- **OQ1** — Should the rename-mode diff also respect an `-M<threshold>`
  flag? Recommendation: no — git already decides R vs D+A at the
  threshold boundary; trust its classification and keep the hook logic
  simple.
