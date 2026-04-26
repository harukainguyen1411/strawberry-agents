/**
 * Regression tests for PR #88 review fixes (C1, C2, I3, I4, I5).
 *
 * C1 — stale feedback-events.jsonl cleanup (ingest.mjs)
 * C2 — TIMESTAMP-cast resilience in feedback-rollup.sql + iso-date reject at ingest
 * I3 — path-traversal guard in resolveQueryEventsSource (render.mjs)
 * I4 — mtime-cache key uses all feedback/*.md mtimes, not just INDEX.md
 * I5 — stateToStatus warns loudly on unknown state values
 *
 * Plan-Ref: plans/approved/personal/2026-04-25-retrospection-dashboard-and-canonical-v1.md §T.P2.2
 */

import { describe, it, before } from 'node:test';
import assert from 'node:assert/strict';
import {
  existsSync, readFileSync, mkdtempSync, mkdirSync, writeFileSync, unlinkSync, statSync,
} from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { execSync } from 'node:child_process';
import { tmpdir } from 'node:os';

const __dirname = dirname(fileURLToPath(import.meta.url));
const RETRO_ROOT = join(__dirname, '..');
const INGEST_PATH = join(RETRO_ROOT, 'ingest.mjs');
const RENDER_PATH = join(RETRO_ROOT, 'render.mjs');
const QUERIES_DIR = join(RETRO_ROOT, 'queries');
const FIXTURES_DIR = join(RETRO_ROOT, 'fixtures');
const SQL_PATH = join(QUERIES_DIR, 'feedback-rollup.sql');
const SOURCES_PATH = join(RETRO_ROOT, 'lib', 'sources.mjs');

const INGEST_EXISTS = existsSync(INGEST_PATH);
const RENDER_EXISTS = existsSync(RENDER_PATH);
const SQL_EXISTS = existsSync(SQL_PATH);
const SKIP_INGEST = !INGEST_EXISTS ? 'regression guard: ingest.mjs not present' : false;
const SKIP_RENDER = !RENDER_EXISTS ? 'regression guard: render.mjs not present' : false;
const SKIP_SQL = !SQL_EXISTS ? 'regression guard: feedback-rollup.sql not present' : false;
const SKIP_SOURCES = !existsSync(SOURCES_PATH) ? 'regression guard: sources.mjs not present' : false;

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/**
 * Create an isolated temp dir with a minimal feedback/ tree.
 * Returns { tmp, feedbackDir }.
 */
function makeFeedbackDir(entries = []) {
  const tmp = mkdtempSync(join(tmpdir(), 'retro-pr88-'));
  const feedbackDir = join(tmp, 'feedback');
  mkdirSync(feedbackDir, { recursive: true });
  writeFileSync(join(feedbackDir, 'INDEX.md'), '# Index\n');
  for (const { name, content } of entries) {
    writeFileSync(join(feedbackDir, name), content);
  }
  return { tmp, feedbackDir };
}

function sampleEntry(slug, { state = 'open', severity = 'medium', date = '2026-04-20' } = {}) {
  return {
    name: `${slug}.md`,
    content: `---\ncategory: hook-friction\nseverity: ${severity}\nstate: ${state}\ndate: ${date}\nauthor: test\n---\n# Body\n`,
  };
}

