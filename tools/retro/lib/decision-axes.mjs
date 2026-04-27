/**
 * decision-axes.mjs — YAML frontmatter parser for decision log files.
 *
 * Parses the four §3.5 bind-point fields from decision-log frontmatter:
 *   axes, match, coordinator_confidence, decision_id
 *
 * Also handles:
 *   - duong_concurred_silently: true → derived match: true (plan B §3.1 line 136)
 *   - confidence mapping: low → 1, medium → 2, high → 3 (total function, no silent zero)
 *   - axes must be a non-empty array of strings (empty/missing raises typed error)
 *
 * Plan-Ref: plans/approved/personal/2026-04-25-retrospection-dashboard-and-canonical-v1.md
 * Read contract: plans/approved/personal/2026-04-21-coordinator-decision-feedback.md §3.5
 * Implements T.P2.3 DoD.
 */

/**
 * Confidence mapping: label → numeric score.
 * Deliberately total — throws for unknown values, never silently returns 0.
 *
 * @param {string|null|undefined} value
 * @returns {number} 1, 2, or 3
 * @throws {Error} for any value outside the known set
 */
export function confidenceToScore(value) {
  switch (value) {
    case 'low':    return 1;
    case 'medium': return 2;
    case 'high':   return 3;
    default:
      throw new Error(
        `Invalid coordinator_confidence value: "${value}". ` +
        `Expected one of: low, medium, high.`
      );
  }
}

/**
 * Parse the §3.5 bind-point fields from a decision-log frontmatter object.
 *
 * Invariants:
 *   - axes must be a non-empty array of strings
 *   - confidence must be a known enum value (total function, no silent zero)
 *   - duong_concurred_silently: true → derived match: true
 *   - explicit match field takes precedence when duong_concurred_silently is absent/false
 *
 * @param {Object} frontmatter — parsed YAML frontmatter fields
 * @param {string[]} frontmatter.axes — required, non-empty array of axis slugs
 * @param {string} frontmatter.coordinator_confidence — required, low|medium|high
 * @param {boolean} [frontmatter.match] — boolean; overridden by duong_concurred_silently
 * @param {boolean} [frontmatter.duong_concurred_silently] — if true, match is forced true
 * @param {string} frontmatter.decision_id — required identifier
 * @returns {{
 *   decision_id: string,
 *   axes: string[],
 *   match: boolean,
 *   confidence_score: number,
 *   coordinator_confidence: string
 * }}
 * @throws {Error} for invalid axes or confidence values
 */
export function parseDecisionFrontmatter(frontmatter) {
  const {
    axes,
    coordinator_confidence,
    match: matchField,
    duong_concurred_silently,
    decision_id,
  } = frontmatter;

  // Validate axes — must be a non-empty array of strings
  if (!Array.isArray(axes)) {
    throw new Error(
      `Decision frontmatter axes must be an array, got: ${typeof axes}. decision_id=${decision_id}`
    );
  }
  if (axes.length === 0) {
    throw new Error(
      `Decision frontmatter axes must be non-empty. decision_id=${decision_id}`
    );
  }

  // Validate confidence (total function — throws on unknown)
  const confidence_score = confidenceToScore(coordinator_confidence);

  // Derive match — duong_concurred_silently: true forces match: true per plan B §3.1 line 136
  const match = duong_concurred_silently === true ? true : Boolean(matchField);

  return {
    decision_id,
    axes: axes.map(String),
    match,
    confidence_score,
    coordinator_confidence: String(coordinator_confidence),
  };
}
