/**
 * TP1.T2 — xfail invariant test: token cost byte-deterministic rollup
 *
 * guards T.P1.2 DoD (b) + T.P1.4 DoD (c) (cross-task invariant)
 * Plan-Ref: plans/approved/personal/2026-04-25-retrospection-dashboard-and-canonical-v1.md
 *
 * xfail: skipped until ingest.mjs + render.mjs (with DuckDB runner) both exist.
 * TODO (T.P1.2 + T.P1.4): implement then flip skip guard.
 */

import { describe, it, before } from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, readFileSync, mkdtempSync, mkdirSync, copyFileSync, writeFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { execSync } from 'node:child_process';
import { tmpdir } from 'node:os';
import { createHash } from 'node:crypto';

const __dirname = dirname(fileURLToPath(import.meta.url));
const RETRO_ROOT = join(__dirname, '..');
const INGEST_PATH = join(RETRO_ROOT, 'ingest.mjs');
const RENDER_PATH = join(RETRO_ROOT, 'render.mjs');
const FIXTURES_DIR = join(RETRO_ROOT, 'fixtures');
const QUERIES_DIR = join(RETRO_ROOT, 'queries');

// xfail guard — both ingest.mjs AND render.mjs must exist
const INGEST_EXISTS = existsSync(INGEST_PATH);
const RENDER_EXISTS = existsSync(RENDER_PATH);
const IMPL_EXISTS = INGEST_EXISTS && RENDER_EXISTS;
const SKIP_REASON = 'xfail: ingest.mjs and/or render.mjs not yet implemented (TODO T.P1.2 + T.P1.4)';

// Known-answer totals from known-token-counts.jsonl fixture:
// 3 turns × {input:100, output:200, cache_read:50, cache_creation:25}
const EXPECTED_TOKENS = {
  tokens_input: 300,
  tokens_output: 600,
  tokens_cache_read: 150,
  tokens_cache_creation: 75,
};

function runPipeline(tmp) {
  const sessDir = join(tmp, 'projects', 'strawberry-agents', 'sess-token-test');
  mkdirSync(sessDir, { recursive: true });
  copyFileSync(join(FIXTURES_DIR, 'known-token-counts.jsonl'), join(sessDir, 'sess-token-test.jsonl'));

  const eventsPath = join(tmp, 'events.jsonl');
  execSync(`node ${INGEST_PATH} --cache-dir ${tmp}`, { cwd: RETRO_ROOT, stdio: 'pipe' });

  const distDir = join(tmp, 'dist', 'data');
  mkdirSync(distDir, { recursive: true });
  execSync(`node ${RENDER_PATH} --events ${eventsPath} --queries-dir ${QUERIES_DIR} --out-dir ${distDir}`, {
    cwd: RETRO_ROOT,
    stdio: 'pipe',
  });

  return { eventsPath, distDir };
}

describe('TP1.T2: token cost byte-deterministic rollup', { skip: !IMPL_EXISTS ? SKIP_REASON : false }, () => {
  let result1;
  let result2;

  before(() => {
    const tmp1 = mkdtempSync(join(tmpdir(), 'retro-t2a-'));
    const tmp2 = mkdtempSync(join(tmpdir(), 'retro-t2b-'));
    result1 = runPipeline(tmp1);
    result2 = runPipeline(tmp2);
  });

  it('plan-rollup token columns equal the hand-summed totals exactly (integer compare)', () => {
    const rollupPath = join(result1.distDir, 'plan-rollup.json');
    assert.ok(existsSync(rollupPath), 'plan-rollup.json must exist after render');
    const rows = JSON.parse(readFileSync(rollupPath, 'utf8'));

    const planRow = rows.find(r =>
      r.plan_slug === '2026-04-25-retrospection-dashboard-and-canonical-v1'
    );
    assert.ok(planRow, 'plan-rollup must contain a row for the token-cost fixture plan');

    assert.strictEqual(planRow.tokens_input, EXPECTED_TOKENS.tokens_input,
      `tokens_input: expected ${EXPECTED_TOKENS.tokens_input}, got ${planRow.tokens_input}`);
    assert.strictEqual(planRow.tokens_output, EXPECTED_TOKENS.tokens_output,
      `tokens_output: expected ${EXPECTED_TOKENS.tokens_output}, got ${planRow.tokens_output}`);
    assert.strictEqual(planRow.tokens_cache_read, EXPECTED_TOKENS.tokens_cache_read,
      `tokens_cache_read: expected ${EXPECTED_TOKENS.tokens_cache_read}, got ${planRow.tokens_cache_read}`);
    assert.strictEqual(planRow.tokens_cache_creation, EXPECTED_TOKENS.tokens_cache_creation,
      `tokens_cache_creation: expected ${EXPECTED_TOKENS.tokens_cache_creation}, got ${planRow.tokens_cache_creation}`);
  });

  it('token columns are integers (no float arithmetic drift)', () => {
    const rows = JSON.parse(readFileSync(join(result1.distDir, 'plan-rollup.json'), 'utf8'));
    const planRow = rows.find(r => r.plan_slug === '2026-04-25-retrospection-dashboard-and-canonical-v1');
    assert.ok(planRow, 'plan row must exist');
    for (const col of ['tokens_input', 'tokens_output', 'tokens_cache_read', 'tokens_cache_creation']) {
      assert.ok(Number.isInteger(planRow[col]),
        `${col} must be an integer, got ${typeof planRow[col]} value ${planRow[col]}`);
    }
  });

  it('running the same fixture twice produces byte-identical events.jsonl', () => {
    const hash1 = createHash('sha256')
      .update(readFileSync(result1.eventsPath))
      .digest('hex');
    const hash2 = createHash('sha256')
      .update(readFileSync(result2.eventsPath))
      .digest('hex');
    assert.equal(hash1, hash2, 'events.jsonl must be byte-identical across two runs on the same fixture');
  });
});
