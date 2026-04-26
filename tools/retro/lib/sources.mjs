/**
 * sources.mjs — per-source readers for the four upstream event sources.
 *
 * Source 1: parent JSONL (~/.claude/projects/<slug>/<session-id>.jsonl)
 * Source 2: subagent JSONL + meta.json (subagents/agent-<id>.{jsonl,meta.json})
 * Source 3: subagent sentinels (strawberry-usage-cache/subagent-sentinels/<agent-id>)
 * Source 4: git log (via RETRO_GIT_LOG_MOCK env or actual git log)
 *
 * Event field naming convention (matching Claude JSONL conventions):
 *   - camelCase for identifiers: sessionId, parentSessionId, agentId, planSlug
 *   - snake_case for token counts: input_tokens, output_tokens, cache_read_input_tokens, etc.
 *   - snake_case for custom fields: kind, role, ts, wall_active_delta_s, stage, signal, etc.
 *
 * Plan-Ref: plans/approved/personal/2026-04-25-retrospection-dashboard-and-canonical-v1.md
 * Implements T.P1.2 DoD (a)-(d).
 */

import {
  readdirSync, readFileSync, statSync, existsSync
} from 'node:fs';
import { join } from 'node:path';
import { execSync } from 'node:child_process';
import {
  parsePlanStageFromGitLog,
  extractPlanSlugFromText,
  maybePlanStageFromDispatch,
} from './plan-stage-detect.mjs';
// T.P2.4: prompt-stats emitter — wired into the subagent-jsonl source below
import { computePromptStats } from './prompt-stats.mjs';

// ---------------------------------------------------------------------------
// Wall-active-delta computation (§3 idle-gap stripping)
// ---------------------------------------------------------------------------

/**
 * Compute wall_active_delta_s for each assistant turn in a session.
 *
 * wall_active_delta_s[0] = 0 (no previous assistant turn to measure from)
 * wall_active_delta_s[i] = assistant_ts[i] - assistant_ts[i-1]
 *   if that delta is > 90s → set to 0 (idle gap stripped)
 *   if delta <= 90s → keep as active wall-clock seconds
 *
 * This matches the §3 time-normalization spec: consecutive-assistant-timestamp
 * delta; idle gap (>90s between assistant turns) is stripped to 0.
 *
 * @param {Array<{ts: string}>} turns — each element only needs `ts`
 * @returns {Array<number>} wall_active_delta_s values in seconds
 */
function computeWallActiveDeltas(turns) {
  const deltas = [];
  for (let i = 0; i < turns.length; i++) {
    if (i === 0) {
      // First assistant turn: no previous assistant to measure from
      deltas.push(0);
      continue;
    }
    const prevMs = new Date(turns[i - 1].ts).getTime();
    const currMs = new Date(turns[i].ts).getTime();
    const deltaMs = currMs - prevMs;
    // Strip idle gaps >90s (boundary 90s is NOT stripped — ≤90s stays active)
    deltas.push(deltaMs > 90000 ? 0 : deltaMs / 1000);
  }
  return deltas;
}

// ---------------------------------------------------------------------------
// Source 1: Parent session JSONL
// ---------------------------------------------------------------------------

/**
 * Look up the most canonical stage for a planSlug from planStageEvents.
 * Preference order (per §Q2 + OQ-R3): trailer > frontmatter-mtime > dispatch-prompt-slug-match.
 * Returns the stage string from the highest-priority signal event, or null if not found.
 *
 * @param {string|null} planSlug
 * @param {Array<Object>} planStageEvents
 * @returns {string|null}
 */
function lookupTrailerStage(planSlug, planStageEvents) {
  if (!planSlug || !planStageEvents || planStageEvents.length === 0) return null;
  const SIGNAL_PRIORITY = { trailer: 0, 'frontmatter-mtime': 1, 'dispatch-prompt-slug-match': 2 };
  let best = null;
  for (const ps of planStageEvents) {
    if (ps.planSlug !== planSlug) continue;
    const priority = SIGNAL_PRIORITY[ps.signal] ?? 99;
    const bestPriority = best !== null ? (SIGNAL_PRIORITY[best.signal] ?? 99) : 999;
    if (priority < bestPriority) best = ps;
  }
  return best ? best.stage : null;
}

/**
 * Parse a parent session JSONL file and emit turn events.
 *
 * Coordinator-inline sessions: no isSidechain flag, path not under subagents/.
 * Plan attribution: prefers trailer signal from planStageEvents when available,
 * falls back to dispatch-prompt-slug-match (path in first user message).
 *
 * @param {string} filePath — absolute path to the session JSONL
 * @param {string} sessionId — derived from the filename (without .jsonl)
 * @param {string} slug — project slug
 * @param {Array<Object>} planStageEvents — plan-stage events (trailer wins per §Q2 + OQ-R3)
 * @returns {Array<Object>} turn events
 */