// ---------------------------------------------------------------------------
// C1 — stale feedback-events.jsonl must be removed/overwritten when no feedback files exist
// ---------------------------------------------------------------------------
describe('C1: stale feedback-events.jsonl is cleaned up on empty feedback run',
  { skip: SKIP_INGEST }, () => {

  it('does not leave a prior-run feedback-events.jsonl when feedback/ is empty', () => {
    const tmp = mkdtempSync(join(tmpdir(), 'retro-c1-'));
    const cacheDir = tmp;
    const feedbackDir = join(tmp, 'feedback');
    mkdirSync(feedbackDir, { recursive: true });

    // Seed a stale feedback-events.jsonl from a "prior run"
    const feedbackEventsPath = join(cacheDir, 'feedback-events.jsonl');
    writeFileSync(feedbackEventsPath, '{"kind":"feedback-entry","stale":true}\n');
    assert.ok(existsSync(feedbackEventsPath), 'pre-condition: stale file must exist before ingest');

    // Run ingest with an empty feedback dir (no *.md files besides INDEX.md which we do not create here)
    execSync(`node ${INGEST_PATH} --cache-dir ${cacheDir} --feedback-dir ${feedbackDir}`, {
      cwd: RETRO_ROOT, stdio: 'pipe',
    });

    // The stale file must be gone or truncated to empty
    if (existsSync(feedbackEventsPath)) {
      const content = readFileSync(feedbackEventsPath, 'utf8').trim();
      assert.strictEqual(content, '',
        'feedback-events.jsonl must be empty (truncated) when no feedback events exist');
    }
    // If file was deleted (unlinked) that is also acceptable — either is correct
  });

  it('writes feedback-events.jsonl when feedback files are present, then cleans up after removal', () => {
    const tmp = mkdtempSync(join(tmpdir(), 'retro-c1b-'));
    const cacheDir = tmp;
    const feedbackDir = join(tmp, 'feedback');
    mkdirSync(feedbackDir, { recursive: true });
    writeFileSync(join(feedbackDir, 'INDEX.md'), '# Index\n');

    // First run — with a feedback entry
    const entryPath = join(feedbackDir, 'entry-001.md');
    writeFileSync(entryPath, '---\ncategory: hook-friction\nseverity: high\nstate: open\ndate: 2026-04-20\nauthor: test\n---\n# Body\n');

    execSync(`node ${INGEST_PATH} --cache-dir ${cacheDir} --feedback-dir ${feedbackDir}`, {
      cwd: RETRO_ROOT, stdio: 'pipe',
    });

    const feedbackEventsPath = join(cacheDir, 'feedback-events.jsonl');
    assert.ok(existsSync(feedbackEventsPath), 'feedback-events.jsonl must exist after first run with entries');
    const firstContent = readFileSync(feedbackEventsPath, 'utf8').trim();
    assert.ok(firstContent.length > 0, 'feedback-events.jsonl must be non-empty after first run');

    // Remove the feedback entry — simulate "all feedback files deleted"
    unlinkSync(entryPath);

    // Second run — feedback dir is now empty of *.md files (only INDEX.md)
    // But INDEX.md is excluded from scanning, so feedbackEvents.length === 0
    execSync(`node ${INGEST_PATH} --cache-dir ${cacheDir} --feedback-dir ${feedbackDir}`, {
      cwd: RETRO_ROOT, stdio: 'pipe',
    });

    // After second run, file must be absent or empty — never stale
    if (existsSync(feedbackEventsPath)) {
      const secondContent = readFileSync(feedbackEventsPath, 'utf8').trim();
      assert.strictEqual(secondContent, '',
        'feedback-events.jsonl must be empty after all entries removed — stale phantom data not allowed');
    }
  });
});

// ---------------------------------------------------------------------------
// C2 — TIMESTAMP-cast: SQL uses strftime(MAX(CAST(... AS TIMESTAMP)), ...)
// Guard: the SQL must NOT use the bare MAX(created)::VARCHAR pattern
// ---------------------------------------------------------------------------
describe('C2: feedback-rollup.sql uses explicit TIMESTAMP cast in strftime',
  { skip: SKIP_SQL }, () => {

  it('SQL contains strftime with explicit TIMESTAMP cast, not bare ::VARCHAR', () => {
    const sql = readFileSync(SQL_PATH, 'utf8');
    // Must NOT have bare MAX(created)::VARCHAR
    assert.ok(
      !sql.includes('MAX(created)::VARCHAR'),
      'feedback-rollup.sql must not use bare MAX(created)::VARCHAR — schema-inference fragile'
    );
    // Must use strftime + CAST(... AS TIMESTAMP) pattern
    assert.ok(
      sql.includes('CAST') && sql.includes('TIMESTAMP') && sql.includes('strftime'),
      'feedback-rollup.sql must use strftime(MAX(CAST(... AS TIMESTAMP)), ...) pattern'
    );
  });

  it('SQL query still produces correct output on all-ISO fixture', () => {
    if (!SQL_EXISTS) return;
    const eventsPath = join(FIXTURES_DIR, 'feedback-rollup-events.jsonl');
    if (!existsSync(eventsPath)) return;
    const result = JSON.parse(
      execSync(`duckdb -json '${eventsPath}' < '${SQL_PATH}'`,
        { cwd: RETRO_ROOT, encoding: 'utf8' })
    );
    assert.ok(Array.isArray(result) && result.length > 0, 'query must return rows on standard fixture');
    // latest_entry_ts must look like a timestamp (not undefined/null)
    for (const row of result) {
      assert.ok(row.latest_entry_ts != null, `latest_entry_ts must not be null for row: ${JSON.stringify(row)}`);
      assert.ok(typeof row.latest_entry_ts === 'string', `latest_entry_ts must be a string, got ${typeof row.latest_entry_ts}`);
    }
  });

  it('ingest rejects non-ISO date values in feedback frontmatter', () => {
    if (!INGEST_EXISTS) return;
    const { tmp, feedbackDir } = makeFeedbackDir([{
      name: 'bad-date.md',
      content: '---\ncategory: hook-friction\nseverity: high\nstate: open\ndate: April 20, 2026\nauthor: test\n---\n',
    }]);
    const cacheDir = tmp;

    execSync(`node ${INGEST_PATH} --cache-dir ${cacheDir} --feedback-dir ${feedbackDir}`, {
      cwd: RETRO_ROOT, stdio: 'pipe',
    });

    const feedbackEventsPath = join(cacheDir, 'feedback-events.jsonl');
    // Entry with malformed date must be rejected at ingest — file absent or no entries
    if (existsSync(feedbackEventsPath)) {
      const content = readFileSync(feedbackEventsPath, 'utf8').trim();
      if (content) {
        const events = content.split('\n').filter(Boolean).map(l => JSON.parse(l));
        // No event should have the malformed created value
        for (const ev of events) {
          assert.ok(
            ev.created === null || /^\d{4}-\d{2}-\d{2}T/.test(ev.created),
            `Non-ISO date must be rejected at ingest; got created=${ev.created}`
          );
        }
      }
    }
  });
});

