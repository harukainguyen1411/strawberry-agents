# Channels plugin: Node --experimental-strip-types vs Bun

**Session:** 2026-04-20 — strawberry-inbox channel plugin

## Problem

Plan specified Bun as the runtime, but Bun was not installed on the machine.
Channels docs say "Bun, Node, and Deno all work."

## Solution

Node 22+ supports `--experimental-strip-types` to run `.ts` files directly
without a compile step. On Node 25 (installed), the flag is stable enough for
local use. The MCP server command in `.mcp.json` becomes:

```json
"command": "node",
"args": ["--experimental-strip-types", "src/index.ts"]
```

## Gotcha: TypeScript import paths

With `--experimental-strip-types`, Node resolves imports the same as ESM —
import paths must use actual file extensions. Since there is no `.js` file
(no build step), import sibling `.ts` files with the `.ts` extension:

```ts
import { parseFrontmatter } from './frontmatter.ts';  // correct
import { parseFrontmatter } from './frontmatter.js';  // WRONG — file doesn't exist
```

## Plugin CWD vs repo root

Claude Code spawns plugin MCP servers from the plugin directory, not the
session's working directory. Any server that needs the repo root must detect it
independently — `git rev-parse --show-toplevel` is the cleanest approach.
Never assume `process.cwd()` is the repo root in a plugin server.

## Channel flag syntax (research preview)

- Installed plugins: `--channels plugin:name@marketplace`
- Local MCP server (no marketplace): `--channels server:<mcp-name>`
- Both require: `--dangerously-load-development-channels` during research preview
- Loading the plugin (skills/agents): `--plugin-dir .claude/plugins/<name>`

Note: `--channels` and `--plugin-dir` serve different purposes. `--channels`
activates the MCP channel server. `--plugin-dir` loads the plugin's skills.
Both are needed to get full functionality.

## plan-promote.sh scope

`scripts/plan-promote.sh` only handles plans leaving `plans/proposed/`. Plans
already in `plans/approved/` or `plans/in-progress/` must be moved with raw
`git mv` + frontmatter rewrite + commit. The script enforces proposed-only to
protect the Drive mirror unpublish step.
