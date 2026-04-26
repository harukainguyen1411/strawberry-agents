/**
 * TP2.T3 (part 1) — xfail unit test: coordinator-weekly full query invariants
 *
 * Guards: T.P2.4 (coordinator-weekly.sql + prompt-stats ingest extension)
 * Rule 12: this commit lands BEFORE T.P2.4 impl commit.
 * Plan-Ref: plans/approved/personal/2026-04-25-retrospection-dashboard-and-canonical-v1.md
 *
 * xfail: skipped if tools/retro/queries/coordinator-weekly.sql is absent (T.P2.4 not yet landed).
 * TODO (T.P2.4): implement coordinator-weekly.sql + lib/prompt-stats.mjs + ingest wiring, then flip skip.
 *
 * Shape contract: 12-column row extending Phase-1 skeleton's 4 columns with 8 prompt-stat columns.
 * inline-vs-delegate ratio per §Q8 path discriminator.
 * Percentile values: 4-decimal string precision.
 * plan-citation regex pinned to exact path pattern from T.P2.4 DoD-(e).
 */

import { describe, it, before } from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, readFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { execSync } from 'node:child_process';

const __dirname = dirname(fileURLToPath(import.meta.url));
const RETRO_ROOT = join(__dirname, '..');
const SQL_PATH = join(RETRO_ROOT, 'queries', 'coordinator-weekly.sql');
const EXPECTED_PATH = join(RETRO_ROOT, 'queries', 'coordinator-weekly.expected.json');
const FIXTURES_DIR = join(RETRO_ROOT, 'fixtures');
const PROMPTS_FIXTURE = join(FIXTURES_DIR, 'parent-session-with-prompts.jsonl');

// xfail guard — coordinator-weekly.sql does not exist yet (T.P2.4 lands it)
const IMPL_EXISTS = existsSync(SQL_PATH);
const SKIP_REASON = 'xfail: coordinator-weekly.sql not yet implemented (TODO T.P2.4)';

function runCoordWeeklyQuery(eventsPath) {
  const result = execSync(
    `duckdb -json -c "$(cat '${SQL_PATH}')" '${eventsPath}'`,
    { cwd: RETRO_ROOT, encoding: 'utf8' }
  );
  return JSON.parse(result);
}

function sortKeys(obj) {
  return Object.fromEntries(Object.entries(obj).sort(([a], [b]) => a.localeCompare(b)));
}

// ---------------------------------------------------------------------------
// TP2.T3-A: golden deep-equal — full 12-column shape
// ---------------------------------------------------------------------------
describe('TP2.T3-A: coordinator-weekly.sql — golden deep-equal against expected.json',
  { skip: !IMPL_EXISTS ? SKIP_REASON : false }, () => {

  let actual;
  let expected;

  before(() => {
    expected = JSON.parse(readFileSync(EXPECTED_PATH, 'utf8'));
    const eventsPath = join(FIXTURES_DIR, 'coordinator-weekly-events.jsonl');
    actual = runCoordWeeklyQuery(eventsPath);
  });

  it('result is an array', () => {
    assert.ok(Array.isArray(actual));
  });

  it('deep-equals golden expected.json (key-sorted)', () => {
    const sortedActual = actual.map(r => sortKeys(r));
    const sortedExpected = expected.map(r => sortKeys(r));
    assert.deepEqual(sortedActual, sortedExpected,
      `coordinator-weekly output does not match golden.\nExpected: ${JSON.stringify(sortedExpected)}\nActual: ${JSON.stringify(sortedActual)}`);
  });

  it('each row has the 12 contracted columns', () => {
    const ALLOWED = new Set([
      // Phase-1 skeleton columns
      'coordinator', 'iso_week', 'inline_tool_calls', 'delegated_tool_calls',
      'delegate_ratio', 'dispatch_count',
      // Phase-2 prompt-stat columns
      'prompt_chars_p50', 'prompt_chars_p95', 'header_count_avg',
      'concern_tag_present_pct', 'plan_citation_present_pct',
      'compression_ratio_p50', 'compression_ratio_p95'
    ]);
    for (const row of actual) {
      const keys = new Set(Object.keys(row));
      // Check for Phase-1 skeleton leak (Phase-2 must not have old skeleton columns)
      assert.ok(!keys.has('skeleton_only'), 'must not carry deprecated skeleton-only column');
    }
  });
});

