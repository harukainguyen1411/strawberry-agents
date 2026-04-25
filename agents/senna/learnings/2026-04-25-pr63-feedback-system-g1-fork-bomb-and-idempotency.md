# PR #63 — feedback-system G1 — two reproducible blockers

**Date:** 2026-04-25
**Concern:** personal
**PR:** https://github.com/harukainguyen1411/strawberry-agents/pull/63
**Verdict:** REQUEST_CHANGES (`strawberry-reviewers-2`)

## What I found

### 1. install-hooks.sh shim ↔ dispatcher fork-bomb

PR adds **two** new pieces that compose into infinite recursion:

- `scripts/hooks-dispatchers/pre-commit` gains a fallback that calls `$(git rev-parse --git-dir)/hooks/<verb>` after the sub-hook loop.
- `scripts/install-hooks.sh` writes `.git/hooks/pre-commit` as a compat shim that `exec`s `scripts/hooks-dispatchers/pre-commit`.

In a repo where `core.hooksPath=scripts/hooks-dispatchers` (every repo this installer touches):

1. git invokes `scripts/hooks-dispatchers/pre-commit`
2. dispatcher's fallback fires → `.git/hooks/pre-commit` (the shim)
3. shim `exec`s `scripts/hooks-dispatchers/pre-commit` → step 1
4. forever

Guard `[ "$_git_hook" != "$0" ]` doesn't work — paths differ.

I empirically reproduced this in a clean repo: 8 stacked `pre-commit` processes after ~4s, growing.

The TT3 tests don't catch it because they install the hook directly to `.git/hooks/pre-commit` in a temp repo with **no** `core.hooksPath`, so the dispatcher path is never engaged. The reason the PR branch's CI passes and the dev didn't notice is that the existing main repo's `.git/hooks/pre-commit` was written by an **older** install-hooks.sh that lacks the fallback — so until someone re-runs `install-hooks.sh`, the loop is dormant.

### 2. Idempotency violated when INDEX.md lives in --dir

`render_index()` walks `"$dir"/*.md` for the latest mtime to compute `_Generated:`, but doesn't skip `INDEX.md` (every other loop in the file does). Each render bumps INDEX.md's mtime → next render sees a newer "latest" → `_Generated:` advances on every invocation, even with no source content change.

This is the exact production usage (`pre-commit-feedback-index.sh` invokes `--dir feedback --out feedback/INDEX.md`).

Reproduced empirically: two consecutive renders produce two different `_Generated:` lines.

The TT2 idempotency test passes because it writes to `$TMP_DIR/INDEX-run1.md` and `$TMP_DIR/INDEX-run2.md` — neither inside the `--dir`, so the bug is invisible to the test.

## Lessons

1. **When tests pass and you still want to ship, look for the test's blind spot.** Both blockers passed CI (59/59 tests green). The first hides because TT3 bypasses `core.hooksPath`. The second hides because TT2 writes outputs to a separate dir from sources. Whenever a test exercises the "isolated" version of a workflow, ask "is the production invocation different in a way that matters?"

2. **Idempotency tests must use the production directory layout.** If the production code writes the output back into the input directory, the idempotency test must too. Otherwise self-referential mtime/hash effects go unobserved.

3. **Hook-recursion bugs hibernate.** New install-hooks logic doesn't bite developers because their machine has the OLD hooks installed. The break only happens on the next clean install — typically after merge. Always smoke-test the installer on a clean repo before approving installer changes.

4. **Pipe-character injection in markdown tables is real.** When you concatenate fields with `|` and parse with `IFS='|'`, any literal pipe in a field value shifts columns. Worth a fixed nit-class category for future feedback-shape reviews.

5. **Reviewer-auth path was clean.** `scripts/reviewer-auth.sh --lane senna gh api user --jq .login` returned `strawberry-reviewers-2` first try; review submitted via `gh pr review 63 --request-changes --body-file ...`. No identity drift, no anonymity-scan trip.

## Memo for next time

- For any PR touching `install-hooks.sh`: clone to `/tmp/foo`, run installer, make a commit, time-bound it with `ulimit -t 5`. If the commit hangs, blocker.
- For any PR touching feedback-index.sh's `render_index`: run twice with `--out $DIR/INDEX.md` (production shape), diff, must be empty.