export function parseParentSession(filePath, sessionId, slug, planStageEvents) {
  let lines;
  try {
    lines = readFileSync(filePath, 'utf8')
      .split('\n')
      .filter(Boolean)
      .map(l => JSON.parse(l));
  } catch {
    // Skip malformed JSONL files (real Claude session files may have complex schemas)
    return [];
  }

  // Extract plan slug from first user message
  const firstUserMsg = lines.find(l => l.type === 'user' || l.role === 'user');
  const firstUserText = firstUserMsg && Array.isArray(firstUserMsg.content)
    ? firstUserMsg.content.filter(c => c && c.type === 'text').map(c => c.text).join(' ')
    : (firstUserMsg && typeof firstUserMsg.content === 'string' ? firstUserMsg.content : '');
  const planMatch = extractPlanSlugFromText(firstUserText);

  // Prefer trailer signal stage over dispatch-prompt-slug-match path stage (I2 fix).
  // Invariant 5 (trailer canonical): the trailer signal is the most authoritative
  // stage source; dispatch-prompt path reflects the plan's directory at dispatch time,
  // which may lag behind an Orianna promotion.
  const planSlug = planMatch ? planMatch.slug : null;
  const dispatchStage = planMatch ? planMatch.stage : null;
  const canonicalStage = lookupTrailerStage(planSlug, planStageEvents) || dispatchStage;

  // Gather assistant turns in order, tracking preceding timestamps
  const assistantRows = [];
  let prevUserTs = null;
  let prevAssistantTs = null;

  for (const line of lines) {
    if (!line || typeof line !== 'object') continue;
    if (line.type === 'user' || line.role === 'user') {
      prevUserTs = line.timestamp || null;
    } else if (
      (line.type === 'assistant' || line.role === 'assistant') &&
      !line.isSidechain &&
      line.usage
    ) {
      assistantRows.push({
        ts: line.timestamp,
        usage: line.usage || {},
        model: line.model || null,
        prevUserTs,
        prevAssistantTs,
      });
      prevAssistantTs = line.timestamp;
    }
  }

  const deltas = computeWallActiveDeltas(assistantRows);
  const events = [];

  for (let i = 0; i < assistantRows.length; i++) {
    const row = assistantRows[i];
    events.push({
      kind: 'turn',
      role: 'coordinator-inline',
      sessionId,
      ts: row.ts,
      input_tokens: row.usage.input_tokens || 0,
      output_tokens: row.usage.output_tokens || 0,
      cache_read_input_tokens: row.usage.cache_read_input_tokens || 0,
      cache_creation_input_tokens: row.usage.cache_creation_input_tokens || 0,
      model: row.model,
      wall_active_delta_s: deltas[i],
      planSlug,
      stage: canonicalStage,
      agentId: null,
    });
  }

  return events;
}

// ---------------------------------------------------------------------------
// Source 2: Subagent JSONL + meta.json
// ---------------------------------------------------------------------------

/**
 * Parse a subagent JSONL file and its paired meta.json.
 *
 * T.P2.4: also computes a dispatch-prompt-stats event (§Q9 three deterministic signals)
 * from the subagent's first user message + total output-token count.
 *
 * @param {string} jsonlPath — absolute path to agent-<id>.jsonl
 * @param {string} metaPath — absolute path to agent-<id>.meta.json
 * @param {string} agentId — extracted from filename
 * @param {Array<Object>} planStageEvents — plan-stage events (trailer wins per §Q2 + OQ-R3)
 * @returns {{ turns: Array<Object>, dispatch: Object | null, promptStats: Object | null }}
 */
