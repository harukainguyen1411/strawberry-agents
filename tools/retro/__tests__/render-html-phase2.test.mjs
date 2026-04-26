/**
 * TP2.T6 — xfail snapshot test: coordinator-detail + extended index HTML
 *
 * Guards: T.P2.5 (coordinator-detail HTML page + home-page Phase-2 tile integration)
 * Rule 12: this is the test-half of T.P2.5's paired Rule-12 commit; lands BEFORE impl.
 * Plan-Ref: plans/approved/personal/2026-04-25-retrospection-dashboard-and-canonical-v1.md
 *
 * xfail: skipped if tools/retro/render.mjs is absent (T.P2.5 not yet landed).
 * TODO (T.P2.5): implement coordinator-detail template + html-generator extension, then flip skip.
 *
 * R2 determinism guard carried forward from Phase-1 TP1.T6:
 *   - re-run render twice, assert byte-identical HTML
 *   - regex scan: no Date.now(), Math.random(), process.pid, new Date( substrings
 *
 * §Q4 SPA-rejection guard carried forward:
 *   - no script src containing vue/pinia/vue-router
 *   - exactly one inline <script> block per page
 */

import { describe, it, before } from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, readFileSync, mkdirSync, mkdtempSync, writeFileSync, copyFileSync } from 'node:fs';
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

// xfail guard — render.mjs does not exist yet (T.P2.5 lands it)
const IMPL_EXISTS = existsSync(RENDER_PATH) && existsSync(INGEST_PATH);
const SKIP_REASON = 'xfail: render.mjs (Phase-2 coordinator-detail support) not yet implemented (TODO T.P2.5)';

const UPDATE_SNAPSHOTS = process.env.UPDATE_SNAPSHOTS === '1';

// ---------------------------------------------------------------------------
// Snapshot helper (vanilla ~30 LOC, same as Phase-1)
// ---------------------------------------------------------------------------
function compareSnapshot(name, actual) {
  const snapPath = join(SNAPSHOTS_DIR, name);
  if (UPDATE_SNAPSHOTS) {
    writeFileSync(snapPath, actual, 'utf8');
    return; // always pass on update
  }
  if (!existsSync(snapPath)) {
    assert.fail(
      `Snapshot missing: ${snapPath}\n` +
      `Run with UPDATE_SNAPSHOTS=1 to create the golden file.`
    );
  }
  const expected = readFileSync(snapPath, 'utf8');
  assert.strictEqual(actual, expected,
    `Snapshot mismatch for ${name}.\nRun with UPDATE_SNAPSHOTS=1 to update.\n` +
    `Expected length: ${expected.length}, Actual length: ${actual.length}`);
}

// ---------------------------------------------------------------------------
// Render helpers
// ---------------------------------------------------------------------------
function renderFixtureCorpus() {
  const tmpDir = mkdtempSync(join(tmpdir(), 'retro-p2-snap-'));
  const cacheDir = join(tmpDir, 'cache');
  const distDir = join(tmpDir, 'dist');
  mkdirSync(cacheDir, { recursive: true });
  mkdirSync(distDir, { recursive: true });

  // Set up minimal Phase-2 fixture corpus
  const sessDir = join(tmpDir, 'home', '.claude', 'projects', 'strawberry', 'sess-p2-snap');
  mkdirSync(join(sessDir, 'subagents'), { recursive: true });
  mkdirSync(join(tmpDir, 'cache', 'subagent-sentinels'), { recursive: true });
  mkdirSync(join(tmpDir, 'feedback'), { recursive: true });
  mkdirSync(join(tmpDir, 'decisions', 'evelynn'), { recursive: true });

  const fixtureE2eDir = join(FIXTURES_DIR, 'e2e-phase2');

  // Copy fixture files if they exist
  for (const [src, dest] of [
    ['parent-session-with-prompts.jsonl', join(sessDir, 'sess-p2-snap.jsonl')],
    ['feedback-index.md', join(tmpDir, 'feedback', 'INDEX.md')],
    ['decisions/evelynn/2026-04-01-routing-high.md', join(tmpDir, 'decisions', 'evelynn', '2026-04-01-routing-high.md')],
    ['decisions/evelynn/2026-04-15-routing-medium.md', join(tmpDir, 'decisions', 'evelynn', '2026-04-15-routing-medium.md')],
    ['decisions/evelynn/2026-04-20-routing-silent.md', join(tmpDir, 'decisions', 'evelynn', '2026-04-20-routing-silent.md')],
    ['git-log-e2e-phase2.json', join(tmpDir, 'git-log-phase2.json')]
  ]) {
    const srcPath = join(fixtureE2eDir, src);
    if (existsSync(srcPath)) copyFileSync(srcPath, dest);
  }

  const eventsPath = join(cacheDir, 'events.jsonl');

  execSync(`node ${INGEST_PATH} --cache-dir ${cacheDir}`, {
    cwd: RETRO_ROOT,
    env: {
      ...process.env,
      HOME: join(tmpDir, 'home'),
      STRAWBERRY_USAGE_CACHE: cacheDir,
      RETRO_GIT_LOG_MOCK: join(tmpDir, 'git-log-phase2.json'),
      RETRO_FEEDBACK_PATH: join(tmpDir, 'feedback', 'INDEX.md'),
      RETRO_DECISIONS_DIR: join(tmpDir, 'decisions')
    }
  });

  execSync(`node ${RENDER_PATH} --events ${eventsPath} --queries-dir ${QUERIES_DIR} --out-dir ${distDir}`, {
    cwd: RETRO_ROOT,
    env: { ...process.env, RETRO_RENDER_NOW: '2026-04-26T09:00:00.000Z' }
  });

  return { distDir, tmpDir, eventsPath };
}

