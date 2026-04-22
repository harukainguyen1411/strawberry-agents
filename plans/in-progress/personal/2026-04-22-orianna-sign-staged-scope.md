---
status: in-progress
concern: personal
owner: karma
created: 2026-04-22
orianna_gate_version: 2
complexity: quick
tests_required: true
tags: [orianna, plan-lifecycle, scripts, concurrency, bugfix]
related:
  - plans/implemented/personal/2026-04-20-orianna-gated-plan-lifecycle.md
  - plans/proposed/personal/2026-04-21-pre-lint-rename-aware.md
orianna_signature_approved: "sha256:1b23501714ab7fe9b92352dc3f89f7014dd15cbe426627a620aaf55450b36b82:2026-04-22T07:11:21Z"
orianna_signature_in_progress: "sha256:1b23501714ab7fe9b92352dc3f89f7014dd15cbe426627a620aaf55450b36b82:2026-04-22T07:15:12Z"
---

# `STAGED_SCOPE` env var for `orianna-sign.sh` — eliminate concurrent-staging race <!-- orianna: ok -->

## Context

`scripts/orianna-sign.sh` writes the signature line into the plan's frontmatter,
then runs `git add <plan>` followed by `git commit`. The signature-guard hook
(`scripts/hooks/pre-commit-orianna-signature-guard.sh`) enforces that Orianna
commits touch exactly one file under the plans/ <!-- orianna: ok --> directory. When a second coordinator
session (Sona or Evelynn) has unrelated files staged in the shared index at the
moment `orianna-sign.sh` reaches its `git commit` step, those staged files ride <!-- orianna: ok -->
along into the commit's staged set and the guard rejects with "must touch
exactly 1 file". Ekko hit this today promoting
`plans/proposed/personal/2026-04-21-pre-lint-rename-aware.md` <!-- orianna: ok -->
and the failure is not a one-off: Evelynn and Sona are designed to run
concurrently, so every plan promotion is exposed to this race whenever the
other coordinator has dirty staged work.

The fix is to narrow the commit scope so the signing commit only carries the
plan file, regardless of what else is staged. Git supports this natively via
`git commit -- <path>` (pathspec-scoped commit), which commits only the index
entries matching that pathspec and leaves other staged entries untouched for
the next commit. We wire this in through an opt-in `STAGED_SCOPE` environment
variable honored by `orianna-sign.sh`. When `STAGED_SCOPE` is set, the script <!-- orianna: ok -->
passes the path as a pathspec to `git commit`; when unset, behavior is
unchanged.

`scripts/plan-promote.sh` is the primary caller of `scripts/orianna-sign.sh` and
already knows the plan path, so it will export `STAGED_SCOPE=<plan-path>`
before invoking signing. Direct manual invocations remain unaffected unless
the caller opts in. The signature-guard hook requires no change — it already
evaluates the commit-in-progress's staged set, and scoping the commit narrows
that set to one file cleanly.

## Decision on opt-in vs default-on

Proposed: **opt-in via `STAGED_SCOPE` env var only**; `scripts/plan-promote.sh` sets
it. Rationale: keeps `scripts/orianna-sign.sh` invocation-safe for any future caller
that deliberately wants index-wide commit behavior (e.g. a dev manually
repairing a signature mid-rebase — which we do not do but should not silently
break). Default-on would change observable behavior for every existing caller;
opt-in is the narrower, reversible change. One gating question for Duong
below in case they want the stronger default.

## Gating questions for Duong

1. **Opt-in vs default-on.** My pick: opt-in via `STAGED_SCOPE`, with
   `scripts/plan-promote.sh` setting it. Alternative: default `scripts/orianna-sign.sh` to
   always scope to the plan path (derive from `$1`), and add an
   `ORIANNA_SIGN_NO_SCOPE=1` escape hatch. Default-on more aggressively
   prevents the race but changes observable behavior for any ad-hoc caller.
   Confirm opt-in is acceptable, or flip to default-on.

## Tasks

### T1. Add xfail test exercising the concurrent-staging race