export function parseSubagentSession(jsonlPath, metaPath, agentId, planStageEvents) {
  let lines;
  try {
    lines = readFileSync(jsonlPath, 'utf8')
      .split('\n')
      .filter(Boolean)
      .map(l => JSON.parse(l));
  } catch {
    return { turns: [], dispatch: null };
  }

  let meta = null;
  if (existsSync(metaPath)) {
    try {
      meta = JSON.parse(readFileSync(metaPath, 'utf8'));
    } catch {
      // ignore malformed meta
    }
  }

  const parentSessionId = meta ? (meta.parentSessionId || null) : null;
  const sessionId = meta ? (meta.sessionId || null) : null;

  // Extract plan slug from first user message
  const firstUserMsg = lines.find(l => l.type === 'user' || l.role === 'user');
  const firstUserText = firstUserMsg && Array.isArray(firstUserMsg.content)
    ? firstUserMsg.content.filter(c => c && c.type === 'text').map(c => c.text).join(' ')
    : '';
  const planMatch = extractPlanSlugFromText(firstUserText);

  // Prefer trailer signal stage over dispatch-prompt-slug-match path stage (I2 fix).
  const planSlug = planMatch ? planMatch.slug : null;
  const dispatchStage = planMatch ? planMatch.stage : null;
  const canonicalStage = lookupTrailerStage(planSlug, planStageEvents) || dispatchStage;

  // Gather assistant turns (isSidechain:true rows)
  const assistantRows = [];
  let prevUserTs = null;
  let prevAssistantTs = null;

  for (const line of lines) {
    if (!line || typeof line !== 'object') continue;
    if (line.type === 'user' || line.role === 'user') {
      prevUserTs = line.timestamp || null;
    } else if (
      (line.type === 'assistant' || line.role === 'assistant') &&
      line.isSidechain &&
      line.usage
    ) {
      assistantRows.push({
        ts: line.timestamp,
        usage: line.usage || {},
        model: line.model || null,
        prevUserTs,
        prevAssistantTs,
      });
      prevAssistantTs = line.timestamp;
    }
  }

  const deltas = computeWallActiveDeltas(assistantRows);
  const turns = [];

  for (let i = 0; i < assistantRows.length; i++) {
    const row = assistantRows[i];
    turns.push({
      kind: 'turn',
      role: 'delegated',
      sessionId,
      parentSessionId,
      agentId,
      ts: row.ts,
      input_tokens: row.usage.input_tokens || 0,
      output_tokens: row.usage.output_tokens || 0,
      cache_read_input_tokens: row.usage.cache_read_input_tokens || 0,
      cache_creation_input_tokens: row.usage.cache_creation_input_tokens || 0,
      model: row.model,
      wall_active_delta_s: deltas[i],
      planSlug,
      stage: canonicalStage,
    });
  }

  // Dispatch event from meta.json
  let dispatch = null;
  if (meta) {
    dispatch = {
      kind: 'dispatch',
      agentId,
      parentSessionId,
      // sessionId for dispatch = parentSessionId (dispatch attributed to coordinator session)
      sessionId: parentSessionId,
      dispatch_start_ts: meta.startTs || null,
      dispatch_end_ts: meta.endTs || null,
    };
  }

  // T.P2.4: emit one dispatch-prompt-stats event per subagent (§Q9 three signals).
  // Uses the already-extracted firstUserText (dispatch prompt) and sums output_tokens
  // from all assistant turns in this subagent session.
  const subagentTotalOutputTokens = assistantRows.reduce(
    (sum, row) => sum + (row.usage.output_tokens || 0), 0
  );
  // dispatch_prompt_tokens: approximate from input_tokens of the first assistant turn
  // (the first assistant turn's input_tokens includes the full dispatch prompt context).
  const dispatchPromptTokens = assistantRows.length > 0
    ? (assistantRows[0].usage.input_tokens || 0)
    : 0;

  const promptStats = computePromptStats({
    dispatch_prompt_text: firstUserText,
    dispatch_prompt_tokens: dispatchPromptTokens,
    subagent_total_output_tokens: subagentTotalOutputTokens,
    // coordinator field: derived from meta if available; null otherwise
    coordinator: meta ? (meta.coordinator || null) : null,
    sessionId: parentSessionId,
    agentId,
    ts: dispatch ? (dispatch.dispatch_start_ts || null) : null,
  });

  return { turns, dispatch, promptStats };
}

// ---------------------------------------------------------------------------
// Source 3: Subagent sentinels
// ---------------------------------------------------------------------------

/**
 * Parse sentinel files from the subagent-sentinels/ directory.
 * Returns a map of agentId → dispatch_end_ts (ISO string).
 *
 * @param {string} sentinelsDir — absolute path to subagent-sentinels/
 * @returns {Record<string, string>}
 */
export function parseSentinels(sentinelsDir) {
  if (!existsSync(sentinelsDir)) return {};
  const result = {};
  try {
    for (const name of readdirSync(sentinelsDir)) {
      const filePath = join(sentinelsDir, name);
      try {
        const mtime = statSync(filePath).mtime;
        result[name] = mtime.toISOString();
      } catch {
        // skip
      }
    }
  } catch {
    // directory not accessible
  }
  return result;
}

