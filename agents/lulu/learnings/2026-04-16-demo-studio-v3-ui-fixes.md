# Demo Studio v3 — UI Fix Plan

**Date:** 2026-04-16
**Author:** Lulu
**For:** Seraphine
**Issues:** Preview not auto-loading · Status indicators not persistent

---

## How to read this plan

Each issue has: root cause diagnosis, exact changes needed, which functions to touch, and what the result should look like. All line references are from the current `studio.js` and `studio.css` as of 2026-04-16.

---

## Issue 1: Preview not loading on initial page load

### Root cause

The problem is in `studio.js` around line 219. The initial load sets the iframe `src` directly:

```js
previewFrame.src = '/session/' + sessionId + '/preview';
```

This fires the load, but no `onload` handler is attached at this point. The `previewEmptyState` overlay only hides inside `refreshPreview()` (line 830–836), which wires up `previewFrame.onload`. Because `refreshPreview()` is never called on initial load, the overlay never hides — even after the iframe finishes loading.

Additionally, the `preview-empty-state` element starts visible (no `.hidden` class in the DOM), so users see the "Waiting for your first message..." placeholder regardless of whether config exists.

### Fix: wire onload on the initial src assignment

**File:** `studio.js`
**Location:** line 218–219 (the `// Load preview` block)

Replace:

```js
// Load preview
previewFrame.src = '/session/' + sessionId + '/preview';
```

With:

```js
// Load preview — wire onload to hide the empty state overlay
previewFrame.onload = function() {
  previewFrame.classList.remove('refreshing');
  hidePreviewEmptyState();
  refreshFlash.classList.add('active');
  setTimeout(function() { refreshFlash.classList.remove('active'); }, 600);
};
previewFrame.src = '/session/' + sessionId + '/preview';
```

### Why refreshPreview() re-assigns onload and that's fine

`refreshPreview()` (line 827) reassigns `previewFrame.onload` on each call, which is intentional — it prevents stale handlers. The initial load should do the same thing. This makes the initial load and all subsequent refreshes behave identically.

### Also: ensure empty state is visible by default, hidden after first load

The `.preview-empty-state` in the DOM starts without `.hidden`, which is correct. But confirm the CSS (line 733–749) has `opacity: 1` as default and `opacity: 0` only on `.hidden`. Currently it does — no CSS change needed.

### Config auto-refresh via Firestore already works — but only after the first load

The Firestore `onSnapshot` handler (line 843–898) calls `refreshPreview()` when `configVersion` increments. This is correct — config changes will auto-refresh the preview. The only gap was the initial page load not hiding the empty state. The fix above resolves it.

### Edge case: session has no config yet

If the session was just created and has no config, the preview endpoint will render an empty/default state. This is fine — the empty state overlay hides as soon as the iframe loads (even if the content is minimal). The preview endpoint should return a 200 with a graceful empty config render, which it already does (`DEFAULTS` in `preview.html`).

---

## Issue 2: Agent status indicators not persistent

### Root cause

There are two problems:

**Problem A — Status clears between tool calls:**
`clearAgentStatus()` is called in `tool_result` handler (line 775), which fires after every single tool completes. When the agent uses multiple tools in sequence, the status clears after each one, then reappears for the next. During the gap the user sees nothing. This also happens in the persistent event stream (line 1191–1193): `tool_result` calls `clearAgentStatus()` if not `sending`.

**Problem B — The status bar is too hidden:**
The `.agent-status-bar` sits in the chat input area below the message thread. It uses `opacity: 0` / `opacity: 1` transitions and `min-height: 22px`. Because it's inside the input area and not prominently placed, users miss it entirely even when it's showing. The text is `font-size: 11px; color: #888` — very easy to overlook.

### Fix A: Add a persistent top-level status banner

A dedicated banner at the top of the chat panel is the right pattern. It should:
- Appear whenever the agent is active (thinking, tool calls, etc.)
- Disappear only when the agent is fully done (`done` event)
- Stay visible across multiple tool calls within the same agent turn
- Show the current operation clearly

**File:** `studio.js`
**Location:** Inside the DOM construction array (line 73–199), after the `chat-messages` div and before the `chat-input-area` div.

Add this element inside the chat panel, between `chat-messages` and `chat-input-area`:

```js
'    <div class="agent-banner" id="agentBanner" aria-live="polite" aria-atomic="true">',
'      <div class="agent-banner-dot" id="agentBannerDot"></div>',
'      <span id="agentBannerText"></span>',
'    </div>',
```

**File:** `studio.css`
**Add after the `.agent-status-bar` block (around line 650):**

