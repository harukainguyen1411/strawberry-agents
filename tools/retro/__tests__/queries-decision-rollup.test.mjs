/**
 * TP2.T2 (part 1) — xfail unit test: decision-rollup query against golden fixture
 *
 * Guards: T.P2.3 (decision-rollup.sql + decision-log source reader)
 * Rule 12: this commit lands BEFORE T.P2.3 impl commit.
 * Plan-Ref: plans/approved/personal/2026-04-25-retrospection-dashboard-and-canonical-v1.md
 *
 * xfail: skipped if tools/retro/queries/decision-rollup.sql is absent (T.P2.3 not yet landed).
 * TODO (T.P2.3): implement decision-rollup.sql + lib/sources.mjs decision-log reader + lib/decision-axes.mjs,
 *   then flip skip.
 *
 * Shape contract (plan B §3.5 bind-points):
 *   row: (coordinator, axis, decisions_total, decisions_matched, match_rate, avg_confidence_at_time)
 *   match_rate: 4-decimal string-compare precision
 *   duong_concurred_silently: true → match: true (plan B §3.1 line 136)
 *   axes treated as per-decision expansion NOT per-coordinator set dedup (axis-explosion)
 */

import { describe, it, before } from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, readFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { execSync } from 'node:child_process';

const __dirname = dirname(fileURLToPath(import.meta.url));
const RETRO_ROOT = join(__dirname, '..');
const SQL_PATH = join(RETRO_ROOT, 'queries', 'decision-rollup.sql');
const EXPECTED_PATH = join(RETRO_ROOT, 'queries', 'decision-rollup.expected.json');
const FIXTURES_DIR = join(RETRO_ROOT, 'fixtures');

// xfail guard — decision-rollup.sql does not exist yet (T.P2.3 lands it)
const IMPL_EXISTS = existsSync(SQL_PATH);
const SKIP_REASON = 'xfail: decision-rollup.sql not yet implemented (TODO T.P2.3)';

function runDecisionRollupQuery(eventsPath) {
  const result = execSync(
    `duckdb -json -c "$(cat '${SQL_PATH}')" '${eventsPath}'`,
    { cwd: RETRO_ROOT, encoding: 'utf8' }
  );
  return JSON.parse(result);
}

function sortKeys(obj) {
  return Object.fromEntries(Object.entries(obj).sort(([a], [b]) => a.localeCompare(b)));
}

function unifiedDiff(expected, actual) {
  return `expected: ${JSON.stringify(expected, null, 2)}\nactual:   ${JSON.stringify(actual, null, 2)}`;
}

// ---------------------------------------------------------------------------
// TP2.T2-A: golden deep-equal check
// ---------------------------------------------------------------------------
describe('TP2.T2-A: decision-rollup.sql — golden deep-equal against expected.json',
  { skip: !IMPL_EXISTS ? SKIP_REASON : false }, () => {

  let actual;
  let expected;

  before(() => {
    expected = JSON.parse(readFileSync(EXPECTED_PATH, 'utf8'));
    const eventsPath = join(FIXTURES_DIR, 'decision-rollup-events.jsonl');
    actual = runDecisionRollupQuery(eventsPath);
  });

  it('result is an array', () => {
    assert.ok(Array.isArray(actual), 'expected DuckDB result to be an array');
  });

  it('deep-equals golden expected.json (key-sorted)', () => {
    const sortedActual = actual.map(r => sortKeys(r));
    const sortedExpected = expected.map(r => sortKeys(r));
    assert.deepEqual(sortedActual, sortedExpected,
      `decision-rollup output does not match golden.\n${unifiedDiff(sortedExpected, sortedActual)}`);
  });

  it('each row has the 6 contracted columns', () => {
    const ALLOWED = new Set([
      'coordinator', 'axis', 'decisions_total', 'decisions_matched', 'match_rate', 'avg_confidence_at_time'
    ]);
    for (const row of actual) {
      const extra = Object.keys(row).filter(k => !ALLOWED.has(k));
      assert.deepEqual(extra, [],
        `Row has extra columns not in plan B §3.5 contract: ${extra.join(', ')}`);
    }
  });

  it('match_rate is a 4-decimal precision string', () => {
    for (const row of actual) {
      const mr = row.match_rate;
      assert.ok(typeof mr === 'string',
        `match_rate must be a string for deterministic 4-decimal compare, got ${typeof mr}`);
      assert.match(mr, /^\d+\.\d{4}$/,
        `match_rate must have exactly 4 decimal places, got: ${mr}`);
    }
  });
});

