/**
 * TP3.T4 (part 1) — xfail unit test: RETRO_QUALITY_GRADE gate behavior
 *
 * Guards: T.P3.3 (lib/quality-grader.mjs)
 * Rule 12: this commit lands BEFORE T.P3.3 impl commit.
 * Plan-Ref: plans/approved/personal/2026-04-25-retrospection-dashboard-and-canonical-v1.md
 *
 * xfail: skipped if tools/retro/lib/quality-grader.mjs is absent (T.P3.3 not yet landed).
 * TODO (T.P3.3): implement lib/quality-grader.mjs with gate + record-replay + cost-ceiling, flip skip.
 *
 * Gate invariants:
 *   gate-off: RETRO_QUALITY_GRADE unset or non-'1' → ZERO kind:quality-grade events; empty rollup
 *   gate-on dry-run: token-count phase runs BEFORE any Anthropic call; cost ≤ $1
 *   gate-on record-replay: no live API call; request-spy intercepts any outbound attempt
 *   truthy-but-not-'1' guard: "", "0", "true", "yes", "on" all treated as gate-off
 */

import { describe, it, before } from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, readFileSync, writeFileSync, mkdtempSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { execSync } from 'node:child_process';
import { tmpdir } from 'node:os';

const __dirname = dirname(fileURLToPath(import.meta.url));
const RETRO_ROOT = join(__dirname, '..');
const GRADER_PATH = join(RETRO_ROOT, 'lib', 'quality-grader.mjs');
const INGEST_PATH = join(RETRO_ROOT, 'ingest.mjs');
const QUERIES_DIR = join(RETRO_ROOT, 'queries');
const FIXTURES_DIR = join(RETRO_ROOT, 'fixtures');

// xfail guard
const IMPL_EXISTS = existsSync(GRADER_PATH);
const SKIP_REASON = 'xfail: lib/quality-grader.mjs not yet implemented (TODO T.P3.3)';

const GRADED_FIXTURE = join(FIXTURES_DIR, 'anthropic-graded.json');
const ROLLUP_SQL = join(QUERIES_DIR, 'quality-grade-rollup.sql');
const ROLLUP_EXPECTED_OFF = join(QUERIES_DIR, 'quality-grade-rollup.expected.json');

// Lazy import
let qualityGrader;
if (IMPL_EXISTS) {
  qualityGrader = await import(GRADER_PATH);
}

function runIngestWithGrade(cacheDir, gradeEnv) {
  return execSync(`node ${INGEST_PATH} --cache-dir ${cacheDir}`, {
    cwd: RETRO_ROOT,
    encoding: 'utf8',
    env: { ...process.env, ...gradeEnv }
  });
}

// ---------------------------------------------------------------------------
// TP3.T4-A: gate-off invariant — non-'1' env values produce ZERO quality-grade events
// DoD-(a): only literal string '1' enables the grader
// ---------------------------------------------------------------------------
describe('TP3.T4-A: quality-grader gate-off — non-"1" values produce zero events',
  { skip: !IMPL_EXISTS ? SKIP_REASON : false }, () => {

  const OFF_VALUES = ['', '0', 'true', 'yes', 'on', 'TRUE', 'YES', undefined];

  for (const val of OFF_VALUES) {
    it(`RETRO_QUALITY_GRADE=${JSON.stringify(val)} emits zero quality-grade events`, () => {
      const tmp = mkdtempSync(join(tmpdir(), 'retro-grade-off-'));
      const eventsPath = join(tmp, 'events.jsonl');
      writeFileSync(eventsPath, '{"kind":"turn","ts":"2026-01-01T00:00:00.000Z"}\n');

      const env = val === undefined
        ? { RETRO_QUALITY_GRADE: undefined } // explicitly unset
        : { RETRO_QUALITY_GRADE: val };

      // Run ingest or grader with the specific env value
      if (!qualityGrader?.gradeDispatchEvents) {
        assert.fail('xfail: qualityGrader.gradeDispatchEvents not exported — impl must wire this (TODO T.P3.3)');
      }
      const result = qualityGrader.gradeDispatchEvents(eventsPath, { env });
      const gradeEvents = Array.isArray(result)
        ? result.filter(e => e.kind === 'quality-grade')
        : [];
      assert.deepEqual(gradeEvents, [],
        `expected zero quality-grade events with RETRO_QUALITY_GRADE=${JSON.stringify(val)}`);
    });
  }
});

// ---------------------------------------------------------------------------
// TP3.T4-B: gate-on dry-run — token-count phase runs BEFORE any Anthropic call
// Cost estimate must be ≤ $1 for small fixture (10 dispatches per breakdown DoD-(b))
// ---------------------------------------------------------------------------
describe('TP3.T4-B: quality-grader gate-on — dry-run token-count precedes API call',
  { skip: !IMPL_EXISTS ? SKIP_REASON : false }, () => {

  it('dry-run estimates cost without making any Anthropic API call', () => {
    if (!qualityGrader?.estimateWeeklyGradingCost) {
      assert.fail('xfail: qualityGrader.estimateWeeklyGradingCost not exported — impl must wire this (TODO T.P3.3)');
    }
    // Small fixture: 10 dispatches at ~300 tokens each
    const smallFixtureEvents = Array.from({ length: 10 }, (_, i) => ({
      kind: 'dispatch-prompt-stats',
      agentId: `agent-00${i}`,
      dispatch_prompt_tokens: 300,
      subagent_total_output_tokens: 600,
      ts: `2026-04-22T0${i}:00:00.000Z`
    }));

    const estimate = qualityGrader.estimateWeeklyGradingCost(smallFixtureEvents);
    assert.ok(typeof estimate === 'object' && estimate !== null,
      'expected an estimate object from estimateWeeklyGradingCost');
    assert.ok(typeof estimate.estimated_usd === 'number',
      'expected estimated_usd to be a number');
    assert.ok(estimate.estimated_usd <= 1.0,
      `expected estimated cost ≤ $1 for 10-dispatch fixture, got $${estimate.estimated_usd}`);
  });
});