```css
/* ── Agent banner — persistent status above input area ── */
.agent-banner {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 7px 16px;
  background: rgba(249, 79, 30, 0.05);
  border-top: 1px solid rgba(249, 79, 30, 0.12);
  font-size: 12px;
  font-weight: 500;
  color: var(--mid);
  min-height: 34px;
  opacity: 0;
  pointer-events: none;
  transition: opacity 0.2s;
  flex-shrink: 0;
}

.agent-banner.active {
  opacity: 1;
  pointer-events: auto;
}

.agent-banner-dot {
  width: 7px;
  height: 7px;
  border-radius: 50%;
  background: var(--red);
  flex-shrink: 0;
  animation: status-pulse 1s ease-in-out infinite;
}
```

The `.agent-banner.active` class controls visibility. The existing `status-pulse` keyframe animation in CSS (line 647–650) already covers the dot animation — no new keyframe needed.

### Fix B: Replace setAgentStatus / clearAgentStatus to drive the banner

**File:** `studio.js`
**Replace the existing `setAgentStatus` and `clearAgentStatus` functions (lines 508–519):**

Current:

```js
function setAgentStatus(text) {
  var bar  = document.getElementById('agentStatusBar');
  var span = document.getElementById('agentStatusText');
  if (!bar || !span) return;
  span.textContent = text;
  bar.classList.remove('hidden');
}

function clearAgentStatus() {
  var bar = document.getElementById('agentStatusBar');
  if (bar) bar.classList.add('hidden');
}
```

Replace with:

```js
function setAgentStatus(text) {
  // Drive the persistent banner
  var banner = document.getElementById('agentBanner');
  var bannerText = document.getElementById('agentBannerText');
  if (banner && bannerText) {
    bannerText.textContent = text;
    banner.classList.add('active');
  }
  // Keep legacy status bar in sync (it lives near the input, belt-and-suspenders)
  var bar  = document.getElementById('agentStatusBar');
  var span = document.getElementById('agentStatusText');
  if (bar && span) {
    span.textContent = text;
    bar.classList.remove('hidden');
  }
}

function clearAgentStatus() {
  var banner = document.getElementById('agentBanner');
  if (banner) banner.classList.remove('active');
  var bar = document.getElementById('agentStatusBar');
  if (bar) bar.classList.add('hidden');
}
```

### Fix C: Don't clear status between tool calls — only on done/error

The critical change: `clearAgentStatus()` must NOT be called in `tool_result`. Remove it from there and call it only on `done` and `error`.

**File:** `studio.js`

**In `handleSSE()` (around line 773–783):**

Current `tool_result` case:

```js
case 'tool_result':
  currentBotMsg = null;
  currentBotText = '';
  clearAgentStatus();         // <-- REMOVE THIS LINE
  resolveToolIndicator(data.tool_use_id, data);
  if (data.configVersion && data.configVersion > lastConfigVersion) {
    ...
  }
  break;
```

Remove `clearAgentStatus()` from `tool_result`. The status should persist until the `done` event.

**In the persistent event stream (around line 1191–1193):**

Current:

```js
eventSource.addEventListener('tool_result', function(e) {
  if (!sending) clearAgentStatus();   // <-- REMOVE THIS
});
```

Remove that handler entirely (or remove just the `clearAgentStatus()` call). The event stream's `done` listener already handles clearing.

### Fix D: Update status messages to be specific and human-readable

**File:** `studio.js`
**Update `toolStatus()` (lines 521–535) and the `handleSSE` `thinking` / `running` cases:**

The emoji prefixes in `toolStatus()` are fine visually but rely on emoji rendering. Replace them with plain text for the banner (where it needs to be consistent):

```js
function toolStatus(name) {
  var map = {
    'web_search':                    'Searching the web...',
    'web_fetch':                     'Fetching page...',
    'demo_studio__update_config':    'Updating config...',
    'demo_studio__set_config':       'Updating config...',
    'set_config':                    'Updating config...',
    'demo_studio__get_config':       'Reading config...',
    'demo_studio__validate_config':  'Validating config...',
    'validate_config':               'Validating config...',
    'demo_studio__trigger_factory':  'Starting factory build...',
    'demo_studio__run_qc':           'Running QC checks...',
  };
  return map[name] || 'Using tool: ' + name.replace(/__/g, ' ').replace(/_/g, ' ') + '...';
}
```

**Update `handleSSE` for `thinking` (line 757–759):**

```js
case 'thinking':
  setAgentStatus('Thinking...');
  addThinkingBubble(data.content_preview || data.thinking || '');
  break;
```

