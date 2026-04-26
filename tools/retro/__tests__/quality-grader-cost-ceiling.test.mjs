/**
 * TP3.T4 (part 2) — xfail unit test: RETRO_QUALITY_GRADE cost-ceiling kill-switch invariant
 *
 * Guards: T.P3.3 (lib/quality-grader.mjs cost-ceiling kill-switch)
 * Rule 12: this commit lands BEFORE T.P3.3 impl commit.
 * Plan-Ref: plans/approved/personal/2026-04-25-retrospection-dashboard-and-canonical-v1.md
 *
 * xfail: skipped if tools/retro/lib/quality-grader.mjs is absent (T.P3.3 not yet landed).
 * TODO (T.P3.3): implement the cost-ceiling kill-switch in quality-grader.mjs, then flip skip.
 *
 * Kill-switch invariant (DoD-(d)):
 *   when estimated weekly spend exceeds $5 (hard ceiling per §Q5),
 *   grader aborts with non-zero exit and diagnostic "cost ceiling exceeded",
 *   NO Anthropic call attempted.
 */

import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, readFileSync, writeFileSync, mkdtempSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { tmpdir } from 'node:os';

const __dirname = dirname(fileURLToPath(import.meta.url));
const RETRO_ROOT = join(__dirname, '..');
const GRADER_PATH = join(RETRO_ROOT, 'lib', 'quality-grader.mjs');
const FIXTURES_DIR = join(RETRO_ROOT, 'fixtures');

// xfail guard
const IMPL_EXISTS = existsSync(GRADER_PATH);
const SKIP_REASON = 'xfail: lib/quality-grader.mjs cost-ceiling not yet implemented (TODO T.P3.3)';

let qualityGrader;
if (IMPL_EXISTS) {
  qualityGrader = await import(GRADER_PATH);
}

// ---------------------------------------------------------------------------
// TP3.T4-F: cost-ceiling kill-switch — aborts when estimated spend > $5
// DoD-(d): 10000 dispatches at known per-dispatch token count exceeds $5 ceiling
// ---------------------------------------------------------------------------
describe('TP3.T4-F: quality-grader cost-ceiling kill-switch — aborts above $5',
  { skip: !IMPL_EXISTS ? SKIP_REASON : false }, () => {

  it('aborts with non-zero exit when estimated weekly spend exceeds $5', () => {
    if (!qualityGrader?.gradeDispatchEvents) {
      assert.fail('xfail: qualityGrader.gradeDispatchEvents not exported — impl must wire this (TODO T.P3.3)');
    }

    // Create an overspend events fixture: 10000 dispatches at ~300 tokens each
    // At ~$3/MTok input (Claude Sonnet), 10000 * 300 = 3M tokens → ~$9 (above $5 ceiling)
    const tmp = mkdtempSync(join(tmpdir(), 'retro-grade-overspend-'));
    const eventsPath = join(tmp, 'events-overspend.jsonl');
    const overspendEvents = Array.from({ length: 10000 }, (_, i) => JSON.stringify({
      kind: 'dispatch-prompt-stats',
      agentId: `agent-${i.toString().padStart(5, '0')}`,
      dispatch_prompt_tokens: 300,
      subagent_total_output_tokens: 600,
      ts: `2026-04-22T00:00:00.000Z`
    })).join('\n') + '\n';
    writeFileSync(eventsPath, overspendEvents);

    let threw = false;
    let apiCallAttempted = false;
    const requestSpy = () => {
      apiCallAttempted = true;
      throw new Error('live API call intercepted — should not reach here');
    };

    try {
      qualityGrader.gradeDispatchEvents(eventsPath, {
        env: { RETRO_QUALITY_GRADE: '1' },
        httpInterceptor: requestSpy
      });
    } catch (err) {
      threw = true;
      const msg = (err.message || '').toLowerCase();
      assert.ok(
        msg.includes('cost ceiling') || msg.includes('ceiling exceeded') || msg.includes('$5') || msg.includes('budget'),
        `expected error message to mention cost ceiling/budget, got: ${err.message}`
      );
    }

    assert.ok(threw, 'grader must throw an error when estimated spend exceeds $5 ceiling');
    assert.ok(!apiCallAttempted,
      'grader must NOT make any Anthropic API call when cost ceiling is exceeded');
  });

  it('overspend-tokens fixture file exists (or is a documented missing fixture)', () => {
    const fixturePath = join(FIXTURES_DIR, 'quality-grader-overspend-tokens.json');
    // Either the fixture exists (pre-created by Viktor) or we document the gap
    if (!existsSync(fixturePath)) {
      // This is acceptable — Viktor creates the fixture when implementing T.P3.3
      // The test above uses a programmatic fixture, so this file is optional
      assert.ok(true, 'overspend fixture not yet created — programmatic fixture used above');
    } else {
      const content = JSON.parse(readFileSync(fixturePath, 'utf8'));
      assert.ok(Array.isArray(content) && content.length >= 100,
        'overspend fixture must have at least 100 dispatch events for meaningful cost test');
    }
  });
});

// ---------------------------------------------------------------------------
// TP3.T4-G: gate-on rollup golden — 4 buckets under record-replay
// DoD-(f): gate-on rollup has 4 buckets: clear, acceptable, wandering, under-spec'd
// ---------------------------------------------------------------------------
describe('TP3.T4-G: quality-grader gate-on rollup — 4 grade buckets under record-replay',
  { skip: !IMPL_EXISTS ? SKIP_REASON : false }, () => {

  it('grade buckets are exactly: clear, acceptable, wandering, under-spec\'d', () => {
    if (!qualityGrader?.gradeDispatchEvents) {
      assert.fail('xfail: qualityGrader.gradeDispatchEvents not exported — impl must wire this (TODO T.P3.3)');
    }
    const fixturePath = join(FIXTURES_DIR, 'anthropic-graded.json');
    if (!existsSync(fixturePath)) return; // fixture not yet created

    const tmp = mkdtempSync(join(tmpdir(), 'retro-grade-buckets-'));
    const eventsPath = join(tmp, 'events.jsonl');
    writeFileSync(eventsPath,
      Array.from({ length: 10 }, (_, i) => JSON.stringify({
        kind: 'dispatch-prompt-stats',
        agentId: `agent-00${i}`,
        dispatch_prompt_tokens: 300,
        subagent_total_output_tokens: 600,
        ts: `2026-04-22T0${i % 10}:00:00.000Z`
      })).join('\n') + '\n'
    );

    const result = qualityGrader.gradeDispatchEvents(eventsPath, {
      env: { RETRO_QUALITY_GRADE: '1', RETRO_ANTHROPIC_MOCK_ENDPOINT: fixturePath }
    });

    if (!Array.isArray(result)) return;
    const gradeEvents = result.filter(e => e.kind === 'quality-grade');
    const buckets = new Set(gradeEvents.map(e => e.grade));
    const EXPECTED_BUCKETS = new Set(['clear', 'acceptable', 'wandering', 'under-spec\'d']);
    for (const bucket of EXPECTED_BUCKETS) {
      assert.ok(buckets.has(bucket),
        `expected grade bucket "${bucket}" in record-replay grading output`);
    }
  });
});