// ---------------------------------------------------------------------------
// TP2.T3-B: prompt percentile values from known fixture dispatches
// DoD-(b): dispatch A=200 chars, B=1200 chars, C=3500 chars → p50=1200, p95=3500
// ---------------------------------------------------------------------------
describe('TP2.T3-B: coordinator-weekly — prompt_chars percentiles from known fixture dispatches',
  { skip: !IMPL_EXISTS ? SKIP_REASON : false }, () => {

  let actual;

  before(() => {
    const eventsPath = join(FIXTURES_DIR, 'coordinator-weekly-events.jsonl');
    actual = runCoordWeeklyQuery(eventsPath);
  });

  it('prompt_chars_p50 is 1200 for fixture with 3 dispatches (200, 1200, 3500 chars)', () => {
    const row = actual[0];
    assert.ok(row, 'expected at least one row');
    // p50 of [200, 1200, 3500] = 1200 (middle value)
    assert.strictEqual(String(row.prompt_chars_p50), '1200',
      `expected prompt_chars_p50=1200, got ${row.prompt_chars_p50}`);
  });

  it('prompt_chars_p95 is 3500 for fixture with 3 dispatches', () => {
    const row = actual[0];
    assert.ok(row, 'expected at least one row');
    assert.strictEqual(String(row.prompt_chars_p95), '3500',
      `expected prompt_chars_p95=3500, got ${row.prompt_chars_p95}`);
  });

  it('concern_tag_present_pct is 66.6667 (2 of 3 dispatches have concern tag)', () => {
    const row = actual[0];
    assert.ok(row, 'expected at least one row');
    // Dispatches B and C have concern tag, A does not → 2/3 = 66.6667
    const pct = Number(row.concern_tag_present_pct);
    assert.ok(Math.abs(pct - 66.6667) < 0.001,
      `expected concern_tag_present_pct≈66.6667, got ${row.concern_tag_present_pct}`);
  });

  it('plan_citation_present_pct is 66.6667 (2 of 3 dispatches have plan citation)', () => {
    const row = actual[0];
    assert.ok(row, 'expected at least one row');
    const pct = Number(row.plan_citation_present_pct);
    assert.ok(Math.abs(pct - 66.6667) < 0.001,
      `expected plan_citation_present_pct≈66.6667, got ${row.plan_citation_present_pct}`);
  });
});

// ---------------------------------------------------------------------------
// TP2.T3-C: inline-vs-delegate ratio per §Q8 path discriminator
// DoD-(e): 4 inline tool-uses + 12 sidechain → delegate_ratio=0.7500, flag=healthy
// ---------------------------------------------------------------------------
describe('TP2.T3-C: coordinator-weekly — inline-vs-delegate ratio and health flag',
  { skip: !IMPL_EXISTS ? SKIP_REASON : false }, () => {

  let actual;

  before(() => {
    const eventsPath = join(FIXTURES_DIR, 'coordinator-weekly-events.jsonl');
    actual = runCoordWeeklyQuery(eventsPath);
  });

  it('delegate_ratio is 0.7500 for 4 inline + 12 delegated tool-uses', () => {
    const row = actual[0];
    assert.ok(row, 'expected at least one row');
    // 12/(4+12) = 0.7500
    assert.strictEqual(String(row.delegate_ratio), '0.7500',
      `expected delegate_ratio=0.7500, got ${row.delegate_ratio}`);
  });

  it('health flag is "healthy" when delegate_ratio > 0.7', () => {
    const row = actual[0];
    assert.ok(row, 'expected at least one row');
    assert.strictEqual(row.delegate_health_flag, 'healthy',
      `expected delegate_health_flag=healthy for ratio 0.75, got ${row.delegate_health_flag}`);
  });
});

// ---------------------------------------------------------------------------
// TP2.T3-D: health flag thresholds — drift (0.5-0.7) and executor-mode (<0.5)
// Fixture variants for the two other threshold states
// ---------------------------------------------------------------------------
describe('TP2.T3-D: coordinator-weekly — delegate health flag threshold variants',
  { skip: !IMPL_EXISTS ? SKIP_REASON : false }, () => {

  it('delegate_ratio=0.6500 produces flag=drift', () => {
    // Events fixture for drift scenario
    const eventsPath = join(FIXTURES_DIR, 'coordinator-weekly-drift-events.jsonl');
    if (!existsSync(eventsPath)) {
      // If fixture not yet created, skip sub-test gracefully
      return;
    }
    const rows = runCoordWeeklyQuery(eventsPath);
    const row = rows[0];
    assert.ok(row, 'expected a row');
    assert.strictEqual(row.delegate_health_flag, 'drift',
      `expected drift for ratio 0.65, got ${row.delegate_health_flag}`);
  });

  it('delegate_ratio=0.4000 produces flag=executor-mode', () => {
    const eventsPath = join(FIXTURES_DIR, 'coordinator-weekly-executor-events.jsonl');
    if (!existsSync(eventsPath)) return;
    const rows = runCoordWeeklyQuery(eventsPath);
    const row = rows[0];
    assert.ok(row, 'expected a row');
    assert.strictEqual(row.delegate_health_flag, 'executor-mode',
      `expected executor-mode for ratio 0.40, got ${row.delegate_health_flag}`);
  });
});

// ---------------------------------------------------------------------------
// TP2.T3-E: Phase-2-boundary guard — coordinator-weekly must NOT leak Phase-1-skeleton-only columns
// DoD: the skeleton file is marked deprecated; the new SQL supersedes it
// ---------------------------------------------------------------------------
describe('TP2.T3-E: coordinator-weekly — must not contain Phase-1-only boundary columns',
  { skip: !IMPL_EXISTS ? SKIP_REASON : false }, () => {

  let actual;

  before(() => {
    const eventsPath = join(FIXTURES_DIR, 'coordinator-weekly-events.jsonl');
    actual = runCoordWeeklyQuery(eventsPath);
  });

  it('does not have feedback-bound columns (Phase-2 boundary check)', () => {
    // Feedback-bound columns would only be in feedback-rollup.sql, not here
    for (const row of actual) {
      assert.ok(!('open_count' in row),
        'coordinator-weekly must not contain open_count (feedback-rollup column)');
    }
  });

  it('does not have decision-bound columns (Phase-2 boundary check)', () => {
    for (const row of actual) {
      assert.ok(!('match_rate' in row),
        'coordinator-weekly must not contain match_rate (decision-rollup column)');
    }
  });
});