(No change needed here — `setAgentStatus` is already called.)

**Update `handleSSE` for `running` (line 785–789):**

```js
case 'running':
  currentBotMsg = null;
  currentBotText = '';
  setAgentStatus('Thinking...');
  break;
```

(No change needed — already correct.)

**Update `handleSSE` for `text` (line 727–754):**

When the agent starts sending a text response, update the banner to show it's responding (not blank between thinking and full message render):

```js
case 'text':
  currentToolGroup = null;
  currentToolGroupItems = [];
  setAgentStatus('Responding...');   // <-- ADD THIS
  // ... rest of existing logic unchanged
```

This prevents the banner from clearing mid-response. The `done` event will clear it when the full turn is finished.

### Summary of all changes for Issue 2

| What | Where | Change |
|------|-------|--------|
| Add `.agent-banner` to DOM | `studio.js` DOM construction array | Insert after `.chat-messages`, before `.chat-input-area` |
| Add `.agent-banner` CSS | `studio.css` after `.agent-status-bar` block | New rules for `.agent-banner` and `.agent-banner-dot` |
| Update `setAgentStatus()` | `studio.js` ~line 508 | Drive both banner and legacy bar |
| Update `clearAgentStatus()` | `studio.js` ~line 516 | Hide both banner and legacy bar |
| Remove `clearAgentStatus()` from `tool_result` | `studio.js` ~line 775 | Delete that one call |
| Remove `clearAgentStatus()` from stream `tool_result` | `studio.js` ~line 1191 | Delete the listener or its body |
| Add `setAgentStatus('Responding...')` to `text` case | `studio.js` ~line 727 | Add one line at top of case |
| Update `toolStatus()` map | `studio.js` ~line 521 | Remove emoji prefixes |

---

## Visual design of the banner

The banner should sit between the message thread and the input area, flush to the full panel width. When active:

```
┌────────────────────────────────────────────┐
│  ● Searching the web...                    │  ← agent-banner (active)
├────────────────────────────────────────────┤
│  [Type a message...              ] [Send]  │  ← chat-input-area
└────────────────────────────────────────────┘
```

The dot pulses (using the existing `status-pulse` animation). The background is a very light red tint (`rgba(249,79,30,0.05)`) with a red-tinted top border. Text is `var(--mid)` at 12px — readable but not alarming.

When inactive (no agent activity), the banner collapses via `opacity: 0` and holds its height at `min-height: 34px` so the layout doesn't jump. If this layout jank is noticeable, change `min-height: 34px` to `height: 0; min-height: 0; padding: 0` when inactive and add a height transition — but try the opacity-only approach first.

---

## SSE events reference — full list currently handled

For Seraphine's reference: these are all SSE event types that exist in the stream and what each should trigger in the status banner.

| Event | Current behavior | Desired banner behavior |
|-------|-----------------|------------------------|
| `running` | `setAgentStatus('Thinking...')` | Show banner: "Thinking..." |
| `thinking` | `setAgentStatus('💬 Thinking...')` | Show banner: "Thinking..." |
| `tool_use` | `setAgentStatus(toolStatus(name))` | Show banner: e.g. "Searching the web..." |
| `tool_result` | `clearAgentStatus()` ← **remove this** | Do nothing — banner persists |
| `text` | `clearAgentStatus()` (implicit via new turn) | Show banner: "Responding..." |
| `done` | `clearAgentStatus()` | Hide banner |
| `error` | `clearAgentStatus()` | Hide banner |
| `status` (stream) | various | No banner change needed |
| `connected` (stream) | various | No banner change needed |

---

## Testing checklist

**Issue 1 — Preview:**
- [ ] Load a session that already has config — preview should appear without hitting Refresh
- [ ] Load a fresh session — preview shows a default/empty state (no "Waiting for your first message" overlay stuck)
- [ ] Send a message that triggers `set_config` — preview auto-refreshes after `tool_result` with configVersion increment
- [ ] Firestore `onSnapshot` fires configVersion change — preview auto-refreshes

**Issue 2 — Status:**
- [ ] Send a message — banner appears immediately with "Thinking..."
- [ ] Agent uses `web_search` — banner updates to "Searching the web..." and stays visible
- [ ] Agent completes tool, moves to next tool — banner stays visible (does not flash empty between tools)
- [ ] Agent sends text response — banner shows "Responding..."
- [ ] Agent turn completes (`done` event) — banner disappears smoothly
- [ ] Agent errors — banner disappears
- [ ] On mobile (chat tab active) — banner is visible at bottom of chat panel above input
