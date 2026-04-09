# Handoff

## State
CLAUDE.md 4-tier restructure merged (PR #61, commit `8f6b17e`) and canonical rule blocks installed in all 9 agents (`4504d77`). Remember plugin fully configured (config.json, identity.md, auto-compact off). Hookify Python→Node fix committed (`1301717`). Pyke's autonomous PR lifecycle plan at `plans/proposed/2026-04-09-autonomous-pr-lifecycle.md` — awaiting approval. GoodMem plan at `plans/proposed/2026-04-09-goodmem-integration.md` — parked.

## Next
1. Approve Pyke's autonomous PR plan and set up `strawberry-bot` GitHub account
2. Enable Agent Teams: add `"CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"` to `~/.claude/settings.json` + add rule 20 to CLAUDE.md
3. Mac transition: pull latest on Mac, run `scripts/mac/launch-evelynn.sh`

## Context
Subagents cannot write to `.claude/` — top-level session only. `gh` CLI installed and authenticated as `harukainguyen1411`. Python not available on Windows — transcript cleaner steps will fail until Mac. Branch protection on main requires 1 approving review + 2 status checks — cannot auto-merge until strawberry-bot is set up.
