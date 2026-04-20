# Demo Studio v3 — Design Review

**Date:** 2026-04-16
**Reviewer:** Lulu
**Audience:** Seraphine (frontend implementation)
**Files reviewed:**
- `company-os/tools/demo-studio-v3/templates/preview.html`
- `company-os/tools/demo-studio-v3/static/studio.css`
- `company-os/tools/demo-studio-v3/static/studio.js`
- PR #24 design spec: `plans/2026-04-09-preview-chat-ui.md`

---

## Context

PR #24 (missmp/company-os) is the v2 demo studio. It does not ship a new preview template — it contains the design specification plan (`plans/2026-04-09-preview-chat-ui.md`) that v3 was built from. The comparison is spec vs. implementation.

---

## What v3 got right

- Side-by-side chat/preview layout with responsive mobile tab switching — matches the spec exactly
- Correct design tokens: `--red`, `--sand`, `--dark`, `--teal`, etc. — fully consistent across studio.css
- SSE streaming with live tool indicators and thinking bubble — matches spec's "tool activity" row
- Collapsible thinking bubble is a nice addition beyond the spec
- Phase bar (Configure → Build → QC → Tweak) is clean and purposeful
- Modal animations (opacity + translateY) are smooth and minimal

---

## Improvement Recommendations

### 1. Chat message avatars / sender labels

The spec shows `[Bot avatar] Bot` as a distinct label above bot messages. v3 uses only background color to distinguish sides. With long agent responses containing markdown, mixed tool indicators, and thinking bubbles all appearing on the left side, there is no clear visual anchor for "this is the agent speaking."

**Recommendation:** Add a small `Bot` label or avatar dot above bot message bubbles (`.msg-bot`). A simple colored circle or "Agent" text label in `var(--subtle)` above the bubble would be sufficient.

### 2. Tool activity accordion should collapse to a summary

The spec defined tool rows as collapsible accordions that collapse to a phrase like "Applied 2 changes." v3 shows each tool indicator inline as a persistent row with a checkmark when done. They never collapse. Over a long session this creates a wall of completed tool rows between meaningful bot messages.

**Recommendation:** After all tools in a burst complete, collapse them into a single summary line — e.g., "3 changes applied" — with an expand toggle. Group them by the bot response turn they belong to. The `.tool-indicator.done` state is the right hook to build this on.

### 3. Empty preview state

When a session is new and no config exists yet, the iframe loads an empty preview. There is no loading skeleton, placeholder illustration, or helpful message visible to the user in the preview area wrapper.

**Recommendation:** Add a centered overlay inside `.preview-iframe-wrap` that shows "Waiting for your first message..." and hides once the first `config-update` postMessage is received from the iframe. This lives in `studio.js` and `studio.css`, not in `preview.html`.

### 4. Preview refresh feedback is easy to miss

The green border flash (`.preview-refresh-flash`) is 0.3s and covers a large surface. It is subtle enough to be missed. The spec calls for a "Preview refreshed" confirmation as a chat message after a tool call succeeds.

**Recommendation:** After a successful tool result that triggers a preview reload, add a system message in the chat: "Preview updated." This is low-cost to add in `resolveToolResult()` in `studio.js` and gives users a reliable text confirmation regardless of whether they caught the visual flash.

### 5. Mobile tab transition direction should follow content order

On mobile, switching between Chat and Preview animates with `translateX(10px)` for both panels — they both slide the same direction. Preview is logically "further right" than chat in the mental model.

**Recommendation:** The chat→preview transition should slide left-out / right-in. The preview→chat transition should slide right-out / left-in. This requires tracking which direction the tab switch is going and applying different transform values. In `studio.css`, the `.hidden` state at line 847 (`transform: translateX(10px)`) needs to differentiate by direction.

### 6. Divergent font stacks

`preview.html` uses `-apple-system, BlinkMacSystemFont, 'SF Pro Text', 'Helvetica Neue', sans-serif` while `studio.css` uses `'Helvetica Neue', Arial, sans-serif`. These render differently on Windows and Android. The studio shell and the preview iframe use different type systems, which creates a subtle disconnect when the two panels are side by side.

**Recommendation:** Standardize both on `system-ui, -apple-system, 'Helvetica Neue', Arial, sans-serif`. This covers macOS/iOS (SF Pro), Windows (Segoe UI), and Android (Roboto) consistently.

### 7. Stop button is visually disruptive

The stop button (`background: #b91c1c`) uses a hardcoded dark red that is heavier than the brand `--red: #F94F1E`. It appears in a dedicated `.stop-bar` row between the generate bar and the input, giving it a lot of visual weight.

**Recommendation:** Change `.stop-btn` to use `--red` as a border color with a transparent or very light background (e.g., `background: rgba(249,79,30,0.06); border: 1px solid var(--red); color: var(--red)`). This remains clearly actionable without reading as an alarm state.

---

## Accessibility Gaps

- **No focus styles on custom buttons** — all custom buttons (`tab-btn`, `send-btn`, `generate-btn`, `stop-btn`, etc.) suppress the browser's default outline without a replacement. Add `:focus-visible` styles that use a `var(--red)` outline offset on each interactive element.

- **Tool indicators and thinking bubbles lack role annotation** — `aria-live="polite"` is correctly set on `.chat-messages`, but tool indicator rows and thinking bubbles appended during streaming have no role. Screen readers may announce them mid-sentence as they appear. Adding `role="status"` to `.tool-indicator` elements would help.

- **Color-only phase indication** — the phase dots in the phase bar use color alone (red = active, teal = done, grey = pending). Users with red-green color blindness cannot distinguish active from done. Adding a filled vs. outlined dot shape, or a checkmark icon on done steps, would make the state perceivable without color.

- **Preview iframe sandbox missing `allow-popups`** — the sandbox value is `allow-scripts allow-same-origin allow-forms`. If any link or element inside the preview opens a modal or external URL, it will silently fail. Evaluate whether `allow-popups allow-popups-to-escape-sandbox` is appropriate for the preview content.

- **Mobile tab bar missing ARIA tab pattern** — the `.tab-btn` elements have no `role="tab"`, `aria-selected`, or `role="tablist"` on the container. They should use the proper tab pattern for screen reader compatibility.

---

## Minor Observations

- **`config-version` display has no label** — the monospace version string in the preview toolbar (`studio.css:352`) has no tooltip or visible label. Add `title="Config version"` as a minimum, or a preceding label text.

- **`session-badge` contrast** — the session ID in the top bar uses `rgba(251, 194, 211, 0.6)` on `--red` background. This is near-invisible. If it is a debug artifact it can be removed; if it is meaningful to users it needs a contrast-compliant treatment (at least 4.5:1 ratio).

- **Dashboard link missing `rel` attribute** — `target="_blank"` without `rel="noopener noreferrer"` is a minor security issue. The opened page gains a reference to the opener window via `window.opener`. Add `rel="noopener noreferrer"` to the dashboard link in `studio.js` line ~89.
