/**
 * TP2.T1 — xfail unit test: feedback-rollup query against golden fixture
 *
 * Guards: T.P2.2 (feedback-rollup.sql + feedback-index source reader)
 * Rule 12: this commit lands BEFORE T.P2.2 impl commit.
 * Plan-Ref: plans/approved/personal/2026-04-25-retrospection-dashboard-and-canonical-v1.md
 *
 * xfail: skipped if tools/retro/queries/feedback-rollup.sql is absent (T.P2.2 not yet landed).
 * TODO (T.P2.2): implement feedback-rollup.sql + lib/sources.mjs feedback-index reader, then flip skip.
 *
 * Shape contract (plan A §D12 read contract):
 *   row: (category, severity, status, open_count, latest_entry_ts)
 *   extra columns fail the test (Phase-2-boundary schema guard).
 *   closed entries must NOT count towards open_count.
 *   latest_entry_ts is the entry `created` frontmatter, NOT file mtime.
 */

import { describe, it, before } from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, readFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { execSync } from 'node:child_process';

const __dirname = dirname(fileURLToPath(import.meta.url));
const RETRO_ROOT = join(__dirname, '..');
const SQL_PATH = join(RETRO_ROOT, 'queries', 'feedback-rollup.sql');
const EXPECTED_PATH = join(RETRO_ROOT, 'queries', 'feedback-rollup.expected.json');
const FIXTURES_DIR = join(RETRO_ROOT, 'fixtures');
const FEEDBACK_FIXTURE = join(FIXTURES_DIR, 'feedback-index.md');

// xfail guard — feedback-rollup.sql does not exist yet (T.P2.2 lands it)
const IMPL_EXISTS = existsSync(SQL_PATH);
const SKIP_REASON = 'xfail: feedback-rollup.sql not yet implemented (TODO T.P2.2)';

// ---------------------------------------------------------------------------
// Helper: run DuckDB CLI against a known events.jsonl derived from the fixture
// ---------------------------------------------------------------------------
function runFeedbackRollupQuery(eventsPath) {
  const result = execSync(
    `duckdb -json -c "$(cat '${SQL_PATH}')" '${eventsPath}'`,
    { cwd: RETRO_ROOT, encoding: 'utf8' }
  );
  return JSON.parse(result);
}

// ---------------------------------------------------------------------------
// TP2.T1-A: golden deep-equal check — shape (category, severity, status, open_count, latest_entry_ts)
// ---------------------------------------------------------------------------
describe('TP2.T1-A: feedback-rollup.sql — golden deep-equal against expected.json',
  { skip: !IMPL_EXISTS ? SKIP_REASON : false }, () => {

  let actual;
  let expected;

  before(() => {
    expected = JSON.parse(readFileSync(EXPECTED_PATH, 'utf8'));
    // The fixture events.jsonl for phase-2 queries lives alongside the feedback-index fixture
    const eventsPath = join(FIXTURES_DIR, 'feedback-rollup-events.jsonl');
    actual = runFeedbackRollupQuery(eventsPath);
  });

  it('result is an array', () => {
    assert.ok(Array.isArray(actual), 'expected DuckDB result to be an array');
  });

  it('deep-equals the golden expected.json (key-sorted)', () => {
    const sortedActual = actual.map(r => sortKeys(r));
    const sortedExpected = expected.map(r => sortKeys(r));
    assert.deepEqual(sortedActual, sortedExpected,
      `feedback-rollup output does not match golden.\nDiff:\n${unifiedDiff(sortedExpected, sortedActual)}`);
  });

  it('each row has exactly the 5 contracted columns', () => {
    const ALLOWED = new Set(['category', 'severity', 'status', 'open_count', 'latest_entry_ts']);
    for (const row of actual) {
      const extra = Object.keys(row).filter(k => !ALLOWED.has(k));
      assert.deepEqual(extra, [],
        `Row has extra columns not in plan A §D12 contract: ${extra.join(', ')}`);
    }
  });
});

// ---------------------------------------------------------------------------
// TP2.T1-B: fixture coverage — 6 rows spanning all severity × status combinations
// ---------------------------------------------------------------------------
describe('TP2.T1-B: feedback-rollup fixture covers all severity × status combinations',
  { skip: !IMPL_EXISTS ? SKIP_REASON : false }, () => {

  let actual;

  before(() => {
    const eventsPath = join(FIXTURES_DIR, 'feedback-rollup-events.jsonl');
    actual = runFeedbackRollupQuery(eventsPath);
  });

  it('result spans all three severity levels (high/medium/low)', () => {
    const severities = new Set(actual.map(r => r.severity));
    assert.ok(severities.has('high'), 'expected a row with severity=high');
    assert.ok(severities.has('medium'), 'expected a row with severity=medium');
    assert.ok(severities.has('low'), 'expected a row with severity=low');
  });

  it('result spans all three status levels (open/triaged/closed)', () => {
    const statuses = new Set(actual.map(r => r.status));
    assert.ok(statuses.has('open'), 'expected a row with status=open');
    assert.ok(statuses.has('triaged'), 'expected a row with status=triaged');
    assert.ok(statuses.has('closed'), 'expected a row with status=closed');
  });

  it('result has at least 2 distinct category values', () => {
    const cats = new Set(actual.map(r => r.category));
    assert.ok(cats.size >= 2, `expected at least 2 categories, got: ${[...cats].join(', ')}`);
  });
});

// ---------------------------------------------------------------------------
// TP2.T1-C: negative invariant — closed entries must NOT appear in open_count
// Plan A §D12 contract: only status=open rows contribute to open_count
// ---------------------------------------------------------------------------
describe('TP2.T1-C: feedback-rollup closed-entries must not inflate open_count',
  { skip: !IMPL_EXISTS ? SKIP_REASON : false }, () => {

  let actual;

  before(() => {
    const eventsPath = join(FIXTURES_DIR, 'feedback-rollup-events.jsonl');
    actual = runFeedbackRollupQuery(eventsPath);
  });

  it('closed status rows have open_count = 0', () => {
    const closedRows = actual.filter(r => r.status === 'closed');
    for (const row of closedRows) {
      assert.strictEqual(row.open_count, 0,
        `closed row has open_count > 0: ${JSON.stringify(row)}`);
    }
  });
});

// ---------------------------------------------------------------------------
// TP2.T1-D: latest_entry_ts uses frontmatter created field, NOT file mtime
// Determinism guard: re-running over the same fixture produces the same ts values
// ---------------------------------------------------------------------------
describe('TP2.T1-D: feedback-rollup latest_entry_ts is deterministic (frontmatter, not mtime)',
  { skip: !IMPL_EXISTS ? SKIP_REASON : false }, () => {

  it('running the query twice produces byte-identical latest_entry_ts values', () => {
    const eventsPath = join(FIXTURES_DIR, 'feedback-rollup-events.jsonl');
    const run1 = runFeedbackRollupQuery(eventsPath);
    const run2 = runFeedbackRollupQuery(eventsPath);
    assert.deepEqual(run1, run2, 'two consecutive query runs must produce identical output');
  });
});

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------
function sortKeys(obj) {
  return Object.fromEntries(Object.entries(obj).sort(([a], [b]) => a.localeCompare(b)));
}

function unifiedDiff(expected, actual) {
  return `expected: ${JSON.stringify(expected, null, 2)}\nactual:   ${JSON.stringify(actual, null, 2)}`;
}
