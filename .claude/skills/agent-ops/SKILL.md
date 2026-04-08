---
name: agent-ops
description: Entry point for local agent operations — send an inbox message to another agent, list the agent roster, or scaffold a new agent. Replaces the former agent-manager MCP. Model-invocable.
disable-model-invocation: false
allowed-tools: Bash Read Write Edit Glob Grep
---

# /agent-ops — local agent operations

## Subcommand dispatch

`$ARGUMENTS` is parsed as `<subcommand> <rest...>`. Supported subcommands:

### `send <agent> <message...>`

Writes an inbox file at `agents/<agent>/inbox/<timestamp>-<shortid>.md` with the following schema (mirroring the former `message_agent` MCP tool):

```
---
from: <sender>
to: <agent>
priority: info
timestamp: YYYY-MM-DD HH:MM
status: pending
---

<message>
```

Sender is derived from `$CLAUDE_AGENT_NAME` if set in environment. If the caller cannot be identified, the skill refuses with `agent-ops send: sender unknown` and exits 2.

**Steps to execute:**

1. Determine sender: use `$CLAUDE_AGENT_NAME` if set, otherwise ask the caller to state who they are. If the caller cannot confirm, exit 2 with `agent-ops send: sender unknown`.
2. Verify `agents/<agent>/` exists. If not, exit 2 with `agent-ops send: unknown agent <name>`.
3. Resolve timestamp: `date -u +%Y%m%d-%H%M`.
4. Generate short ID: last 6 chars of `date -u +%s%N` or equivalent.
5. Write the inbox file using Write tool to `agents/<agent>/inbox/<timestamp>-<shortid>.md`.
6. Print the full path of the created inbox file.

### `list [--json]`

Shells out to `scripts/list-agents.sh` (with `--format json` if `--json` is given) via Bash and prints the result.

```bash
REPO_ROOT="$(git rev-parse --show-toplevel)"
bash "$REPO_ROOT/scripts/list-agents.sh"
# or with --json flag:
bash "$REPO_ROOT/scripts/list-agents.sh" --format json
```

### `new <agent-name> [--role "<role>"]`

Shells out to `scripts/new-agent.sh` with the provided arguments via Bash:

```bash
REPO_ROOT="$(git rev-parse --show-toplevel)"
bash "$REPO_ROOT/scripts/new-agent.sh" <agent-name> [--role "<role>"]
```

## Refusal rules

- If `$ARGUMENTS` is empty, print the subcommand help below and exit 0.
- If the subcommand is unrecognized, refuse with `agent-ops: unknown subcommand <name>` and exit 2.
- If `send` cannot determine a sender, refuse with `agent-ops send: sender unknown` and exit 2.
- If `send` target agent directory does not exist, refuse with `agent-ops send: unknown agent <name>` and exit 2.

**Subcommand help (printed when arguments empty):**

```
/agent-ops <subcommand> [args]

Subcommands:
  send <agent> <message...>   Write an inbox message to an agent
  list [--json]               List all agents (TSV or JSON)
  new <agent-name> [--role]   Scaffold a new agent directory
```

## Platform note

This skill runs identically on macOS and Windows (Git Bash). All subcommands use POSIX-portable bash via the `Bash` tool — no macOS-specific commands. Agent launching is macOS-only and is handled by `scripts/mac/launch-agent-iterm.sh`; it is not available from this skill.

## Cross-references

- `architecture/platform-parity.md` — full platform support matrix
- `plans/proposed/2026-04-08-mcp-restructure.md` — rough plan (governs Phases 2–3)
- `plans/implemented/2026-04-09-mcp-restructure-phase-1-detailed.md` — this Phase 1 spec (once promoted)
