# PR #32 — subagent identity propagation via hook JSON `agent_type`

## Verdict
APPROVE.

## What changed
`scripts/hooks/pretooluse-plan-lifecycle-guard.sh`: moved identity resolution
after JSON-parse validation and added `.agent_type` (jq `//empty`) as the first
source, ahead of `$CLAUDE_AGENT_NAME` and `$STRAWBERRY_AGENT`. Two unit xfail
cases (A1/A2) and three integration cases (Steps 4-6) added.

## Verification (what I actually ran)
Built the PR branch in a worktree, ran the full suites: 36/36 unit + 6/6
integration green. Then ran six adversarial spoof checks locally:

- **Forged `agent_type` inside `tool_input`** (nested, not top-level) → exit 2,
  agent reads empty. jq `.agent_type` only reads top-level. Spoof door closed.
- **Top-level `agent_type` wins over env** (`agent_type=ekko` with
  `CLAUDE_AGENT_NAME=orianna`) → exit 2. Correct precedence: runtime-populated
  identity beats env. An agent cannot downgrade or upgrade itself via env
  manipulation when the runtime populates `agent_type`.
- **Case-insensitive** — `ORIANNA` → exit 0 (lowercased via existing `tr`).
- **Empty string / null / missing `agent_type`** all fall through cleanly to
  env fallbacks.
- **Non-string `agent_type: 42`** stringified and fails exact `"orianna"` match
  → blocked. Not a vulnerability.

## Senna/security design notes
- The safety of this change hinges on one claim: the Claude Code runtime
  populates `agent_type` at the hook-payload top level, not inside `tool_input`.
  Plan cites current docs (fetched 2026-04-23). I verified the guard's jq
  query respects that boundary by construction: nested `.tool_input.agent_type`
  is ignored.
- The env-var fallbacks remain intact — defense-in-depth, 4 lines, harmless.
  Plan's OQ1 already queues removal for a follow-up after a release cycle.
- `//empty` handles `null`, missing field, and empty string uniformly. Good jq
  hygiene — no accidental `"null"` string propagation.

## Spot-check of tests
A1/A2 unit cases cover the core invariants directly. Integration Steps 4-6
exercise the Evelynn-dispatched-Orianna scenario end-to-end, plus a negative
case (karma subagent) to prove blocking still fires. Both test suites use
`unset CLAUDE_AGENT_NAME STRAWBERRY_AGENT` to ensure the new path is what's
being tested, not a leftover env leak. Honest tests.

## Review URL
https://github.com/harukainguyen1411/strawberry-agents/pull/32 — review
`strawberry-reviewers-2` APPROVED at 2026-04-23T09:03:21Z.

## Lane discipline
Lucian's APPROVED posted first (strawberry-reviewers). Mine posted second via
`--lane senna`. Separate-lane pattern held — no masking risk.
