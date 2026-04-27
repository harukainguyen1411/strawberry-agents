/**
 * Regression: ingest must emit Phase-1 event kinds from real-format Claude JSONL.
 *
 * Real Claude JSONL nests usage/model inside a `message` wrapper object rather than
 * at the top level. This test uses a minimal fake ~/.claude/projects/ tree written
 * in that real format and asserts that at least one event of each Phase-1 kind is
 * emitted — the test that would have caught the real-data schema mismatch.
 *
 * Phase-1 event kinds asserted:
 *   - kind: 'turn' (role: coordinator-inline) from parent session
 *   - kind: 'turn' (role: delegated) from subagent session
 *   - kind: 'dispatch' from subagent meta.json
 *   - kind: 'plan-stage' from git-log mock
 *
 * Plan-Ref: plans/approved/personal/2026-04-25-retrospection-dashboard-and-canonical-v1.md
 */

import { describe, it, before } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, writeFileSync, readFileSync, existsSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { execSync } from 'node:child_process';
import { tmpdir } from 'node:os';

const __dirname = dirname(fileURLToPath(import.meta.url));
const RETRO_ROOT = join(__dirname, '..');
const INGEST_PATH = join(RETRO_ROOT, 'ingest.mjs');
const FIXTURES_DIR = join(RETRO_ROOT, 'fixtures');

// Real-format JSONL: usage/model nested inside message (as produced by the Claude app).
const REAL_FORMAT_PARENT_SESSION = [
  // user turn — content in message.content (string)
  JSON.stringify({
    type: 'user',
    isSidechain: false,
    promptId: 'p001',
    uuid: 'u001',
    timestamp: '2026-04-20T08:00:00.000Z',
    sessionId: 'real-sess-001',
    message: {
      role: 'user',
      content: 'Plan-Ref: plans/approved/personal/2026-04-25-retrospection-dashboard-and-canonical-v1.md\n\nRun weekly retro.',
    },
  }),
  // assistant turn — usage/model in message
  JSON.stringify({
    type: 'assistant',
    isSidechain: false,
    uuid: 'a001',
    timestamp: '2026-04-20T08:00:10.000Z',
    sessionId: 'real-sess-001',
    message: {
      role: 'assistant',
      model: 'claude-opus-4-7',
      usage: {
        input_tokens: 120,
        output_tokens: 50,
        cache_read_input_tokens: 0,
        cache_creation_input_tokens: 0,
      },
      content: [{ type: 'text', text: 'Processing...' }],
    },
  }),
  // second assistant turn — confirms wall_active_delta_s < 90s path
  JSON.stringify({
    type: 'assistant',
    isSidechain: false,
    uuid: 'a002',
    timestamp: '2026-04-20T08:00:40.000Z',
    sessionId: 'real-sess-001',
    message: {
      role: 'assistant',
      model: 'claude-opus-4-7',
      usage: {
        input_tokens: 200,
        output_tokens: 80,
        cache_read_input_tokens: 10,
        cache_creation_input_tokens: 5,
      },
      content: [{ type: 'text', text: 'Done.' }],
    },
  }),
].join('\n') + '\n';

// Real-format subagent JSONL: isSidechain:true on assistant lines.
const REAL_FORMAT_SUBAGENT_SESSION = [
  JSON.stringify({
    type: 'user',
    isSidechain: true,
    uuid: 'su001',
    timestamp: '2026-04-20T08:00:20.000Z',
    sessionId: 'real-subagent-001',
    agentId: 'agent-realfixt001',
    message: {
      role: 'user',
      content: '[concern: personal]\n\nRun the plan-rollup query.',
    },
  }),
  JSON.stringify({
    type: 'assistant',
    isSidechain: true,
    uuid: 'sa001',
    timestamp: '2026-04-20T08:00:35.000Z',
    sessionId: 'real-subagent-001',
    agentId: 'agent-realfixt001',
    message: {
      role: 'assistant',
      model: 'claude-sonnet-4-6',
      usage: {
        input_tokens: 300,
        output_tokens: 120,
        cache_read_input_tokens: 50,
        cache_creation_input_tokens: 25,
      },
      content: [{ type: 'text', text: 'Rollup complete.' }],
    },
  }),
].join('\n') + '\n';

const REAL_FORMAT_SUBAGENT_META = JSON.stringify({
  agentId: 'agent-realfixt001',
  sessionId: 'real-subagent-001',
  parentSessionId: 'real-sess-001',
  coordinator: 'evelynn',
  startTs: '2026-04-20T08:00:20.000Z',
  endTs: '2026-04-20T08:00:50.000Z',
});

