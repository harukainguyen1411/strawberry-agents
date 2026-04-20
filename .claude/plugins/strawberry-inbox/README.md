# strawberry-inbox

A local Claude Code Channels plugin that watches the current coordinator's
inbox directory and emits a channel event whenever a new `status: pending`
message appears.

## Requirements

- Node.js >= 22 (or Bun >= 1.1)
- Claude Code v2.1.80+ with a claude.ai account

## How it works

On startup the plugin:

1. Reads `CLAUDE_AGENT_NAME` (set by `claude --agent <name>`) or falls back to
   `STRAWBERRY_AGENT` to identify which coordinator's inbox to watch.
2. Resolves the repo root via `git rev-parse --show-toplevel`.
3. Opens an `fs.watch` on `agents/<agent>/inbox/` with a 250 ms debounce.
4. On any `.md` file change, reads its YAML frontmatter.
5. If `status: pending` and `to:` matches (or is unset), emits a
   `notifications/claude/channel` event to the running Claude Code session.

## Launch

The `evelynn` and `sona` aliases in `scripts/mac/aliases.sh` load this plugin
automatically. To launch manually:

```sh
cd ~/Documents/Personal/strawberry-agents
STRAWBERRY_AGENT=evelynn claude --agent evelynn \
  --plugin-dir .claude/plugins/strawberry-inbox \
  --channels server:strawberry-inbox \
  --dangerously-load-development-channels
```

## Companion skill

Run `/check-inbox` inside the session to display and mark pending messages.
The skill is defined at `.claude/skills/check-inbox/SKILL.md`.

## Dependencies

Install once before first use:

```sh
cd .claude/plugins/strawberry-inbox
npm install
```

The `node_modules/` directory is gitignored — it must be installed locally.