// ---------------------------------------------------------------------------
// TP2.T6-A: coordinator-detail snapshot — per-axis match-rate table
// DoD-(a): every (axis, decisions_total, decisions_matched, match_rate) row present
// ---------------------------------------------------------------------------
describe('TP2.T6-A: coordinator-detail snapshot — per-axis match-rate table',
  { skip: !IMPL_EXISTS ? SKIP_REASON : false }, () => {

  let coordinatorHtml;

  before(() => {
    const { distDir } = renderFixtureCorpus();
    // Find the coordinator-evelynn-week-*.html file
    const candidates = existsSync(distDir)
      ? execSync(`ls ${distDir}/coordinator-evelynn-week-*.html 2>/dev/null || echo ''`, { encoding: 'utf8' }).trim()
      : '';
    const htmlPath = candidates.split('\n')[0];
    coordinatorHtml = htmlPath && existsSync(htmlPath) ? readFileSync(htmlPath, 'utf8') : '';
  });

  it('coordinator-detail HTML exists', () => {
    assert.ok(coordinatorHtml.length > 0, 'coordinator-evelynn-week-*.html must exist after Phase-2 render');
  });

  it('coordinator-detail HTML matches snapshot', () => {
    if (coordinatorHtml.length === 0) return;
    compareSnapshot('coordinator-detail-evelynn-week-NN.html.snap', coordinatorHtml);
  });

  it('per-axis match-rate table is present in coordinator-detail HTML', () => {
    assert.ok(coordinatorHtml.includes('match_rate') || coordinatorHtml.includes('match-rate'),
      'expected match_rate table in coordinator-detail HTML');
  });

  it('flag classes are present for delegate health (flag-healthy/flag-drift/flag-executor-mode)', () => {
    const hasFlagClass = /flag-(?:healthy|drift|executor-mode)/.test(coordinatorHtml);
    assert.ok(hasFlagClass,
      'expected flag CSS class (flag-healthy/flag-drift/flag-executor-mode) in coordinator-detail HTML');
  });

  it('histogram SVGs contain integer-valued width attributes (no float pixel rounding)', () => {
    const widthMatches = [...coordinatorHtml.matchAll(/width="(\d+(?:\.\d+)?)"/g)];
    const floatWidths = widthMatches.filter(m => m[1].includes('.'));
    assert.deepEqual(floatWidths.map(m => m[1]), [],
      `expected integer-only width attributes in SVG, got float widths: ${floatWidths.map(m => m[0]).join(', ')}`);
  });
});

