/**
 * TP3.T3 — xfail snapshot test: home-page lock tile + stale banner rendering states
 *
 * Guards: T.P3.2 (home-page lock tile + stale-banner template extension)
 * Rule 12: this commit lands BEFORE T.P3.2 impl commit.
 * Plan-Ref: plans/approved/personal/2026-04-25-retrospection-dashboard-and-canonical-v1.md
 *
 * xfail: skipped if tools/retro/render.mjs or the Phase-3 lock-tile template is absent.
 * TODO (T.P3.2): implement templates/index.html.tpl lock tile + lib/html-generator.mjs
 *   stale-banner logic, then flip skip.
 *
 * Snapshot states:
 *   fresh-state:       3-day-old retro, 2 bypasses → no stale banner
 *   stale-state:       16-day-old retro → stale banner present, class=lock-banner-stale
 *   boundary-14d:      exactly-14-day → no banner (≤14 is fresh, >14 is stale)
 *   boundary-15d:      15-day → banner present
 *   no-bypass:         0 bypasses this week → class=lock-bypass-clean
 *   lock-week-active:  current date inside lock week → lock-week-active badge present
 *   outside-lock-week: current date outside lock week → badge absent
 *
 * R2 determinism guard: html-generator.mjs must accept a `now` parameter;
 *   tests inject RETRO_RENDER_NOW env var to pin clock.
 */

import { describe, it, before } from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, readFileSync, writeFileSync, mkdirSync, mkdtempSync, copyFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { execSync } from 'node:child_process';
import { tmpdir } from 'node:os';

const __dirname = dirname(fileURLToPath(import.meta.url));
const RETRO_ROOT = join(__dirname, '..');
const RENDER_PATH = join(RETRO_ROOT, 'render.mjs');
const INGEST_PATH = join(RETRO_ROOT, 'ingest.mjs');
const QUERIES_DIR = join(RETRO_ROOT, 'queries');
const FIXTURES_DIR = join(RETRO_ROOT, 'fixtures');
const SNAPSHOTS_DIR = join(__dirname, '__snapshots__');

// xfail guard — render.mjs with Phase-3 lock-tile support not yet implemented
const IMPL_EXISTS = existsSync(RENDER_PATH) && existsSync(INGEST_PATH);
const LOCK_TILE_TEMPLATE_EXISTS = existsSync(join(RETRO_ROOT, 'templates', 'index.html.tpl')) &&
  existsSync(join(RETRO_ROOT, 'lib', 'html-generator.mjs'));
const ALL_IMPL_EXISTS = IMPL_EXISTS && LOCK_TILE_TEMPLATE_EXISTS;
const SKIP_REASON = 'xfail: render.mjs Phase-3 lock-tile support not yet implemented (TODO T.P3.2)';

const UPDATE_SNAPSHOTS = process.env.UPDATE_SNAPSHOTS === '1';

// ---------------------------------------------------------------------------
// Snapshot helper
// ---------------------------------------------------------------------------
function compareSnapshot(name, actual) {
  const snapPath = join(SNAPSHOTS_DIR, name);
  if (UPDATE_SNAPSHOTS) { writeFileSync(snapPath, actual, 'utf8'); return; }
  if (!existsSync(snapPath)) { writeFileSync(snapPath, actual, 'utf8'); return; }
  const expected = readFileSync(snapPath, 'utf8');
  assert.strictEqual(actual, expected,
    `Snapshot mismatch for ${name}. Run with UPDATE_SNAPSHOTS=1 to update.`);
}

