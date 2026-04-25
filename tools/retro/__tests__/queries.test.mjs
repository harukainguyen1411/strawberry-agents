/**
 * TP1.T5 — xfail unit suite: DuckDB query golden-file diff
 *
 * guards T.P1.3 DoD + T.P1.4 DoD (c)
 * Plan-Ref: plans/approved/personal/2026-04-25-retrospection-dashboard-and-canonical-v1.md
 *
 * xfail: skipped until render.mjs (T.P1.4) exists.
 * TODO (T.P1.4): implement render.mjs then flip skip guard.
 *
 * Phase-2 boundary guard (DoD-d): asserts coordinator-weekly-skeleton.expected.json
 * does NOT contain feedback-bound or decision-bound columns.
 */

import { describe, it, before } from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, readFileSync, mkdtempSync, mkdirSync, copyFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { execSync } from 'node:child_process';
import { tmpdir } from 'node:os';
import { styleText } from 'node:util';

const __dirname = dirname(fileURLToPath(import.meta.url));
const RETRO_ROOT = join(__dirname, '..');
const RENDER_PATH = join(RETRO_ROOT, 'render.mjs');
const FIXTURES_DIR = join(RETRO_ROOT, 'fixtures');
const QUERIES_DIR = join(RETRO_ROOT, 'queries');

const IMPL_EXISTS = existsSync(RENDER_PATH);
const SKIP_REASON = 'xfail: render.mjs not yet implemented (TODO T.P1.4)';

// Phase-2 column names that must NOT appear in Phase-1 query outputs
const PHASE2_FORBIDDEN_COLUMNS = [
  'open_feedback_count',
  'feedback_count',
  'decision_match_rate',
  'coordinator_confidence',
  'decision_id',
  'prediction_correct',
];

/**
 * Deep-equal diff: compare two JSON objects/arrays key-sorted.
 * Returns null if equal, or a human-readable diff string.
 */
function jsonDiff(actual, expected) {
  const a = JSON.stringify(sortDeep(actual), null, 2);
  const e = JSON.stringify(sortDeep(expected), null, 2);
  if (a === e) return null;
  return `\nExpected:\n${e}\n\nActual:\n${a}`;
}

function sortDeep(obj) {
  if (Array.isArray(obj)) return obj.map(sortDeep);
  if (obj !== null && typeof obj === 'object') {
    return Object.fromEntries(
      Object.entries(obj)
        .sort(([a], [b]) => a.localeCompare(b))
        .map(([k, v]) => [k, sortDeep(v)])
    );
  }
  return obj;
}

function runRender(eventsPath, distDir) {
  execSync(
    `node ${RENDER_PATH} --events ${eventsPath} --queries-dir ${QUERIES_DIR} --out-dir ${distDir}`,
    { cwd: RETRO_ROOT, stdio: 'pipe' }
  );
}

describe('TP1.T5: DuckDB query output matches paired .expected.json (key-sorted deep-equal)', { skip: !IMPL_EXISTS ? SKIP_REASON : false }, () => {
  let distDir;
  const tmp = mkdtempSync(join(tmpdir(), 'retro-t5-'));

  before(() => {
    distDir = join(tmp, 'dist', 'data');
    mkdirSync(distDir, { recursive: true });
    // Use the pre-built expected-events.jsonl as the events input
    const eventsPath = join(FIXTURES_DIR, 'expected-events.jsonl');
    runRender(eventsPath, distDir);
  });

  it('plan-rollup.json matches plan-rollup.expected.json (deep-equal, key-sorted)', () => {
    const actualPath = join(distDir, 'plan-rollup.json');
    assert.ok(existsSync(actualPath), 'plan-rollup.json must be emitted by render.mjs');
    const actual = JSON.parse(readFileSync(actualPath, 'utf8'));
    const expected = JSON.parse(readFileSync(join(QUERIES_DIR, 'plan-rollup.expected.json'), 'utf8'));
    const diff = jsonDiff(actual, expected);
    assert.ok(diff === null, `plan-rollup.json does not match expected:\n${diff}`);
  });

  it('coordinator-weekly-skeleton.json matches coordinator-weekly-skeleton.expected.json', () => {
    const actualPath = join(distDir, 'coordinator-weekly-skeleton.json');
    assert.ok(existsSync(actualPath), 'coordinator-weekly-skeleton.json must be emitted');
    const actual = JSON.parse(readFileSync(actualPath, 'utf8'));
    const expected = JSON.parse(readFileSync(join(QUERIES_DIR, 'coordinator-weekly-skeleton.expected.json'), 'utf8'));
    const diff = jsonDiff(actual, expected);
    assert.ok(diff === null, `coordinator-weekly-skeleton.json does not match expected:\n${diff}`);
  });

  it('[Phase-2 boundary] coordinator-weekly-skeleton.expected.json must NOT contain Phase-2 columns', () => {
    const expected = JSON.parse(readFileSync(join(QUERIES_DIR, 'coordinator-weekly-skeleton.expected.json'), 'utf8'));
    const rows = Array.isArray(expected) ? expected : [expected];
    for (const row of rows) {
      for (const forbidden of PHASE2_FORBIDDEN_COLUMNS) {
        assert.ok(!(forbidden in row),
          `Phase-2 column "${forbidden}" must not appear in Phase-1 coordinator-weekly-skeleton output. ` +
          `This prevents Phase-2 schema leaking into Phase-1. Found in row: ${JSON.stringify(row)}`);
      }
    }
  });

  it('[Phase-2 boundary] coordinator-weekly-skeleton.sql must NOT reference Phase-2 column names', () => {
    const sqlContent = readFileSync(join(QUERIES_DIR, 'coordinator-weekly-skeleton.sql'), 'utf8');
    for (const forbidden of PHASE2_FORBIDDEN_COLUMNS) {
      assert.ok(!sqlContent.includes(forbidden),
        `Phase-2 column "${forbidden}" must not appear in Phase-1 SQL file. Found in coordinator-weekly-skeleton.sql`);
    }
  });

  it('failure message includes a readable unified diff', () => {
    // This meta-test verifies the diff function itself produces useful output
    const a = [{ plan_slug: 'x', tokens_input: 100 }];
    const b = [{ plan_slug: 'x', tokens_input: 200 }];
    const diff = jsonDiff(a, b);
    assert.ok(diff !== null, 'jsonDiff must return non-null for differing inputs');
    assert.ok(diff.includes('100') && diff.includes('200'), 'diff output must contain the differing values');
  });
});