// Git-log mock: one Orianna promotion commit (reuse fixture).
const GIT_LOG_MOCK = readFileSync(join(FIXTURES_DIR, 'git-log-plans.json'), 'utf8');

function runIngestOnRealFixtures(setup) {
  const tmp = mkdtempSync(join(tmpdir(), 'retro-real-test-'));
  setup(tmp);
  const eventsPath = join(tmp, 'events.jsonl');
  execSync(`node ${INGEST_PATH} --cache-dir ${tmp}`, {
    cwd: RETRO_ROOT,
    stdio: 'pipe',
    env: { ...process.env, RETRO_GIT_LOG_MOCK: join(tmp, 'git-log-plans.json') },
  });
  if (!existsSync(eventsPath)) return [];
  return readFileSync(eventsPath, 'utf8')
    .split('\n')
    .filter(Boolean)
    .map(l => JSON.parse(l));
}

// xfail: real-data smoke test — fails before normalizeLine fix; green after (Rule 12)
describe('ingest-real-data: Phase-1 event kinds from real-format JSONL', () => {
  let events;

  before(() => {
    events = runIngestOnRealFixtures((tmp) => {
      // Seed a fake ~/.claude/projects/ tree under tmp/projects/
      const sessId = 'real-sess-001';
      const projectDir = join(tmp, 'projects', 'strawberry-agents');
      // Flat parent session JSONL
      mkdirSync(projectDir, { recursive: true });
      writeFileSync(join(projectDir, `${sessId}.jsonl`), REAL_FORMAT_PARENT_SESSION);

      // Directory-style session (subagents alongside)
      const sessDir = join(projectDir, sessId);
      const subDir = join(sessDir, 'subagents');
      mkdirSync(subDir, { recursive: true });
      writeFileSync(join(subDir, 'agent-realfixt001.jsonl'), REAL_FORMAT_SUBAGENT_SESSION);
      writeFileSync(join(subDir, 'agent-realfixt001.meta.json'), REAL_FORMAT_SUBAGENT_META);

      // Git-log mock
      writeFileSync(join(tmp, 'git-log-plans.json'), GIT_LOG_MOCK);
    });
  });

  it('emits at least one kind:turn role:coordinator-inline from real-format parent JSONL', () => {
    const turns = events.filter(e => e.kind === 'turn' && e.role === 'coordinator-inline');
    assert.ok(
      turns.length >= 1,
      `expected coordinator-inline turn events, got 0 — ` +
      `likely usage/model still not lifted from message wrapper. ` +
      `All events: ${JSON.stringify(events.map(e => e.kind + '/' + (e.role || '')))}`,
    );
  });

  it('coordinator-inline turns carry non-zero token counts', () => {
    const turns = events.filter(e => e.kind === 'turn' && e.role === 'coordinator-inline');
    for (const t of turns) {
      assert.ok(
        (t.input_tokens + t.output_tokens) > 0,
        `turn at ${t.ts} has zero total tokens — usage not lifted from message.usage`,
      );
    }
  });

  it('emits at least one kind:turn role:delegated from real-format subagent JSONL', () => {
    const turns = events.filter(e => e.kind === 'turn' && e.role === 'delegated');
    assert.ok(
      turns.length >= 1,
      `expected delegated turn events, got 0 — ` +
      `isSidechain check or usage lift likely broken for subagent JSONL`,
    );
  });

  it('emits at least one kind:dispatch from subagent meta.json', () => {
    const dispatches = events.filter(e => e.kind === 'dispatch');
    assert.ok(
      dispatches.length >= 1,
      `expected dispatch event, got 0 — meta.json not being read or processed`,
    );
  });

  it('emits at least one kind:plan-stage from git-log mock', () => {
    const planStages = events.filter(e => e.kind === 'plan-stage');
    assert.ok(
      planStages.length >= 1,
      `expected plan-stage events, got 0 — git-log mock not read`,
    );
  });

  it('coordinator-inline turn count matches real-format parent session assistant rows', () => {
    const turns = events.filter(e => e.kind === 'turn' && e.role === 'coordinator-inline' && e.sessionId === 'real-sess-001');
    // REAL_FORMAT_PARENT_SESSION has 2 assistant rows
    assert.equal(turns.length, 2, `expected 2 coordinator-inline turns from 2-assistant-row real session, got ${turns.length}`);
  });
});
