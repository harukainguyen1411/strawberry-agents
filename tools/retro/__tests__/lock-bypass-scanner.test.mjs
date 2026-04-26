/**
 * TP3.T1 — xfail unit test: lock-bypass scanner I-LOCK-1 / I-LOCK-2 / I-LOCK-5 invariants
 *
 * Guards: T.P3.1 (tools/retro/lib/lock-bypass.mjs + ingest wiring)
 * Rule 12: this commit lands BEFORE T.P3.1 impl commit.
 * Plan-Ref: plans/approved/personal/2026-04-25-retrospection-dashboard-and-canonical-v1.md
 *
 * xfail: skipped if tools/retro/lib/lock-bypass.mjs is absent (T.P3.1 not yet landed).
 * TODO (T.P3.1): implement lib/lock-bypass.mjs + ingest wiring + architecture/canonical-v1-bypasses.md,
 *   then flip skip.
 *
 * Invariants tested:
 *   I-LOCK-1: manifest-path commit without Lock-Bypass: trailer → kind:lock-violation
 *   I-LOCK-2: Lock-Bypass: trailer on non-manifest commit → kind:lock-violation (spurious trailer)
 *   I-LOCK-5: pre-lock-tag commits → ZERO violation events regardless of trailer
 *
 * Cross-plan dependency T.COORD.3 → T.P3.1:
 *   scanner must exit non-zero with named diagnostic when architecture/canonical-v1.md is absent
 */

import { describe, it, before } from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, readFileSync, writeFileSync, mkdirSync, mkdtempSync, copyFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { execSync, spawnSync } from 'node:child_process';
import { tmpdir } from 'node:os';

const __dirname = dirname(fileURLToPath(import.meta.url));
const RETRO_ROOT = join(__dirname, '..');
const SCANNER_PATH = join(RETRO_ROOT, 'lib', 'lock-bypass.mjs');
const INGEST_PATH = join(RETRO_ROOT, 'ingest.mjs');
const FIXTURES_DIR = join(RETRO_ROOT, 'fixtures');

// xfail guard — lib/lock-bypass.mjs does not exist yet (T.P3.1 lands it)
const IMPL_EXISTS = existsSync(SCANNER_PATH);
const SKIP_REASON = 'xfail: lib/lock-bypass.mjs not yet implemented (TODO T.P3.1)';

// Fixture paths
const MANIFEST_FIXTURE = join(FIXTURES_DIR, 'canonical-v1-manifest.md');
const GIT_LOG_BYPASS = join(FIXTURES_DIR, 'git-log-with-bypass.json');
const GIT_LOG_CLEAN = join(FIXTURES_DIR, 'git-log-clean-week.json');
const GIT_LOG_PRE_LOCK = join(FIXTURES_DIR, 'git-log-pre-lock.json');

// Lazy import
let runLockBypassScanner;
if (IMPL_EXISTS) {
  const mod = await import(SCANNER_PATH);
  runLockBypassScanner = mod.runLockBypassScanner ?? mod.default;
}

// ---------------------------------------------------------------------------
// Helper: run scanner with fixture manifest and git-log, return emitted events
// ---------------------------------------------------------------------------
function scanWithFixtures(gitLogFixturePath, manifestPath) {
  if (!IMPL_EXISTS) return [];
  const tmp = mkdtempSync(join(tmpdir(), 'retro-lock-scan-'));
  const eventsPath = join(tmp, 'events.jsonl');
  const result = runLockBypassScanner({
    gitLogPath: gitLogFixturePath,
    manifestPath: manifestPath || MANIFEST_FIXTURE,
    eventsPath,
    lockTagDate: '2026-04-21T00:00:00.000Z' // lock starts on this date
  });
  if (!existsSync(eventsPath)) return [];
  return readFileSync(eventsPath, 'utf8')
    .split('\n')
    .filter(Boolean)
    .map(l => JSON.parse(l));
}

// ---------------------------------------------------------------------------
// TP3.T1-A: manifest fixture covers 8 paths spanning 4 lock-set categories
// DoD-(a): agent defs, agents-network, CLAUDE.md, settings.json
// ---------------------------------------------------------------------------
describe('TP3.T1-A: lock-bypass scanner — manifest fixture has adequate path coverage',
  { skip: !IMPL_EXISTS ? SKIP_REASON : false }, () => {

  it('canonical-v1-manifest.md fixture exists', () => {
    assert.ok(existsSync(MANIFEST_FIXTURE),
      `canonical-v1-manifest.md fixture must exist at ${MANIFEST_FIXTURE}`);
  });

  it('manifest fixture contains at least 8 locked paths', () => {
    const content = readFileSync(MANIFEST_FIXTURE, 'utf8');
    // Each locked path is expected on its own line starting with - or |
    const pathLines = content.split('\n').filter(l =>
      l.includes('.claude/agents/') || l.includes('CLAUDE.md') ||
      l.includes('settings.json') || l.includes('agent-network')
    );
    assert.ok(pathLines.length >= 8,
      `expected at least 8 manifest path lines, found ${pathLines.length}`);
  });
});

