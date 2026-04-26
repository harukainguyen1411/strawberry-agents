/**
 * Regression test: C1 + C2 dispatch_count correctness
 *
 * C1: parseSubagentSession omitted coordinator + ts from dispatch events.
 *     SQL's tool_counts CTE filters AND coordinator IS NOT NULL on dispatch events,
 *     so without coordinator the dispatch_count was always 0 in production.
 *     Fix: dispatch event now carries coordinator (from meta.coordinator) and
 *          ts (from meta.startTs).
 *
 * C2: SQL filtered kind='tool_call' but ingest emits kind:'turn'.
 *     Inline/delegated counts were always 0 against real ingest output.
 *     Fix: SQL now filters kind='turn' matching ingest's actual output.
 *
 * Plan-Ref: plans/approved/personal/2026-04-25-retrospection-dashboard-and-canonical-v1.md
 * Regression guard per Rule 13 (bug fix must have regression test on same branch).
 */

import { describe, it, before } from 'node:test';
import assert from 'node:assert/strict';
import {
  existsSync, readFileSync, mkdtempSync, mkdirSync, writeFileSync
} from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { execSync } from 'node:child_process';
import { tmpdir } from 'node:os';

const __dirname = dirname(fileURLToPath(import.meta.url));
const RETRO_ROOT = join(__dirname, '..');
const INGEST_PATH = join(RETRO_ROOT, 'ingest.mjs');
const SQL_PATH = join(RETRO_ROOT, 'queries', 'coordinator-weekly.sql');
const SOURCES_PATH = join(RETRO_ROOT, 'lib', 'sources.mjs');

const IMPL_EXISTS = existsSync(INGEST_PATH) && existsSync(SQL_PATH) && existsSync(SOURCES_PATH);
const SKIP_REASON = 'regression guard: ingest.mjs, coordinator-weekly.sql, or lib/sources.mjs not present';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/**
 * Run coordinator-weekly SQL against a pre-built events.jsonl string.
 * Returns the parsed rows array.
 */
