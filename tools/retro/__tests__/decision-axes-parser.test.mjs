/**
 * TP2.T2 (part 2) — xfail unit test: decision-axes parser invariants
 *
 * Guards: T.P2.3 (lib/decision-axes.mjs parser)
 * Rule 12: this commit lands BEFORE T.P2.3 impl commit.
 * Plan-Ref: plans/approved/personal/2026-04-25-retrospection-dashboard-and-canonical-v1.md
 *
 * xfail: skipped if tools/retro/lib/decision-axes.mjs is absent (T.P2.3 not yet landed).
 * TODO (T.P2.3): implement lib/decision-axes.mjs, then flip skip.
 *
 * Invariants tested:
 *   - confidence mapping low/medium/high → 1/2/3 is total (no silent zero for unknown values)
 *   - axes field must be a non-empty array of strings (missing/empty fails with diagnostic)
 *   - duong_concurred_silently: true → derived match: true (plan B §3.1 line 136)
 */

import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { existsSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const RETRO_ROOT = join(__dirname, '..');
const PARSER_PATH = join(RETRO_ROOT, 'lib', 'decision-axes.mjs');

// xfail guard — lib/decision-axes.mjs does not exist yet (T.P2.3 lands it)
const IMPL_EXISTS = existsSync(PARSER_PATH);
const SKIP_REASON = 'xfail: lib/decision-axes.mjs not yet implemented (TODO T.P2.3)';

// Lazy import to avoid errors during xfail state
let parseDecisionFrontmatter;
before_lazy: {
  if (IMPL_EXISTS) {
    const mod = await import(PARSER_PATH);
    parseDecisionFrontmatter = mod.parseDecisionFrontmatter ?? mod.default;
  }
}

// ---------------------------------------------------------------------------
// TP2.T2-E: confidence mapping is total — unknown value raises typed error
// DoD-(b): any value other than low/medium/high raises typed error, NOT silent zero
// ---------------------------------------------------------------------------
describe('TP2.T2-E: decision-axes-parser — confidence mapping is total (no silent zero)',
  { skip: !IMPL_EXISTS ? SKIP_REASON : false }, () => {

  it('maps low → 1', () => {
    const result = parseDecisionFrontmatter({
      coordinator_confidence: 'low', axes: ['routing-track'], match: true, decision_id: 'd-001'
    });
    assert.strictEqual(result.confidence_score, 1, 'low must map to 1');
  });

  it('maps medium → 2', () => {
    const result = parseDecisionFrontmatter({
      coordinator_confidence: 'medium', axes: ['routing-track'], match: true, decision_id: 'd-002'
    });
    assert.strictEqual(result.confidence_score, 2, 'medium must map to 2');
  });

  it('maps high → 3', () => {
    const result = parseDecisionFrontmatter({
      coordinator_confidence: 'high', axes: ['routing-track'], match: true, decision_id: 'd-003'
    });
    assert.strictEqual(result.confidence_score, 3, 'high must map to 3');
  });

  it('raises a typed error for unknown confidence values (no silent zero)', () => {
    assert.throws(
      () => parseDecisionFrontmatter({
        coordinator_confidence: 'very-high', axes: ['routing-track'], match: true, decision_id: 'd-004'
      }),
      (err) => {
        assert.ok(err instanceof Error,
          'expected an Error to be thrown for unknown confidence value');
        assert.ok(err.message.toLowerCase().includes('confidence') || err.message.toLowerCase().includes('invalid'),
          `expected error message to mention confidence, got: ${err.message}`);
        return true;
      }
    );
  });

  it('raises a typed error for null/undefined confidence', () => {
    assert.throws(
      () => parseDecisionFrontmatter({
        coordinator_confidence: null, axes: ['routing-track'], match: true, decision_id: 'd-005'
      }),
      Error,
      'expected an Error for null coordinator_confidence'
    );
  });
});

// ---------------------------------------------------------------------------
// TP2.T2-F: axes field must be a non-empty array of strings
// DoD-(c): empty/missing axes fails ingest with a diagnostic (not a silent empty)
// ---------------------------------------------------------------------------
describe('TP2.T2-F: decision-axes-parser — axes must be non-empty string array',
  { skip: !IMPL_EXISTS ? SKIP_REASON : false }, () => {

  it('accepts a valid non-empty axes array', () => {
    assert.doesNotThrow(() => parseDecisionFrontmatter({
      coordinator_confidence: 'high', axes: ['routing-track', 'model-tier'],
      match: true, decision_id: 'd-006'
    }), 'valid axes array should not throw');
  });

  it('raises an error for an empty axes array', () => {
    assert.throws(
      () => parseDecisionFrontmatter({
        coordinator_confidence: 'high', axes: [], match: true, decision_id: 'd-007'
      }),
      (err) => {
        assert.ok(err instanceof Error, 'expected Error for empty axes');
        assert.ok(
          err.message.toLowerCase().includes('axes') || err.message.toLowerCase().includes('empty'),
          `expected error to mention axes/empty, got: ${err.message}`
        );
        return true;
      }
    );
  });

  it('raises an error for missing axes field', () => {
    assert.throws(
      () => parseDecisionFrontmatter({
        coordinator_confidence: 'high', match: true, decision_id: 'd-008'
      }),
      Error,
      'expected Error for missing axes field'
    );
  });

  it('raises an error for non-array axes field', () => {
    assert.throws(
      () => parseDecisionFrontmatter({
        coordinator_confidence: 'high', axes: 'routing-track', match: true, decision_id: 'd-009'
      }),
      Error,
      'expected Error for string axes (must be array)'
    );
  });
});

// ---------------------------------------------------------------------------
// TP2.T2-G: duong_concurred_silently:true derives match:true (plan B §3.1 line 136)
// ---------------------------------------------------------------------------
describe('TP2.T2-G: decision-axes-parser — duong_concurred_silently derives match:true',
  { skip: !IMPL_EXISTS ? SKIP_REASON : false }, () => {

  it('silently-concurred decision has match=true in parsed output', () => {
    const result = parseDecisionFrontmatter({
      coordinator_confidence: 'medium',
      axes: ['routing-track'],
      duong_concurred_silently: true,
      decision_id: 'd-010'
      // NOTE: no explicit 'match' field — must be derived from duong_concurred_silently
    });
    assert.strictEqual(result.match, true,
      'duong_concurred_silently:true must derive match=true');
  });

  it('parser output is byte-identical across two calls over the same silent-concur input', () => {
    const input = {
      coordinator_confidence: 'medium', axes: ['routing-track'],
      duong_concurred_silently: true, decision_id: 'd-011'
    };
    const r1 = parseDecisionFrontmatter(input);
    const r2 = parseDecisionFrontmatter(input);
    assert.deepEqual(r1, r2, 'parser must be deterministic for silent-concur inputs');
  });
});