// ---------------------------------------------------------------------------
// TP3.T1-B: I-LOCK-1 — manifest-path commit WITH Lock-Bypass: trailer → kind:lock-bypass
// ---------------------------------------------------------------------------
describe('TP3.T1-B: I-LOCK-1 — Lock-Bypass: trailer emits kind:lock-bypass event',
  { skip: !IMPL_EXISTS ? SKIP_REASON : false }, () => {

  let events;
  before(() => { events = scanWithFixtures(GIT_LOG_BYPASS); });

  it('emits at least one kind:lock-bypass event', () => {
    const bypassEvents = events.filter(e => e.kind === 'lock-bypass');
    assert.ok(bypassEvents.length >= 1, 'expected at least one kind:lock-bypass event');
  });

  it('lock-bypass event carries severity field from the trailer', () => {
    const bypassEvent = events.find(e => e.kind === 'lock-bypass');
    assert.ok(bypassEvent, 'expected a lock-bypass event');
    assert.ok(['low', 'medium', 'high'].includes(bypassEvent.severity),
      `expected severity to be low/medium/high, got: ${bypassEvent.severity}`);
  });
});

// ---------------------------------------------------------------------------
// TP3.T1-C: I-LOCK-1 violation — manifest-path commit WITHOUT Lock-Bypass: trailer → kind:lock-violation
// ---------------------------------------------------------------------------
describe('TP3.T1-C: I-LOCK-1 violation — missing trailer on manifest-path commit → lock-violation',
  { skip: !IMPL_EXISTS ? SKIP_REASON : false }, () => {

  let events;
  before(() => {
    // Use the bypass git-log but strip the trailer from the fixture
    const gitLogContent = JSON.parse(readFileSync(GIT_LOG_BYPASS, 'utf8'));
    const withoutTrailer = gitLogContent.map(c => ({
      ...c,
      trailers: (c.trailers || []).filter(t => !t.key?.startsWith('Lock-Bypass'))
    }));
    const tmp = mkdtempSync(join(tmpdir(), 'retro-lock-v-'));
    const noTrailerPath = join(tmp, 'git-log-no-trailer.json');
    writeFileSync(noTrailerPath, JSON.stringify(withoutTrailer));
    events = scanWithFixtures(noTrailerPath);
  });

  it('emits kind:lock-violation for missing trailer on manifest-path commit', () => {
    const violations = events.filter(e => e.kind === 'lock-violation');
    assert.ok(violations.length >= 1, 'expected a lock-violation event for missing Lock-Bypass trailer');
  });

  it('lock-violation diagnostic mentions missing Lock-Bypass trailer', () => {
    const v = events.find(e => e.kind === 'lock-violation');
    assert.ok(v, 'expected a lock-violation event');
    const diag = (v.diagnostic || '').toLowerCase();
    assert.ok(
      diag.includes('lock-bypass') || diag.includes('missing') || diag.includes('trailer'),
      `expected diagnostic to mention Lock-Bypass/missing/trailer, got: ${v.diagnostic}`
    );
  });
});

// ---------------------------------------------------------------------------
// TP3.T1-D: I-LOCK-2 — Lock-Bypass: trailer on NON-manifest commit → kind:lock-violation (spurious trailer)
// DoD-(d): guards against trailer-noise discipline drift
// ---------------------------------------------------------------------------
describe('TP3.T1-D: I-LOCK-2 — spurious Lock-Bypass: trailer on non-manifest commit → lock-violation',
  { skip: !IMPL_EXISTS ? SKIP_REASON : false }, () => {

  let events;
  before(() => {
    // Create a git-log fixture with a Lock-Bypass: trailer on a non-manifest path commit
    const spuriousLog = [{
      sha: 'deadbeef0001',
      subject: 'chore: update apps/web/foo.ts',
      authorDate: '2026-04-22T10:00:00.000Z', // within lock week
      touchedFiles: ['apps/web/foo.ts'],
      trailers: [{ key: 'Lock-Bypass', value: 'spurious trailer on non-manifest path' }]
    }];
    const tmp = mkdtempSync(join(tmpdir(), 'retro-lock-spurious-'));
    const spuriousPath = join(tmp, 'git-log-spurious.json');
    writeFileSync(spuriousPath, JSON.stringify(spuriousLog));
    events = scanWithFixtures(spuriousPath);
  });

  it('emits kind:lock-violation for spurious Lock-Bypass: trailer on non-manifest commit', () => {
    const violations = events.filter(e => e.kind === 'lock-violation');
    assert.ok(violations.length >= 1,
      'expected a lock-violation event for spurious Lock-Bypass: trailer on non-manifest commit');
  });

  it('lock-violation diagnostic mentions spurious trailer', () => {
    const v = events.find(e => e.kind === 'lock-violation');
    assert.ok(v, 'expected a lock-violation event');
    const diag = (v.diagnostic || '').toLowerCase();
    assert.ok(
      diag.includes('spurious') || diag.includes('non-manifest') || diag.includes('bypass'),
      `expected diagnostic to mention spurious/non-manifest/bypass, got: ${v.diagnostic}`
    );
  });
});