// ---------------------------------------------------------------------------
// Source 4: git log over plans/**
// ---------------------------------------------------------------------------

/**
 * Load plan-stage git log data.
 * If RETRO_GIT_LOG_MOCK is set, reads the JSON mock file.
 * Otherwise runs `git log` over plans/** and parses the output.
 *
 * @param {string} repoRoot — repository root for git log
 * @returns {Array<Object>} raw git log entries
 */
export function loadGitLogPlanData(repoRoot) {
  const mockPath = process.env.RETRO_GIT_LOG_MOCK;
  if (mockPath && existsSync(mockPath)) {
    try {
      return JSON.parse(readFileSync(mockPath, 'utf8'));
    } catch {
      return [];
    }
  }
  // Real git log: find commits touching plans/** with Promoted-By trailer.
  // Use %x1e (ASCII record separator, 0x1e) as a record delimiter so that
  // multi-paragraph commit bodies (which contain blank lines) do not split
  // the record prematurely. Split on \x1e instead of \n\n in parseRealGitLog.
  try {
    const raw = execSync(
      'git log --all --format="%x1e%H%x00%s%x00%b%x00%aI" -- "plans/" 2>/dev/null',
      { cwd: repoRoot, stdio: 'pipe', encoding: 'utf8', timeout: 10000 }
    );
    return parseRealGitLog(raw);
  } catch {
    return [];
  }
}

/**
 * Parse real git log output into entries compatible with parsePlanStageFromGitLog.
 * @param {string} raw
 * @returns {Array<Object>}
 */
function parseRealGitLog(raw) {
  const entries = [];
  // Split on ASCII record separator 0x1e (injected as %x1e in git log --format).
  // This avoids the multi-paragraph-body bug: splitting on \n\n would break any
  // commit body that contains blank lines (e.g. Orianna promotion rationale),
  // causing Promoted-By trailers in the second paragraph to be silently lost.
  const blocks = raw.split('\x1e').filter(Boolean);
  for (const block of blocks) {
    const parts = block.split('\x00');
    if (parts.length < 3) continue;
    const [hash, subject, body, isoDate] = parts;
    // Parse trailers from body
    const trailers = {};
    for (const line of (body || '').split('\n')) {
      const m = line.match(/^([A-Za-z-]+):\s*(.+)$/);
      if (m) trailers[m[1].trim()] = m[2].trim();
    }
    // Extract planSlug from subject
    const slugMatch = subject && subject.match(/promote\s+(\S+)\s+to\s+(\S+)/);
    if (!slugMatch && !trailers['Promoted-By']) continue;
    // Use a deterministic sentinel when isoDate is absent rather than wall-clock now()
    // (non-deterministic clock calls break the R2 byte-identical-output invariant).
    const trimmedDate = isoDate && isoDate.trim();
    entries.push({
      commit: hash && hash.trim(),
      subject: subject && subject.trim(),
      trailers,
      timestamp: trimmedDate || '0000-00-00T00:00:00.000Z',
      planSlug: slugMatch ? slugMatch[1] : null,
      toStage: slugMatch ? slugMatch[2] : null,
    });
  }
  return entries.filter(e => e.planSlug);
}

// ---------------------------------------------------------------------------
// Main scanner
// ---------------------------------------------------------------------------

/**
 * Scan all four upstream sources and produce a list of events.
 *
 * @param {Object} opts
 * @param {string} opts.cacheDir — root dir (for fallback sentinel lookup)
 * @param {string[]} [opts.sentinelDirs] — explicit sentinel dirs to scan (overrides cacheDir)
 * @param {string|null} opts.projectsDir — root of ~/.claude/projects (null = skip sessions)
 * @param {string} [opts.repoRoot] — for git log (defaults to cwd)
 * @returns {Array<Object>} all events, sorted by ts ascending
 */
