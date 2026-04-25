# PR missmp/mcps#33 — T-new-D canonical decrypt-exec start.sh — REQUEST_CHANGES

Date: 2026-04-25
Concern: work
Plan: `plans/approved/work/2026-04-24-sona-secretary-mcp-suite.md` §4.2 + T-new-D

## Verdict
REQUEST_CHANGES, block merge.

## Top finding (structural block)
Cross-repo path resolution is wrong. The script computes
`REPO_ROOT=$MCP_DIR/../../..` from `mcps/slack/scripts/start.sh`, landing at
`~/Documents/Work/mmp/`, then concatenates `/strawberry-agents` — but the actual
strawberry-agents checkout lives at `~/Documents/Personal/strawberry-agents/`,
not as a sibling of `mcps`. Pre-flight `AGE_BLOB` existence check will hard-fail
once P1-T2 lands.

The §4.2 canonical template was authored monorepo-style. T-new-D is the first
cross-repo adaptation and the adaptation is incorrect. Recommended fix:
`STRAWBERRY_AGENTS_HOME` env var with fail-loud unset path.

## Process note
xfail script is grep-only — six string assertions, never execs the file.
A `bash -n` + dry-run path-existence assertion would have caught the bug.
Worth flagging to Aphelios that future T-new-D-style "shape" xfails should
include at least one runtime path-resolution check, not pure greps.

## Comment URL
https://github.com/missmp/mcps/pull/33#issuecomment-4318181214

## Reviewer-auth path used
`scripts/post-reviewer-comment.sh --pr 33 --repo missmp/mcps --file ...` (work-concern, posted under `duongntd99`, signed `-- reviewer`). Anonymity scan passed.
