/**
 * TP1.T1 — xfail unit suite: events.jsonl scanner per upstream source
 *
 * guards T.P1.1 DoD bullets (a)-(e) / T.P1.2 DoD bullet (a)-(d)
 * Plan-Ref: plans/approved/personal/2026-04-25-retrospection-dashboard-and-canonical-v1.md
 *
 * xfail: skipped until tools/retro/ingest.mjs exists (Rule 12 — test lands before impl).
 * TODO (T.P1.2): implement ingest.mjs then flip skip guard.
 */

import { describe, it, before } from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, readFileSync, mkdtempSync, mkdirSync, copyFileSync, writeFileSync, statSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { execSync } from 'node:child_process';
import { tmpdir } from 'node:os';

const __dirname = dirname(fileURLToPath(import.meta.url));
const RETRO_ROOT = join(__dirname, '..');
const INGEST_PATH = join(RETRO_ROOT, 'ingest.mjs');
const FIXTURES_DIR = join(RETRO_ROOT, 'fixtures');

// xfail guard — ingest.mjs does not exist yet (T.P1.2 lands it)
const IMPL_EXISTS = existsSync(INGEST_PATH);
const SKIP_REASON = 'xfail: ingest.mjs not yet implemented (TODO T.P1.2)';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/**
 * Create a temp working dir, seed it with the given fixture subtree,
 * run ingest.mjs, and return the emitted events as parsed JSONL lines.
 */
function runIngestOnFixtures(fixtureSetup) {
  if (!IMPL_EXISTS) return [];
  const tmp = mkdtempSync(join(tmpdir(), 'retro-test-'));
  fixtureSetup(tmp);
  const eventsPath = join(tmp, 'events.jsonl');
  execSync(`node ${INGEST_PATH} --cache-dir ${tmp}`, { cwd: RETRO_ROOT, stdio: 'pipe' });
  if (!existsSync(eventsPath)) return [];
  return readFileSync(eventsPath, 'utf8')
    .split('\n')
    .filter(Boolean)
    .map(l => JSON.parse(l));
}

// ---------------------------------------------------------------------------
// TP1.T1-A: parent JSONL — coordinator-inline turns
// §Q1 source 1: ~/.claude/projects/<slug>/<session-id>.jsonl
// asserts rows without isSidechain are tagged role:coordinator-inline, kind:turn
// ---------------------------------------------------------------------------
describe('TP1.T1-A: parent-jsonl source — coordinator-inline discrimination', { skip: !IMPL_EXISTS ? SKIP_REASON : false }, () => {
  let events;

  before(() => {
    events = runIngestOnFixtures((tmp) => {
      const sessDir = join(tmp, 'projects', 'strawberry-agents', 'sess-parent-001');
      mkdirSync(sessDir, { recursive: true });
      copyFileSync(join(FIXTURES_DIR, 'parent-session.jsonl'), join(sessDir, 'sess-parent-001.jsonl'));
    });
  });

  it('emits turn events for every assistant row in parent jsonl', () => {
    const turns = events.filter(e => e.kind === 'turn' && e.sessionId === 'sess-parent-001');
    // parent-session.jsonl has 3 assistant rows
    assert.equal(turns.length, 3, 'expected 3 coordinator-inline turn events');
  });

  it('tags parent-jsonl assistant rows as role:coordinator-inline', () => {
    const turns = events.filter(e => e.kind === 'turn' && e.sessionId === 'sess-parent-001');
    for (const t of turns) {
      assert.equal(t.role, 'coordinator-inline',
        `expected role=coordinator-inline, got ${t.role} at ts=${t.ts}`);
    }
  });

  it('does not tag parent-jsonl rows as delegated', () => {
    const delegated = events.filter(e => e.sessionId === 'sess-parent-001' && e.role === 'delegated');
    assert.equal(delegated.length, 0, 'parent session must have no delegated turns');
  });

  it('preserves all four token fields from usage block', () => {
    const turns = events.filter(e => e.kind === 'turn' && e.sessionId === 'sess-parent-001');
    for (const t of turns) {
      assert.ok(Number.isInteger(t.input_tokens), `input_tokens must be integer at ts=${t.ts}`);
      assert.ok(Number.isInteger(t.output_tokens), `output_tokens must be integer at ts=${t.ts}`);
      assert.ok(Number.isInteger(t.cache_read_input_tokens), `cache_read_input_tokens must be integer at ts=${t.ts}`);
      assert.ok(Number.isInteger(t.cache_creation_input_tokens), `cache_creation_input_tokens must be integer at ts=${t.ts}`);
    }
  });
});