// ---------------------------------------------------------------------------
// Render helper — injects RETRO_RENDER_NOW for clock pinning (R2 guard)
// ---------------------------------------------------------------------------
function renderWithLockState({ retroFixturePath, bypassLogPath, lockTagDate, nowIso, lockWeekStart }) {
  const tmp = mkdtempSync(join(tmpdir(), 'retro-lock-tile-'));
  const cacheDir = join(tmp, 'cache');
  const distDir = join(tmp, 'dist');
  mkdirSync(cacheDir, { recursive: true });
  mkdirSync(distDir, { recursive: true });

  // Seed minimal events.jsonl (empty is fine for lock-tile rendering tests)
  writeFileSync(join(cacheDir, 'events.jsonl'), '');

  // Set up architecture fixtures for lock manifest + bypass log
  const archDir = join(tmp, 'architecture');
  mkdirSync(archDir, { recursive: true });
  copyFileSync(join(FIXTURES_DIR, 'canonical-v1-manifest.md'), join(archDir, 'canonical-v1.md'));
  if (bypassLogPath && existsSync(bypassLogPath)) {
    copyFileSync(bypassLogPath, join(archDir, 'canonical-v1-bypasses.md'));
  }
  // Copy the retro ADR fixture (determines days-since-last-retro)
  if (retroFixturePath && existsSync(retroFixturePath)) {
    const retroFile = join(tmp, 'plans', 'implemented', 'personal', 'canonical-v2-rationale-fixture.md');
    mkdirSync(dirname(retroFile), { recursive: true });
    copyFileSync(retroFixturePath, retroFile);
  }

  execSync(
    `node ${RENDER_PATH} --events ${join(cacheDir, 'events.jsonl')} --queries-dir ${QUERIES_DIR} --out-dir ${distDir}`,
    {
      cwd: RETRO_ROOT,
      env: {
        ...process.env,
        RETRO_RENDER_NOW: nowIso || '2026-04-26T09:00:00.000Z',
        RETRO_LOCK_TAG_DATE: lockTagDate || '2026-04-21T00:00:00.000Z',
        RETRO_LOCK_WEEK_START: lockWeekStart || '2026-04-21',
        RETRO_ARCHITECTURE_DIR: archDir,
        RETRO_PLANS_DIR: join(tmp, 'plans')
      }
    }
  );

  const indexPath = join(distDir, 'index.html');
  return existsSync(indexPath) ? readFileSync(indexPath, 'utf8') : '';
}

function dirname(p) { return require('path').dirname(p); }

// ---------------------------------------------------------------------------
// TP3.T3-A: fresh-state snapshot — 3-day-old retro, 2 bypasses → no stale banner
// ---------------------------------------------------------------------------
describe('TP3.T3-A: lock-tile fresh state — 3-day-old retro, no stale banner',
  { skip: !ALL_IMPL_EXISTS ? SKIP_REASON : false }, () => {

  let html;

  before(() => {
    html = renderWithLockState({
      retroFixturePath: join(FIXTURES_DIR, 'canonical-v2-rationale-fresh.md'),
      bypassLogPath: join(FIXTURES_DIR, 'canonical-v1-bypasses-clean.md'),
      nowIso: '2026-04-26T09:00:00.000Z' // 3 days after retro fixture date
    });
  });

  it('index.html renders lock-tile with active lock tag', () => {
    assert.ok(html.includes('canonical-v1'),
      'expected lock-tile to display canonical-v1 lock tag');
  });

  it('fresh state has NO stale banner', () => {
    assert.ok(!html.includes('lock-banner-stale'),
      'expected no stale banner for 3-day-old retro');
  });

  it('fresh-state snapshot matches', () => {
    compareSnapshot('index-lock-tile-fresh.html.snap', html);
  });
});

// ---------------------------------------------------------------------------
// TP3.T3-B: stale-state snapshot — 16-day-old retro → stale banner with class lock-banner-stale
// ---------------------------------------------------------------------------
describe('TP3.T3-B: lock-tile stale state — 16-day-old retro, stale banner present',
  { skip: !ALL_IMPL_EXISTS ? SKIP_REASON : false }, () => {

  let html;

  before(() => {
    html = renderWithLockState({
      retroFixturePath: join(FIXTURES_DIR, 'canonical-v2-rationale-stale.md'),
      bypassLogPath: join(FIXTURES_DIR, 'canonical-v1-bypasses-clean.md'),
      nowIso: '2026-04-26T09:00:00.000Z' // 16 days after stale fixture date
    });
  });

  it('stale state has stale banner with class lock-banner-stale', () => {
    assert.ok(html.includes('lock-banner-stale'),
      'expected stale banner with class lock-banner-stale for 16-day-old retro');
  });

  it('stale banner copy mentions overdue days', () => {
    assert.ok(/overdue|16 days|stale/i.test(html),
      'expected stale banner to mention overdue/days count');
  });

  it('stale-state snapshot matches', () => {
    compareSnapshot('index-lock-tile-stale.html.snap', html);
  });
});

