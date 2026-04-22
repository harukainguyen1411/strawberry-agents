# 2026-04-22 — PR #19 Orianna gate speedups review

## Context
Code-quality + security review on Viktor's `feat/orianna-gate-speedups` PR (T2/T4/T5/T7/T9/T10/T11.c shipped; T-prompt-1/2/3 deferred). Lucian had already approved ADR fidelity; my lane was shell safety, races, guard correctness, and secrets.

## Verdict
Advisory LGTM (COMMENTED). No merge blockers; six findings ranging important→nit.

## Top findings

1. **F1 (important)** — Sig guard's unconditional `exec 2>>$GIT_DIR/orianna-sig-guard.log` hijacks stderr for interactive commits too, not just Viktor's command-substitution test context. A TTY-guard (`if [ ! -t 2 ]; then exec 2>>...; fi`) is a one-liner fix that preserves both UX and test behavior.

2. **F2 (important)** — `orianna-sign.sh` runs pre-fix BEFORE claude. If claude block-findings, the plan is mutated on disk but no commit. Violates Rule 1 (never leave work uncommitted). Fix: snapshot `cp "$PLAN_PATH" "$PLAN_PATH.bak"` pre-fix and restore on failure.

3. **F3 (important)** — `grep -c ... || echo 0` produces the two-line string `"0\n0"`, not `"0"`. Verified on macOS zsh. Breaks integer comparison; latent bug in new shape-B block at signature-guard.sh:135 (also pre-existing at :194 from T2.3).

4. **F4 (suggestion)** — `/tmp/body-hash-guard-failures-$$.txt` is a predictable path. Use `mktemp`.

5. **F5 (suggestion)** — T11.c regex `<!-- orianna: ok -- [^-]` rejects reasons that start with `-`.

6. **F6 (nit)** — install-hooks.sh comment still says `pre-commit-t-plan-structure.sh` (was renamed to `pre-commit-zz-`).

## Clean areas
Stale-lock helper, body-hash guard, shape-B commit emission, pre-fix idempotency, secret hygiene, xfail→impl ordering — all clean.

## Reusable technique
The `grep -c || echo 0` anti-pattern is easy to miss on review. Always read `wc -l <<<$(pipeline)` or `[ "$var" -ne ... ]` sites and ask: "what if the pipeline finds zero matches?" The idiomatic safe replacements are `{ grep -c ... || true; }` (exit swallowed but output preserved) or `grep -c ... 2>/dev/null` followed by `[ -z "$x" ] && x=0`.

## Lane hygiene
Auth check passed cleanly as `strawberry-reviewers-2`. No conflict with Lucian's prior approval from `strawberry-reviewers` — separate-lanes-separate-slots design worked: GitHub shows both the APPROVED (Lucian) and COMMENTED (me) as distinct review entries.

## Review URL
https://github.com/harukainguyen1411/strawberry-agents/pull/19
