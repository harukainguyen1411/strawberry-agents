# 2026-04-25 — PR #54 T-new-D wrapper triple — APPROVE

**Concern:** personal (`harukainguyen1411/strawberry-agents`)
**Author:** Talon (executor)
**Lane:** Senna (code-quality + security)
**Verdict:** APPROVE
**Review:** https://github.com/harukainguyen1411/strawberry-agents/pull/54#pullrequestreview-4175255184

## Context

Third attempt at T-new-D after PR #48 (wrong codebase — personal TS Slack MCP requires
two tokens) and PR #33 (cross-repo path arithmetic + grep-only smoke) both closed. Corrected
architecture: a strawberry-agents-scoped wrapper at `mcps/wrappers/slack-launcher.sh` that
decrypt-execs the unmodified company-shared upstream Slack MCP. No upstream files modified.

## What I verified positively

- **Scope discipline:** PR diff is exactly 5 files all under `strawberry-agents/`. `git status`
  in `~/Documents/Work/mmp/workspace` confirms zero `mcps/` modifications. Recurrence prevented.
- **Path resolution:** `STRAWBERRY_AGENTS="${STRAWBERRY_AGENTS:-...}"` env-overridable + `[[ -d ]]`
  existence check + `UPSTREAM_START` override + existence check. Fixes the PR #33 blocker.
- **Plaintext discipline:** `--var` passes NAME not value (no argv leak); ciphertext via stdin
  redirect; runtime env-file at 0600; `--exec` keeps plaintext out of parent shell.
- **Smoke honesty:** ran `bats wrapper-slack-launcher.bats` against the branch in a clean clone
  — `1..3, ok 1, ok 2, ok 3`. Manually exercised the wrapper end-to-end: marker file contains
  the sentinel `__SLACK_TEST_TOKEN__` → assertion (b) proves env injection from child's
  perspective via probe shim, NOT grep-only. PR #33 / PR #48 weakness fixed.
- **Hook wiring:** `pre-commit-wrapper-slack-test.sh` matches dispatcher glob, triggers on the
  right path set, gracefully skips when bats absent.
- **TDD ordering:** xfail commit `d563e513` strictly before impl `c6174c79`.
- **Shellcheck clean** on all three new bash artifacts.

## Non-blocking findings I posted

1. **(d) grep is dead code.** `echo "$output" | grep -qv "$SENTINEL"` — `-qv` returns 0 if any
   line doesn't match, trivially true for multi-line `env` output. The redeeming explicit
   `[ -z "${SLACK_USER_TOKEN:-}" ]` on the next line does correctly prove absence in the bats
   process, so (d) still holds; grep just contributes nothing. Correct form: `! echo "$output" | grep -q "$SENTINEL"`.

2. **xfail commit uses `bats skip` not actual failure.** Both tests in `d563e513` start with
   `skip "xfail — ..."` which short-circuits before the assertion runs. Same Rule 12 weakness
   flagged on PR #48. Commit ordering satisfies the hook gate, but the assertion was never
   proven red. Future xfail commits should write the failing assertion as the body without skip.

3. **(c)'s "or absent" branch.** Empirically the runtime env-file is always present post-exec
   (child exec'd into upstream, never returned). The fallback hides regressions in
   decrypt.sh's file-creation behavior. Tighten to require presence + 0600.

## Class of bug to remember

**Negative-grep false confidence in env absence tests.** Pattern `grep -qv "$NEEDLE"` reads
naturally as "test absence" but returns 0 if any input line doesn't match the needle. Always
prefer `! grep -q "$NEEDLE"` to assert absence. Add to PR-review checklist for any future
"env var must NOT be set" assertion.

**`bats skip` is not "test red".** A skipped test does not exercise its body. Rule 12's
intent (xfail commit must commit a failing assertion against missing impl) is not satisfied
by an unconditional `skip` even though the pre-push hook accepts it. For the rule to do its
work, the assertion body must run and fail. Pattern carry-forward note for T-new-E onwards.

## Process

- Personal-concern PR → `scripts/reviewer-auth.sh --lane senna` path.
- Preflight: `gh api user --jq .login` returned `strawberry-reviewers-2`. Correct.
- APPROVE submitted; review URL captured. Block-merge: NO.

## Reusable probes used

- **Branch + bats clone test:** `git clone --branch <branch> --depth 1 <repo>; bats <file>`.
  Quick way to verify smoke claims independent of local repo state.
- **Manual end-to-end:** spin a `mktemp -d` fake-repo with throwaway age key + sentinel blob,
  run the wrapper with `UPSTREAM_START=$probe`, then `stat` the runtime env-file and `cat` the
  marker. Faster than reading-and-reasoning when the test mechanics are non-trivial.
- **Cross-repo scope check:** `git status` in the OTHER repo to prove the upstream is untouched
  when reviewing a wrapper PR.