// ---------------------------------------------------------------------------
// TP2.T2-B: duong_concurred_silently: true derives match:true (plan B §3.1 line 136)
// ---------------------------------------------------------------------------
describe('TP2.T2-B: decision-rollup — duong_concurred_silently:true derives match:true',
  { skip: !IMPL_EXISTS ? SKIP_REASON : false }, () => {

  let actual;

  before(() => {
    const eventsPath = join(FIXTURES_DIR, 'decision-rollup-events.jsonl');
    actual = runDecisionRollupQuery(eventsPath);
  });

  it('coordinator evelynn has decisions_matched count including the silent-concur fixture', () => {
    // Fixture has 3 decisions: match:true explicit, match:false, duong_concurred_silently:true
    // So decisions_matched for evelynn over routing-track axis should be 2/3
    const rows = actual.filter(r => r.coordinator === 'evelynn');
    const routingRow = rows.find(r => r.axis === 'routing-track');
    assert.ok(routingRow, 'expected a routing-track axis row for evelynn');
    assert.strictEqual(Number(routingRow.decisions_total), 3,
      'expected decisions_total=3 for evelynn/routing-track');
    assert.strictEqual(Number(routingRow.decisions_matched), 2,
      'expected decisions_matched=2 (explicit match + silent concur)');
  });
});

// ---------------------------------------------------------------------------
// TP2.T2-C: axis-explosion invariant — axes array is per-decision, not per-coordinator set dedup
// DoD-(e): a decision with axes:[routing-track] and another with axes:[routing-track, model-tier]
//   produces TWO rollup rows for routing-track (one per decision), not one deduplicated row
// ---------------------------------------------------------------------------
describe('TP2.T2-C: decision-rollup — axis-explosion (not per-coordinator set dedup)',
  { skip: !IMPL_EXISTS ? SKIP_REASON : false }, () => {

  let actual;

  before(() => {
    const eventsPath = join(FIXTURES_DIR, 'decision-rollup-axis-explosion.jsonl');
    actual = runDecisionRollupQuery(eventsPath);
  });

  it('routing-track axis appears as an aggregation of two separate decisions', () => {
    const routingRows = actual.filter(r => r.axis === 'routing-track');
    assert.ok(routingRows.length >= 1, 'expected at least one routing-track row');
    // decisions_total for routing-track must be 2 (from 2 decisions that include it)
    const total = routingRows.reduce((sum, r) => sum + Number(r.decisions_total), 0);
    assert.ok(total >= 2,
      `expected routing-track to aggregate 2 decisions (axis-explosion), got total=${total}`);
  });

  it('model-tier axis appears from the multi-axis decision', () => {
    const modelRows = actual.filter(r => r.axis === 'model-tier');
    assert.ok(modelRows.length >= 1, 'expected at least one model-tier row from multi-axis decision');
  });
});

// ---------------------------------------------------------------------------
// TP2.T2-D: silent-concur idempotence — re-running parser produces byte-identical records
// ---------------------------------------------------------------------------
describe('TP2.T2-D: decision-rollup — silent-concur parsing is deterministic (no Date.now leak)',
  { skip: !IMPL_EXISTS ? SKIP_REASON : false }, () => {

  it('two consecutive query runs over the same fixture produce identical output', () => {
    const eventsPath = join(FIXTURES_DIR, 'decision-rollup-events.jsonl');
    const run1 = runDecisionRollupQuery(eventsPath);
    const run2 = runDecisionRollupQuery(eventsPath);
    assert.deepEqual(run1, run2, 'two consecutive decision-rollup query runs must be identical');
  });
});
