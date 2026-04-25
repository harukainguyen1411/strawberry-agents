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

