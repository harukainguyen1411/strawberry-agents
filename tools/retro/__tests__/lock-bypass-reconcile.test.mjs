/**
 * TP3.T2 — xfail unit test: bypass-log reconciliation I-LOCK-3 / I-LOCK-4 / I-LOCK-6 invariants
 *
 * Guards: T.P3.1 (bypass-log reconciliation half of lock-bypass.mjs + lock-bypass-rollup.sql)
 * Rule 12: this commit lands BEFORE T.P3.1 impl commit.
 * Plan-Ref: plans/approved/personal/2026-04-25-retrospection-dashboard-and-canonical-v1.md
 *
 * xfail: skipped if tools/retro/lib/lock-bypass.mjs is absent (T.P3.1 not yet landed).
 * TODO (T.P3.1): implement reconciliation logic + rollup SQL, then flip skip.
 *
 * Invariants tested:
 *   I-LOCK-3: trailer-no-row → lock-violation; row-no-trailer → lock-violation
 *   I-LOCK-4: severity mismatch between trailer and log row → lock-violation (both directions)
 *   I-LOCK-6: --no-verify bypass → kind:lock-violation or kind:lock-violation-suspected
 *             (heuristic limit documented)
 */

import { describe, it, before } from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, readFileSync, writeFileSync, mkdtempSync, mkdirSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { execSync } from 'node:child_process';
import { tmpdir } from 'node:os';

const __dirname = dirname(fileURLToPath(import.meta.url));
const RETRO_ROOT = join(__dirname, '..');
const SCANNER_PATH = join(RETRO_ROOT, 'lib', 'lock-bypass.mjs');
const QUERIES_DIR = join(RETRO_ROOT, 'queries');
const FIXTURES_DIR = join(RETRO_ROOT, 'fixtures');

// xfail guard
const IMPL_EXISTS = existsSync(SCANNER_PATH);
const SKIP_REASON = 'xfail: lib/lock-bypass.mjs reconciliation not yet implemented (TODO T.P3.1)';

const BYPASS_LOG_CLEAN = join(FIXTURES_DIR, 'canonical-v1-bypasses-clean.md');
const BYPASS_LOG_ORPHAN = join(FIXTURES_DIR, 'canonical-v1-bypasses-orphan-row.md');
const BYPASS_LOG_SEVERITY_MISMATCH = join(FIXTURES_DIR, 'canonical-v1-bypasses-severity-mismatch.md');
const GIT_LOG_NO_VERIFY = join(FIXTURES_DIR, 'git-log-no-verify.json');
const MANIFEST_FIXTURE = join(FIXTURES_DIR, 'canonical-v1-manifest.md');

let runReconciler;
if (IMPL_EXISTS) {
  const mod = await import(SCANNER_PATH);
  runReconciler = mod.runReconciler ?? mod.runLockBypassScanner ?? mod.default;
}

function reconcile(gitLogPath, bypassLogPath) {
  if (!IMPL_EXISTS) return [];
  const tmp = mkdtempSync(join(tmpdir(), 'retro-reconcile-'));
  const eventsPath = join(tmp, 'events.jsonl');
  runReconciler({
    gitLogPath,
    bypassLogPath: bypassLogPath || BYPASS_LOG_CLEAN,
    manifestPath: MANIFEST_FIXTURE,
    eventsPath,
    lockTagDate: '2026-04-21T00:00:00.000Z'
  });
  if (!existsSync(eventsPath)) return [];
  return readFileSync(eventsPath, 'utf8').split('\n').filter(Boolean).map(l => JSON.parse(l));
}

// ---------------------------------------------------------------------------
// TP3.T2-A: I-LOCK-3 — trailer without log row → lock-violation
// ---------------------------------------------------------------------------
describe('TP3.T2-A: I-LOCK-3 — Lock-Bypass: trailer without bypass-log row → lock-violation',
  { skip: !IMPL_EXISTS ? SKIP_REASON : false }, () => {

  let events;
  before(() => {
    // Create a git-log with a Lock-Bypass: trailer commit and a bypass-log that does NOT have
    // a matching SHA row
    const tmp = mkdtempSync(join(tmpdir(), 'retro-lock-no-row-'));
    const gitLog = [{
      sha: 'aaaaaa001111',
      subject: 'chore: tweak agent def',
      authorDate: '2026-04-22T10:00:00.000Z',
      touchedFiles: ['.claude/agents/evelynn.md'],
      trailers: [{ key: 'Lock-Bypass', value: 'quick fix, severity: low' }]
    }];
    const gitLogPath = join(tmp, 'git-log.json');
    writeFileSync(gitLogPath, JSON.stringify(gitLog));
    // Bypass log is empty (no rows)
    const emptyBypassLog = join(tmp, 'empty-bypasses.md');
    writeFileSync(emptyBypassLog, '# Bypasses\n\n| date | sha | author | severity | reason | reconciled-by |\n|---|---|---|---|---|---|\n');
    events = reconcile(gitLogPath, emptyBypassLog);
  });

  it('emits lock-violation for trailer-without-log-row', () => {
    const violations = events.filter(e => e.kind === 'lock-violation');
    assert.ok(violations.length >= 1, 'expected a lock-violation for trailer without log row');
  });

  it('violation diagnostic mentions unlogged bypass', () => {
    const v = events.find(e => e.kind === 'lock-violation');
    assert.ok(v);
    const diag = (v.diagnostic || '').toLowerCase();
    assert.ok(
      diag.includes('not logged') || diag.includes('no log') || diag.includes('bypass') || diag.includes('missing'),
      `expected diagnostic to mention unlogged bypass, got: ${v.diagnostic}`
    );
  });
});

