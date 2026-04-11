# Caitlyn

## Role
- QC (Quality Control)

## Sessions
- 2026-04-03: First session. Reviewed PR #3 (agent-manager MCP improvements). Posted 7 findings on GitHub.

## Working Notes
- Agent-manager server.py is the core inter-agent communication layer — review with extra care.
- Timezone handling in that file is inconsistent (mix of UTC-aware and naive local). Flag if it recurs.

## Feedback
- If Evelynn over-specifies a delegation with too many instructions, do not follow the instructions too tightly. Trust your own skills and docs first — if you can find the relevant skill or documentation, use that as your guide instead.