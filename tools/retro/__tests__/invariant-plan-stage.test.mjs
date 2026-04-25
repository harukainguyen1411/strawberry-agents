/**
 * TP1.T4 — xfail invariant test: plan-stage three-signal layered detection
 *
 * guards T.P1.2 DoD (c) — three-signal plan-stage detection per §Q2
 * Plan-Ref: plans/approved/personal/2026-04-25-retrospection-dashboard-and-canonical-v1.md
 *
 * xfail: skipped until ingest.mjs exists.
 * TODO (T.P1.2): implement three-signal detection then flip skip guard.
 *
 * Sub-test (d) — R3 rank-tie — stays xfail BLOCKED-ON-OQ-R3 even after T.P1.2 lands.
 * OQ-R3: behavior when Orianna trailer and frontmatter mtime DISAGREE on current stage.
 * Xayah recommendation: trailer wins + log warning (option 1 of 3 in §Test plan OQ-R3).
 * This sub-test will only flip green once Swain rules on OQ-R3.
 */

import { describe, it, before } from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, readFileSync, mkdtempSync, mkdirSync, copyFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { execSync } from 'node:child_process';
import { tmpdir } from 'node:os';

const __dirname = dirname(fileURLToPath(import.meta.url));
const RETRO_ROOT = join(__dirname, '..');
const INGEST_PATH = join(RETRO_ROOT, 'ingest.mjs');
const FIXTURES_DIR = join(RETRO_ROOT, 'fixtures');
const SIGNALS_DIR = join(FIXTURES_DIR, 'plan-stage-signals');

const IMPL_EXISTS = existsSync(INGEST_PATH);
const SKIP_REASON = 'xfail: ingest.mjs not yet implemented (TODO T.P1.2)';

function runIngestWithSignalFixture(fixtureSubdir, envOverrides = {}) {
  if (!IMPL_EXISTS) return [];
  const tmp = mkdtempSync(join(tmpdir(), 'retro-t4-'));
  const mockDir = join(tmp, 'git-log-mock');
  mkdirSync(mockDir, { recursive: true });

  const gitLogPath = join(SIGNALS_DIR, fixtureSubdir, 'git-log.json');
  if (existsSync(gitLogPath)) {
    copyFileSync(gitLogPath, join(mockDir, 'git-log-plans.json'));
    envOverrides.RETRO_GIT_LOG_MOCK = join(mockDir, 'git-log-plans.json');
  }

  const subagentPath = join(SIGNALS_DIR, fixtureSubdir, 'subagent-dispatch.jsonl');
  if (existsSync(subagentPath)) {
    const sessDir = join(tmp, 'projects', 'strawberry-agents', 'sess-signals-parent');
    const subDir = join(sessDir, 'subagents');
    mkdirSync(subDir, { recursive: true });
    copyFileSync(subagentPath, join(subDir, 'agent-signal001.jsonl'));
  }

  execSync(`node ${INGEST_PATH} --cache-dir ${tmp}`, {
    cwd: RETRO_ROOT,
    stdio: 'pipe',
    env: { ...process.env, ...envOverrides },
  });

  const eventsPath = join(tmp, 'events.jsonl');
  return readFileSync(eventsPath, 'utf8')
    .split('\n')
    .filter(Boolean)
    .map(l => JSON.parse(l));
}

// ---------------------------------------------------------------------------
// Sub-test (a): trailer-only signal
// ---------------------------------------------------------------------------
describe('TP1.T4-A: trailer-only signal emits plan-stage with signal:trailer', { skip: !IMPL_EXISTS ? SKIP_REASON : false }, () => {
  let events;

  before(() => {
    events = runIngestWithSignalFixture('trailer-only');
  });

  it('emits a plan-stage event for 2026-04-22-trailer-only-plan', () => {
    const ps = events.find(e => e.kind === 'plan-stage' && e.planSlug === '2026-04-22-trailer-only-plan');
    assert.ok(ps, 'expected a plan-stage event for trailer-only-plan');
  });

  it('sets signal:trailer for the Promoted-By:Orianna commit', () => {
    const ps = events.find(e => e.kind === 'plan-stage' && e.planSlug === '2026-04-22-trailer-only-plan');
    assert.equal(ps.signal, 'trailer', `expected signal=trailer, got ${ps.signal}`);
  });
});

// ---------------------------------------------------------------------------
// Sub-test (b): frontmatter-only signal
// ---------------------------------------------------------------------------
describe('TP1.T4-B: frontmatter-only signal emits plan-stage with signal:frontmatter-mtime', { skip: !IMPL_EXISTS ? SKIP_REASON : false }, () => {
  let events;

  before(() => {
    events = runIngestWithSignalFixture('frontmatter-only');
  });

  it('emits a plan-stage event for 2026-04-22-frontmatter-only-plan', () => {
    const ps = events.find(e => e.kind === 'plan-stage' && e.planSlug === '2026-04-22-frontmatter-only-plan');
    assert.ok(ps, 'expected a plan-stage event for frontmatter-only-plan');
  });

  it('sets signal:frontmatter-mtime when no Orianna trailer present', () => {
    const ps = events.find(e => e.kind === 'plan-stage' && e.planSlug === '2026-04-22-frontmatter-only-plan');
    assert.equal(ps.signal, 'frontmatter-mtime', `expected signal=frontmatter-mtime, got ${ps.signal}`);
  });
});

