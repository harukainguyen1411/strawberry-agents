# Script-only agent pattern

**Date:** 2026-04-20 (S62)
**Triggered by:** Duong flagging that Orianna was invokable via Agent tool despite being designed for script-only invocation.

## Pattern

When an agent should be invocable by a script (e.g. `claude -p` subprocess) but NOT by coordinator Agent-tool calls, physically relocate the definition file OUT of `.claude/agents/` into a sibling directory such as `.claude/_script-only-agents/`.

The harness walks only `.claude/agents/` to populate the `subagent_type` enum. Files outside that tree are invisible to the Agent tool but fully available to `claude -p` invocations, since those use raw prompt strings and never reference the agent-def file.

## Ranking of alternatives

| Option | Durability | Debuggability | Blast radius |
|---|---|---|---|
| **Physical relocation** (chosen) | High — harness can't see it at all | High — absence is grep-obvious | Zero — subprocess path untouched |
| Frontmatter flag (e.g. `disable-model-invocation`) | N/A — field doesn't exist for agents (only for skills) | — | — |
| PreToolUse hook on Task with `subagent_type` matcher | Medium — lives in settings.json, can drift | Medium — hook trace needed | Low, but couples to every Task call |

## Directory convention

- `.claude/agents/` — live agents, Agent-tool callable
- `.claude/_retired-agents/` — fully retired, no invocation path
- `.claude/_script-only-agents/` — partial retirement, script-invocable only

Distinct directories signal distinct intent in `ls .claude/`.

## Required co-changes

1. Add a header comment as the file's first line:
   `<!-- Script-only: invoke via scripts/<name>-<task>.sh, not via the Agent tool. -->`
2. Update `agents/memory/agent-network.md` — keep the agent in the roster but annotate "script-invocable only" with a pointer to the invoking script.
3. Verify the subprocess path still works end-to-end after the move.

## Verification

For Orianna: `./scripts/orianna-fact-check.sh <plan-path>` succeeded post-move, confirming the script doesn't reference `subagent_type` or the agent-def path. See commit `8373bef`.
