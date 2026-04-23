# Chat UI polish punch list — session page

**Advisory only.** Target: `http://localhost:8080/session/<id>`. Files anchored:
`templates/session.html`, `static/studio.css`, `static/studio.js` under
`company-os/tools/demo-studio-v3/`.

Top 5 highest-impact, smallest-scope improvements. Each is independently
dispatchable to Soraka/Seraphine.

---

## 1. Replace "Sending..." / "Responding..." with a single living status pill

**Anchors:** `studio.js:704` (`setAgentStatus('Sending...')`), `studio.js:1119`
(`'Responding...'`), `studio.js:1129` (`'Using ' + name + '...'`),
`studio.js:1137` (`'Thinking...'`); banner markup `studio.js:122-125`; CSS
`studio.css:653-683` (`.agent-banner`).

**Fix:** Unify vocabulary to verb phrases of the same shape ("Sending",
"Thinking", "Searching the web", "Writing reply") and drop the trailing
ellipsis — the pulsing dot already conveys liveness. Replace raw `'Using ' +
name` at `studio.js:1129` with `toolStatus(name)` (already exists at :570) so
the pill shows "Updating config" instead of "Using demo_studio__update_config".

**Why:** Current copy mixes gerunds, imperatives, and raw tool IDs. One voice
reads calm; three reads noisy.

---

## 2. Hide the three-dot typing indicator when the agent-status banner is active

**Anchors:** `studio.js:705` (`showTyping()` after `setAgentStatus`),
`studio.js:519-532` (typing markup), `studio.css:595-617`.

**Fix:** Remove the `showTyping()` call from `sendMessage` (`studio.js:705`)
and from any SSE path where the banner is already showing a status. Keep
typing dots only as a *pre-status* signal (first 300ms before the banner
appears) or delete entirely.

**Why:** Right now on send you get: user bubble + three-dot bubble + pulsing
banner saying "Sending..." — three loading affordances stacked. Pick one.

---

## 3. Add sender column/avatar rhythm and tighten bot message spacing

**Anchors:** `studio.css:394-403` (`.chat-messages` gap 12px),
`studio.css:410-466` (`.msg`, `.msg-bot`, `.msg-user`), `studio.css:746-759`
(`.msg-bot-wrap`, `.msg-bot-label`).

**Fix:** (a) Increase inter-message gap to 16px and add 4px extra top margin
when sender changes (group consecutive same-sender messages with 6px gap
instead). (b) Move the `.msg-bot-label` ("Agent") to render only on the first
message of a bot turn, not every bubble — currently repeats on every chunk.
(c) Drop `.msg` `font-size` from 13px to 14px for readability; keep 13px for
input/controls.

**Why:** Current layout reads as a flat list of pills; a conversational
rhythm (turn grouping + readable body size) is the single biggest perceived-
quality lift.

---

## 4. Error messages need an icon, a title, and a retry affordance

**Anchors:** `studio.js:716` (`addMessage('error', 'Chat request failed (' +
status + ')')`), `:723`, `:678`, `:839`, `:1172`; CSS `studio.css:478-486`
(`.msg-error`).

**Fix:** Introduce a structured error variant in `addMessage` that renders:
warning glyph + bold one-line summary ("Couldn't send message") + muted
secondary line with the status code + a text-link "Retry" that re-runs the
last action. At minimum, prepend an SVG/emoji warning glyph to the existing
`.msg-error` block and render the raw status on a second muted line.

**Why:** Errors currently look like any other bot bubble with a red left
border. Users miss them, and there is no recovery path without reloading.

---

## 5. Smooth message entry + preview-refresh flash timing

**Anchors:** `studio.css:374-382` (`.preview-refresh-flash` 0.3s /
`setTimeout 600`), `studio.js:236`, `:784`; message insertion at
`studio.js:351`, `:747`; no entry transition on `.msg`.

**Fix:** (a) Add a 120ms fade+translateY(4px) entry transition on `.msg`,
`.tool-indicator`, `.thinking-bubble` — cheap CSS, huge perceived polish.
(b) Soften preview flash: drop border width from 3px to 2px, change color
from solid teal to `rgba(13,148,136,0.5)`, shorten visible time to 400ms
(`studio.js:236` + `:784`). Current flash is jarring on every config write.
(c) On `chat-messages` auto-scroll (`studio.js:332-334`), only scroll if the
user was already within ~80px of the bottom — respect scroll-up to read
history.

**Why:** Three micro-interactions that each cost under 10 lines and together
make the agent feel unhurried rather than twitchy.

---

## Dispatch notes

- Items 1, 2, 4 are pure `studio.js` edits — dispatch to one Seraphine.
- Item 3 is CSS + small JS guard in `addMessage` — separate dispatch.
- Item 5 splits cleanly: 5a CSS-only, 5b JS constants, 5c JS scroll guard.

No new design tokens required; all changes use existing `--red`, `--teal`,
`--subtle`, `--mid`.