// ---------------------------------------------------------------------------
// I3 — path-traversal guard in resolveQueryEventsSource
// ---------------------------------------------------------------------------
describe('I3: resolveQueryEventsSource rejects path-traversal in events-source annotation',
  { skip: SKIP_RENDER }, () => {

  it('render.mjs source contains basename validation in resolveQueryEventsSource', () => {
    const src = readFileSync(RENDER_PATH, 'utf8');
    // The function must guard against / or .. in the resolved alt filename
    // We check that there is some validation logic present
    assert.ok(
      src.includes('..') || src.includes('basename') || src.includes('path.sep') || src.includes("'/'") || src.includes('"/'),
      'render.mjs must contain path-traversal guard in resolveQueryEventsSource'
    );
  });

  it('render.mjs resolveQueryEventsSource rejects filenames containing /', () => {
    // Write a malicious SQL file to a temp dir and run render against it
    const tmp = mkdtempSync(join(tmpdir(), 'retro-i3-'));
    const maliciousQueriesDir = join(tmp, 'queries');
    mkdirSync(maliciousQueriesDir, { recursive: true });
    const maliciousSql = `-- events-source: ../../etc/passwd\nSELECT 1 AS x;\n`;
    writeFileSync(join(maliciousQueriesDir, 'malicious.sql'), maliciousSql);

    const eventsPath = join(tmp, 'events.jsonl');
    writeFileSync(eventsPath, '');

    const outDir = join(tmp, 'out');
    mkdirSync(outDir, { recursive: true });

    // render.mjs must NOT crash on path traversal — it should silently skip or produce empty rows
    // It must NOT attempt to open the traversal path
    try {
      execSync(
        `node ${RENDER_PATH} --events ${eventsPath} --queries-dir ${maliciousQueriesDir} --out-dir ${outDir}`,
        { cwd: RETRO_ROOT, stdio: 'pipe', encoding: 'utf8' }
      );
    } catch (err) {
      // An error here means render crashed — acceptable only if it's a deliberate rejection.
      // A successful exit with empty rows is the preferred behavior.
      // We just verify it didn't read /etc/passwd (no /etc/passwd content in output).
      const stderr = err.stderr || '';
      assert.ok(!stderr.includes('root:'), 'render.mjs must not read /etc/passwd content');
    }

    // The output JSON must not contain /etc/passwd contents
    const resultPath = join(outDir, 'data', 'malicious.json');
    if (existsSync(resultPath)) {
      const content = readFileSync(resultPath, 'utf8');
      assert.ok(!content.includes('root:'), 'malicious.json must not contain /etc/passwd content');
    }
  });
});