export function scanAllSources({ cacheDir, sentinelDirs, projectsDir, repoRoot = process.cwd() }) {
  const events = [];

  // --- Source 4: git log (collected first so plan-stage events are available) ---
  const gitLogEntries = loadGitLogPlanData(repoRoot);
  const planStageEvents = parsePlanStageFromGitLog(gitLogEntries);

  // --- Source 3: sentinels ---
  // Merge sentinels from all provided sentinel dirs
  const effectiveSentinelDirs = sentinelDirs || [join(cacheDir, 'subagent-sentinels')];
  const sentinelEndTimes = {};
  for (const dir of effectiveSentinelDirs) {
    Object.assign(sentinelEndTimes, parseSentinels(dir));
  }

  // --- Sources 1 + 2: project JSONL files ---
  if (projectsDir && existsSync(projectsDir)) {
    let projectSlugs;
    try {
      projectSlugs = readdirSync(projectsDir);
    } catch {
      projectSlugs = [];
    }

    for (const projectSlug of projectSlugs) {
      const projectDir = join(projectsDir, projectSlug);
      let projectStat;
      try {
        projectStat = statSync(projectDir);
      } catch {
        continue;
      }
      if (!projectStat.isDirectory()) continue;

      let sessionEntries;
      try {
        sessionEntries = readdirSync(projectDir);
      } catch {
        continue;
      }

      for (const sessionEntry of sessionEntries) {
        const sessionEntryPath = join(projectDir, sessionEntry);
        let entryStat;
        try {
          entryStat = statSync(sessionEntryPath);
        } catch {
          continue;
        }

        if (!entryStat.isDirectory()) {
          // Flat session JSONL (e.g. projects/<slug>/<session-id>.jsonl)
          if (sessionEntry.endsWith('.jsonl')) {
            const sid = sessionEntry.replace(/\.jsonl$/, '');
            const turns = parseParentSession(sessionEntryPath, sid, projectSlug, planStageEvents);
            events.push(...turns);
          }
          continue;
        }

        // Directory-style session: projects/<slug>/<session-id>/
        const sessionId = sessionEntry;
        const sessionDir = sessionEntryPath;

        // Check for parent session JSONL
        const parentJsonl = join(sessionDir, `${sessionId}.jsonl`);
        if (existsSync(parentJsonl)) {
          const turns = parseParentSession(parentJsonl, sessionId, projectSlug, planStageEvents);
          events.push(...turns);
        }

        // Check for subagents/ subdirectory
        const subagentsDir = join(sessionDir, 'subagents');
        if (existsSync(subagentsDir)) {
          let subFiles;
          try {
            subFiles = readdirSync(subagentsDir);
          } catch {
            subFiles = [];
          }
          const jsonlFiles = subFiles.filter(f => f.endsWith('.jsonl'));

          for (const jsonlFile of jsonlFiles) {
            const agentId = jsonlFile.replace(/\.jsonl$/, '');
            const jsonlPath = join(subagentsDir, jsonlFile);
            const metaPath = join(subagentsDir, `${agentId}.meta.json`);
            const { turns, dispatch, promptStats } = parseSubagentSession(
              jsonlPath, metaPath, agentId, planStageEvents
            );
            events.push(...turns);
            if (dispatch) {
              // Override dispatch_end_ts with sentinel mtime if available
              if (sentinelEndTimes[agentId]) {
                dispatch.dispatch_end_ts = sentinelEndTimes[agentId];
              }
              events.push(dispatch);
            }
            // T.P2.4: emit prompt-stats event if the subagent had content to measure
            if (promptStats) {
              events.push(promptStats);
            }
          }
        }
      }
    }
  }

  // --- Sentinel-only dispatch events ---
  // For sentinels without a corresponding subagent JSONL+meta (test isolation case),
  // emit a minimal dispatch event so the sentinel mtime is captured.
  const emittedAgentIds = new Set(events.filter(e => e.kind === 'dispatch').map(e => e.agentId));
  for (const [agentId, endTs] of Object.entries(sentinelEndTimes)) {
    if (!emittedAgentIds.has(agentId)) {
      events.push({
        kind: 'dispatch',
        agentId,
        parentSessionId: null,
        sessionId: null,
        dispatch_start_ts: null,
        dispatch_end_ts: endTs,
      });
    }
  }

  // --- Dispatch-prompt plan-stage fallback ---
  // For each delegated turn with a planSlug, check if a dispatch-prompt-slug-match
  // plan-stage event needs to be emitted (no trailer/frontmatter signal for that slug).
  for (const turn of events.filter(e => e.kind === 'turn' && e.role === 'delegated' && e.planSlug)) {
    const ps = maybePlanStageFromDispatch(
      turn.planSlug,
      turn.stage,
      turn.ts,
      planStageEvents
    );
    if (ps) planStageEvents.push(ps);
  }

  // Combine all events
  const allEvents = [...events, ...planStageEvents];

  // Stable sort by ts ascending; dispatch after turns at same ts; plan-stage last
  const tsOf = e => new Date(e.ts || e.dispatch_start_ts || 0).getTime();
  allEvents.sort((a, b) => {
    const d = tsOf(a) - tsOf(b);
    if (d !== 0) return d;
    const rank = k => k === 'plan-stage' ? 2 : k === 'dispatch' ? 1 : 0;
    return rank(a.kind) - rank(b.kind);
  });

  return allEvents;
}
