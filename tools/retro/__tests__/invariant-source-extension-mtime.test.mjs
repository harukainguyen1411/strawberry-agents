/**
 * TP2.T4 — xfail invariant test: ingest source-extension paths are mtime-cache safe
 *
 * Guards: T.P2.2 + T.P2.3 + T.P2.4 (cross-task mtime invariant)
 * Rule 12: this commit lands BEFORE any of T.P2.2/T.P2.3/T.P2.4 impl commits.
 * Plan-Ref: plans/approved/personal/2026-04-25-retrospection-dashboard-and-canonical-v1.md
 *
 * xfail: skipped until ingest.mjs exists AND lib/sources.mjs carries Phase-2 source readers.
 * TODO (T.P2.2/T.P2.3/T.P2.4): implement Phase-2 source readers + mtime-cache integration, flip skip.
 *
 * Cross-task guard: this test FAILS if T.P2.2 ships its feedback-index reader
 *   without wiring lib/mtime-cache.mjs — catches the bug-class where a parallel-track
 *   impl forgets the cache integration.
 *
 * Covers all FIVE source readers (Phase 2 additions):
 *   parent-jsonl, subagent-jsonl, sentinel, feedback-index, decision-log
 */

import { describe, it, before, after } from 'node:test';
import assert from 'node:assert/strict';
import {
  existsSync, readFileSync, writeFileSync, mkdirSync, mkdtempSync,
  copyFileSync, unlinkSync, statSync
} from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { execSync } from 'node:child_process';
import { tmpdir } from 'node:os';

const __dirname = dirname(fileURLToPath(import.meta.url));
const RETRO_ROOT = join(__dirname, '..');
const INGEST_PATH = join(RETRO_ROOT, 'ingest.mjs');
const SOURCES_PATH = join(RETRO_ROOT, 'lib', 'sources.mjs');
const FIXTURES_DIR = join(RETRO_ROOT, 'fixtures');

// xfail guard — needs ingest.mjs AND Phase-2 source readers
const IMPL_EXISTS = existsSync(INGEST_PATH) && existsSync(SOURCES_PATH);
const SKIP_REASON = 'xfail: ingest.mjs / lib/sources.mjs not yet implemented with Phase-2 readers (TODO T.P2.2/T.P2.3/T.P2.4)';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function makeFixtureTree(tmpDir, scenario) {
  // Set up a minimal fixture tree for mtime-cache tests
  const cacheDir = join(tmpDir, 'cache');
  mkdirSync(cacheDir, { recursive: true });

  if (scenario === 'cold') {
    // No events.mtimecache present — cold start
  } else if (scenario === 'warm') {
    // events.mtimecache present, no source changes
    writeFileSync(join(cacheDir, 'events.mtimecache'), JSON.stringify({
      'parent-jsonl': Date.now() - 60000,
      'subagent-jsonl': Date.now() - 60000,
      'sentinel': Date.now() - 60000,
      'feedback-index': Date.now() - 60000,
      'decision-log': Date.now() - 60000
    }));
    // Seed a baseline events.jsonl
    writeFileSync(join(cacheDir, 'events.jsonl'), '{"kind":"turn","ts":"2026-01-01T00:00:00.000Z","role":"coordinator-inline"}\n');
  } else if (scenario === 'partial-update') {
    // Cache present but feedback-index has been modified (newer mtime)
    const oldTime = Date.now() - 120000; // 2 min ago
    const recentTime = Date.now() - 5000; // 5 sec ago
    writeFileSync(join(cacheDir, 'events.mtimecache'), JSON.stringify({
      'parent-jsonl': oldTime,
      'subagent-jsonl': oldTime,
      'sentinel': oldTime,
      'feedback-index': oldTime, // stale — will be re-scanned
      'decision-log': oldTime
    }));
    writeFileSync(join(cacheDir, 'events.jsonl'), '{"kind":"turn","ts":"2026-01-01T00:00:00.000Z","role":"coordinator-inline"}\n');
    // Touch feedback-index fixture to make it appear newer than cache
    const feedbackPath = join(tmpDir, 'feedback', 'INDEX.md');
    mkdirSync(dirname(feedbackPath), { recursive: true });
    copyFileSync(
      join(FIXTURES_DIR, 'mtime-cache-scenarios', 'feedback-index-v2.md'),
      feedbackPath
    );
  } else if (scenario === 'corrupt-cache') {
    // Corrupt mtimecache triggers full re-scan
    writeFileSync(join(cacheDir, 'events.mtimecache'), '{corrupted json');
    writeFileSync(join(cacheDir, 'events.jsonl'), '{"kind":"turn","ts":"2026-01-01T00:00:00.000Z"}\n');
  }

  return cacheDir;
}

