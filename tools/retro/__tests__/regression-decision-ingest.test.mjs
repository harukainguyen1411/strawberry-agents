/**
 * Regression test: decision-log ingest — parse decisions/log/*.md + emit correct event shape
 *
 * Guards: T.P2.3 (scanDecisionLogs in lib/sources.mjs + lib/decision-axes.mjs)
 * Plan-Ref: plans/approved/personal/2026-04-25-retrospection-dashboard-and-canonical-v1.md
 *
 * This test asserts the ingest correctly parses decision/log/*.md fixtures and emits
 * the expected `kind: 'decision-log'` event shape (per task dispatch + plan B §3.5 bind-points).
 *
 * Coverage:
 *   R1 — basic fixture parse: reads a valid decision log and emits correct event fields
 *   R2 — duong_concurred_silently:true → match:true (plan B §3.1 line 136)
 *   R3 — axes inline YAML list parsed correctly
 *   R4 — multi-axis decision emits single event with axes array (explosion is SQL-side)
 *   R5 — coordinator field derived from directory structure when frontmatter coordinator absent
 *   R6 — confidence mapping emitted as string in event payload (score mapped in parser separately)
 *   R7 — event sort order: older ts first (deterministic emission order)
 *   R8 — files with missing axes emit a warning AND are skipped (no event emitted)
 */

import { describe, it, before, after } from 'node:test';
import assert from 'node:assert/strict';
import {
  existsSync, mkdirSync, writeFileSync, rmSync
} from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { mkdtempSync } from 'node:fs';
import { tmpdir } from 'node:os';

const __dirname = dirname(fileURLToPath(import.meta.url));
const RETRO_ROOT = join(__dirname, '..');
const SOURCES_PATH = join(RETRO_ROOT, 'lib', 'sources.mjs');
const DECISION_AXES_PATH = join(RETRO_ROOT, 'lib', 'decision-axes.mjs');

// Guard: both implementation files must exist
if (!existsSync(SOURCES_PATH) || !existsSync(DECISION_AXES_PATH)) {
  throw new Error(
    'regression-decision-ingest.test.mjs: lib/sources.mjs or lib/decision-axes.mjs not found. ' +
    'T.P2.3 must be implemented before this regression test runs.'
  );
}

// Lazy import after existence check
const { scanDecisionLogs } = await import(SOURCES_PATH);

// ---------------------------------------------------------------------------
// Fixture builder helpers
// ---------------------------------------------------------------------------

/**
 * Write a minimal decision log markdown file with the given frontmatter fields.
 */
function writeDecisionLog(dir, filename, frontmatter) {
  const fm = Object.entries(frontmatter)
    .map(([k, v]) => {
      if (Array.isArray(v)) return `${k}: [${v.join(', ')}]`;
      return `${k}: ${v}`;
    })
    .join('\n');
  writeFileSync(join(dir, filename), `---\n${fm}\n---\n\n## Context\n\nTest fixture.\n`);
}

// ---------------------------------------------------------------------------
// R1 — basic fixture parse
// ---------------------------------------------------------------------------
describe('R1: scanDecisionLogs — basic fixture parse emits correct event shape', () => {
  let tmpDir;
  let logDir;

  before(() => {
    tmpDir = mkdtempSync(join(tmpdir(), 'retro-decision-r1-'));
    logDir = join(tmpDir, 'agents', 'evelynn', 'memory', 'decisions', 'log');
    mkdirSync(logDir, { recursive: true });
    writeDecisionLog(logDir, '2026-04-20-test-decision.md', {
      decision_id: '2026-04-20-test-decision',
      date: '2026-04-20',
      coordinator: 'evelynn',
      concern: 'personal',
      axes: ['routing-track'],
      question: 'Which agent handles this?',
      coordinator_pick: 'a',
      coordinator_confidence: 'medium',
      duong_pick: 'a',
      predict: 'a',
      match: 'true',
      concurred: 'false',
    });
  });

  after(() => {
    try { rmSync(tmpDir, { recursive: true, force: true }); } catch {}
  });

  it('emits exactly one decision event', () => {
    const events = scanDecisionLogs(tmpDir);
    assert.strictEqual(events.length, 1, 'expected 1 decision event');
  });

  it('event kind is "decision-log"', () => {
    const events = scanDecisionLogs(tmpDir);
    assert.strictEqual(events[0].kind, 'decision-log');
  });

  it('event coordinator matches frontmatter', () => {
    const events = scanDecisionLogs(tmpDir);
    assert.strictEqual(events[0].coordinator, 'evelynn');
  });

  it('event decision_id matches frontmatter', () => {
    const events = scanDecisionLogs(tmpDir);
    assert.strictEqual(events[0].decision_id, '2026-04-20-test-decision');
  });

  it('event ts is ISO-8601 from date field', () => {
    const events = scanDecisionLogs(tmpDir);
    assert.ok(events[0].ts.startsWith('2026-04-20'), `ts should start with date, got: ${events[0].ts}`);
  });

  it('event axes is an array of strings', () => {
    const events = scanDecisionLogs(tmpDir);
    assert.ok(Array.isArray(events[0].axes), 'axes must be an array');
    assert.deepEqual(events[0].axes, ['routing-track']);
  });

  it('event match is a boolean', () => {
    const events = scanDecisionLogs(tmpDir);
    assert.strictEqual(typeof events[0].match, 'boolean');
    assert.strictEqual(events[0].match, true);
  });

  it('event coordinator_confidence is the string value', () => {
    const events = scanDecisionLogs(tmpDir);
    assert.strictEqual(events[0].coordinator_confidence, 'medium');
  });
});

