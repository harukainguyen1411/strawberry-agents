# Last Session — 2026-04-08, CLI (Opus, borrowed Windows machine)

- Duong is on a borrowed Windows laptop. Mac stack (iTerm, MCP, Telegram) doesn't run here.
- Built **Windows Mode** — parallel isolated setup using Claude Code subagents + Remote Control instead of iTerm windows + Telegram. Mac stack untouched.
- Commit `a161190` on main: 6 subagent definitions in `.claude/agents/` (Syndra, Swain, Pyke, Bard, Katarina, Lissandra), launch scripts in `windows-mode/`, README.
- Plan in `plans/in-progress/2026-04-08-windows-mode.md`. Move to `implemented/` once Duong validates end-to-end.
- Old plan `2026-04-08-mcp-cross-platform.md` archived (superseded — porting Mac stack was the wrong direction).
- Git identity on this machine set locally (not global) to `harukainguyen1411` — Duong rejected using his work email, agent account is the right call for agent commits.
- This commit is **not yet pushed** — waiting for Duong to validate Windows Mode first, and unclear if GH token is available on this machine.

**Next session on this machine:**
- Launch via `windows-mode\launch-evelynn.bat` (runs `claude --dangerously-skip-permissions --remote-control "Evelynn"`)
- Test invoking a subagent (try Syndra on something light) to verify memory continuity works
- If everything works, move plan to `plans/implemented/` and push commit `a161190`

**Open threads (carried over, untouched today):**
- PR #54 (myapps) ready to merge, needs firestore index deploy
- Bard's launch-verification + Evelynn liveness plan — proposed, awaiting approval
- Swain's plan viewer plan — proposed, needs manual setup
- Stale PRs #26 #27 #28 — can be closed
- Firestore MCP server — Syndra recommends as next build priority
- Syndra's earlier work-agent-isolation plan in `plans/proposed/2026-04-06-work-agent-isolation.md` — still awaiting approval