function runIngest(cacheDir, extraEnv = {}) {
  return execSync(`node ${INGEST_PATH} --cache-dir ${cacheDir}`, {
    cwd: RETRO_ROOT,
    encoding: 'utf8',
    env: { ...process.env, ...extraEnv }
  });
}

function countEventsJsonlLines(cacheDir) {
  const p = join(cacheDir, 'events.jsonl');
  if (!existsSync(p)) return 0;
  return readFileSync(p, 'utf8').split('\n').filter(Boolean).length;
}

function readMtimeCache(cacheDir) {
  const p = join(cacheDir, 'events.mtimecache');
  if (!existsSync(p)) return null;
  return JSON.parse(readFileSync(p, 'utf8'));
}

// ---------------------------------------------------------------------------
// TP2.T4-A: cold start — no mtimecache, full scan executes
// ---------------------------------------------------------------------------
describe('TP2.T4-A: mtime-cache — cold start performs full scan',
  { skip: !IMPL_EXISTS ? SKIP_REASON : false }, () => {

  let tmpDir;
  before(() => { tmpDir = mkdtempSync(join(tmpdir(), 'retro-mtime-cold-')); });
  after(() => { try { execSync(`rm -rf ${tmpDir}`); } catch {} });

  it('produces events.jsonl after cold-start ingest', () => {
    const cacheDir = makeFixtureTree(tmpDir, 'cold');
    runIngest(cacheDir);
    assert.ok(existsSync(join(cacheDir, 'events.jsonl')),
      'events.jsonl must exist after cold start');
  });

  it('produces events.mtimecache after cold-start ingest', () => {
    const cacheDir = makeFixtureTree(tmpDir, 'cold');
    runIngest(cacheDir);
    assert.ok(existsSync(join(cacheDir, 'events.mtimecache')),
      'events.mtimecache must be created on cold start');
  });

  it('mtimecache after cold start contains all 5 source keys', () => {
    const cacheDir = makeFixtureTree(tmpDir, 'cold');
    runIngest(cacheDir);
    const cache = readMtimeCache(cacheDir);
    const EXPECTED_KEYS = ['parent-jsonl', 'subagent-jsonl', 'sentinel', 'feedback-index', 'decision-log'];
    for (const key of EXPECTED_KEYS) {
      assert.ok(key in cache, `mtimecache missing source key: ${key}`);
    }
  });
});

// ---------------------------------------------------------------------------
// TP2.T4-B: warm start — cache present, no source changes → ZERO new events emitted
// ---------------------------------------------------------------------------
describe('TP2.T4-B: mtime-cache — warm start with no source changes emits zero new events',
  { skip: !IMPL_EXISTS ? SKIP_REASON : false }, () => {

  let tmpDir;
  before(() => { tmpDir = mkdtempSync(join(tmpdir(), 'retro-mtime-warm-')); });
  after(() => { try { execSync(`rm -rf ${tmpDir}`); } catch {} });

  it('warm start produces no additional lines in events.jsonl', () => {
    const cacheDir = makeFixtureTree(tmpDir, 'warm');
    const beforeCount = countEventsJsonlLines(cacheDir);
    runIngest(cacheDir);
    const afterCount = countEventsJsonlLines(cacheDir);
    assert.strictEqual(afterCount, beforeCount,
      `warm start must emit zero new events; before=${beforeCount} after=${afterCount}`);
  });

  it('warm start produces byte-identical events.mtimecache', () => {
    const cacheDir = makeFixtureTree(tmpDir, 'warm');
    const before = readFileSync(join(cacheDir, 'events.mtimecache'), 'utf8');
    runIngest(cacheDir);
    const after = readFileSync(join(cacheDir, 'events.mtimecache'), 'utf8');
    assert.strictEqual(before, after, 'mtimecache must be byte-identical on warm no-op run');
  });
});