// ---------------------------------------------------------------------------
// TP1.T1-B: subagent JSONL — delegated turns carry parentSessionId
// §Q1 source 2: subagents/agent-<id>.{jsonl,meta.json}
// asserts isSidechain:true rows are tagged role:delegated with parentSessionId
// ---------------------------------------------------------------------------
describe('TP1.T1-B: subagent-jsonl source — delegated turn discrimination', { skip: !IMPL_EXISTS ? SKIP_REASON : false }, () => {
  let events;

  before(() => {
    events = runIngestOnFixtures((tmp) => {
      const sessDir = join(tmp, 'projects', 'strawberry-agents', 'sess-parent-001');
      const subDir = join(sessDir, 'subagents');
      mkdirSync(subDir, { recursive: true });
      copyFileSync(join(FIXTURES_DIR, 'subagents', 'agent-fixt001.jsonl'), join(subDir, 'agent-fixt001.jsonl'));
      copyFileSync(join(FIXTURES_DIR, 'subagents', 'agent-fixt001.meta.json'), join(subDir, 'agent-fixt001.meta.json'));
    });
  });

  it('emits turn events for every assistant row in subagent jsonl', () => {
    const turns = events.filter(e => e.kind === 'turn' && e.sessionId === 'sess-subagent-001');
    // agent-fixt001.jsonl has 2 assistant rows
    assert.equal(turns.length, 2, 'expected 2 delegated turn events');
  });

  it('tags subagent isSidechain:true rows as role:delegated', () => {
    const turns = events.filter(e => e.kind === 'turn' && e.sessionId === 'sess-subagent-001');
    for (const t of turns) {
      assert.equal(t.role, 'delegated',
        `expected role=delegated for subagent turn at ts=${t.ts}`);
    }
  });

  it('carries parentSessionId from meta.json', () => {
    const turns = events.filter(e => e.kind === 'turn' && e.sessionId === 'sess-subagent-001');
    for (const t of turns) {
      assert.equal(t.parentSessionId, 'sess-parent-001',
        `expected parentSessionId=sess-parent-001 at ts=${t.ts}`);
    }
  });

  it('carries agentId from the subagents/ path', () => {
    const turns = events.filter(e => e.kind === 'turn' && e.sessionId === 'sess-subagent-001');
    for (const t of turns) {
      assert.equal(t.agentId, 'agent-fixt001',
        `expected agentId=agent-fixt001 at ts=${t.ts}`);
    }
  });
});

// ---------------------------------------------------------------------------
// TP1.T1-C: sentinel — zero-byte file mtime becomes dispatch_end_ts
// §Q1 source 3: subagent-sentinels/<agent-id>
// asserts sentinel mtime becomes dispatch_end_ts for its agent-<id>
// ---------------------------------------------------------------------------
describe('TP1.T1-C: sentinel source — mtime becomes dispatch_end_ts', { skip: !IMPL_EXISTS ? SKIP_REASON : false }, () => {
  let events;
  let sentinelMtime;

  before(() => {
    events = runIngestOnFixtures((tmp) => {
      const sentinelDir = join(tmp, 'strawberry-usage-cache', 'subagent-sentinels');
      mkdirSync(sentinelDir, { recursive: true });
      const sentinelPath = join(sentinelDir, 'agent-fixt001');
      writeFileSync(sentinelPath, '');
      // Capture its mtime in ms since epoch
      sentinelMtime = statSync(sentinelPath).mtimeMs;
    });
  });

  it('emits a dispatch event for agent-fixt001', () => {
    const dispatches = events.filter(e => e.kind === 'dispatch' && e.agentId === 'agent-fixt001');
    assert.ok(dispatches.length >= 1, 'expected at least one dispatch event for agent-fixt001');
  });

  it('sets dispatch_end_ts to the sentinel file mtime', () => {
    const dispatch = events.find(e => e.kind === 'dispatch' && e.agentId === 'agent-fixt001');
    assert.ok(dispatch, 'dispatch event must exist');
    const endTs = new Date(dispatch.dispatch_end_ts).getTime();
    // Allow 1s tolerance for filesystem mtime rounding
    assert.ok(Math.abs(endTs - sentinelMtime) < 1000,
      `dispatch_end_ts ${dispatch.dispatch_end_ts} does not match sentinel mtime`);
  });
});

// ---------------------------------------------------------------------------
// TP1.T1-D: git-log mock — Promoted-By:Orianna trailer emits plan-stage events
// §Q1 source 4: git log over plans/**
// asserts trailer commits emit kind:plan-stage events with correct (slug, stage, signal)
// ---------------------------------------------------------------------------
describe('TP1.T1-D: git-log source — Promoted-By:Orianna trailer emits plan-stage events', { skip: !IMPL_EXISTS ? SKIP_REASON : false }, () => {
  let events;

  before(() => {
    events = runIngestOnFixtures((tmp) => {
      // Provide the mock git-log JSON via env / fixture file
      const mockDir = join(tmp, 'git-log-mock');
      mkdirSync(mockDir, { recursive: true });
      copyFileSync(join(FIXTURES_DIR, 'git-log-plans.json'), join(mockDir, 'git-log-plans.json'));
      // ingest.mjs should read RETRO_GIT_LOG_MOCK env var or a well-known path
      process.env.RETRO_GIT_LOG_MOCK = join(mockDir, 'git-log-plans.json');
    });
  });

  it('emits plan-stage events for all Orianna-trailercommits in the mock log', () => {
    const planStages = events.filter(e => e.kind === 'plan-stage');
    // git-log-plans.json has 3 Orianna commits
    assert.equal(planStages.length, 3, 'expected 3 plan-stage events from git-log mock');
  });

  it('sets signal:trailer for Promoted-By:Orianna commits', () => {
    const planStages = events.filter(e => e.kind === 'plan-stage');
    for (const ps of planStages) {
      assert.equal(ps.signal, 'trailer',
        `expected signal=trailer for plan-stage at slug=${ps.planSlug} stage=${ps.stage}`);
    }
  });

  it('correctly maps commit to (planSlug, stage) tuple', () => {
    const implementedEvent = events.find(
      e => e.kind === 'plan-stage'
        && e.planSlug === '2026-04-21-agent-feedback-system'
        && e.stage === 'implemented'
    );
    assert.ok(implementedEvent, 'expected a plan-stage event for implemented stage');
    assert.equal(implementedEvent.commit, 'abc123def456');
  });

  it('events are emitted in stable timestamp order', () => {
    const planStages = events
      .filter(e => e.kind === 'plan-stage' && e.planSlug === '2026-04-21-agent-feedback-system')
      .map(e => e.ts);
    const sorted = [...planStages].sort();
    assert.deepEqual(planStages, sorted, 'plan-stage events must be in ascending ts order');
  });
});
