/**
 * TP1.T3 — xfail invariant test: wall-active-minutes strips gaps >90s
 *
 * guards T.P1.2 DoD (d) — idle-gap stripping per §3 time-normalization
 * Plan-Ref: plans/approved/personal/2026-04-25-retrospection-dashboard-and-canonical-v1.md
 *
 * xfail: skipped until ingest.mjs exists.
 * TODO (T.P1.2): implement idle-gap stripping then flip skip guard.
 *
 * Fixture: idle-gap-session.jsonl
 *   Turn timestamps and deltas between consecutive assistant turns:
 *     T1 → T2: delta = 30s  (active, <= 90s)
 *     T2 → T3: delta = 125s (idle gap, > 90s — STRIP)
 *     T3 → T4: delta = 45s  (active, <= 90s)
 *     T4 → T5: delta = 91s  (idle gap, > 90s — STRIP)
 *     T5 → T6: delta = 60s  (active, <= 90s)
 *
 *   wall_active_minutes = (30 + 45 + 60) / 60 = 2.25
 *
 * Edge-case fixture (inline): gap of exactly 90s IS counted (boundary inclusive).
 */

import { describe, it, before } from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, readFileSync, mkdtempSync, mkdirSync, copyFileSync, writeFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { execSync } from 'node:child_process';
import { tmpdir } from 'node:os';

const __dirname = dirname(fileURLToPath(import.meta.url));
const RETRO_ROOT = join(__dirname, '..');
const INGEST_PATH = join(RETRO_ROOT, 'ingest.mjs');
const FIXTURES_DIR = join(RETRO_ROOT, 'fixtures');

const IMPL_EXISTS = existsSync(INGEST_PATH);
const SKIP_REASON = 'xfail: ingest.mjs not yet implemented (TODO T.P1.2)';

// Expected wall_active_minutes for idle-gap-session: (30 + 45 + 60) / 60 = 2.25
const EXPECTED_WALL_ACTIVE_MINUTES = 2.25;
const EPSILON = 0.001; // floating-point tolerance for division

function runIngest(tmp, fixtureFile, sessId) {
  const sessDir = join(tmp, 'projects', 'strawberry-agents', sessId);
  mkdirSync(sessDir, { recursive: true });
  copyFileSync(join(FIXTURES_DIR, fixtureFile), join(sessDir, `${sessId}.jsonl`));
  execSync(`node ${INGEST_PATH} --cache-dir ${tmp}`, { cwd: RETRO_ROOT, stdio: 'pipe' });
  const eventsPath = join(tmp, 'events.jsonl');
  return readFileSync(eventsPath, 'utf8')
    .split('\n')
    .filter(Boolean)
    .map(l => JSON.parse(l));
}

