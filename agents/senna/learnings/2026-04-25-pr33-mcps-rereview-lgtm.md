# missmp/mcps PR #33 — re-review — LGTM (advisory)

**Date:** 2026-04-25
**PR:** missmp/mcps#33 (work-side Slack MCP T-new-D canonical start.sh)
**Branch:** `chore/t-new-d-slack-canonical-start-sh`
**Head OID at re-review:** `18841cd`
**Round:** 2 (after C1 blocker round 1)
**Verdict:** LGTM (advisory)
**Comment URL:** https://github.com/missmp/mcps/pull/33#issuecomment-4318212737

## Summary

Round-1 C1 (cross-repo path arithmetic — `REPO_ROOT="$MCP_DIR/../../.."` resolves
to `~/Documents/Work/mmp/`, no `strawberry-agents` sibling) is resolved as
prescribed: env-overridable default + existence sanity check.

## Verification approach

Reproduced both polarities locally:

- Cloned PR branch into `/tmp/senna-pr33-r2/testpr`.
- Ran `bash scripts/test-t-new-d-slack-start-sh.sh` against HEAD
  (commit `18841cd`) → all 7 assertions PASS.
- Reverted `slack/scripts/start.sh` to `b9227c6` (pre-fix impl) keeping the
  smoke-test extension at `4d8ba87` → assertion 7 FAILS with
  `STRAWBERRY_AGENTS='///strawberry-agents' does not exist on disk`.
- Confirmed assertions 1–6 (the original grep-only set) still PASS against
  the broken impl — proving lesson #2 (grep-only smoke is blind to path
  arithmetic) is closed by the new structural assertion.

## What made the smoke-test extension sound

Eval-the-preamble approach:
1. awk extracts variable-assignment lines from start.sh up to and including
   the `STRAWBERRY_AGENTS=` line, skipping shebang/set/exec/if/fi/blank/comment.
2. The snippet is fed into `bash -c` with `BASH_SOURCE[0]` set to the real
   start.sh path and `MCP_DIR` precomputed from its parent dir.
3. The subshell echoes `$STRAWBERRY_AGENTS`; the test then `[[ -d ]]`-checks
   the resolved value.

This is not a different grep — it exercises the actual resolution logic the
same way runtime would. Catches `REPO_ROOT`-style path arithmetic regressions
regardless of where the worktree/clone lives.

## Residual non-blocking observations

- **Assertion-7 quoting fragility.** `$_snippet` is interpolated into a
  `bash -c "..."` string. Current snippet contains no inner `"`, but a future
  preamble line with embedded double-quotes could misparse. Logged as
  future-proofing, not blocking. Suggested mitigation: snippet via temp file
  or `bash -c '<literal>' arg`.
- **ADR §4.2 cross-repo subsection.** Canonical template still assumes
  start.sh lives inside the agents repo. The cross-repo case (mcps repo
  consumes agents-repo decrypt.sh) needs explicit ADR text. Out of scope for
  PR #33; flagged as a follow-up docs PR.

## Class-of-bug notes

- **Cross-repo path arithmetic from "canonical" templates that assume in-repo
  layout.** Whenever a script designed for in-repo use gets ported to a sibling
  repo, the relative-path anchors (`../../..`) silently break. Smoke tests
  must exercise resolution against a fixture, not just grep the script text.
- **Misleading diagnostics from cascaded existence checks.** When the first
  computed path is wrong, downstream existence checks (`[[ -f "$AGE_BLOB" ]]`)
  fire with messages that point operators at the wrong root cause. Sanity-check
  upstream variables before downstream ones, with diagnostics that name the
  upstream variable explicitly.

## Reviewer-auth path used

Work-side concern → `scripts/post-reviewer-comment.sh --pr 33 --repo missmp/mcps`.
Posted as `duongntd99` PR comment. No `strawberry-reviewers-2` identity used
(work concern routes through duongntd99 only).

## Time to close

~15 min — focused re-review on the two fix-up commits; sandbox reuse
(`/tmp/senna-pr33-r2/`) for the polarity-flip verification was efficient.