// ---------------------------------------------------------------------------
// TP3.T1-E: I-LOCK-5 — pre-lock-tag commits emit ZERO violation events
// Lock applies only within the lock-week (after lock-tag commit date)
// ---------------------------------------------------------------------------
describe('TP3.T1-E: I-LOCK-5 — pre-lock-tag commits never emit violations',
  { skip: !IMPL_EXISTS ? SKIP_REASON : false }, () => {

  let events;
  before(() => { events = scanWithFixtures(GIT_LOG_PRE_LOCK); });

  it('emits zero violation events for pre-lock-tag commits (even with manifest-path edits)', () => {
    const violations = events.filter(e =>
      e.kind === 'lock-violation' || e.kind === 'lock-bypass'
    );
    assert.deepEqual(violations, [],
      `expected zero lock events for pre-lock-tag commits, got: ${JSON.stringify(violations)}`);
  });
});

// ---------------------------------------------------------------------------
// TP3.T1-F: scanner determinism — byte-identical output across two runs
// ---------------------------------------------------------------------------
describe('TP3.T1-F: scanner determinism — byte-identical events.jsonl across two runs',
  { skip: !IMPL_EXISTS ? SKIP_REASON : false }, () => {

  it('two consecutive scanner runs over the same fixture produce byte-identical events', () => {
    const run1 = scanWithFixtures(GIT_LOG_BYPASS);
    const run2 = scanWithFixtures(GIT_LOG_BYPASS);
    assert.deepEqual(run1, run2, 'lock-bypass scanner must be deterministic');
  });
});

// ---------------------------------------------------------------------------
// TP3.T1-G: manifest-missing failure — exits non-zero with named diagnostic
// Cross-plan dependency T.COORD.3 → T.P3.1: manifest must exist for scanner to run
// ---------------------------------------------------------------------------
describe('TP3.T1-G: scanner — exits non-zero when architecture/canonical-v1.md is absent',
  { skip: !IMPL_EXISTS ? SKIP_REASON : false }, () => {

  it('scanner exits non-zero when manifest is missing', () => {
    const tmp = mkdtempSync(join(tmpdir(), 'retro-lock-no-manifest-'));
    const eventsPath = join(tmp, 'events.jsonl');
    let threw = false;
    try {
      runLockBypassScanner({
        gitLogPath: GIT_LOG_BYPASS,
        manifestPath: join(tmp, 'canonical-v1.md'), // does not exist
        eventsPath,
        lockTagDate: '2026-04-21T00:00:00.000Z'
      });
    } catch (err) {
      threw = true;
      const msg = (err.message || '').toLowerCase();
      assert.ok(
        msg.includes('manifest') || msg.includes('canonical-v1') || msg.includes('t.coord.3'),
        `expected error message to mention manifest/canonical-v1/T.COORD.3, got: ${err.message}`
      );
    }
    assert.ok(threw, 'scanner must throw when manifest is missing');
  });
});

// ---------------------------------------------------------------------------
// TP3.T1-H: cross-plan dependency exercise — manifest path-set loaded from fixture
// Guards against impl drifting to hard-coded path-list instead of reading the manifest
// ---------------------------------------------------------------------------
describe('TP3.T1-H: scanner loads manifest path-set from file (not hard-coded)',
  { skip: !IMPL_EXISTS ? SKIP_REASON : false }, () => {

  it('replacing manifest with a fixture-only manifest changes which commits are flagged', () => {
    // Create a minimal manifest with only one path: .claude/settings.json
    const tmp = mkdtempSync(join(tmpdir(), 'retro-lock-minimal-manifest-'));
    const minimalManifest = join(tmp, 'minimal-manifest.md');
    writeFileSync(minimalManifest,
      '# Minimal lock manifest\n\n## Locked paths\n- .claude/settings.json\n');
    const eventsWithMinimal = scanWithFixtures(GIT_LOG_BYPASS, minimalManifest);

    // Full manifest events
    const eventsWithFull = scanWithFixtures(GIT_LOG_BYPASS, MANIFEST_FIXTURE);

    // The two runs may produce different event counts if the bypass fixture touches multiple paths
    // Key assertion: scanner uses the manifest dynamically, not a hard-coded list
    // We verify this by checking that the minimal-manifest run does NOT flag agent-def paths
    const agentDefViolations = eventsWithMinimal.filter(e =>
      (e.kind === 'lock-bypass' || e.kind === 'lock-violation') &&
      (e.touchedFiles || []).some(f => f.includes('.claude/agents/') && !f.includes('settings.json'))
    );
    assert.deepEqual(agentDefViolations, [],
      'minimal manifest should not flag agent-def paths (only settings.json is locked)');
  });
});
