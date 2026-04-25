/**
 * plan-stage-detect.mjs — three-signal layered plan-stage detection per §Q2.
 *
 * Signal hierarchy (canonical first):
 *   1. Orianna Promoted-By trailer commit  (signal: 'trailer')
 *   2. Plan-file status: frontmatter mtime (signal: 'frontmatter-mtime')
 *   3. Dispatch-prompt slug match          (signal: 'dispatch-prompt-slug-match')
 *
 * OQ-R3 ruling (Swain, 2026-04-25): when trailer and frontmatter disagree on
 * current stage, trailer wins and signal_conflict is logged.
 *
 * Field naming: planSlug uses camelCase to match Claude JSONL conventions and
 * the events.jsonl schema. All other fields are snake_case (kind, stage, signal,
 * ts, commit, signal_corroborators, signal_conflict).
 *
 * Plan-Ref: plans/approved/personal/2026-04-25-retrospection-dashboard-and-canonical-v1.md
 */

/**
 * Extract a plan slug from a text string (scans first 200 chars).
 * Matches paths like plans/(proposed|approved|in-progress|implemented|archived)/.+/<slug>.md
 * Returns null if not found.
 * @param {string} text
 * @returns {{ slug: string, stage: string } | null}
 */
export function extractPlanSlugFromText(text) {
  if (!text) return null;
  const region = text.slice(0, 200);
  const match = region.match(
    /plans\/(proposed|approved|in-progress|implemented|archived)\/[^/]+\/([^/\s'"]+)\.md/
  );
  if (!match) return null;
  return { slug: match[2], stage: match[1] };
}

/**
 * Parse a JSON git-log entry and emit plan-stage events.
 *
 * Each entry may carry:
 *   - trailers.Promoted-By = 'Orianna'  → signal: 'trailer'
 *   - frontmatterStatusChange            → signal: 'frontmatter-mtime'
 *   - (neither)                          → no plan-stage event from this source
 *
 * When all-three-signals coexist (trailer + frontmatter + pending dispatch-prompt),
 * the trailer wins; others are listed as signal_corroborators.
 *
 * OQ-R3: when trailer and frontmatter disagree on stage (different toStage values),
 * trailer wins and signal_conflict: 'frontmatter-newer-than-trailer' is set.
 *
 * @param {Array<Object>} gitLogEntries — parsed from git-log-plans.json / RETRO_GIT_LOG_MOCK
 * @returns {Array<Object>} plan-stage events
 */
export function parsePlanStageFromGitLog(gitLogEntries) {
  const events = [];

  for (const entry of gitLogEntries) {
    const hasTrailer = entry.trailers && entry.trailers['Promoted-By'] === 'Orianna';
    const hasFrontmatter = Boolean(entry.frontmatterStatusChange);

    if (!hasTrailer && !hasFrontmatter) continue;

    const corroborators = [];
    let signal;
    let stage;
    let signalConflict;

    if (hasTrailer) {
      signal = 'trailer';
      stage = entry.toStage;
      if (hasFrontmatter) {
        const fmStage = entry.frontmatterStatusChange.to;
        if (fmStage !== stage) {
          // OQ-R3: trailer wins, log conflict
          signalConflict = 'frontmatter-newer-than-trailer';
        } else {
          corroborators.push('frontmatter-mtime');
        }
      }
    } else if (hasFrontmatter) {
      signal = 'frontmatter-mtime';
      stage = entry.frontmatterStatusChange.to;
    }

    const event = {
      kind: 'plan-stage',
      planSlug: entry.planSlug,
      stage,
      signal,
      ts: entry.timestamp,
      commit: entry.commit || null,
    };

    if (corroborators.length > 0) {
      event.signal_corroborators = corroborators;
    }
    if (signalConflict) {
      event.signal_conflict = signalConflict;
    }

    events.push(event);
  }

  // Sort by timestamp ascending for stable output
  events.sort((a, b) => new Date(a.ts).getTime() - new Date(b.ts).getTime());
  return events;
}

/**
 * Emit a plan-stage event from a dispatch-prompt slug match.
 * Used as fallback (signal 3) when no trailer/frontmatter exists.
 *
 * Mutates existingPlanStageEvents in-place to add corroborators if the slug
 * is already covered by a higher-priority signal.
 *
 * @param {string} planSlug
 * @param {string} stageFromPath — stage inferred from the plans/ subdirectory
 * @param {string} ts — ISO timestamp of the dispatch
 * @param {Array<Object>} existingPlanStageEvents — already-emitted trailer/frontmatter events
 * @returns {Object | null} plan-stage event, or null if already covered by higher-priority signals
 */
export function maybePlanStageFromDispatch(planSlug, stageFromPath, ts, existingPlanStageEvents) {
  // Check if this slug already has a trailer or frontmatter plan-stage event
  const canonicalEvent = existingPlanStageEvents.find(
    e => e.planSlug === planSlug &&
         (e.signal === 'trailer' || e.signal === 'frontmatter-mtime')
  );

  if (canonicalEvent) {
    // Add dispatch-prompt-slug-match as corroborator
    if (!canonicalEvent.signal_corroborators) canonicalEvent.signal_corroborators = [];
    if (!canonicalEvent.signal_corroborators.includes('dispatch-prompt-slug-match')) {
      canonicalEvent.signal_corroborators.push('dispatch-prompt-slug-match');
    }
    return null;
  }

  return {
    kind: 'plan-stage',
    planSlug,
    stage: stageFromPath,
    signal: 'dispatch-prompt-slug-match',
    ts,
    commit: null,
  };
}
