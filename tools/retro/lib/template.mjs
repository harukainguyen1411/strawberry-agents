/**
 * template.mjs — zero-dependency {{token}} interpolator + escape-HTML helper.
 *
 * No Vue, no Pinia, no SPA framework per §Q4.
 *
 * Plan-Ref: plans/approved/personal/2026-04-25-retrospection-dashboard-and-canonical-v1.md
 * Implements T.P1.6 DoD (a) — template interpolation for static HTML render.
 */

/**
 * Escape HTML special characters to prevent injection in rendered output.
 * @param {unknown} value
 * @returns {string}
 */
export function escapeHtml(value) {
  if (value === null || value === undefined) return '';
  return String(value)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

/**
 * Simple {{token}} string interpolation.
 * Tokens referencing nested paths (e.g. {{foo.bar}}) are NOT supported.
 * All values are HTML-escaped before substitution.
 *
 * @param {string} template — template string with {{TOKEN}} placeholders
 * @param {Record<string, unknown>} data — substitution map
 * @returns {string}
 */
export function render(template, data) {
  return template.replace(/\{\{([^}]+)\}\}/g, (_, key) => {
    const trimmed = key.trim();
    return Object.prototype.hasOwnProperty.call(data, trimmed)
      ? escapeHtml(data[trimmed])
      : '';
  });
}

/**
 * Render a block template for each item in an array, concatenating results.
 *
 * @param {string} template — template string with {{TOKEN}} placeholders
 * @param {Array<Record<string, unknown>>} items
 * @returns {string}
 */
export function renderEach(template, items) {
  return items.map(item => render(template, item)).join('');
}