- Kind: test
- Estimate_minutes: 20
- Files: `scripts/__tests__/test-orianna-sign-staged-scope.sh` (new). <!-- orianna: ok -->
- Detail: POSIX bash test that builds a throwaway temp repo with `REPO=`,
  seeds a minimal plan under `plans/proposed/` <!-- orianna: ok --> with a valid v2 frontmatter,
  stubs `claude` on `PATH` to emit a clean report, then stages an extra
  unrelated file (e.g. `noise.txt`) <!-- orianna: ok --> into the temp repo index, then invokes
  `bash scripts/orianna-sign.sh <plan> approved` with <!-- orianna: ok -->
  `STAGED_SCOPE=<plan-relpath>` exported, then asserts the resulting HEAD
  commit's `git show --name-only HEAD` touches exactly the plan file and
  `noise.txt` <!-- orianna: ok --> remains staged in the index post-commit. Mark the test xfail
  against the current script (grep a sentinel `# xfail: STAGED_SCOPE`
  comment; CI's tdd-gate recognizes the plan reference in the commit message).
  Reference this plan file in the test header comment.
- DoD: test file committed; running it against un-patched `scripts/orianna-sign.sh`
  fails with the expected guard error; running it against the patched script
  (after T2) passes.

### T2. Implement `STAGED_SCOPE` handling in `scripts/orianna-sign.sh`

- Kind: code
- Estimate_minutes: 15
- Files: `scripts/orianna-sign.sh`.
- Detail: After the existing `git add "$PLAN_PATH"` call, when
  `STAGED_SCOPE` is non-empty in the environment, change the `git commit`
  invocation to pass `-- "$STAGED_SCOPE"` as a trailing pathspec. Resolve
  `STAGED_SCOPE` as repo-relative (reject absolute paths outside
  `REPO_ROOT`). Log a single `[orianna-sign] scoping commit to $STAGED_SCOPE`
  line to stderr when the branch activates. No behavior change when
  `STAGED_SCOPE` is unset. Keep the `COMMIT_EDITMSG` write-ahead unchanged;
  the guard hook continues to read it.
- DoD: T1 test passes; running `scripts/orianna-sign.sh` without `STAGED_SCOPE`
  behaves identically to today (verified by the existing test suite if
  present, otherwise by a second unit test with an empty index).

### T3. Wire `scripts/plan-promote.sh` to export `STAGED_SCOPE`

- Kind: code
- Estimate_minutes: 10
- Files: `scripts/plan-promote.sh`.
- Detail: Before invoking `scripts/orianna-sign.sh`, export
  `STAGED_SCOPE="$DEST_REL"` (the destination plan path that
  `scripts/plan-promote.sh` has already computed as the `git mv` target). Unset or
  scope the export to the invocation so callers of `scripts/plan-promote.sh` do not
  inherit it. Add a one-line comment citing this plan.
- DoD: manual dry-run of `scripts/plan-promote.sh` on a throwaway plan with noise
  staged in the index completes cleanly; noise remains staged post-promote.

### T4. Document `STAGED_SCOPE` in `architecture/key-scripts.md`

- Kind: docs
- Estimate_minutes: 5
- Files: `architecture/key-scripts.md`.
- Detail: Add a short paragraph under the `scripts/orianna-sign.sh` entry describing
  the `STAGED_SCOPE` env var, when to set it, and the concurrent-coordinator
  rationale. Cross-reference this plan.
- DoD: doc committed on the same branch as T2/T3.

## Test plan

Invariants protected:

1. **Signing commit touches exactly one file under plans/** <!-- orianna: ok --> — existing
   signature-guard invariant; T1 asserts it holds even when the index carries
   unrelated staged files.
2. **Orphan staged files survive the signing commit** — T1 asserts
   `noise.txt` <!-- orianna: ok --> remains in the index post-commit so the concurrent
   coordinator's work is not stolen or silently committed under Orianna's
   identity.
3. **Default behavior unchanged when `STAGED_SCOPE` unset** — T2's DoD test
   (or manual verification) confirms the unscoped path still commits as
   today.

Test harness: the existing `scripts/__tests__/` <!-- orianna: ok --> POSIX bash pattern (see sibling
Orianna tests if present; otherwise a self-contained script using `mktemp -d`,
`git init`, a stubbed `claude` on `PATH`, and `trap` cleanup). All three
checks live in `scripts/__tests__/test-orianna-sign-staged-scope.sh`. <!-- orianna: ok -->

## References

- `scripts/orianna-sign.sh` — the script being patched.
- `scripts/hooks/pre-commit-orianna-signature-guard.sh` — the guard
  enforcing the exactly-one-file invariant.
- `scripts/plan-promote.sh` — the primary caller; T3 wires the opt-in.
- `plans/implemented/personal/2026-04-20-orianna-gated-plan-lifecycle.md` §D1.2,
  §D7.3 — the origin of the signing-commit shape invariant.
