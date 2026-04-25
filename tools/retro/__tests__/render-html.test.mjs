/**
 * TP1.T6 — xfail static-HTML render snapshot suite
 *
 * guards T.P1.5 DoD + T.P1.6 DoD (R2 snapshot-determinism guard)
 * Plan-Ref: plans/approved/personal/2026-04-25-retrospection-dashboard-and-canonical-v1.md
 *
 * xfail: skipped until render.mjs (T.P1.6) exists with the HTML generator wired.
 * TODO (T.P1.6): wire html-generator.mjs into render.mjs then flip skip guard.
 *
 * R2 guard (DoD-d): runs render twice, asserts byte-identical output.
 * Also regex-scans render.mjs source for non-deterministic runtime calls.
 */

import { describe, it, before } from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, readFileSync, mkdtempSync, mkdirSync, readdirSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { execSync } from 'node:child_process';
import { tmpdir } from 'node:os';
import { assertSnapshot } from './lib/snapshot.mjs';

const __dirname = dirname(fileURLToPath(import.meta.url));
const RETRO_ROOT = join(__dirname, '..');
const RENDER_PATH = join(RETRO_ROOT, 'render.mjs');
const SOURCES_PATH = join(RETRO_ROOT, 'lib', 'sources.mjs');
const FIXTURES_DIR = join(RETRO_ROOT, 'fixtures');
const QUERIES_DIR = join(RETRO_ROOT, 'queries');
const EXPECTED_EVENTS = join(FIXTURES_DIR, 'expected-events.jsonl');

const IMPL_EXISTS = existsSync(RENDER_PATH);
const SKIP_REASON = 'xfail: render.mjs HTML generator not yet implemented (TODO T.P1.6)';

// Phase-1 fixture plan slug from git-log-plans.json
const FIXTURE_PLAN_SLUG = '2026-04-21-agent-feedback-system';

// Non-deterministic patterns that must not appear in render.mjs OR lib/sources.mjs source.
// sources.mjs is included because it contains the git-log parser and timestamp fallback —
// any non-deterministic clock call there breaks the R2 byte-identical-output invariant.
const NON_DETERMINISTIC_PATTERNS = [
  /Date\.now\(\)/,
  /new Date\(\)/,
  /Math\.random\(\)/,
  /process\.pid/,
];

// Sources to scan for non-deterministic patterns (I3 extension)
const DETERMINISM_SCAN_SOURCES = [
  { label: 'render.mjs', path: RENDER_PATH },
  { label: 'lib/sources.mjs', path: SOURCES_PATH },
];

function runRenderToDir(eventsPath, distDir) {
  execSync(
    `node ${RENDER_PATH} --events ${eventsPath} --queries-dir ${QUERIES_DIR} --out-dir ${distDir}`,
    { cwd: RETRO_ROOT, stdio: 'pipe' }
  );
}