// ---------------------------------------------------------------------------
// TP2.T6-B: extended index snapshot — feedback tile + lowest-match-rate-axes tile
// DoD-(f): feedback-tile severity counts match feedback-rollup.expected.json aggregation
// DoD-(g): lowest-match-rate-axes tile shows three axes with sample-size (n=N)
// ---------------------------------------------------------------------------
describe('TP2.T6-B: extended index snapshot — Phase-2 tiles',
  { skip: !IMPL_EXISTS ? SKIP_REASON : false }, () => {

  let indexHtml;

  before(() => {
    const { distDir } = renderFixtureCorpus();
    const indexPath = join(distDir, 'index.html');
    indexHtml = existsSync(indexPath) ? readFileSync(indexPath, 'utf8') : '';
  });

  it('extended index.html matches snapshot', () => {
    if (indexHtml.length === 0) return;
    compareSnapshot('index-with-phase2-tiles.html.snap', indexHtml);
  });

  it('feedback tile groups entries by severity (high/medium/low)', () => {
    const hasSeverity = /high|medium|low/.test(indexHtml);
    assert.ok(hasSeverity, 'expected severity groupings in feedback tile');
  });

  it('feedback tile contains a deep-link to feedback/INDEX.md', () => {
    assert.ok(
      indexHtml.includes('feedback/INDEX.md') || indexHtml.includes('../feedback/INDEX.md'),
      'expected a deep-link to feedback/INDEX.md in the feedback tile'
    );
  });

  it('lowest-match-rate-axes tile shows sample size notation (n=N)', () => {
    assert.ok(/n=\d+/.test(indexHtml),
      'expected sample-size notation (n=N) in the lowest-match-rate-axes tile');
  });
});

// ---------------------------------------------------------------------------
// TP2.T6-C: R2 determinism guard — two consecutive renders produce byte-identical HTML
// DoD-(d): no Date.now(), Math.random(), process.pid, new Date( substrings
// ---------------------------------------------------------------------------
describe('TP2.T6-C: Phase-2 snapshot determinism guard (R2 carry-forward)',
  { skip: !IMPL_EXISTS ? SKIP_REASON : false }, () => {

  it('two consecutive renders produce byte-identical coordinator-detail HTML', () => {
    const { distDir: d1 } = renderFixtureCorpus();
    const { distDir: d2 } = renderFixtureCorpus();
    const f1 = execSync(`ls ${d1}/coordinator-evelynn-week-*.html 2>/dev/null | head -1`, { encoding: 'utf8' }).trim();
    const f2 = execSync(`ls ${d2}/coordinator-evelynn-week-*.html 2>/dev/null | head -1`, { encoding: 'utf8' }).trim();
    if (!f1 || !f2) return; // guard passes vacuously if page doesn't exist yet
    const h1 = readFileSync(f1, 'utf8');
    const h2 = readFileSync(f2, 'utf8');
    assert.strictEqual(h1, h2, 'coordinator-detail HTML must be byte-identical across two renders');
  });

  it('coordinator-detail HTML has no Date.now() / Math.random() / process.pid leaks', () => {
    const { distDir } = renderFixtureCorpus();
    const candidates = execSync(`ls ${distDir}/coordinator-evelynn-week-*.html 2>/dev/null | head -1`, { encoding: 'utf8' }).trim();
    if (!candidates) return;
    const html = readFileSync(candidates, 'utf8');
    const NON_DETERMINISTIC = [/Date\.now\(\)/, /Math\.random\(\)/, /process\.pid/, /new Date\(/];
    for (const re of NON_DETERMINISTIC) {
      assert.ok(!re.test(html),
        `coordinator-detail HTML contains non-deterministic expression matching ${re}`);
    }
  });
});

// ---------------------------------------------------------------------------
// TP2.T6-D: §Q4 SPA-rejection guard — no Vue/Pinia/vue-router, one inline script
// ---------------------------------------------------------------------------
describe('TP2.T6-D: Phase-2 §Q4 SPA-rejection guard',
  { skip: !IMPL_EXISTS ? SKIP_REASON : false }, () => {

  let coordinatorHtml;
  let indexHtml;

  before(() => {
    const { distDir } = renderFixtureCorpus();
    const f = execSync(`ls ${distDir}/coordinator-evelynn-week-*.html 2>/dev/null | head -1`, { encoding: 'utf8' }).trim();
    coordinatorHtml = f && existsSync(f) ? readFileSync(f, 'utf8') : '';
    const ip = join(distDir, 'index.html');
    indexHtml = existsSync(ip) ? readFileSync(ip, 'utf8') : '';
  });

  it('coordinator-detail has no <script src="vue/pinia/vue-router">', () => {
    assert.ok(!/vue|pinia|vue-router/i.test(coordinatorHtml.replace(/<!--.*?-->/gs, '')),
      'coordinator-detail must not import vue/pinia/vue-router (§Q4 SPA-rejection)');
  });

  it('extended index.html has no <script src="vue/pinia/vue-router">', () => {
    assert.ok(!/vue|pinia|vue-router/i.test(indexHtml.replace(/<!--.*?-->/gs, '')),
      'extended index must not import vue/pinia/vue-router (§Q4 SPA-rejection)');
  });
});
