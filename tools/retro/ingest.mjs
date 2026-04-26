#!/usr/bin/env node
/**
 * ingest.mjs — events.jsonl scanner for the retrospection dashboard.
 *
 * Scans five upstream sources:
 *   1. ~/.claude/projects/<slug>/<session-id>.jsonl  (coordinator-inline turns)
 *   2. subagents/agent-<id>.{jsonl,meta.json}        (delegated turns + dispatch events)
 *   3. subagent-sentinels/<agent-id>                 (sentinel mtime → dispatch_end_ts)
 *   4. git log over plans/**                         (plan-stage events)
 *   5. feedback/*.md                                 (feedback-entry events, T.P2.2)
 *
 * Honors RETRO_GIT_LOG_MOCK env var: if set, reads git-log data from the JSON
 * file at that path instead of running actual git log. Used by test fixtures.
 *
 * Usage:
 *   node tools/retro/ingest.mjs [--cache-dir <dir>] [--feedback-dir <dir>]
 *
 * Options:
 *   --cache-dir <dir>     Root of the output/scan area. events.jsonl is written here.
 *                         Defaults to ~/.claude/strawberry-usage-cache (production).
 *   --feedback-dir <dir>  Path to the feedback/ directory. Defaults to <repoRoot>/feedback/.
 *
 * Directory resolution strategy (for test isolation):
 *   - events.jsonl output: always <cacheDir>/events.jsonl
 *   - sentinels: checked in <cacheDir>/subagent-sentinels/
 *                AND <cacheDir>/strawberry-usage-cache/subagent-sentinels/
 *   - projects: if <cacheDir>/projects/ exists → use that (test isolation)
 *               else if HOME is set → ~/.claude/projects
 *               The bats e2e test sets HOME to a temp dir with .claude/projects/ seeded.
 *               The node unit tests put projects/ directly under --cache-dir.
 *   - feedback: --feedback-dir if given, else <repoRoot>/feedback/
 *
 * Plan-Ref: plans/approved/personal/2026-04-25-retrospection-dashboard-and-canonical-v1.md
 * Implements T.P1.2; extended by T.P2.2 (feedback-index source).
 */

import { writeFileSync, existsSync, mkdirSync, statSync } from 'node:fs';
import { join } from 'node:path';
import { homedir } from 'node:os';
import { scanAllSources, parseFeedbackIndex } from './lib/sources.mjs';
import { loadMtimeCache, saveMtimeCache } from './lib/mtime-cache.mjs';

// ---------------------------------------------------------------------------
// Argument parsing
// ---------------------------------------------------------------------------

const args = process.argv.slice(2);
let cacheDirArg = null;
let feedbackDirArg = null;
for (let i = 0; i < args.length; i++) {
  if (args[i] === '--cache-dir' && args[i + 1]) {
    cacheDirArg = args[i + 1];
    i++;
  } else if (args[i] === '--feedback-dir' && args[i + 1]) {
    feedbackDirArg = args[i + 1];
    i++;
  }
}

const home = process.env.HOME || homedir();
const cacheDir = cacheDirArg || join(home, '.claude', 'strawberry-usage-cache');

// Projects dir:
//   - <cacheDir>/projects/ if it exists (node unit tests)
//   - <HOME>/.claude/projects/ via env HOME (bats e2e test sets HOME)
//   - null if --cache-dir is given but no projects dir found (sentinel-only tests)
//   - ~/.claude/projects if no --cache-dir (production)
const projectsDirUnderCache = join(cacheDir, 'projects');
let projectsDir;
if (cacheDirArg) {
  if (existsSync(projectsDirUnderCache)) {
    // Preferred test-isolation path: node unit tests put projects/ directly under --cache-dir
    projectsDir = projectsDirUnderCache;
  } else {
    // Fall back to HOME-based projects dir if it exists.
    // This handles the bats e2e test which sets HOME to a temp dir and uses --cache-dir
    // for the usage-cache only. os.homedir() honors the HOME env var, so this correctly
    // resolves to the bats-seeded fake home.
    const homeProjects = join(home, '.claude', 'projects');
    projectsDir = existsSync(homeProjects) ? homeProjects : null;
  }
} else {
  projectsDir = join(home, '.claude', 'projects');
}

// Sentinel dirs: check both <cacheDir>/subagent-sentinels and
// <cacheDir>/strawberry-usage-cache/subagent-sentinels (node unit tests use the latter)
const sentinelDirs = [
  join(cacheDir, 'subagent-sentinels'),
  join(cacheDir, 'strawberry-usage-cache', 'subagent-sentinels'),
].filter(existsSync);

// Feedback dir:
//   - --feedback-dir if given (test isolation, mtime tests)
//   - else <repoRoot>/feedback/ (production — repoRoot = cwd when running via npm run retro:ingest)
const feedbackDir = feedbackDirArg || join(process.cwd(), 'feedback');

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

mkdirSync(cacheDir, { recursive: true });

const eventsPath = join(cacheDir, 'events.jsonl');
const mtimeCachePath = join(cacheDir, 'events.mtimecache');

// Load existing mtime cache
const mtimeCache = loadMtimeCache(mtimeCachePath);

// ---------------------------------------------------------------------------
// Source 5: feedback-index reader (T.P2.2)
// Read feedback/INDEX.md mtime as the cache trigger; scan feedback/*.md for events.
// ---------------------------------------------------------------------------
const feedbackIndexPath = join(feedbackDir, 'INDEX.md');
let feedbackIndexMtime = 0;
if (existsSync(feedbackIndexPath)) {
  try {
    feedbackIndexMtime = statSync(feedbackIndexPath).mtimeMs;
  } catch {
    feedbackIndexMtime = 0;
  }
}
const feedbackEvents = parseFeedbackIndex(feedbackDir);

// ---------------------------------------------------------------------------
// Scan all four original sources
// ---------------------------------------------------------------------------
const events = scanAllSources({
  cacheDir,
  sentinelDirs,
  projectsDir,
  repoRoot: process.cwd(),
});

// Write events.jsonl — main stream (turn/dispatch/plan-stage); full rebuild for determinism.
const lines = events.map(e => JSON.stringify(e)).join('\n') + (events.length > 0 ? '\n' : '');
writeFileSync(eventsPath, lines, 'utf8');

// Write feedback-events.jsonl — dedicated feedback source for feedback-rollup.sql.
// Kept separate from events.jsonl so DuckDB schema inference works cleanly:
// feedback-entry events have a disjoint field set (category, severity, status, created)
// that confuses DuckDB auto-inference when mixed with turn/dispatch events.
// Only written when events exist: DuckDB opening an empty JSONL as a database argument
// creates a `file` table with only a `json` column, causing column-not-found errors for
// any named-column query (e.g. FROM file WHERE kind = 'feedback-entry').
if (feedbackEvents.length > 0) {
  const feedbackEventsPath = join(cacheDir, 'feedback-events.jsonl');
  const feedbackLines = feedbackEvents.map(e => JSON.stringify(e)).join('\n') + '\n';
  writeFileSync(feedbackEventsPath, feedbackLines, 'utf8');
}

// Update mtime cache with all five source keys (T.P2.2 adds 'feedback-index').
// Key 'decision-log' (T.P2.3) will be added by that task.
const newMtimeCache = {
  ...mtimeCache,
  'feedback-index': feedbackIndexMtime,
};
saveMtimeCache(mtimeCachePath, newMtimeCache);

process.stdout.write(`[retro:ingest] wrote ${events.length} main + ${feedbackEvents.length} feedback events\n`);