describe('TP1.T3: wall_active_minutes strips inter-turn gaps > 90s', { skip: !IMPL_EXISTS ? SKIP_REASON : false }, () => {
  let events;

  before(() => {
    const tmp = mkdtempSync(join(tmpdir(), 'retro-t3-'));
    events = runIngest(tmp, 'idle-gap-session.jsonl', 'sess-idle-gap');
  });

  it('session-level wall_active_minutes equals 2.25 (30+45+60 seconds / 60)', () => {
    // The scanner should emit either a session-summary event or annotate each turn
    // with wall_active_delta_s. We compute the total here.
    const turns = events.filter(e => e.kind === 'turn' && e.sessionId === 'sess-idle-gap');
    assert.ok(turns.length > 0, 'expected turn events for idle-gap session');

    const totalActiveSeconds = turns.reduce((sum, t) => sum + (t.wall_active_delta_s || 0), 0);
    const wallActiveMinutes = totalActiveSeconds / 60;

    assert.ok(
      Math.abs(wallActiveMinutes - EXPECTED_WALL_ACTIVE_MINUTES) < EPSILON,
      `wall_active_minutes: expected ${EXPECTED_WALL_ACTIVE_MINUTES}, got ${wallActiveMinutes}`
    );
  });

  it('gaps > 90s contribute zero to wall_active_delta_s', () => {
    // Turns at index 2 (T3, delta=125s) and index 4 (T5, delta=91s) must have wall_active_delta_s=0
    const turns = events
      .filter(e => e.kind === 'turn' && e.sessionId === 'sess-idle-gap')
      .sort((a, b) => new Date(a.ts) - new Date(b.ts));

    // T3 is the turn after the 125s gap — its wall_active_delta_s should be 0
    const t3 = turns.find(t => t.ts === '2026-04-22T10:02:55.000Z');
    assert.ok(t3, 'Turn T3 (post-125s-gap) must exist');
    assert.equal(t3.wall_active_delta_s, 0,
      `T3 has a 125s gap before it; wall_active_delta_s must be 0, got ${t3.wall_active_delta_s}`);

    // T5 is the turn after the 91s gap — its wall_active_delta_s should be 0
    const t5 = turns.find(t => t.ts === '2026-04-22T10:05:25.000Z');
    assert.ok(t5, 'Turn T5 (post-91s-gap) must exist');
    assert.equal(t5.wall_active_delta_s, 0,
      `T5 has a 91s gap before it; wall_active_delta_s must be 0, got ${t5.wall_active_delta_s}`);
  });

  it('edge-case: gap of exactly 90s IS counted (boundary inclusive — <=90s criterion)', () => {
    // Construct an inline fixture with exactly a 90s gap between two assistant turns
    // T0: 2026-04-22T10:00:00.000Z
    // T1: 2026-04-22T10:01:30.000Z (exactly 90s later)
    const tmp = mkdtempSync(join(tmpdir(), 'retro-t3-edge-'));
    const sessDir = join(tmp, 'projects', 'strawberry-agents', 'sess-90s-edge');
    mkdirSync(sessDir, { recursive: true });
    const edgeFixture = [
      JSON.stringify({ type: 'user', role: 'user', content: [{ type: 'text', text: 'Go.' }], sessionId: 'sess-90s-edge', timestamp: '2026-04-22T10:00:00.000Z' }),
      JSON.stringify({ type: 'assistant', role: 'assistant', content: [{ type: 'text', text: 'A.' }], usage: { input_tokens: 10, output_tokens: 10, cache_read_input_tokens: 0, cache_creation_input_tokens: 0 }, sessionId: 'sess-90s-edge', timestamp: '2026-04-22T10:00:05.000Z', model: 'claude-sonnet-4-6' }),
      JSON.stringify({ type: 'user', role: 'user', content: [{ type: 'text', text: 'Continue.' }], sessionId: 'sess-90s-edge', timestamp: '2026-04-22T10:01:25.000Z' }),
      JSON.stringify({ type: 'assistant', role: 'assistant', content: [{ type: 'text', text: 'B — exactly 90s after A.' }], usage: { input_tokens: 10, output_tokens: 10, cache_read_input_tokens: 0, cache_creation_input_tokens: 0 }, sessionId: 'sess-90s-edge', timestamp: '2026-04-22T10:01:35.000Z', model: 'claude-sonnet-4-6' }),
    ].join('\n') + '\n';
    writeFileSync(join(sessDir, 'sess-90s-edge.jsonl'), edgeFixture);
    execSync(`node ${INGEST_PATH} --cache-dir ${tmp}`, { cwd: RETRO_ROOT, stdio: 'pipe' });
    const edgeEvents = readFileSync(join(tmp, 'events.jsonl'), 'utf8')
      .split('\n').filter(Boolean).map(l => JSON.parse(l));

    const turnB = edgeEvents.find(e => e.kind === 'turn' && e.sessionId === 'sess-90s-edge' && e.ts === '2026-04-22T10:01:35.000Z');
    assert.ok(turnB, 'Turn B (90s boundary) must exist');
    assert.equal(turnB.wall_active_delta_s, 90,
      `A 90s gap must NOT be stripped (boundary inclusive). wall_active_delta_s should be 90, got ${turnB.wall_active_delta_s}`);
  });
});
