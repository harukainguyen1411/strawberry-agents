#!/usr/bin/env bun
/**
 * strawberry-inbox channel plugin
 *
 * Watches the current coordinator's inbox directory for new pending messages
 * and emits a `notifications/claude/channel` event so the running session is
 * notified immediately instead of waiting for the next user turn.
 *
 * Coordinator identity is resolved from:
 *   1. CLAUDE_AGENT_NAME env var (set by `claude --agent <name>`)
 *   2. STRAWBERRY_AGENT env var (fallback, set explicitly in the alias)
 * If neither is set, the plugin exits with a clear error.
 */

import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { watch } from 'fs';
import { readFile } from 'fs/promises';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';
import { execSync } from 'child_process';
import { parseFrontmatter } from './frontmatter.ts';

// --- Resolve coordinator identity -------------------------------------------

const agent =
  process.env.CLAUDE_AGENT_NAME?.trim() ||
  process.env.STRAWBERRY_AGENT?.trim();

if (!agent) {
  process.stderr.write(
    '[strawberry-inbox] ERROR: Cannot identify coordinator.\n' +
      'Set CLAUDE_AGENT_NAME or STRAWBERRY_AGENT before launching.\n' +
      'Example: STRAWBERRY_AGENT=evelynn claude ...\n',
  );
  process.exit(1);
}

// --- Resolve repo root -------------------------------------------------------

// Use git to find the repo root. This works regardless of which directory
// Claude Code spawns the plugin server from (plugin dir or repo root).
// Falls back to the directory containing this source file (which lives at
// .claude/plugins/strawberry-inbox/src/index.ts, i.e. 4 levels above root).
let repoRoot: string;
try {
  repoRoot = execSync('git rev-parse --show-toplevel', { encoding: 'utf8' }).trim();
} catch {
  // Fallback: go 4 levels up from src/index.ts → .claude/plugins/strawberry-inbox/src
  const __dirname = dirname(fileURLToPath(import.meta.url));
  repoRoot = join(__dirname, '..', '..', '..', '..');
}

const inboxDir = join(repoRoot, 'agents', agent, 'inbox');

process.stderr.write(
  `[strawberry-inbox] Watching inbox for '${agent}' at: ${inboxDir}\n`,
);

// --- MCP server setup --------------------------------------------------------

const mcp = new Server(
  { name: 'strawberry-inbox', version: '1.0.0' },
  {
    capabilities: {
      experimental: { 'claude/channel': {} },
    },
    instructions:
      `Events from the strawberry-inbox channel arrive as ` +
      `<channel source="strawberry-inbox" kind="new-message" from="..." priority="...">. ` +
      `A new inbox message has landed for coordinator '${agent}'. ` +
      `Run /check-inbox to read and mark it. Do not ignore these events — ` +
      `they may be time-sensitive messages from sibling agents.`,
  },
);

await mcp.connect(new StdioServerTransport());

// --- fs.watch loop with 250 ms debounce -------------------------------------

// Track debounce timers per filename to coalesce rapid write sequences
// (editors often do rename → write, firing two events for one logical change).
const debounceMap = new Map<string, ReturnType<typeof setTimeout>>();
const DEBOUNCE_MS = 250;

async function handleFile(filename: string): Promise<void> {
  if (!filename.endsWith('.md')) return;

  const filePath = join(inboxDir, filename);
  let content: string;
  try {
    content = await readFile(filePath, 'utf8');
  } catch {
    // File may have been deleted between the watch event and the read.
    return;
  }

  const fm = parseFrontmatter(content);
  if (!fm) return;
  if (fm.status !== 'pending') return;
  if (fm.to && fm.to !== agent) return; // addressed to someone else

  const relPath = `agents/${agent}/inbox/${filename}`;

  await mcp.notification({
    method: 'notifications/claude/channel',
    params: {
      content:
        `New inbox message for ${agent} from ${fm.from ?? 'unknown'} ` +
        `(priority: ${fm.priority ?? 'normal'}). ` +
        `Run /check-inbox to read and mark pending messages.`,
      meta: {
        kind: 'new_message',
        from: fm.from ?? 'unknown',
        to: agent,
        priority: fm.priority ?? 'normal',
        path: relPath,
      },
    },
  });

  process.stderr.write(
    `[strawberry-inbox] Emitted new-message event: ${relPath}\n`,
  );
}

function scheduleHandle(filename: string): void {
  const existing = debounceMap.get(filename);
  if (existing) clearTimeout(existing);

  const timer = setTimeout(() => {
    debounceMap.delete(filename);
    handleFile(filename).catch((err) => {
      process.stderr.write(
        `[strawberry-inbox] Error handling ${filename}: ${err}\n`,
      );
    });
  }, DEBOUNCE_MS);

  debounceMap.set(filename, timer);
}

try {
  const watcher = watch(inboxDir, { recursive: false }, (eventType, filename) => {
    if (filename) scheduleHandle(filename);
  });

  watcher.on('error', (err) => {
    process.stderr.write(`[strawberry-inbox] Watch error: ${err}\n`);
  });

  process.stderr.write('[strawberry-inbox] Watch active. Waiting for events...\n');
} catch (err) {
  process.stderr.write(
    `[strawberry-inbox] Failed to watch inbox directory: ${err}\n` +
      `Make sure agents/${agent}/inbox/ exists.\n`,
  );
  process.exit(1);
}