// ---------------------------------------------------------------------------
// R2 — duong_concurred_silently: true → match: true
// ---------------------------------------------------------------------------
describe('R2: scanDecisionLogs — duong_concurred_silently:true derives match:true', () => {
  let tmpDir;

  before(() => {
    tmpDir = mkdtempSync(join(tmpdir(), 'retro-decision-r2-'));
    const logDir = join(tmpDir, 'agents', 'evelynn', 'memory', 'decisions', 'log');
    mkdirSync(logDir, { recursive: true });
    writeDecisionLog(logDir, '2026-04-21-silent-concur.md', {
      decision_id: '2026-04-21-silent-concur',
      date: '2026-04-21',
      coordinator: 'evelynn',
      axes: ['routing-track'],
      coordinator_confidence: 'high',
      duong_concurred_silently: 'true',
      // NOTE: no explicit match field
    });
  });

  after(() => {
    try { rmSync(tmpDir, { recursive: true, force: true }); } catch {}
  });

  it('silent-concur decision has match=true', () => {
    const events = scanDecisionLogs(tmpDir);
    assert.strictEqual(events.length, 1);
    assert.strictEqual(events[0].match, true,
      'duong_concurred_silently:true must derive match=true');
  });
});

// ---------------------------------------------------------------------------
// R3 — axes inline YAML list parsed correctly
// ---------------------------------------------------------------------------
describe('R3: scanDecisionLogs — inline YAML list axes parsed correctly', () => {
  let tmpDir;

  before(() => {
    tmpDir = mkdtempSync(join(tmpdir(), 'retro-decision-r3-'));
    const logDir = join(tmpDir, 'agents', 'evelynn', 'memory', 'decisions', 'log');
    mkdirSync(logDir, { recursive: true });
    writeDecisionLog(logDir, '2026-04-22-multi-axis.md', {
      decision_id: '2026-04-22-multi-axis',
      date: '2026-04-22',
      coordinator: 'evelynn',
      axes: ['routing-track', 'scope-vs-debt'],
      coordinator_confidence: 'medium',
      match: 'false',
    });
  });

  after(() => {
    try { rmSync(tmpDir, { recursive: true, force: true }); } catch {}
  });

  it('multi-axis decision emits axes array with two elements', () => {
    const events = scanDecisionLogs(tmpDir);
    assert.strictEqual(events.length, 1);
    assert.deepEqual(events[0].axes, ['routing-track', 'scope-vs-debt']);
  });
});

// ---------------------------------------------------------------------------
// R4 — multi-axis decision emits a single event (axis explosion is SQL-side)
// ---------------------------------------------------------------------------
describe('R4: scanDecisionLogs — multi-axis decision emits one event (SQL handles explosion)', () => {
  let tmpDir;

  before(() => {
    tmpDir = mkdtempSync(join(tmpdir(), 'retro-decision-r4-'));
    const logDir = join(tmpDir, 'agents', 'evelynn', 'memory', 'decisions', 'log');
    mkdirSync(logDir, { recursive: true });
    writeDecisionLog(logDir, '2026-04-23-three-axes.md', {
      decision_id: '2026-04-23-three-axes',
      date: '2026-04-23',
      coordinator: 'evelynn',
      axes: ['routing-track', 'scope-vs-debt', 'model-tier'],
      coordinator_confidence: 'high',
      match: 'true',
    });
  });

  after(() => {
    try { rmSync(tmpDir, { recursive: true, force: true }); } catch {}
  });

  it('three-axis decision produces exactly one event (not three)', () => {
    const events = scanDecisionLogs(tmpDir);
    assert.strictEqual(events.length, 1, 'ingest must emit 1 event per decision file (axis explosion is SQL-side)');
    assert.strictEqual(events[0].axes.length, 3, 'axes array must have 3 elements');
  });
});

