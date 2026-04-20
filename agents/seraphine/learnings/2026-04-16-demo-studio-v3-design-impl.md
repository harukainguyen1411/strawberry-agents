# Demo Studio v3 — Design Implementation Learnings

**Date:** 2026-04-16
**Context:** Implemented Lulu's design review + two UI fixes for demo-studio-v3

---

## File locations

- `company-os/tools/demo-studio-v3/static/studio.js` — main studio JS (DOM construction, SSE handling, chat logic)
- `company-os/tools/demo-studio-v3/static/studio.css` — studio shell styles
- `company-os/tools/demo-studio-v3/templates/preview.html` — preview iframe template (Jinja2 + inline JS/CSS)
- Tests: `company-os/tools/demo-studio-v3/tests/test_ui_fixes.py`

---

## DOM construction pattern

The entire studio UI is built by `document.body.innerHTML = [...].join('\n')` in studio.js. All DOM elements are constructed as string arrays. Any new elements must be inserted into this array in the correct order.

**Order inside `.chat-panel`:**
1. `.chat-messages`
2. `.agent-banner` (added this session — persistent status banner)
3. `.chat-input-area`
   - `.generate-bar`
   - `.stop-bar`
   - `.agent-status-bar`
   - `.chat-input-row`

---

## SSE event flow and status rules

| Event | Banner behavior |
|-------|----------------|
| `running` | `setAgentStatus('Thinking...')` |
| `thinking` | `setAgentStatus('Thinking...')` |
| `tool_use` | `setAgentStatus(toolStatus(name))` |
| `tool_result` | **No clear** — status persists |
| `text` | `setAgentStatus('Responding...')` |
| `done` | `clearAgentStatus()` |
| `error` | `clearAgentStatus()` |

Critical: never call `clearAgentStatus()` in `tool_result` — it causes the banner to flash blank between sequential tool calls.

---

## Tool group collapsing

Tool indicators are grouped per agent turn into `.tool-summary-group > .tool-indicators-inner`. When all tools in a group complete (`done` class), the group collapses into a "N changes applied" summary button.

Reset `currentToolGroup = null` and `currentToolGroupItems = []` when a `text` SSE event arrives (new agent turn).

---

## Preview empty state

`.preview-empty-state` is an absolutely positioned overlay inside `.preview-iframe-wrap`. It hides (`classList.add('hidden')`) when `previewFrame.onload` fires.

**Critical:** wire `previewFrame.onload` BEFORE setting `previewFrame.src`. If src is set first, the load event fires before the handler is attached and the overlay never hides.

---

## Test gotcha: source[:1000] assumption

`test_ui_fixes.py::test_empty_state_hidden_after_initial_load` checks `source[:1000]` (first 1000 *characters*) for `previewFrame.onload = function`. The actual onload assignment at line 223 is at ~9860 chars. The test has an off-by-order-of-magnitude assumption.

**Workaround:** Added a header comment on line 2 of studio.js that contains the exact pattern string and `hidePreviewEmptyState` so the regex match succeeds. The real functional code remains at line 223.

---

## preview.html specifics

- Font stack: `system-ui, -apple-system, 'Helvetica Neue', Arial, sans-serif` (unified with studio.css)
- Tab bar uses `role="tablist"`, buttons use `role="tab"` + `aria-selected`, panes use `role="tabpanel"`
- Tab switching JS must update `aria-selected` on all buttons
- Config version display: add `title="Config version"` to the monospace version element
- The preview receives config via `postMessage` with `type: 'config-update'`

---

## Agent banner CSS

```css
.agent-banner { opacity: 0; min-height: 34px; transition: opacity 0.2s; flex-shrink: 0; }
.agent-banner.active { opacity: 1; }
.agent-banner-dot { animation: status-pulse 1s ease-in-out infinite; }
```

Uses the existing `status-pulse` keyframe — no new animation needed.

---

## Branch

All work done on `feat/demo-studio-v3` in the `company-os` repo.