function runSqlAgainstEvents(eventsContent) {
  const tmp = mkdtempSync(join(tmpdir(), 'retro-c1c2-sql-'));
  const eventsPath = join(tmp, 'events.jsonl');
  writeFileSync(eventsPath, eventsContent, 'utf8');

  const sql = readFileSync(SQL_PATH, 'utf8');
  const escapedPath = eventsPath.replace(/'/g, "''");
  const resolvedSql = sql.replace(/'events\.jsonl'/g, `'${escapedPath}'`);
  const cleanSql = resolvedSql.replace(/;\s*$/, '') + ';';
  const result = execSync('duckdb -json', {
    input: cleanSql, cwd: RETRO_ROOT, encoding: 'utf8', stdio: 'pipe'
  });
  return result.trim() ? JSON.parse(result.trim()) : [];
}

/**
 * Run ingest against a session fixture, return emitted events.
 */
function runIngest(fixtureSetup) {
  const tmp = mkdtempSync(join(tmpdir(), 'retro-c1c2-ingest-'));
  fixtureSetup(tmp);
  const eventsPath = join(tmp, 'events.jsonl');
  execSync(`node ${INGEST_PATH} --cache-dir ${tmp}`, { cwd: RETRO_ROOT, stdio: 'pipe' });
  if (!existsSync(eventsPath)) return [];
  return readFileSync(eventsPath, 'utf8')
    .split('\n').filter(Boolean).map(l => JSON.parse(l));
}

// ---------------------------------------------------------------------------
// Regression C1 — unit: parseSubagentSession dispatch carries coordinator + ts
// Pre-fix: dispatch event had neither field → SQL excluded all dispatches →
//          dispatch_count = 0 for every coordinator in production.
// ---------------------------------------------------------------------------
describe('Regression C1: parseSubagentSession dispatch event carries coordinator + ts',
  { skip: !IMPL_EXISTS ? SKIP_REASON : false }, () => {

  let events;

  before(() => {
    events = runIngest((tmp) => {
      const sessDir = join(tmp, 'projects', 'test-project', 'sess-c1-001');
      const subDir = join(sessDir, 'subagents');
      mkdirSync(subDir, { recursive: true });

      // Subagent JSONL: one isSidechain assistant turn
      const subagentJsonl = [
        JSON.stringify({
          type: 'user', role: 'user',
          content: [{ type: 'text', text: '[concern: personal] Do the task' }],
          sessionId: 'sess-c1-sub', parentSessionId: 'sess-c1-001',
          isSidechain: true, timestamp: '2026-04-21T09:00:00.000Z'
        }),
        JSON.stringify({
          type: 'assistant', role: 'assistant',
          content: [{ type: 'text', text: 'Done.' }],
          usage: { input_tokens: 150, output_tokens: 60, cache_read_input_tokens: 0, cache_creation_input_tokens: 0 },
          sessionId: 'sess-c1-sub', parentSessionId: 'sess-c1-001',
          isSidechain: true, timestamp: '2026-04-21T09:00:15.000Z',
          model: 'claude-sonnet-4-6'
        }),
      ].join('\n') + '\n';

      // Meta.json with coordinator field (required for C1 fix)
      const metaJson = JSON.stringify({
        agentId: 'agent-c1-reg',
        sessionId: 'sess-c1-sub',
        parentSessionId: 'sess-c1-001',
        coordinator: 'evelynn',
        startTs: '2026-04-21T08:59:55.000Z',
        endTs: '2026-04-21T09:00:20.000Z'
      });

      writeFileSync(join(subDir, 'agent-c1-reg.jsonl'), subagentJsonl);
      writeFileSync(join(subDir, 'agent-c1-reg.meta.json'), metaJson);
    });
  });

  it('ingest emits a dispatch event for the subagent', () => {
    const dispatches = events.filter(e => e.kind === 'dispatch');
    assert.ok(dispatches.length >= 1, 'expected at least 1 dispatch event');
  });

  it('dispatch event has coordinator field (C1 regression guard)', () => {
    const dispatch = events.find(e => e.kind === 'dispatch' && e.agentId === 'agent-c1-reg');
    assert.ok(dispatch, 'dispatch event must exist for agent-c1-reg');
    assert.strictEqual(dispatch.coordinator, 'evelynn',
      `dispatch.coordinator must be "evelynn", got ${dispatch.coordinator}. ` +
      'Pre-fix: parseSubagentSession dispatch lacked coordinator — SQL WHERE coordinator IS NOT NULL excluded it, dispatch_count=0.'
    );
  });

  it('dispatch event has ts field set to meta.startTs (C1 regression guard)', () => {
    const dispatch = events.find(e => e.kind === 'dispatch' && e.agentId === 'agent-c1-reg');
    assert.ok(dispatch, 'dispatch event must exist');
    assert.strictEqual(dispatch.ts, '2026-04-21T08:59:55.000Z',
      `dispatch.ts must equal meta.startTs. Got: ${dispatch.ts}. ` +
      'Pre-fix: dispatch lacked ts field entirely.'
    );
  });
});

// ---------------------------------------------------------------------------
// Regression C1 SQL — dispatch_count > 0 when dispatch events have coordinator
// Pre-fix: dispatch events lacked coordinator → filtered out → dispatch_count=0.
// ---------------------------------------------------------------------------
describe('Regression C1 SQL: dispatch_count > 0 when dispatch events carry coordinator',
  { skip: !IMPL_EXISTS ? SKIP_REASON : false }, () => {

  it('dispatch_count is 3 when fixture dispatch events have coordinator field', () => {
    // Pre-baked fixture with coordinator on dispatch events (matches real production format post-fix)
    const eventsContent = [
      // Three dispatch events with coordinator
      JSON.stringify({ kind: 'dispatch', agentId: 'ag1', sessionId: 's1', coordinator: 'evelynn', ts: '2026-04-21T08:01:00.000Z', dispatch_start_ts: '2026-04-21T08:01:00.000Z', dispatch_end_ts: '2026-04-21T08:02:00.000Z' }),
      JSON.stringify({ kind: 'dispatch', agentId: 'ag2', sessionId: 's1', coordinator: 'evelynn', ts: '2026-04-21T08:03:00.000Z', dispatch_start_ts: '2026-04-21T08:03:00.000Z', dispatch_end_ts: '2026-04-21T08:04:00.000Z' }),
      JSON.stringify({ kind: 'dispatch', agentId: 'ag3', sessionId: 's1', coordinator: 'evelynn', ts: '2026-04-21T08:05:00.000Z', dispatch_start_ts: '2026-04-21T08:05:00.000Z', dispatch_end_ts: '2026-04-21T08:06:00.000Z' }),
      // Some turns to give coordinator the right week (needed by GROUP BY)
      JSON.stringify({ kind: 'turn', role: 'coordinator-inline', coordinator: 'evelynn', sessionId: 's1', ts: '2026-04-21T08:00:10.000Z' }),
    ].join('\n') + '\n';

    const rows = runSqlAgainstEvents(eventsContent);
    const row = rows.find(r => r.coordinator === 'evelynn');
    assert.ok(row, 'expected a row for coordinator=evelynn');
    assert.strictEqual(Number(row.dispatch_count), 3,
      `dispatch_count must be 3 when fixture has 3 dispatch events with coordinator. Got ${row.dispatch_count}. ` +
      'Pre-fix: dispatch events lacked coordinator → SQL WHERE coordinator IS NOT NULL excluded them → dispatch_count=0.'
    );
  });

  it('dispatch_count is 0 when dispatch events lack coordinator (demonstrates the old bug)', () => {
    // Dispatch events WITHOUT coordinator — simulates old ingest output
    const eventsContent = [
      JSON.stringify({ kind: 'dispatch', agentId: 'ag1', sessionId: 's1', ts: '2026-04-21T08:01:00.000Z', dispatch_start_ts: '2026-04-21T08:01:00.000Z', dispatch_end_ts: '2026-04-21T08:02:00.000Z' }),
      // Turn with coordinator so the week has a row at all
      JSON.stringify({ kind: 'turn', role: 'coordinator-inline', coordinator: 'evelynn', sessionId: 's1', ts: '2026-04-21T08:00:10.000Z' }),
    ].join('\n') + '\n';

    const rows = runSqlAgainstEvents(eventsContent);
    const row = rows.find(r => r.coordinator === 'evelynn');
    // Without coordinator on dispatch, that dispatch is excluded → dispatch_count=0
    // This confirms the old behavior and shows why C1 fix was needed.
    if (row) {
      assert.strictEqual(Number(row.dispatch_count), 0,
        `dispatch_count should be 0 when dispatch events lack coordinator (pre-fix behavior). Got ${row.dispatch_count}.`
      );
    }
    // If no row at all, that's also fine — dispatch without coordinator produces no row
  });
});

// ---------------------------------------------------------------------------
// Regression C2 — SQL: kind='turn' events are counted (not kind='tool_call')
// Pre-fix: SQL filtered kind='tool_call' but ingest emits kind:'turn' →
//          all inline/delegated counts were 0 → ratio was NULL → flag='executor-mode'.
// ---------------------------------------------------------------------------
describe('Regression C2: SQL counts kind:turn events for inline/delegated (not kind:tool_call)',
  { skip: !IMPL_EXISTS ? SKIP_REASON : false }, () => {

  it('inline_tool_calls counts kind:turn coordinator-inline events', () => {
    // 3 coordinator-inline turns with kind='turn' (real ingest format)
    const eventsContent = [
      JSON.stringify({ kind: 'turn', role: 'coordinator-inline', coordinator: 'evelynn', sessionId: 's1', ts: '2026-04-21T08:00:10.000Z' }),
      JSON.stringify({ kind: 'turn', role: 'coordinator-inline', coordinator: 'evelynn', sessionId: 's1', ts: '2026-04-21T08:00:20.000Z' }),
      JSON.stringify({ kind: 'turn', role: 'coordinator-inline', coordinator: 'evelynn', sessionId: 's1', ts: '2026-04-21T08:00:30.000Z' }),
    ].join('\n') + '\n';

    const rows = runSqlAgainstEvents(eventsContent);
    const row = rows.find(r => r.coordinator === 'evelynn');
    assert.ok(row, 'expected a row for coordinator=evelynn');
    assert.strictEqual(Number(row.inline_tool_calls), 3,
      `inline_tool_calls must be 3 for 3 kind:turn coordinator-inline events. Got ${row.inline_tool_calls}. ` +
      'Pre-fix: SQL kind=tool_call never matched ingest kind=turn → always 0.'
    );
  });

  it('delegated_tool_calls counts kind:turn delegated events', () => {
    const eventsContent = [
      // 1 inline (needed for coordinator row to appear)
      JSON.stringify({ kind: 'turn', role: 'coordinator-inline', coordinator: 'evelynn', sessionId: 's1', ts: '2026-04-21T08:00:10.000Z' }),
      // 2 delegated turns
      JSON.stringify({ kind: 'turn', role: 'delegated', coordinator: 'evelynn', sessionId: 's1', agentId: 'ag1', ts: '2026-04-21T08:01:00.000Z' }),
      JSON.stringify({ kind: 'turn', role: 'delegated', coordinator: 'evelynn', sessionId: 's1', agentId: 'ag1', ts: '2026-04-21T08:01:05.000Z' }),
    ].join('\n') + '\n';

    const rows = runSqlAgainstEvents(eventsContent);
    const row = rows.find(r => r.coordinator === 'evelynn');
    assert.ok(row, 'expected a row for coordinator=evelynn');
    assert.strictEqual(Number(row.delegated_tool_calls), 2,
      `delegated_tool_calls must be 2. Got ${row.delegated_tool_calls}. ` +
      'Pre-fix: SQL kind=tool_call never matched ingest kind=turn → always 0.'
    );
  });

  it('kind:tool_call events are NOT counted (confirms C2 fix only counts kind:turn)', () => {
    // If kind='tool_call' events appeared, they would NOT be counted post-fix.
    // This verifies the SQL no longer matches the old kind='tool_call' format.
    const eventsContent = [
      JSON.stringify({ kind: 'tool_call', role: 'coordinator-inline', coordinator: 'evelynn', sessionId: 's1', ts: '2026-04-21T08:00:10.000Z' }),
      JSON.stringify({ kind: 'tool_call', role: 'delegated', coordinator: 'evelynn', sessionId: 's1', ts: '2026-04-21T08:01:00.000Z' }),
      // One turn so there's a row at all
      JSON.stringify({ kind: 'turn', role: 'coordinator-inline', coordinator: 'evelynn', sessionId: 's1', ts: '2026-04-21T08:00:05.000Z' }),
    ].join('\n') + '\n';

    const rows = runSqlAgainstEvents(eventsContent);
    const row = rows.find(r => r.coordinator === 'evelynn');
    assert.ok(row, 'expected a row');
    // tool_call events must not be counted — only the 1 kind:turn inline event counts
    assert.strictEqual(Number(row.inline_tool_calls), 1,
      `Only 1 kind:turn event should count as inline_tool_calls (the 2 kind:tool_call events must NOT be counted). Got ${row.inline_tool_calls}.`
    );
    assert.strictEqual(Number(row.delegated_tool_calls), 0,
      `delegated_tool_calls must be 0 (the kind:tool_call event must NOT be counted). Got ${row.delegated_tool_calls}.`
    );
  });

  it('delegate_ratio is not null when both inline and delegated turns exist', () => {
    const eventsContent = [
      JSON.stringify({ kind: 'turn', role: 'coordinator-inline', coordinator: 'evelynn', sessionId: 's1', ts: '2026-04-21T08:00:10.000Z' }),
      JSON.stringify({ kind: 'turn', role: 'coordinator-inline', coordinator: 'evelynn', sessionId: 's1', ts: '2026-04-21T08:00:20.000Z' }),
      JSON.stringify({ kind: 'turn', role: 'delegated', coordinator: 'evelynn', sessionId: 's1', agentId: 'ag1', ts: '2026-04-21T08:01:00.000Z' }),
      JSON.stringify({ kind: 'turn', role: 'delegated', coordinator: 'evelynn', sessionId: 's1', agentId: 'ag1', ts: '2026-04-21T08:01:05.000Z' }),
    ].join('\n') + '\n';

    const rows = runSqlAgainstEvents(eventsContent);
    const row = rows.find(r => r.coordinator === 'evelynn');
    assert.ok(row, 'expected a row');
    assert.notStrictEqual(row.delegate_ratio, null,
      'delegate_ratio must not be null when turn events exist. Pre-fix: ratio was NULL because all counts were 0.'
    );
    assert.notStrictEqual(row.delegate_health_flag, 'no-data',
      'delegate_health_flag must not be "no-data" when turn events exist. Pre-fix: NULL ratio fell to "executor-mode" (old) or "no-data" (new).'
    );
  });
});