// ---------------------------------------------------------------------------
// Sub-test (c): dispatch-prompt-only signal
// ---------------------------------------------------------------------------
describe('TP1.T4-C: dispatch-prompt-only signal emits plan-stage with signal:dispatch-prompt-slug-match', { skip: !IMPL_EXISTS ? SKIP_REASON : false }, () => {
  let events;

  before(() => {
    events = runIngestWithSignalFixture('dispatch-prompt-only');
  });

  it('emits a plan-stage event for 2026-04-22-dispatch-prompt-only-plan', () => {
    const ps = events.find(e => e.kind === 'plan-stage' && e.planSlug === '2026-04-22-dispatch-prompt-only-plan');
    assert.ok(ps, 'expected a plan-stage event via dispatch-prompt slug match');
  });

  it('sets signal:dispatch-prompt-slug-match when only the dispatch prompt cites the plan', () => {
    const ps = events.find(e => e.kind === 'plan-stage' && e.planSlug === '2026-04-22-dispatch-prompt-only-plan');
    assert.equal(ps.signal, 'dispatch-prompt-slug-match',
      `expected signal=dispatch-prompt-slug-match, got ${ps.signal}`);
  });
});

// ---------------------------------------------------------------------------
// Sub-test (precedence): all three signals present — trailer wins
// ---------------------------------------------------------------------------
describe('TP1.T4-D: precedence — all three signals present, trailer wins', { skip: !IMPL_EXISTS ? SKIP_REASON : false }, () => {
  let events;

  before(() => {
    events = runIngestWithSignalFixture('all-three-signals');
  });

  it('emits exactly one plan-stage event for 2026-04-22-all-three-plan (no duplicates)', () => {
    const planStages = events.filter(
      e => e.kind === 'plan-stage' && e.planSlug === '2026-04-22-all-three-plan'
    );
    assert.equal(planStages.length, 1, 'expected exactly one plan-stage event when all signals agree');
  });

  it('winning signal is trailer (canonical per §Q2 + Rule 19)', () => {
    const ps = events.find(e => e.kind === 'plan-stage' && e.planSlug === '2026-04-22-all-three-plan');
    assert.equal(ps.signal, 'trailer',
      `trailer must win when all three signals present; got ${ps.signal}`);
  });

  it('corroborating signals are recorded in signal_corroborators array', () => {
    const ps = events.find(e => e.kind === 'plan-stage' && e.planSlug === '2026-04-22-all-three-plan');
    assert.ok(Array.isArray(ps.signal_corroborators),
      'signal_corroborators must be an array when corroborating signals exist');
    assert.ok(ps.signal_corroborators.includes('frontmatter-mtime'),
      'frontmatter-mtime must be listed as corroborator');
    assert.ok(ps.signal_corroborators.includes('dispatch-prompt-slug-match'),
      'dispatch-prompt-slug-match must be listed as corroborator');
  });
});

// ---------------------------------------------------------------------------
// Sub-test (R3 rank-tie) — BLOCKED-ON-OQ-R3 — stays xfail permanently until Swain rules
//
// OQ-R3: Orianna trailer says "approved" but frontmatter mtime says "in-progress" 30s LATER.
// Xayah recommendation: trailer wins + emit signal_conflict annotation.
// This test documents the expected behavior once OQ-R3 is resolved.
// ---------------------------------------------------------------------------
describe('TP1.T4-E [BLOCKED-ON-OQ-R3]: rank-tie — trailer vs frontmatter disagree on stage', {
  skip: 'xfail BLOCKED-ON-OQ-R3: Swain must rule on plan-stage rank-tie rule before this test can pass',
}, () => {
  let events;

  before(() => {
    events = runIngestWithSignalFixture('rank-tie');
  });

  it('emits a plan-stage event for 2026-04-22-rank-tie-plan with signal:trailer (trailer wins)', () => {
    const ps = events.find(e => e.kind === 'plan-stage' && e.planSlug === '2026-04-22-rank-tie-plan');
    assert.ok(ps, 'expected a plan-stage event for rank-tie-plan');
    assert.equal(ps.signal, 'trailer',
      'trailer must win over a later frontmatter mutation per Xayah recommendation (option 1)');
  });

  it('emits a signal_conflict annotation when frontmatter is newer than the trailer', () => {
    const ps = events.find(e => e.kind === 'plan-stage' && e.planSlug === '2026-04-22-rank-tie-plan');
    assert.ok(ps, 'plan-stage event must exist');
    assert.equal(ps.signal_conflict, 'frontmatter-newer-than-trailer',
      'signal_conflict must be set to frontmatter-newer-than-trailer when mtime disagrees');
  });
});
