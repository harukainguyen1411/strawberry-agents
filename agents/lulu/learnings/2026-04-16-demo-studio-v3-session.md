---
name: Demo Studio v3 session learnings — 2026-04-16
description: Gotchas and process insights from the full design advisory session on Demo Studio v3
type: reference
---

## PR diff too large

`gh pr diff 24 -R missmp/company-os` fails when diff exceeds 20000 lines. Workaround: use `gh api repos/missmp/company-os/pulls/24/files` to list files, then fetch specific file patches with `jq '.[] | select(.filename == "...") | .patch'`.

## Write tool rejects unread files

The Write tool will refuse to overwrite a file that hasn't been read in the current context window ("File has not been read yet"). Fix: read at least a few lines of the file first with the Read tool before overwriting.

## Architecture changed mid-session

The refactor plan at `company-os/plans/2026-04-16-demo-studio-v3-refactor.md` was updated during the session — it went from a 3-service model to a 5-service model where Services 2-5 are separate team-owned codebases. Always re-read the plan file before producing architecture diagrams or design advice.

## Preview empty state bug (Issue 1)

Root cause: `studio.js` line 219 sets `previewFrame.src` without attaching an `onload` handler first. `hidePreviewEmptyState()` is only called inside `refreshPreview()`'s `onload` — which is never called on initial load. Fix: attach `onload` before setting `.src` at line 219.

## Agent status indicator bug (Issue 2)

Two-part: (1) `clearAgentStatus()` is called after every `tool_result` event, causing gaps between sequential tool calls. (2) The status bar (`.agent-status-bar`) is too subtle — 11px, `opacity: 0` by default, only visible when `.visible` is added. Fix: (1) remove `clearAgentStatus()` from `tool_result` handlers; (2) introduce a more prominent `.agent-banner` DOM element above the chat input with a pulsing red dot.

## SSE event handlers are in two places

Both `handleSSE()` (line 725) and the persistent stream `connectStream()` block (lines 1079-1280) contain `tool_result` case handlers that call `clearAgentStatus()`. Both must be updated when changing status behavior.

## plans-overview.html is a design artifact

The file at `company-os/tools/demo-studio-v3/plans-overview.html` is a standalone HTML architecture overview — no external dependencies, all CSS inline. It was rewritten 3 times during the session (3-service → target arch → 5-service). Current version (5-service) is authoritative.
