#!/usr/bin/env node
/**
 * render.mjs — DuckDB query runner + static HTML generator for the retrospection dashboard.
 *
 * Reads events.jsonl, runs each .sql in queries/, writes JSON to dist/data/,
 * then generates static HTML into dist/.
 *
 * Fully deterministic — no runtime time-sources or random sources used.
 * Timestamps come from fixture data only (R2 snapshot-determinism guard per TP1.T6 DoD-d).
 *
 * Usage:
 *   node tools/retro/render.mjs \
 *     --events <events.jsonl path> \
 *     --queries-dir <queries dir> \
 *     --out-dir <output dir>
 *
 * The --out-dir receives both data/*.json and *.html files.
 * If a data/ subdirectory is intended, pass that as --out-dir; HTML goes to its parent.
 *
 * When --out-dir is used, JSON data files go to <out-dir>/data/ and HTML goes to <out-dir>.
 * When --out-dir already ends in /data, JSON goes there and HTML goes to the parent.
 *
 * Plan-Ref: plans/approved/personal/2026-04-25-retrospection-dashboard-and-canonical-v1.md
 * Implements T.P1.4 + T.P1.6.
 */

import { readFileSync, writeFileSync, readdirSync, mkdirSync, existsSync } from 'node:fs';
import { join, dirname, basename, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { runDuckDBQuery } from './lib/duckdb-runner.mjs';
import { generateHtml } from './lib/html-generator.mjs';

const __dirname = dirname(fileURLToPath(import.meta.url));

// ---------------------------------------------------------------------------
// Argument parsing
// ---------------------------------------------------------------------------

const args = process.argv.slice(2);
let eventsPath = null;
let queriesDir = null;
let outDir = null;

for (let i = 0; i < args.length; i++) {
  if (args[i] === '--events' && args[i + 1]) { eventsPath = resolve(args[++i]); }
  else if (args[i] === '--queries-dir' && args[i + 1]) { queriesDir = resolve(args[++i]); }
  else if (args[i] === '--out-dir' && args[i + 1]) { outDir = resolve(args[++i]); }
}

if (!eventsPath || !queriesDir || !outDir) {
  process.stderr.write('Usage: render.mjs --events <path> --queries-dir <dir> --out-dir <dir>\n');
  process.exit(1);
}

// ---------------------------------------------------------------------------
// Directory resolution
// ---------------------------------------------------------------------------

// JSON data files always go to <outDir>/data
// HTML files go to <outDir> (the top-level output dir)
// Exception: if outDir itself ends with /data, put JSON there, HTML in parent.
let dataDir, htmlDir;
if (basename(outDir) === 'data') {
  dataDir = outDir;
  htmlDir = dirname(outDir);
} else {
  dataDir = join(outDir, 'data');
  htmlDir = outDir;
}

mkdirSync(dataDir, { recursive: true });
mkdirSync(htmlDir, { recursive: true });

// ---------------------------------------------------------------------------
// Run queries
// ---------------------------------------------------------------------------

if (!existsSync(eventsPath)) {
  // No events yet — write empty JSON files and minimal HTML
  process.stderr.write(`[retro:render] events file not found at ${eventsPath}, writing empty outputs\n`);
}

const sqlFiles = readdirSync(queriesDir).filter(f => f.endsWith('.sql')).sort();
const queryResults = {};

for (const sqlFile of sqlFiles) {
  const queryName = sqlFile.replace(/\.sql$/, '');
  const sql = readFileSync(join(queriesDir, sqlFile), 'utf8');
  let rows = [];
  if (existsSync(eventsPath)) {
    try {
      rows = runDuckDBQuery(sql, eventsPath);
    } catch (err) {
      // Gracefully degrade if the events file does not have columns required by this query
      // (e.g. a Phase-2 query run against a Phase-1 events fixture). Log but do not crash.
      process.stderr.write(`[retro:render] ${queryName}: query skipped — ${err.message.split('\n')[0]}\n`);
      rows = [];
    }
  }
  queryResults[queryName] = rows;
  writeFileSync(join(dataDir, `${queryName}.json`), JSON.stringify(rows, null, 2), 'utf8');
  process.stdout.write(`[retro:render] ${queryName}: ${rows.length} rows → ${queryName}.json\n`);
}

// ---------------------------------------------------------------------------
// Generate HTML
// ---------------------------------------------------------------------------

// Load raw events for plan-stage slug enumeration
let events = [];
if (existsSync(eventsPath)) {
  events = readFileSync(eventsPath, 'utf8')
    .split('\n')
    .filter(Boolean)
    .map(l => JSON.parse(l));
}

const templatesDir = join(__dirname, 'templates');
generateHtml({ dataDir, distDir: htmlDir, templatesDir, events });

process.stdout.write(`[retro:render] HTML written to ${htmlDir}\n`);