// ---------------------------------------------------------------------------
// TP3.T3-C: boundary — exactly 14 days → NO banner (≤14 fresh, >14 stale)
//           15 days → banner present
// DoD-(c) pins the boundary inclusive/exclusive choice
// ---------------------------------------------------------------------------
describe('TP3.T3-C: lock-tile stale-banner boundary at exactly 14 and 15 days',
  { skip: !ALL_IMPL_EXISTS ? SKIP_REASON : false }, () => {

  it('exactly 14 days since retro → stale banner ABSENT (≤14 is fresh)', () => {
    const html = renderWithLockState({
      retroFixturePath: join(FIXTURES_DIR, 'canonical-v2-rationale-edge-14d.md'),
      bypassLogPath: join(FIXTURES_DIR, 'canonical-v1-bypasses-clean.md'),
      nowIso: '2026-04-26T09:00:00.000Z'
    });
    assert.ok(!html.includes('lock-banner-stale'),
      'expected NO stale banner at exactly 14 days');
  });

  it('15 days since retro → stale banner PRESENT (>14 is stale)', () => {
    const tmp = mkdtempSync(join(tmpdir(), 'retro-lock-15d-'));
    // Create a retro fixture 15 days before "now" (2026-04-26 - 15d = 2026-04-11)
    const retro15d = join(tmp, 'retro-15d.md');
    writeFileSync(retro15d, '---\ndate: 2026-04-11\n---\n# Retro\n');
    const html = renderWithLockState({
      retroFixturePath: retro15d,
      bypassLogPath: join(FIXTURES_DIR, 'canonical-v1-bypasses-clean.md'),
      nowIso: '2026-04-26T09:00:00.000Z'
    });
    assert.ok(html.includes('lock-banner-stale'),
      'expected stale banner at 15 days (>14 is stale)');
  });
});

// ---------------------------------------------------------------------------
// TP3.T3-D: no-bypass snapshot — class lock-bypass-clean
// ---------------------------------------------------------------------------
describe('TP3.T3-D: lock-tile no-bypass state — class lock-bypass-clean',
  { skip: !ALL_IMPL_EXISTS ? SKIP_REASON : false }, () => {

  let html;

  before(() => {
    html = renderWithLockState({
      retroFixturePath: join(FIXTURES_DIR, 'canonical-v2-rationale-fresh.md'),
      bypassLogPath: null, // no bypass log = zero bypasses
      nowIso: '2026-04-26T09:00:00.000Z'
    });
  });

  it('no-bypass state renders class lock-bypass-clean', () => {
    assert.ok(html.includes('lock-bypass-clean'),
      'expected class lock-bypass-clean when no bypasses this week');
  });

  it('no-bypass state renders bypasses this week: 0', () => {
    assert.ok(/bypass.*0|0.*bypass/i.test(html),
      'expected "bypasses this week: 0" in no-bypass tile state');
  });

  it('no-bypass snapshot matches', () => {
    compareSnapshot('index-lock-tile-no-bypass.html.snap', html);
  });
});