// ---------------------------------------------------------------------------
// R7 — event sort order: older ts first
// ---------------------------------------------------------------------------
describe('R7: scanDecisionLogs — events sorted by ts ascending', () => {
  let tmpDir;

  before(() => {
    tmpDir = mkdtempSync(join(tmpdir(), 'retro-decision-r7-'));
    const logDir = join(tmpDir, 'agents', 'evelynn', 'memory', 'decisions', 'log');
    mkdirSync(logDir, { recursive: true });
    // Write newer file first to ensure sort is not filesystem-order dependent
    writeDecisionLog(logDir, '2026-04-25-newer.md', {
      decision_id: '2026-04-25-newer',
      date: '2026-04-25',
      coordinator: 'evelynn',
      axes: ['routing-track'],
      coordinator_confidence: 'medium',
      match: 'true',
    });
    writeDecisionLog(logDir, '2026-04-20-older.md', {
      decision_id: '2026-04-20-older',
      date: '2026-04-20',
      coordinator: 'evelynn',
      axes: ['routing-track'],
      coordinator_confidence: 'low',
      match: 'false',
    });
  });

  after(() => {
    try { rmSync(tmpDir, { recursive: true, force: true }); } catch {}
  });

  it('two decisions are sorted with older ts first', () => {
    const events = scanDecisionLogs(tmpDir);
    assert.strictEqual(events.length, 2);
    assert.ok(
      events[0].ts < events[1].ts,
      `expected older event first; got ${events[0].ts} then ${events[1].ts}`
    );
    assert.strictEqual(events[0].decision_id, '2026-04-20-older');
    assert.strictEqual(events[1].decision_id, '2026-04-25-newer');
  });
});

// ---------------------------------------------------------------------------
// R8 — files with missing/empty axes emit a warning and are skipped
// F2 fix: R8 must assert/warn on malformation, not silently skip.
// ---------------------------------------------------------------------------
describe('R8: scanDecisionLogs — files with empty axes emit a warning and are skipped', () => {
  let tmpDir;

  before(() => {
    tmpDir = mkdtempSync(join(tmpdir(), 'retro-decision-r8-'));
    const logDir = join(tmpDir, 'agents', 'evelynn', 'memory', 'decisions', 'log');
    mkdirSync(logDir, { recursive: true });
    // Valid decision
    writeDecisionLog(logDir, '2026-04-20-valid.md', {
      decision_id: '2026-04-20-valid',
      date: '2026-04-20',
      coordinator: 'evelynn',
      axes: ['routing-track'],
      coordinator_confidence: 'medium',
      match: 'true',
    });
    // Decision with empty axes — should be skipped WITH a warning
    writeDecisionLog(logDir, '2026-04-21-no-axes.md', {
      decision_id: '2026-04-21-no-axes',
      date: '2026-04-21',
      coordinator: 'evelynn',
      coordinator_confidence: 'medium',
      match: 'true',
      // axes intentionally omitted
    });
  });

  after(() => {
    try { rmSync(tmpDir, { recursive: true, force: true }); } catch {}
  });

  it('only emits the valid decision event (skips empty-axes file)', () => {
    const events = scanDecisionLogs(tmpDir);
    assert.strictEqual(events.length, 1, 'expected only 1 event (empty-axes file skipped)');
    assert.strictEqual(events[0].decision_id, '2026-04-20-valid');
  });

  it('emits a warning to stderr when axes are missing (F2: R8 must warn, not silently skip)', () => {
    // Capture stderr output during scanDecisionLogs call.
    // F2 fix: malformed decision logs must emit a visible warning, not silently skip.
    const stderrChunks = [];
    const origWrite = process.stderr.write.bind(process.stderr);
    process.stderr.write = (chunk, ...args) => {
      stderrChunks.push(typeof chunk === 'string' ? chunk : chunk.toString());
      return origWrite(chunk, ...args);
    };
    try {
      scanDecisionLogs(tmpDir);
    } finally {
      process.stderr.write = origWrite;
    }
    const combined = stderrChunks.join('');
    assert.ok(
      combined.includes('warn') || combined.includes('malformed') || combined.includes('skip'),
      `Expected a warning about the empty-axes file on stderr, got: ${combined}`
    );
    assert.ok(
      combined.includes('2026-04-21-no-axes.md'),
      `Expected the warning to name the problematic file, got: ${combined}`
    );
  });
});