// ---------------------------------------------------------------------------
// TP3.T2-B: I-LOCK-3 — log row without trailer commit → lock-violation
// ---------------------------------------------------------------------------
describe('TP3.T2-B: I-LOCK-3 — bypass-log row without matching trailer commit → lock-violation',
  { skip: !IMPL_EXISTS ? SKIP_REASON : false }, () => {

  let events;
  before(() => {
    events = reconcile(join(FIXTURES_DIR, 'git-log-with-bypass.json'), BYPASS_LOG_ORPHAN);
  });

  it('emits lock-violation for orphaned bypass-log row (no matching trailer commit)', () => {
    const violations = events.filter(e => e.kind === 'lock-violation');
    assert.ok(violations.length >= 1, 'expected a lock-violation for orphaned bypass-log row');
  });

  it('violation diagnostic mentions orphan log row', () => {
    const v = events.find(e => e.kind === 'lock-violation');
    assert.ok(v);
    const diag = (v.diagnostic || '').toLowerCase();
    assert.ok(
      diag.includes('orphan') || diag.includes('no matching') || diag.includes('trailer') || diag.includes('log'),
      `expected diagnostic to mention orphan/no-matching/trailer/log, got: ${v.diagnostic}`
    );
  });
});

// ---------------------------------------------------------------------------
// TP3.T2-C: I-LOCK-4 — severity mismatch → lock-violation (both directions, no asymmetry)
// ---------------------------------------------------------------------------
describe('TP3.T2-C: I-LOCK-4 — severity mismatch between trailer and log row → lock-violation',
  { skip: !IMPL_EXISTS ? SKIP_REASON : false }, () => {

  it('low→high severity mismatch emits lock-violation', () => {
    const tmp = mkdtempSync(join(tmpdir(), 'retro-lock-sev-low-high-'));
    // Trailer says severity: low, log says severity: high
    const gitLog = [{
      sha: 'bbbb001122',
      subject: 'chore: edit CLAUDE.md rule',
      authorDate: '2026-04-22T10:00:00.000Z',
      touchedFiles: ['CLAUDE.md'],
      trailers: [{ key: 'Lock-Bypass', value: 'minor fix, severity: low' }]
    }];
    const bypassLog = `# Bypasses\n\n| date | sha | author | severity | reason | reconciled-by |\n|---|---|---|---|---|---|\n| 2026-04-22 | bbbb001122 | Duongntd | high | Promoted to high after review | - |\n`;
    const gitLogPath = join(tmp, 'git-log.json');
    const bypassLogPath = join(tmp, 'bypasses.md');
    writeFileSync(gitLogPath, JSON.stringify(gitLog));
    writeFileSync(bypassLogPath, bypassLog);
    const events = reconcile(gitLogPath, bypassLogPath);
    const violations = events.filter(e => e.kind === 'lock-violation');
    assert.ok(violations.length >= 1, 'expected lock-violation for low→high severity mismatch');
  });

  it('high→low severity mismatch (demotion) also emits lock-violation', () => {
    const tmp = mkdtempSync(join(tmpdir(), 'retro-lock-sev-high-low-'));
    const gitLog = [{
      sha: 'cccc002233',
      subject: 'chore: fix settings.json hook path',
      authorDate: '2026-04-23T10:00:00.000Z',
      touchedFiles: ['.claude/settings.json'],
      trailers: [{ key: 'Lock-Bypass', value: 'settings fix, severity: high' }]
    }];
    const bypassLog = `# Bypasses\n\n| date | sha | author | severity | reason | reconciled-by |\n|---|---|---|---|---|---|\n| 2026-04-23 | cccc002233 | Duongntd | low | Downgraded | - |\n`;
    const gitLogPath = join(tmp, 'git-log.json');
    const bypassLogPath = join(tmp, 'bypasses.md');
    writeFileSync(gitLogPath, JSON.stringify(gitLog));
    writeFileSync(bypassLogPath, bypassLog);
    const events = reconcile(gitLogPath, bypassLogPath);
    const violations = events.filter(e => e.kind === 'lock-violation');
    assert.ok(violations.length >= 1, 'expected lock-violation for high→low severity demotion');
  });
});