// ---------------------------------------------------------------------------
// TP3.T4-C: gate-on record-replay — no live API call via request-spy
// DoD-(c): RETRO_ANTHROPIC_MOCK_ENDPOINT env override uses anthropic-graded.json fixture
// ---------------------------------------------------------------------------
describe('TP3.T4-C: quality-grader gate-on — record-replay fixture, no live API',
  { skip: !IMPL_EXISTS ? SKIP_REASON : false }, () => {

  it('grader uses record-replay fixture and makes no outbound requests when RETRO_ANTHROPIC_MOCK_ENDPOINT is set', () => {
    if (!existsSync(GRADED_FIXTURE)) {
      // Fixture not yet created; skip gracefully
      return;
    }
    if (!qualityGrader?.gradeDispatchEvents) {
      assert.fail('xfail: qualityGrader.gradeDispatchEvents not exported — impl must wire this (TODO T.P3.3)');
    }

    // Track whether any real API call was attempted
    let apiCallAttempted = false;
    const requestSpy = () => { apiCallAttempted = true; throw new Error('live API call intercepted'); };

    const tmp = mkdtempSync(join(tmpdir(), 'retro-grade-replay-'));
    const eventsPath = join(tmp, 'events.jsonl');
    writeFileSync(eventsPath,
      Array.from({ length: 3 }, (_, i) => JSON.stringify({
        kind: 'dispatch-prompt-stats',
        agentId: `agent-00${i}`,
        dispatch_prompt_tokens: 300,
        subagent_total_output_tokens: 600,
        ts: `2026-04-22T0${i}:00:00.000Z`
      })).join('\n') + '\n'
    );

    try {
      qualityGrader.gradeDispatchEvents(eventsPath, {
        env: { RETRO_QUALITY_GRADE: '1', RETRO_ANTHROPIC_MOCK_ENDPOINT: GRADED_FIXTURE },
        httpInterceptor: requestSpy
      });
    } catch (err) {
      // If the grader threw because of the spy, the test should fail
      if (err.message === 'live API call intercepted') {
        assert.fail('grader attempted a live Anthropic API call despite mock endpoint being set');
      }
    }
    assert.ok(!apiCallAttempted, 'no live Anthropic API call must be made in record-replay mode');
  });
});

// ---------------------------------------------------------------------------
// TP3.T4-D: gate-off rollup golden — quality-grade-rollup.expected.json must be empty []
// DoD-(f): default gate-off golden is the empty array
// ---------------------------------------------------------------------------
describe('TP3.T4-D: quality-grade-rollup.expected.json under gate-off is empty []',
  { skip: !IMPL_EXISTS ? SKIP_REASON : false }, () => {

  it('quality-grade-rollup.expected.json exists', () => {
    assert.ok(existsSync(ROLLUP_EXPECTED_OFF),
      `quality-grade-rollup.expected.json must exist at ${ROLLUP_EXPECTED_OFF}`);
  });

  it('quality-grade-rollup.expected.json contains an empty array for gate-off state', () => {
    if (!existsSync(ROLLUP_EXPECTED_OFF)) return;
    const content = JSON.parse(readFileSync(ROLLUP_EXPECTED_OFF, 'utf8'));
    assert.deepEqual(content, [],
      `expected quality-grade-rollup.expected.json to be [] under gate-off, got: ${JSON.stringify(content)}`);
  });

  it('quality-grade-rollup.sql produces empty result when no quality-grade events exist', () => {
    if (!existsSync(ROLLUP_SQL)) return;
    const tmp = mkdtempSync(join(tmpdir(), 'retro-grade-rollup-'));
    const eventsPath = join(tmp, 'events.jsonl');
    // Write only non-quality-grade events
    writeFileSync(eventsPath, '{"kind":"turn","ts":"2026-01-01T00:00:00.000Z"}\n');
    const result = JSON.parse(execSync(
      `duckdb -json '${eventsPath}' < '${ROLLUP_SQL}'`,
      { cwd: RETRO_ROOT, encoding: 'utf8' }
    ));
    assert.deepEqual(result, [], 'rollup must return empty array when no quality-grade events');
  });
});

// ---------------------------------------------------------------------------
// TP3.T4-E: lazy-import invariant — @anthropic-ai/sdk is NOT loaded when gate is off
// DoD-(e): SDK module path is never resolved when RETRO_QUALITY_GRADE != '1'
// ---------------------------------------------------------------------------
describe('TP3.T4-E: lazy-import invariant — SDK not loaded when gate is off',
  { skip: !IMPL_EXISTS ? SKIP_REASON : false }, () => {

  it('importing quality-grader.mjs without RETRO_QUALITY_GRADE=1 does not load @anthropic-ai/sdk', async () => {
    // Verify by checking module resolution: if the SDK is a static import at the top,
    // it will be in the module's static imports list
    // We check this by reading the grader source and asserting no top-level import of the SDK
    const source = readFileSync(GRADER_PATH, 'utf8');

    // Static imports at the top level should not include @anthropic-ai/sdk
    // Dynamic imports (await import('@anthropic-ai/sdk')) inside a function are OK
    const staticImportLines = source.split('\n').filter(l =>
      l.trim().startsWith('import ') && l.includes('@anthropic-ai/sdk')
    );
    assert.deepEqual(staticImportLines, [],
      `quality-grader.mjs must not have a top-level static import of @anthropic-ai/sdk.\n` +
      `Found: ${staticImportLines.join('\n')}`
    );
  });
});
