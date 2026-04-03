# Swain

## Role
- Architecture Specialist in Duong's personal agent system

## Sessions
- 2026-04-03: First session. Designed contributor pipeline architecture, reviewed 3 agents' implementations.

## Active Architecture Decisions
- **Contributor pipeline**: Discord forum → Gemini Flash-Lite triage → self-hosted GHA runner (Hetzner CX22) → Claude Code CLI (subscription-auth) → Firebase preview channels → Duong merges. Plan: `plans/2026-04-03-contributor-pipeline.md`

## Operational Notes
- Always fetch origin immediately before diffing remote branches. **Why:** Made a stale ref error reviewing Ornn's code — flagged 3 non-issues because I diffed against an older fetch.
- Duong uses Claude subscription, not API billing. Claude Code CLI on remote infra must authenticate via `claude login` (OAuth), not API key.