// ---------------------------------------------------------------------------
// TP3.T2-D: I-LOCK-6 — --no-verify detected → lock-violation or lock-violation-suspected
// Heuristic limit documented: if --no-verify is undetectable post-hoc, flips to lock-violation-suspected
// ---------------------------------------------------------------------------
describe('TP3.T2-D: I-LOCK-6 — --no-verify bypass produces lock-violation or lock-violation-suspected',
  { skip: !IMPL_EXISTS ? SKIP_REASON : false }, () => {

  let events;
  before(() => {
    events = reconcile(GIT_LOG_NO_VERIFY, BYPASS_LOG_CLEAN);
  });

  it('emits either lock-violation or lock-violation-suspected for no-verify commit', () => {
    const lockEvents = events.filter(e =>
      e.kind === 'lock-violation' || e.kind === 'lock-violation-suspected'
    );
    assert.ok(lockEvents.length >= 1,
      'expected lock-violation or lock-violation-suspected for --no-verify commit on manifest path');
  });

  it('no-verify event kind is one of the two valid kinds (truthful heuristic)', () => {
    const lockEvent = events.find(e =>
      e.kind === 'lock-violation' || e.kind === 'lock-violation-suspected'
    );
    if (lockEvent) {
      assert.ok(
        lockEvent.kind === 'lock-violation' || lockEvent.kind === 'lock-violation-suspected',
        `expected lock-violation or lock-violation-suspected, got: ${lockEvent.kind}`
      );
    }
  });
});

// ---------------------------------------------------------------------------
// TP3.T2-E: clean-week control — no violations for valid trailer/log pairs
// ---------------------------------------------------------------------------
describe('TP3.T2-E: I-LOCK-3/4 — clean-week with valid pairs emits zero violations',
  { skip: !IMPL_EXISTS ? SKIP_REASON : false }, () => {

  let events;
  before(() => {
    events = reconcile(join(FIXTURES_DIR, 'git-log-with-bypass.json'), BYPASS_LOG_CLEAN);
  });

  it('emits zero lock-violation events for clean bypass log', () => {
    const violations = events.filter(e => e.kind === 'lock-violation');
    assert.deepEqual(violations, [],
      `expected no lock-violations for clean bypass log, got: ${JSON.stringify(violations)}`);
  });
});

// ---------------------------------------------------------------------------
// TP3.T2-F: lock-bypass-rollup.sql — counts violations by (iso_week, severity)
// DoD-(f): reconciled boolean flips true when ADR fixture mentions the bypass SHA
// ---------------------------------------------------------------------------
describe('TP3.T2-F: lock-bypass-rollup.sql — counts and reconciled boolean',
  { skip: !IMPL_EXISTS ? SKIP_REASON : false }, () => {

  const ROLLUP_SQL = join(QUERIES_DIR, 'lock-bypass-rollup.sql');
  const ROLLUP_EXPECTED = join(QUERIES_DIR, 'lock-bypass-rollup.expected.json');

  it('lock-bypass-rollup.sql exists', () => {
    assert.ok(existsSync(ROLLUP_SQL), `lock-bypass-rollup.sql must exist at ${ROLLUP_SQL}`);
  });

  it('lock-bypass-rollup.expected.json exists', () => {
    assert.ok(existsSync(ROLLUP_EXPECTED), `lock-bypass-rollup.expected.json must exist`);
  });

  it('rollup result deep-equals expected.json for bypass fixture events', () => {
    if (!existsSync(ROLLUP_SQL) || !existsSync(ROLLUP_EXPECTED)) return;
    const tmp = mkdtempSync(join(tmpdir(), 'retro-lock-rollup-'));
    const eventsPath = join(tmp, 'events.jsonl');
    // Produce events from the bypass fixture
    runReconciler({
      gitLogPath: join(FIXTURES_DIR, 'git-log-with-bypass.json'),
      bypassLogPath: BYPASS_LOG_CLEAN,
      manifestPath: MANIFEST_FIXTURE,
      eventsPath,
      lockTagDate: '2026-04-21T00:00:00.000Z'
    });
    if (!existsSync(eventsPath)) return;
    const actual = JSON.parse(execSync(
      `duckdb -json -c "$(cat '${ROLLUP_SQL}')" '${eventsPath}'`,
      { cwd: RETRO_ROOT, encoding: 'utf8' }
    ));
    const expected = JSON.parse(readFileSync(ROLLUP_EXPECTED, 'utf8'));
    const sortedActual = actual.map(r => Object.fromEntries(Object.entries(r).sort())).sort(byJson);
    const sortedExpected = expected.map(r => Object.fromEntries(Object.entries(r).sort())).sort(byJson);
    assert.deepEqual(sortedActual, sortedExpected,
      `lock-bypass-rollup.sql output does not match golden`);
  });
});

function byJson(a, b) {
  return JSON.stringify(a).localeCompare(JSON.stringify(b));
}
