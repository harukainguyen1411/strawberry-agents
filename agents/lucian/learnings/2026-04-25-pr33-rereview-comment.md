# 2026-04-25 — PR #33 missmp/mcps re-review (T-new-D start.sh)

## Verdict
COMMENT (advisory). Comment URL: https://github.com/missmp/mcps/pull/33#issuecomment-4318205509

## What I verified
- Prior structural-block (path arithmetic from arbitrary checkout) is resolved by `STRAWBERRY_AGENTS="${STRAWBERRY_AGENTS:-$HOME/Documents/Personal/strawberry-agents}"` + `[[ -d ]]` fail-loud check in slack/scripts/start.sh. Naming variant (`STRAWBERRY_AGENTS` vs `STRAWBERRY_AGENTS_HOME`) is semantically equivalent — accepted.
- Drift #2 (xfail grep-only) addressed by assertion 7 in scripts/test-t-new-d-slack-start-sh.sh: extracts preamble var assignments, evals in a subshell with synthesized `BASH_SOURCE`, asserts the resolved path is a directory on disk. This catches the path-arithmetic class even without spawning the MCP server.
- Drift #3 (T-new-E follow-up surfacing) NOT addressed in PR body — left as advisory; tracked in the plan.

## Notable
- The work-side anonymity scan in `scripts/post-reviewer-comment.sh` rejected my draft because I named "Senna" in the closing line. Reworded to "code/security review" and the post succeeded. Lesson: even neutral cross-agent references like "once X clears" must be agent-name-free on missmp/* PRs.
- ADR §4.2 canonical-template fold-back (env-overridable + sanity check as the cross-repo precedent) is the right call but belongs as a separate ADR docs task, not a PR #33 blocker.
