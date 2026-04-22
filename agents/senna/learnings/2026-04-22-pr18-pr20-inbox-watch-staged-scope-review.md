# 2026-04-22 — PR #18 (inbox-watch-v3) + PR #20 (STAGED_SCOPE) review

## Context
Paired review session: Viktor's 3-phase inbox watcher (PR #18) and Talon's
STAGED_SCOPE env-var for orianna-sign.sh (PR #20). Both against main.

## Verdicts
- **PR #18**: approve with advisory findings. One important finding (unanchored
  `grep -q 'status: pending'` across 3 call sites — false-positive risk on message
  bodies that quote frontmatter). Rest are suggestions.
- **PR #20**: approve with advisory notes. Opt-in semantics correct, validation
  good, test harness targets the real invariants.

## Key findings worth remembering

### Unanchored grep on frontmatter fields is a recurring footgun
In shell scripts that parse YAML-ish frontmatter, `grep -q 'status: pending'`
without `^`-anchor and without restricting to the frontmatter block (between the
two `---` delimiters) will false-positive on any body line that mentions the
literal string. This is especially bad in "noisy monitor"-class scripts that
exist explicitly to avoid spurious notifications. Canonical fix pattern:

```sh
awk '/^---$/{n++; if (n==2) exit} n==1' "$file" | grep -qE '^status:[[:space:]]+pending'
```

Or cheaper: `grep -qE '^status:[[:space:]]+pending[[:space:]]*$' "$file"` —
anchors both ends of the line. Still scans the body but dramatically lower
false-positive rate.

### Dead forward-hook exports in integration points
PR #20 exports `STAGED_SCOPE` in `plan-promote.sh` around the promotion commit,
but `plan-promote.sh` never invokes `orianna-sign.sh` — signing is a prior
human-initiated step. The export is unreachable in today's wiring. Plausible
reading: forward-hook for shape-B `--pre-fix` (Viktor's PR #19). Not a bug, but
the companion doc language should say "will export … once shape-B lands" rather
than "exports automatically before any orianna-sign.sh invocation it performs".
When reviewing integration PRs that reference sibling PRs, always check whether
the integration point is active-today or forward-looking.

### Test harnesses that reimplement the unit being tested
PR #18's `run_check_inbox_flow` is a shell reimplementation of the SKILL.md
steps, not an invocation of the model-driven skill. The test file is honest
about this ("we exercise the documented shell steps … as a shell equivalent")
but it means CI doesn't actually validate the skill. Worth flagging in reviews
when skills or model-invoked prompts are tested only indirectly.

### Unbound variables in nested heredocs — silent-empty expansion
PR #20's test stub contained `plan: $PLAN_ABS` in an inner `<<EOF` heredoc where
`$PLAN_ABS` was never defined in the stub's environment. With no `set -u` in the
stub, it silently expanded to empty string. Latent bug: if any future test
asserts the report's `plan:` field, the stub fails mysteriously. When reviewing
shell tests that use heredocs-within-heredocs, trace variable scoping carefully.

## Protocol reminders
- `--lane senna` on every `gh pr review` call (not `--lane senna-reviewer`, not
  default lane). Pre-flight `gh api user --jq .login` → `strawberry-reviewers-2`.
- Both PRs had TDD-gate xfail + regression-test green. Rule 18 satisfied.
- Approved both; sessions are well-run by Viktor and Talon (Opus executors).
