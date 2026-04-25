/**
 * html-generator.mjs — generates static HTML files from query JSON outputs.
 *
 * Reads plan-rollup.json and coordinator-weekly-skeleton.json from the data dir,
 * produces index.html and plan-<slug>.html files in the dist dir.
 *
 * No Date.now(), no Math.random(), no process.pid — fully deterministic output.
 *
 * Plan-Ref: plans/approved/personal/2026-04-25-retrospection-dashboard-and-canonical-v1.md
 * Implements T.P1.6 DoD (a)-(d).
 */

import { readFileSync, writeFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';
import { escapeHtml } from './template.mjs';

// ---------------------------------------------------------------------------
// Plan row HTML for index.html
// ---------------------------------------------------------------------------

/**
 * Group plan-rollup rows by plan_slug and compute aggregate stats.
 * @param {Array<Object>} rollupRows
 * @returns {Array<{slug: string, stageCount: number, totalTokensIn: number, totalWall: number}>}
 */
function aggregatePlans(rollupRows) {
  const bySlug = new Map();
  for (const row of rollupRows) {
    const slug = row.plan_slug || 'unknown';
    if (!bySlug.has(slug)) {
      bySlug.set(slug, { slug, stages: new Set(), totalTokensIn: 0, totalWall: 0 });
    }
    const agg = bySlug.get(slug);
    if (row.stage) agg.stages.add(row.stage);
    agg.totalTokensIn += (row.tokens_input || 0);
    agg.totalWall += (row.wall_active_minutes || 0);
  }
  return Array.from(bySlug.values())
    .map(a => ({
      slug: a.slug,
      stageCount: a.stages.size,
      totalTokensIn: a.totalTokensIn,
      totalWall: Math.round(a.totalWall * 10000) / 10000,
    }))
    .sort((a, b) => a.slug.localeCompare(b.slug));
}

/**
 * Also list plans from plan-stage events that have no rollup rows.
 * These plans have stage history but no attributed turns.
 * @param {Array<Object>} rollupRows
 * @param {Array<Object>} planStageRows — from a plan-stage query or parsed from events
 * @returns {Array<string>} additional slugs
 */
function planSlugsFromStageEvents(planStageRows, existingSlugs) {
  const stageSlugs = new Set(planStageRows.map(r => r.plan_slug || r.planSlug).filter(Boolean));
  return Array.from(stageSlugs).filter(s => !existingSlugs.has(s)).sort();
}

// ---------------------------------------------------------------------------
// HTML builders
// ---------------------------------------------------------------------------

/**
 * Build the plan rows HTML for index.html.
 * @param {Array<{slug, stageCount, totalTokensIn, totalWall}>} plans
 * @returns {string}
 */
function buildPlanRows(plans) {
  if (plans.length === 0) return '<tr><td colspan="4">No plans with attributed turns yet.</td></tr>';
  return plans.map(p => [
    '<tr>',
    `<td><a href="plan-${escapeHtml(p.slug)}.html">${escapeHtml(p.slug)}</a></td>`,
    `<td>${escapeHtml(p.stageCount)}</td>`,
    `<td>${escapeHtml(p.totalTokensIn)}</td>`,
    `<td>${escapeHtml(p.totalWall)}</td>`,
    '</tr>',
  ].join('')).join('\n');
}

/**
 * Build stage rows HTML for plan-detail.html.
 * @param {Array<Object>} rows — rows from plan-rollup.json for this slug
 * @param {Array<Object>} [planStageEvents] — plan-stage events for this slug (fallback)
 * @returns {string}
 */
function buildStageRows(rows, planStageEvents = []) {
  if (rows.length > 0) {
    return rows
      .sort((a, b) => (a.stage || '').localeCompare(b.stage || '') || (a.agent_id || '').localeCompare(b.agent_id || ''))
      .map(r => [
        '<tr>',
        `<td>${escapeHtml(r.stage)}</td>`,
        `<td>${escapeHtml(r.agent_id)}</td>`,
        `<td>${escapeHtml(r.tokens_input)}</td>`,
        `<td>${escapeHtml(r.tokens_output)}</td>`,
        `<td>${escapeHtml(r.tokens_cache_read)}</td>`,
        `<td>${escapeHtml(r.tokens_cache_creation)}</td>`,
        `<td>${escapeHtml(r.wall_active_minutes)}</td>`,
        `<td>${escapeHtml(r.turns)}</td>`,
        `<td>${escapeHtml(r.tool_calls)}</td>`,
        '</tr>',
      ].join('')).join('\n');
  }
  // No rollup rows — show stage-timeline rows from plan-stage events
  if (planStageEvents.length > 0) {
    return planStageEvents
      .sort((a, b) => (a.ts || '').localeCompare(b.ts || ''))
      .map(e => [
        '<tr>',
        `<td>${escapeHtml(e.stage)}</td>`,
        `<td></td>`,
        `<td>0</td>`,
        `<td>0</td>`,
        `<td>0</td>`,
        `<td>0</td>`,
        `<td>0</td>`,
        `<td>0</td>`,
        `<td>0</td>`,
        '</tr>',
      ].join('')).join('\n');
  }
  return '<tr><td colspan="9">No attributed turns for this plan.</td></tr>';
}

// ---------------------------------------------------------------------------
// Main generator
// ---------------------------------------------------------------------------

/**
 * Generate all static HTML files from query output JSON files.
 *
 * @param {Object} opts
 * @param {string} opts.dataDir — directory containing plan-rollup.json etc.
 * @param {string} opts.distDir — output directory for HTML files
 * @param {string} opts.templatesDir — directory containing *.html.tpl files
 * @param {Array<Object>} opts.events — raw events array (for plan-stage slugs without rollup rows)
 */
export function generateHtml({ dataDir, distDir, templatesDir, events = [] }) {
  // Load query outputs
  const rollupPath = join(dataDir, 'plan-rollup.json');
  const rollupRows = existsSync(rollupPath)
    ? JSON.parse(readFileSync(rollupPath, 'utf8'))
    : [];

  // Gather plan slugs from plan-stage events (even if no turns attributed)
  // Events use camelCase field names (planSlug), matching events.jsonl schema.
  const planStageEventSlugs = [
    ...new Set(events.filter(e => e.kind === 'plan-stage').map(e => e.planSlug || e.plan_slug).filter(Boolean)),
  ].sort();
  const rollupSlugs = new Set(rollupRows.map(r => r.plan_slug).filter(Boolean));
  const allPlanSlugs = [
    ...new Set([...rollupSlugs, ...planStageEventSlugs]),
  ].sort();

  // Load templates
  const indexTpl = readFileSync(join(templatesDir, 'index.html.tpl'), 'utf8');
  const detailTpl = readFileSync(join(templatesDir, 'plan-detail.html.tpl'), 'utf8');

  // Build plan aggregates for index
  const planAggregates = aggregatePlans(rollupRows);
  const aggregateSlugs = new Set(planAggregates.map(p => p.slug));

  // Also include plans that have only stage events (no rollup rows)
  const stagOnlyPlans = allPlanSlugs
    .filter(s => !aggregateSlugs.has(s))
    .map(s => ({ slug: s, stageCount: 0, totalTokensIn: 0, totalWall: 0 }));
  const allPlanAggregates = [...planAggregates, ...stagOnlyPlans]
    .sort((a, b) => a.slug.localeCompare(b.slug));

  // Generate index.html
  const planRowsHtml = buildPlanRows(allPlanAggregates);
  const indexHtml = indexTpl.replace('{{PLAN_ROWS}}', planRowsHtml);
  writeFileSync(join(distDir, 'index.html'), indexHtml, 'utf8');

  // Generate plan-<slug>.html for each known plan slug
  for (const slug of allPlanSlugs) {
    const rows = rollupRows.filter(r => r.plan_slug === slug);
    const slugPlanStageEvents = events.filter(
      e => e.kind === 'plan-stage' && (e.planSlug || e.plan_slug) === slug
    );
    const stageRowsHtml = buildStageRows(rows, slugPlanStageEvents);
    const detailHtml = detailTpl
      .replace(/\{\{PLAN_SLUG\}\}/g, escapeHtml(slug))
      .replace('{{STAGE_ROWS}}', stageRowsHtml);
    writeFileSync(join(distDir, `plan-${slug}.html`), detailHtml, 'utf8');
  }
}
