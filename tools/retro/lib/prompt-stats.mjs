/**
 * prompt-stats.mjs — §Q9 deterministic prompt-quality signals.
 *
 * Computes three per-dispatch signal fields:
 *   - prompt_chars         integer  character length of the dispatch prompt text
 *   - header_count         integer  number of ^## lines in the dispatch prompt
 *   - concern_tag_present  boolean  [concern: personal|work] tag present
 *   - plan_citation_present boolean regex match for canonical plan-tree path
 *   - compression_ratio    number   subagent_total_output_tokens / dispatch_prompt_tokens
 *
 * Emits one event per dispatch with kind: 'dispatch-prompt-stats'.
 * p50/p95 aggregations are SQL-level — NOT computed here (DoD TP2.T3-J).
 *
 * Plan-Ref: plans/approved/personal/2026-04-25-retrospection-dashboard-and-canonical-v1.md
 * Implements T.P2.4 DoD (a)-(f).
 */

// ---------------------------------------------------------------------------
// Regex constants (pinned per T.P2.4 DoD-(f))
// ---------------------------------------------------------------------------

/**
 * Plan-citation regex: covers all live plan-tree stage × concern combinations.
 * Anchored at plans/ start to avoid matching embedded substrings unintentionally.
 * Pinned pattern: plans/(proposed|approved|in-progress|implemented|archived)/(personal|work)/.+\.md
 */
const PLAN_CITATION_RE = /\bplans\/(proposed|approved|in-progress|implemented|archived)\/(personal|work)\/.+\.md/;

/**
 * Concern-tag regex: [concern: personal] or [concern: work]
 */
const CONCERN_TAG_RE = /\[concern:\s*(personal|work)\]/;

// ---------------------------------------------------------------------------
// extractPromptSignals — per-dispatch structural signal extraction
// ---------------------------------------------------------------------------

/**
 * Extract structural signals from a dispatch prompt text.
 *
 * @param {string} promptText — the full dispatch prompt (first user message in subagent JSONL)
 * @returns {{
 *   prompt_chars: number,
 *   header_count: number,
 *   concern_tag_present: boolean,
 *   plan_citation_present: boolean,
 * }}
 */
export function extractPromptSignals(promptText) {
  const text = typeof promptText === 'string' ? promptText : '';

  // Character length
  const prompt_chars = text.length;

  // Header count: count all ^## occurrences (global flag, multiline)
  const headerMatches = text.match(/^##\s/gm);
  const header_count = headerMatches ? headerMatches.length : 0;

  // Concern-tag presence
  const concern_tag_present = CONCERN_TAG_RE.test(text);

  // Plan-citation presence (pinned regex per DoD-(f))
  const plan_citation_present = PLAN_CITATION_RE.test(text);

  return {
    prompt_chars,
    header_count,
    concern_tag_present,
    plan_citation_present,
  };
}

// ---------------------------------------------------------------------------
// computePromptStats — builds the dispatch-prompt-stats event record
// ---------------------------------------------------------------------------

/**
 * Compute all §Q9 prompt-quality signals for one dispatch and return
 * an event record ready for emission into events.jsonl.
 *
 * Per DoD TP2.T3-J: this function returns ONE per-dispatch record.
 * p50 / p95 are SQL aggregations — callers must NOT expect those keys here.
 *
 * @param {{
 *   dispatch_prompt_text:          string,
 *   dispatch_prompt_tokens:        number,
 *   subagent_total_output_tokens:  number,
 *   coordinator?:                  string,
 *   sessionId?:                    string,
 *   agentId?:                      string,
 *   ts?:                           string,
 * }} opts
 * @returns {{
 *   kind:                    'dispatch-prompt-stats',
 *   coordinator:             string|null,
 *   sessionId:               string|null,
 *   agentId:                 string|null,
 *   ts:                      string|null,
 *   prompt_chars:            number,
 *   dispatch_prompt_tokens:  number,
 *   header_count:            number,
 *   concern_tag_present:     boolean,
 *   plan_citation_present:   boolean,
 *   compression_ratio:       number,
 * }}
 */
export function computePromptStats(opts) {
  const {
    dispatch_prompt_text = '',
    dispatch_prompt_tokens = 0,
    subagent_total_output_tokens = 0,
    coordinator = null,
    sessionId = null,
    agentId = null,
    ts = null,
  } = opts;

  const signals = extractPromptSignals(dispatch_prompt_text);

  // Compression ratio: subagent_total_output_tokens / dispatch_prompt_tokens
  // Guard against division by zero — emit 0 if prompt_tokens is 0
  const compression_ratio =
    dispatch_prompt_tokens > 0
      ? Math.round((subagent_total_output_tokens / dispatch_prompt_tokens) * 10000) / 10000
      : 0;

  return {
    kind: 'dispatch-prompt-stats',
    coordinator,
    sessionId,
    agentId,
    ts,
    prompt_chars: signals.prompt_chars,
    dispatch_prompt_tokens,
    header_count: signals.header_count,
    concern_tag_present: signals.concern_tag_present,
    plan_citation_present: signals.plan_citation_present,
    compression_ratio,
  };
}