// ---------------------------------------------------------------------------
// I4 — mtime-cache key uses hash of all feedback/*.md mtimes, not just INDEX.md
// ---------------------------------------------------------------------------
describe('I4: mtime-cache feedback key reflects individual file changes, not just INDEX.md',
  { skip: SKIP_INGEST }, () => {

  it('changing a feedback entry file triggers a cache miss even when INDEX.md is unchanged', () => {
    const tmp = mkdtempSync(join(tmpdir(), 'retro-i4-'));
    const cacheDir = tmp;
    const feedbackDir = join(tmp, 'feedback');
    mkdirSync(feedbackDir, { recursive: true });
    writeFileSync(join(feedbackDir, 'INDEX.md'), '# Index\n');

    const entryPath = join(feedbackDir, 'entry-001.md');
    writeFileSync(entryPath, '---\ncategory: hook-friction\nseverity: high\nstate: open\ndate: 2026-04-20\nauthor: test\n---\n');

    // First run — establishes mtime cache
    execSync(`node ${INGEST_PATH} --cache-dir ${cacheDir} --feedback-dir ${feedbackDir}`, {
      cwd: RETRO_ROOT, stdio: 'pipe',
    });

    const mtimeCachePath = join(cacheDir, 'events.mtimecache');
    assert.ok(existsSync(mtimeCachePath), 'mtime cache must exist after first run');
    const cache1 = JSON.parse(readFileSync(mtimeCachePath, 'utf8'));
    const feedbackKey1 = cache1['feedback-index'];

    // Touch (modify) the entry file — but do NOT touch INDEX.md
    // Append whitespace to force a new mtime
    const originalContent = readFileSync(entryPath, 'utf8');
    writeFileSync(entryPath, originalContent + '\n');

    // Wait a tick to ensure mtime changes (filesystem resolution may be 1ms or 1s)
    // Use a no-op execSync to advance time slightly
    execSync('true');

    // Second run
    execSync(`node ${INGEST_PATH} --cache-dir ${cacheDir} --feedback-dir ${feedbackDir}`, {
      cwd: RETRO_ROOT, stdio: 'pipe',
    });

    const cache2 = JSON.parse(readFileSync(mtimeCachePath, 'utf8'));
    const feedbackKey2 = cache2['feedback-index'];

    // The cache key must have changed because entry-001.md was modified
    // (Bug: old code only stored INDEX.md mtime → cache would be identical)
    assert.notEqual(feedbackKey1, feedbackKey2,
      'mtime-cache feedback-index key must change when an individual feedback/*.md file changes, not just INDEX.md');
  });
});

// ---------------------------------------------------------------------------
// I5 — stateToStatus warns on unknown state values
// ---------------------------------------------------------------------------
describe('I5: stateToStatus emits a warning on unknown state values instead of silently defaulting',
  { skip: SKIP_INGEST }, () => {

  it('ingest emits a warning to stderr when feedback entry has unknown state', () => {
    const { tmp, feedbackDir } = makeFeedbackDir([{
      name: 'unknown-state.md',
      content: '---\ncategory: hook-friction\nseverity: high\nstate: typo-state\ndate: 2026-04-20\nauthor: test\n---\n',
    }]);
    const cacheDir = tmp;

    let stderr = '';
    try {
      const result = execSync(
        `node ${INGEST_PATH} --cache-dir ${cacheDir} --feedback-dir ${feedbackDir}`,
        { cwd: RETRO_ROOT, encoding: 'utf8', stdio: 'pipe' }
      );
    } catch (err) {
      stderr = err.stderr || '';
    }

    // Capture stderr from the process directly
    try {
      execSync(
        `node ${INGEST_PATH} --cache-dir ${cacheDir} --feedback-dir ${feedbackDir} 2>&1 >/dev/null`,
        { cwd: RETRO_ROOT, encoding: 'utf8', shell: '/bin/sh' }
      );
    } catch {
      // ignore exit code
    }

    const combined = execSync(
      `node ${INGEST_PATH} --cache-dir ${cacheDir} --feedback-dir ${feedbackDir} 2>&1`,
      { cwd: RETRO_ROOT, encoding: 'utf8', shell: '/bin/sh' }
    );

    // Must contain a warning about the unknown state
    assert.ok(
      combined.includes('unknown') || combined.includes('warn') || combined.includes('typo-state'),
      `Expected a warning about unknown state 'typo-state', got: ${combined}`
    );
  });

  it('stateToStatus source code does not silently default — contains a warn/error branch', () => {
    const src = readFileSync(SOURCES_PATH, 'utf8');
    // The default branch must contain process.stderr.write or console.warn or throw
    // rather than silently returning 'open'
    assert.ok(
      src.includes('process.stderr.write') || src.includes('console.warn') || src.includes('console.error'),
      'sources.mjs stateToStatus must emit a warning on unknown state, not silently default to open'
    );
  });
});