// ---------------------------------------------------------------------------
// TP2.T4-C: partial-update — only feedback-index modified → only feedback events emitted
// Cross-task guard: catches impl that ships source reader without mtime-cache integration
// ---------------------------------------------------------------------------
describe('TP2.T4-C: mtime-cache — partial update only re-scans modified source',
  { skip: !IMPL_EXISTS ? SKIP_REASON : false }, () => {

  let tmpDir;
  before(() => { tmpDir = mkdtempSync(join(tmpdir(), 'retro-mtime-partial-')); });
  after(() => { try { execSync(`rm -rf ${tmpDir}`); } catch {} });

  it('only emits events for the feedback-index source after partial update', () => {
    const cacheDir = makeFixtureTree(tmpDir, 'partial-update');
    const beforeLines = countEventsJsonlLines(cacheDir);
    runIngest(cacheDir);
    const eventsContent = readFileSync(join(cacheDir, 'events.jsonl'), 'utf8');
    const newLines = eventsContent.split('\n').filter(Boolean).slice(beforeLines);
    const newEvents = newLines.map(l => JSON.parse(l));
    // All new events must be from feedback-index source
    const nonFeedback = newEvents.filter(e => e.kind !== 'feedback-entry');
    assert.deepEqual(nonFeedback, [],
      `partial update must only emit feedback-entry events; got non-feedback events: ${JSON.stringify(nonFeedback)}`);
    assert.ok(newEvents.length > 0, 'expected at least one new feedback-entry event');
  });
});

// ---------------------------------------------------------------------------
// TP2.T4-D: corrupt-cache → full re-scan with logged warning (data-loss guard)
// ---------------------------------------------------------------------------
describe('TP2.T4-D: mtime-cache — corrupt cache triggers full re-scan with warning',
  { skip: !IMPL_EXISTS ? SKIP_REASON : false }, () => {

  let tmpDir;
  before(() => { tmpDir = mkdtempSync(join(tmpdir(), 'retro-mtime-corrupt-')); });
  after(() => { try { execSync(`rm -rf ${tmpDir}`); } catch {} });

  it('ingest does not abort on corrupt mtimecache (recovers via full re-scan)', () => {
    const cacheDir = makeFixtureTree(tmpDir, 'corrupt-cache');
    assert.doesNotThrow(
      () => runIngest(cacheDir),
      'ingest must not throw on corrupt mtimecache'
    );
  });

  it('produces valid events.jsonl after recovering from corrupt cache', () => {
    const cacheDir = makeFixtureTree(tmpDir, 'corrupt-cache');
    runIngest(cacheDir);
    assert.ok(existsSync(join(cacheDir, 'events.jsonl')),
      'events.jsonl must exist after corrupt-cache recovery');
  });
});

// ---------------------------------------------------------------------------
// TP2.T4-E: idempotence — two consecutive runs over same sources produce byte-identical output
// ---------------------------------------------------------------------------
describe('TP2.T4-E: mtime-cache — two consecutive no-op runs are byte-identical',
  { skip: !IMPL_EXISTS ? SKIP_REASON : false }, () => {

  let tmpDir;
  before(() => { tmpDir = mkdtempSync(join(tmpdir(), 'retro-mtime-idem-')); });
  after(() => { try { execSync(`rm -rf ${tmpDir}`); } catch {} });

  it('events.jsonl is byte-identical after two consecutive ingest runs with no source changes', () => {
    const cacheDir = makeFixtureTree(tmpDir, 'cold');
    runIngest(cacheDir); // First run
    const eventsAfterRun1 = readFileSync(join(cacheDir, 'events.jsonl'), 'utf8');
    runIngest(cacheDir); // Second run (warm)
    const eventsAfterRun2 = readFileSync(join(cacheDir, 'events.jsonl'), 'utf8');
    assert.strictEqual(eventsAfterRun1, eventsAfterRun2,
      'events.jsonl must be byte-identical across two consecutive no-op ingest runs');
  });

  it('events.mtimecache is byte-identical after two consecutive runs with no source changes', () => {
    const cacheDir = makeFixtureTree(tmpDir, 'cold');
    runIngest(cacheDir);
    const cacheAfterRun1 = readFileSync(join(cacheDir, 'events.mtimecache'), 'utf8');
    runIngest(cacheDir);
    const cacheAfterRun2 = readFileSync(join(cacheDir, 'events.mtimecache'), 'utf8');
    assert.strictEqual(cacheAfterRun1, cacheAfterRun2,
      'events.mtimecache must be byte-identical across two consecutive no-op ingest runs');
  });
});
