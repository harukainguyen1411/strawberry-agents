/**
 * TP2.T3 (part 2) — xfail unit test: prompt-stats computation invariants
 *
 * Guards: T.P2.4 (lib/prompt-stats.mjs)
 * Rule 12: this commit lands BEFORE T.P2.4 impl commit.
 * Plan-Ref: plans/approved/personal/2026-04-25-retrospection-dashboard-and-canonical-v1.md
 *
 * xfail: skipped if tools/retro/lib/prompt-stats.mjs is absent (T.P2.4 not yet landed).
 * TODO (T.P2.4): implement lib/prompt-stats.mjs, then flip skip.
 *
 * Invariants:
 *   - compression_ratio: subagent_total_output_tokens / dispatch_prompt_tokens
 *   - plan-citation regex pinned to plans/(proposed|approved|in-progress|implemented|archived)/(personal|work)/.+\.md
 *   - concern-tag regex: [concern: ...] bracket presence
 *   - header-count: count of ^## lines in dispatch prompt
 *   - p50/p95 derived from per-dispatch distribution (not session-level aggregate)
 */

import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { existsSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const RETRO_ROOT = join(__dirname, '..');
const STATS_PATH = join(RETRO_ROOT, 'lib', 'prompt-stats.mjs');

// xfail guard — lib/prompt-stats.mjs does not exist yet (T.P2.4 lands it)
const IMPL_EXISTS = existsSync(STATS_PATH);
const SKIP_REASON = 'xfail: lib/prompt-stats.mjs not yet implemented (TODO T.P2.4)';

// Lazy import
let computePromptStats;
let extractPromptSignals;
if (IMPL_EXISTS) {
  const mod = await import(STATS_PATH);
  computePromptStats = mod.computePromptStats ?? mod.default;
  extractPromptSignals = mod.extractPromptSignals;
}

// ---------------------------------------------------------------------------
// TP2.T3-F: compression ratio invariant — subagent_output_tokens / dispatch_prompt_tokens
// DoD-(d): dispatch B emits 800 subagent output tokens against 300 prompt tokens → ratio 2.6667
// ---------------------------------------------------------------------------
describe('TP2.T3-F: prompt-stats — compression ratio computation',
  { skip: !IMPL_EXISTS ? SKIP_REASON : false }, () => {

  it('compression_ratio = subagent_output_tokens / dispatch_prompt_tokens', () => {
    const stats = computePromptStats({
      dispatch_prompt_text: 'x'.repeat(300), // 300 chars as proxy for prompt tokens
      dispatch_prompt_tokens: 300,
      subagent_total_output_tokens: 800
    });
    const ratio = Number(stats.compression_ratio);
    // 800/300 = 2.6667
    assert.ok(Math.abs(ratio - 2.6667) < 0.001,
      `expected compression_ratio≈2.6667 (800/300), got ${stats.compression_ratio}`);
  });
});

// ---------------------------------------------------------------------------
// TP2.T3-G: regex-pin invariant — plan-citation regex must match valid paths and reject invalid ones
// DoD-(f): plans/(proposed|approved|in-progress|implemented|archived)/(personal|work)/.+\.md
// ---------------------------------------------------------------------------
describe('TP2.T3-G: prompt-stats — plan-citation regex is pinned and correct',
  { skip: !IMPL_EXISTS ? SKIP_REASON : false }, () => {

  it('matches valid in-progress personal plan path', () => {
    const signals = extractPromptSignals(
      'Please work on plans/in-progress/personal/2026-04-25-foo.md for context'
    );
    assert.strictEqual(signals.plan_citation_present, true,
      'should detect valid in-progress plan citation');
  });

  it('matches valid approved work plan path', () => {
    const signals = extractPromptSignals(
      'Reference: plans/approved/work/2026-04-20-bar.md'
    );
    assert.strictEqual(signals.plan_citation_present, true,
      'should detect valid approved work plan citation');
  });

  it('rejects plans/foo.md (no stage subdir)', () => {
    const signals = extractPromptSignals('See plans/foo.md for details');
    assert.strictEqual(signals.plan_citation_present, false,
      'should not match plans/foo.md (no stage subdir)');
  });

  it('rejects plans/proposed/foo.md (no concern subdir)', () => {
    const signals = extractPromptSignals('See plans/proposed/foo.md');
    assert.strictEqual(signals.plan_citation_present, false,
      'should not match plans/proposed/foo.md (no concern subdir)');
  });
});

// ---------------------------------------------------------------------------
// TP2.T3-H: concern-tag detection — [concern: personal] or [concern: work]
// ---------------------------------------------------------------------------
describe('TP2.T3-H: prompt-stats — concern-tag presence detection',
  { skip: !IMPL_EXISTS ? SKIP_REASON : false }, () => {

  it('detects [concern: personal]', () => {
    const signals = extractPromptSignals('[concern: personal] do the thing');
    assert.strictEqual(signals.concern_tag_present, true);
  });

  it('detects [concern: work]', () => {
    const signals = extractPromptSignals('[concern: work] check the plan');
    assert.strictEqual(signals.concern_tag_present, true);
  });

  it('rejects prompt without concern tag', () => {
    const signals = extractPromptSignals('Do the thing without any tag');
    assert.strictEqual(signals.concern_tag_present, false);
  });
});

// ---------------------------------------------------------------------------
// TP2.T3-I: header-count — count of ^## lines in dispatch prompt
// ---------------------------------------------------------------------------
describe('TP2.T3-I: prompt-stats — header count (^## lines)',
  { skip: !IMPL_EXISTS ? SKIP_REASON : false }, () => {

  it('counts 4 ## headers in dispatch B fixture', () => {
    const prompt = [
      '## Context', 'intro text',
      '## Scope', 'some scope',
      '## Tasks', 'task list',
      '## Notes', 'extra notes'
    ].join('\n');
    const signals = extractPromptSignals(prompt);
    assert.strictEqual(signals.header_count, 4,
      `expected 4 ## headers, got ${signals.header_count}`);
  });

  it('counts 0 headers in plain text prompt', () => {
    const signals = extractPromptSignals('Just do the thing, no structure here');
    assert.strictEqual(signals.header_count, 0);
  });
});

// ---------------------------------------------------------------------------
// TP2.T3-J: p50/p95 are per-dispatch aggregations, NOT pre-aggregated session values
// DoD-(d) clarification: weekly percentiles are SQL aggregations over per-dispatch events
// This tests that computePromptStats emits one event per dispatch (not a session aggregate)
// ---------------------------------------------------------------------------
describe('TP2.T3-J: prompt-stats — emits per-dispatch events (p50/p95 computed in SQL, not pre-agg)',
  { skip: !IMPL_EXISTS ? SKIP_REASON : false }, () => {

  it('computePromptStats returns a single event record (not a percentile object)', () => {
    const stats = computePromptStats({
      dispatch_prompt_text: '[concern: personal] ## Task\nDo the thing',
      dispatch_prompt_tokens: 150,
      subagent_total_output_tokens: 300
    });
    // Must be a single event, not an object with p50/p95 keys
    assert.ok(!('p50' in stats), 'computePromptStats must not emit p50 (that is SQL responsibility)');
    assert.ok(!('p95' in stats), 'computePromptStats must not emit p95 (that is SQL responsibility)');
    // Must have the per-dispatch fields
    assert.ok('compression_ratio' in stats, 'expected compression_ratio field');
    assert.ok('header_count' in stats || 'header_count_raw' in stats,
      'expected header_count or header_count_raw field');
  });
});
