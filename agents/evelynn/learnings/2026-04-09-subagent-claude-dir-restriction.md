# Subagents cannot write to .claude/

**Date:** 2026-04-09
**Session:** S31

Subagents (even Sonnet executors with full tool access) are blocked by the Claude Code harness from writing to `.claude/` paths — this includes `.claude/agents/*.md`, `.claude/skills/`, etc. This is a deliberate harness security restriction, not a permissions bug.

**Implication:** Any task that requires modifying agent definitions, skills, or other `.claude/` files MUST be done from the top-level Evelynn session. Cannot be delegated to Katarina, Fiora, or any other subagent.

**Workaround:** Run the edit directly from the top-level session using Write/Edit/Bash tools. This is one of the legitimate exceptions to rule 18 (Evelynn coordinates only — never executes).
