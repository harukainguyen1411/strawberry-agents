# Verify current-state before accepting a gap-analysis table

**Context:** Sona's 2026-04-24 task brief for the secretary-MCP ADR included a
current-state table that labeled the Slack MCP as "⚠️ MCP registered but
connection broken (failed to reconnect today)." The table also listed
`mcp__gdrive__*` and `mcp__gcalendar__*` as "✅ exists — confirm scope."

**What actually turned out to be true:**
1. Running `claude mcp list` from `~/Documents/Work/mmp/workspace/` showed
   **6/6 work-side MCPs connected**, including Slack (`duong.nguyen.thai`).
2. The "broken Slack" was the *personal*-side MCP at
   `~/Documents/Personal/strawberry-agents/mcps/slack/`, which is
   Evelynn-concern and out of scope for a work-concern ADR.
3. Atlassian MCP was described as "❌ absent" but was actually scaffolded
   at `mcps/mcp-atlassian/` — just missing `.env` and not registered in
   `.mcp.json`.

**Lesson:** task briefs assembled by a coordinator with limited visibility
into the other concern's runtime state will occasionally misdiagnose
current state. Before writing an ADR that prescribes "fix the broken X"
or "add the missing Y," run the minimum verification:

- `claude mcp list` from the *correct* CWD (concern-appropriate `.mcp.json`
  is CWD-scoped — running from the wrong directory gives you the wrong
  surface).
- `ls mcps/<name>/` for anything tagged "absent" — scaffolds with missing
  `.env` look the same as genuine absence from a distance.
- `cat .mcp.json` on the relevant workspace to see what's actually
  registered vs. what's present-but-unregistered.

**Consequence for the ADR:** the decisions changed. The "Slack reconnect"
task in Sona's proposed Phase 0 became "confirm connection + migrate
secrets to encrypted path," and the Atlassian task became "provision + register"
rather than "full install." Both framings ship to Aphelios differently.

**Generalization:** this is the same family as the 2026-04-19
audit-the-doc-not-the-rule learning. Claims about *enforcement* drift
silently when the artifact changes; claims about *runtime state* drift
silently when the workspace/CWD that was probed differs from the
workspace the ADR operates in. The fix is identical: verify the claim
against the authoritative artifact before building on it.

| last_used: 2026-04-24