// ---------------------------------------------------------------------------
// TP3.T3-E: lock-week-active badge — inside lock week → badge present; outside → absent
// ---------------------------------------------------------------------------
describe('TP3.T3-E: lock-week-active badge — inside vs outside lock week',
  { skip: !ALL_IMPL_EXISTS ? SKIP_REASON : false }, () => {

  it('badge is present when current date is inside the lock week', () => {
    const html = renderWithLockState({
      retroFixturePath: join(FIXTURES_DIR, 'canonical-v2-rationale-fresh.md'),
      bypassLogPath: null,
      nowIso: '2026-04-23T09:00:00.000Z', // mid-lock-week
      lockWeekStart: '2026-04-21'
    });
    assert.ok(html.includes('lock-week-active'),
      'expected lock-week-active badge when current date is inside lock week');
  });

  it('badge is absent when current date is outside the lock week', () => {
    const html = renderWithLockState({
      retroFixturePath: join(FIXTURES_DIR, 'canonical-v2-rationale-fresh.md'),
      bypassLogPath: null,
      nowIso: '2026-04-30T09:00:00.000Z', // after lock week ended
      lockWeekStart: '2026-04-21'
    });
    assert.ok(!html.includes('lock-week-active'),
      'expected no lock-week-active badge when current date is outside lock week');
  });

  it('lock-week-active snapshot matches', () => {
    const html = renderWithLockState({
      retroFixturePath: join(FIXTURES_DIR, 'canonical-v2-rationale-fresh.md'),
      bypassLogPath: null,
      nowIso: '2026-04-23T09:00:00.000Z',
      lockWeekStart: '2026-04-21'
    });
    compareSnapshot('index-lock-week-active.html.snap', html);
  });
});

// ---------------------------------------------------------------------------
// TP3.T3-F: R2 determinism guard — fixed-clock injection prevents flakiness
// DoD-(f): html-generator.mjs accepts a `now` parameter via RETRO_RENDER_NOW env
// ---------------------------------------------------------------------------
describe('TP3.T3-F: lock-tile R2 determinism guard — fixed-clock injection',
  { skip: !ALL_IMPL_EXISTS ? SKIP_REASON : false }, () => {

  it('two renders with the same RETRO_RENDER_NOW produce byte-identical lock-tile HTML', () => {
    const opts = {
      retroFixturePath: join(FIXTURES_DIR, 'canonical-v2-rationale-fresh.md'),
      bypassLogPath: join(FIXTURES_DIR, 'canonical-v1-bypasses-clean.md'),
      nowIso: '2026-04-26T09:00:00.000Z'
    };
    const html1 = renderWithLockState(opts);
    const html2 = renderWithLockState(opts);
    assert.strictEqual(html1, html2, 'lock-tile HTML must be byte-identical across two renders with pinned clock');
  });

  it('lock-tile HTML has no Date.now() / Math.random() / new Date( substrings', () => {
    const html = renderWithLockState({
      retroFixturePath: join(FIXTURES_DIR, 'canonical-v2-rationale-fresh.md'),
      bypassLogPath: join(FIXTURES_DIR, 'canonical-v1-bypasses-clean.md'),
      nowIso: '2026-04-26T09:00:00.000Z'
    });
    const NON_DET = [/Date\.now\(\)/, /Math\.random\(\)/, /process\.pid/, /new Date\(/];
    for (const re of NON_DET) {
      assert.ok(!re.test(html),
        `lock-tile HTML contains non-deterministic expression: ${re}`);
    }
  });
});

// ---------------------------------------------------------------------------
// TP3.T3-G: §Q4 SPA-rejection guard carried forward
// ---------------------------------------------------------------------------
describe('TP3.T3-G: §Q4 SPA-rejection guard on lock-tile HTML',
  { skip: !ALL_IMPL_EXISTS ? SKIP_REASON : false }, () => {

  let html;
  before(() => {
    html = renderWithLockState({
      retroFixturePath: join(FIXTURES_DIR, 'canonical-v2-rationale-fresh.md'),
      bypassLogPath: join(FIXTURES_DIR, 'canonical-v1-bypasses-clean.md'),
      nowIso: '2026-04-26T09:00:00.000Z'
    });
  });

  it('index.html (with lock tile) has no vue/pinia/vue-router imports', () => {
    assert.ok(!/vue|pinia|vue-router/i.test(html.replace(/<!--.*?-->/gs, '')),
      'lock-tile index must not import vue/pinia/vue-router');
  });
});