describe('TP1.T6: static-HTML render snapshot + determinism guard', { skip: !IMPL_EXISTS ? SKIP_REASON : false }, () => {
  let distDir1;
  let distDir2;

  before(() => {
    const tmp1 = mkdtempSync(join(tmpdir(), 'retro-t6a-'));
    const tmp2 = mkdtempSync(join(tmpdir(), 'retro-t6b-'));
    distDir1 = join(tmp1, 'dist');
    distDir2 = join(tmp2, 'dist');
    mkdirSync(distDir1, { recursive: true });
    mkdirSync(distDir2, { recursive: true });
    runRenderToDir(EXPECTED_EVENTS, distDir1);
    // Second run for determinism comparison
    runRenderToDir(EXPECTED_EVENTS, distDir2);
  });

  // -------------------------------------------------------------------------
  // R2 snapshot-determinism guard — render twice, compare byte-for-byte
  // -------------------------------------------------------------------------
  it('[R2] re-running render twice produces byte-identical index.html', () => {
    const path1 = join(distDir1, 'index.html');
    const path2 = join(distDir2, 'index.html');
    assert.ok(existsSync(path1), 'index.html must exist after first render run');
    assert.ok(existsSync(path2), 'index.html must exist after second render run');
    const content1 = readFileSync(path1, 'utf8');
    const content2 = readFileSync(path2, 'utf8');
    assert.strictEqual(content1, content2,
      'render must be deterministic: two runs on identical input must produce byte-identical index.html');
  });

  it('[R2] re-running render twice produces byte-identical plan-<slug>.html', () => {
    const html1 = join(distDir1, `plan-${FIXTURE_PLAN_SLUG}.html`);
    const html2 = join(distDir2, `plan-${FIXTURE_PLAN_SLUG}.html`);
    assert.ok(existsSync(html1), `plan-${FIXTURE_PLAN_SLUG}.html must exist after first render run`);
    assert.ok(existsSync(html2), `plan-${FIXTURE_PLAN_SLUG}.html must exist after second render run`);
    assert.strictEqual(
      readFileSync(html1, 'utf8'),
      readFileSync(html2, 'utf8'),
      'plan-detail HTML must be byte-identical across two render runs'
    );
  });

  // -------------------------------------------------------------------------
  // R2 source-code scan for non-deterministic runtime calls
  // This fires on EVERY CI run — not just on snapshot update
  // -------------------------------------------------------------------------
  it('[R2] render.mjs and lib/sources.mjs must not contain Date.now(), new Date(), Math.random(), or process.pid', () => {
    // I3: extend scan to lib/sources.mjs — it contains the git-log timestamp fallback.
    // A non-deterministic clock call in sources.mjs breaks the R2 byte-identical invariant
    // for events.jsonl, which render.mjs consumes.
    for (const { label, path: srcPath } of DETERMINISM_SCAN_SOURCES) {
      if (!existsSync(srcPath)) continue; // skip if not yet implemented
      const source = readFileSync(srcPath, 'utf8');
      for (const pattern of NON_DETERMINISTIC_PATTERNS) {
        assert.ok(!pattern.test(source),
          `${label} must not contain non-deterministic expression matching ${pattern}. ` +
          `Found in source. Pass timestamps explicitly from fixtures instead.`);
      }
    }
  });

  // -------------------------------------------------------------------------
  // index.html snapshot — must list the fixture plan
  // -------------------------------------------------------------------------
  it('index.html lists the fixture plan slug as a link', () => {
    const indexPath = join(distDir1, 'index.html');
    const content = readFileSync(indexPath, 'utf8');
    assert.ok(content.includes(`href="plan-${FIXTURE_PLAN_SLUG}.html"`),
      `index.html must contain an anchor to plan-${FIXTURE_PLAN_SLUG}.html`);
  });

  it('index.html snapshot matches stored snap (assertSnapshot)', () => {
    const content = readFileSync(join(distDir1, 'index.html'), 'utf8');
    assertSnapshot(content, 'index.html');
  });

  // -------------------------------------------------------------------------
  // plan-detail.html snapshot — must contain every (stage, agent, tokens) cell
  // from plan-rollup.expected.json
  // -------------------------------------------------------------------------
  it('plan-detail HTML contains all expected (stage, agent, tokens_input, tokens_output, wall_active_minutes) cells', () => {
    const planHtml = readFileSync(join(distDir1, `plan-${FIXTURE_PLAN_SLUG}.html`), 'utf8');
    const expectedRollup = JSON.parse(
      readFileSync(join(QUERIES_DIR, 'plan-rollup.expected.json'), 'utf8')
    );

    for (const row of expectedRollup) {
      if (row.plan_slug !== FIXTURE_PLAN_SLUG) continue;
      assert.ok(planHtml.includes(row.stage),
        `plan-detail HTML must contain stage "${row.stage}"`);
      assert.ok(planHtml.includes(String(row.tokens_input)),
        `plan-detail HTML must contain tokens_input "${row.tokens_input}"`);
      assert.ok(planHtml.includes(String(row.tokens_output)),
        `plan-detail HTML must contain tokens_output "${row.tokens_output}"`);
      assert.ok(planHtml.includes(String(row.wall_active_minutes)),
        `plan-detail HTML must contain wall_active_minutes "${row.wall_active_minutes}"`);
    }
  });

  it('plan-detail.html snapshot matches stored snap', () => {
    const content = readFileSync(join(distDir1, `plan-${FIXTURE_PLAN_SLUG}.html`), 'utf8');
    assertSnapshot(content, `plan-detail-${FIXTURE_PLAN_SLUG}.html`);
  });

  // -------------------------------------------------------------------------
  // HTML-shape lint (DoD-e)
  // -------------------------------------------------------------------------
  it('index.html contains <link rel="stylesheet" href="app.css">', () => {
    const content = readFileSync(join(distDir1, 'index.html'), 'utf8');
    assert.ok(content.includes('<link rel="stylesheet" href="app.css">'),
      'index.html must include the app.css stylesheet link per §Q4');
  });

  it('index.html contains no SPA framework script tags (no vue, pinia, vue-router)', () => {
    const content = readFileSync(join(distDir1, 'index.html'), 'utf8').toLowerCase();
    for (const forbidden of ['src="vue', 'src="pinia', 'src="vue-router', '/vue.', '/pinia.', '/vue-router.']) {
      assert.ok(!content.includes(forbidden),
        `index.html must not load SPA framework "${forbidden}" per §Q4 SPA-rejection guard`);
    }
  });

  it('index.html has exactly one inline <script> block', () => {
    const content = readFileSync(join(distDir1, 'index.html'), 'utf8');
    const inlineScripts = [...content.matchAll(/<script(?!\s+src)[^>]*>/gi)];
    assert.equal(inlineScripts.length, 1,
      `expected exactly one inline <script> block, found ${inlineScripts.length}`);
  });
});
