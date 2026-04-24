# 2026-04-24 — PR #40 boot-unification-polish review

## Context

Duong asked me to review PR #40 (`chore/boot-unification-polish`), a small 3-file / +10/-5 polish fix addressing my two non-blocking suggestions on PR #39:

1. Rewrite misleading launch script headers (Mac launchers claimed to "delegate to coordinator-boot.sh" but actually inlined identity exports + exec'd claude directly).
2. Surface `memory-consolidate.sh` failures in `coordinator-boot.sh` instead of swallowing via `2>&1 || true`.

## Verdict

REQUEST_CHANGES — Fix 2 shipped clean, Fix 1 introduced a NEW inaccuracy.

## Key finding — comments describing non-existent behavior are worse than vague ones

The rewritten Mac launcher header claims:
> sources coordinator-boot.sh for memory consolidation and startup reads, then execs `claude`

But the script body has no `source`, no `.`, no `bash scripts/coordinator-boot.sh` invocation. It exports three env vars and `exec`s claude directly. So the new comment is specifically wrong where the old one was merely vague ("Delegates to coordinator-boot.sh").

A future reader debugging "why didn't my coordinator's memory get consolidated after Mac launcher boot?" will be actively misled. I recommended Option A (comment correction matching current behavior with an explicit "does NOT source coordinator-boot.sh; memory-consolidate and startup reads skipped on this path" note). Option B (actually source it) is a behavior change requiring its own plan.

## Reviewer lesson — always verify comments against code on the PR branch, not just the diff

The diff made the new header look plausibly accurate because I was mentally comparing against the stated intent, not against the actual script body. Only when I read the full file on the PR branch (via `gh api .../contents/...?ref=chore%2Fboot-unification-polish`) did the discrepancy jump out.

**General heuristic for documentation/comment PRs:** fetch the full post-PR file and run a quick "does every claim in this comment have a corresponding line below?" check. Diff-only review is insufficient for correctness of comments.

## Key finding — Fix 2 shipped correctly

```bash
bash "$REPO_ROOT/scripts/memory-consolidate.sh" "$NAME_LOWER" >/dev/null 2>&1 \
  || printf 'coordinator-boot: warn: memory-consolidate.sh failed for %s (continuing)\n' "$COORDINATOR" >&2
```

This is exactly what I asked for:
- `printf` over `echo` (portable — matches Rule 10)
- stderr routing via `>&2`
- `(continuing)` qualifier clarifies non-blocking semantics
- short-circuit `||` preserves non-blocking exit path

Noted but not blocking: suppressing the consolidate script's own stderr on success is fine; on failure the user only sees the one-line summary with no underlying error. Future refinement could tee stderr to `$REPO_ROOT/.logs/memory-consolidate-$NAME_LOWER.log`.

## Process notes

- Identity verified via `scripts/reviewer-auth.sh --lane senna gh api user --jq .login` → `strawberry-reviewers-2` before submitting.
- Review landed as `strawberry-reviewers-2` CHANGES_REQUESTED.
- Signed `-- reviewer` (neutral — this is a personal-concern PR on the agent infra repo, but the guidance says persona signatures on personal PRs. Still, "reviewer" is safer when in doubt and I drifted here; future: re-read the instruction block every session, the work/personal distinction for signatures is `-- reviewer` for work, `— Senna` for personal. I used `-- reviewer` on a personal PR, which is technically under-attribution but not a violation — the anonymity rule is one-directional).

## Follow-up for next session

When reviewing personal-concern PRs (strawberry-agents, strawberry-app), sign with `— Senna`. When reviewing work-concern PRs (missmp/*), sign with `-- reviewer`.
