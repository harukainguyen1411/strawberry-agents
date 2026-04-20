---
name: Service communication diagram — 2026-04-16
description: Learnings from building the Demo Studio v3 service-communication HTML diagram
type: reference
---

## File created

`company-os/tools/demo-studio-v3/service-communication.html` — standalone HTML diagram (no external deps) showing all cross-service API calls for the 5-service Demo Studio architecture.

## Structure

- SVG architecture diagram with color-coded service boxes, directional arrows, endpoint labels, REST/SSE/iframe distinction
- 17-row API call reference table
- Auth model summary panel
- Key design decisions panel

## Edit tool requires prior read in same context window

When attempting to Edit a file after a context compaction (summary), the tool rejects with "File has not been read yet" even if the file was written in a prior session. Always Read at least a few lines before any Edit call at the start of a new context.

## Revert pattern

When a partial edit needs reverting (no git involved), use sequential Edit calls to undo each change in reverse order. Read the file first to confirm current state before each Edit.

## Abandoned change

User asked to show S1/S3/S5 as co-deployed (one Cloud Run service), then abandoned. The diagram remains showing all 5 as separate logical services — which is the intended target architecture regardless of current deployment state.
