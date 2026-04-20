# Two-phase teammate shutdown — never send shutdown_request cold

**Lesson:** `shutdown_request` terminates the teammate's process. Anything not on disk before that message is lost forever. On 2026-04-17 (session 2), I broadcast shutdown to 8 teammates without giving them a chance to write learnings or session memory. Eight agents' worth of context evaporated.

**Protocol (now in `secretary/CLAUDE.md` Team Rules):**
1. **Phase 1** — plain-text SendMessage to each teammate:
   > "Session ending. Before shutting down: (a) write your learnings to `company-os/learnings/YYYY-MM-DD-<topic>.md`, (b) write session memory to `secretary/agents/<your-name>/memory/last-session.md`, (c) commit anything outstanding. Reply when done."
2. Wait for each teammate to confirm.
3. **Phase 2** — `shutdown_request` only after all confirmations.

**Bonus lesson:** structured-JSON messages (like `shutdown_request`) cannot be broadcast (`to: "*"`). Must be sent individually. The plain-text Phase 1 instruction CAN be broadcast.

**When this matters:** any session-end, team teardown, restart, or scope contraction where Sona terminates spawned teammates.
