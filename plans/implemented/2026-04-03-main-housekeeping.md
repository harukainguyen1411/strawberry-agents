---
status: draft
owner: pyke
gdoc_id: 1wZsbgD71XJp-xGzcrxqOWXV7ltxZ5yQOXinyq-qXtqc
gdoc_url: https://docs.google.com/document/d/1wZsbgD71XJp-xGzcrxqOWXV7ltxZ5yQOXinyq-qXtqc/edit
---

# Main Branch Housekeeping

Post-merge cleanup after PRs #1-7. Five items, ordered by dependency.

## Step 0 — Reduce agent state churn in git

**Problem:** Every session, ~6 agents update memory, journals, learnings, and last-session files. That's 15-20 file changes hitting main constantly. The ops separation (PR #5) only moved truly ephemeral files (inbox, health JSON, conversations). The remaining "durable" files still churn.

**Analysis — what actually needs git history:**

| File type | Churn | Value in git | Verdict |
|---|---|---|---|
| `memory/<name>.md` | Every session | HIGH — agent's evolving state, meaningful diffs | **Keep in git** |
| `learnings/` | Occasional | HIGH — reusable knowledge, rarely changes | **Keep in git** |
| `journal/` | Every session | LOW — session reflections, archival only | **Move to ops** |
| `memory/last-session.md` | Every session | NONE — handoff note, only useful for next boot | **Move to ops** |

**Recommendation: Extend ops separation for journal/ and last-session.md**

This cuts session churn from ~20 files to ~6 (just the memory files that meaningfully changed). Those remaining diffs are valuable — they're the agent's memory evolving.

**Implementation:**
1. Add to `.gitignore`:
   ```
   agents/*/journal/
   agents/*/memory/last-session.md
   ```
2. Update `scripts/migrate-ops.sh` to migrate journal/ and last-session.md to `~/.strawberry/ops/`
3. Update agent-manager MCP server if it reads/writes these paths
4. Update CLAUDE.md session closing instructions to reflect new paths (or keep paths the same if MCP handles the redirect via OPS_PATH)

**Why not broader options:**
- **.gitignore everything** — memory/<name>.md has real value in git. Losing it on clone kills the agent.
- **Dedicated branch** — merge hell. Overengineered for the problem.
- **Selective commits** — still requires discipline every session. Automating the boundary is cleaner.

**Bundle with Step 3** — same fix/ branch, same PR. Both touch migrate-ops.sh and .gitignore.

### Agent memory commit strategy

**Recommendation: Direct commit to main during session close. No PRs.**

Each agent commits their own `memory/<name>.md` and `learnings/` files as part of the session closing sequence, using prefix `chore(agent):`.

**Why this works:**
- **No conflict risk.** Agent X only writes to `agents/X/memory/` and `agents/X/learnings/`. Files are agent-scoped — no two agents touch the same file.
- **PRs add zero value here.** Nobody reviews a memory diff. It's an agent's internal state, not code. Routing it through PRs is bureaucracy for its own sake.
- **Low blast radius.** If a memory file is wrong, the agent overwrites it next session. Self-healing.

**The one real risk — simultaneous sessions:**
Two agents running at the same time, both try to commit + push. Git rejects the second push (non-fast-forward). Solution: `git pull --rebase` before commit in the session close sequence. Memory files don't overlap, so rebase will always auto-resolve.

**Session close commit sequence:**
```bash
git pull --rebase origin main
git add agents/<name>/memory/<name>.md agents/<name>/learnings/
git commit -m "chore(agent): <name> session state update"
git push origin main
```

**Branch protection implications:**
If/when Duong enables branch protection on main, we need one of:
- Exempt `chore(agent):` commits (not natively supported by GitHub branch protection)
- Add a bypass for the bot/user account agents run under
- Or accept that memory commits go through a lightweight auto-merge PR (last resort — adds friction)

**Recommendation for Step 5:** Configure branch protection to require PRs for code changes but allow the account running agents to push directly. This is the cleanest split.

---

## Execution Order

### Step 1 — Chore commit: agent state files

Commit all modified and untracked agent memory/journal/learning files on main.

**Files (modified):**
- agents/bard/memory/bard.md
- agents/caitlyn/memory/caitlyn.md
- agents/conversations/agent-network-optimization.md
- agents/evelynn/memory/evelynn.md
- agents/evelynn/memory/last-session.md
- agents/lissandra/memory/lissandra.md
- agents/pyke/memory/pyke.md
- agents/syndra/memory/syndra.md
- agents/health/evelynn.json
- agents/health/pyke.json

**Files (untracked):**
- agents/bard/journal/, agents/bard/learnings/, agents/bard/memory/last-session.md
- agents/caitlyn/journal/, agents/caitlyn/memory/last-session.md
- agents/evelynn/journal/cli-2026-04-03.md
- agents/lissandra/journal/, agents/lissandra/memory/last-session.md
- agents/pyke/journal/, agents/pyke/memory/last-session.md
- agents/syndra/journal/, agents/syndra/memory/last-session.md

**Commit message:** `chore(agents): commit session state — memory, journals, learnings`

**Why first:** Clean working tree required before branching for Step 3.

---

### Step 2 — Stash cleanup

Delete stale stashes left from feature/ops-separation work.

**Commands:**
```
git stash list   # verify which stashes exist
git stash drop <index>   # drop each one
```

**Why here:** Low risk, no dependencies. Good to clear before branching.

---

### Step 3 — Fix PR: Syndra's two findings on migrate-ops.sh

Branch from main, fix, PR, review, merge.

**Branch:** `fix/migrate-ops-improvements`

**Finding 1 — Missing inbox-queue/ in migration script**
- File: `scripts/migrate-ops.sh`
- The migration moves inbox/ but not inbox-queue/. Add inbox-queue/ to the ephemeral directories list.

**Finding 2 — Hardcoded AGENTS array**
- File: `scripts/migrate-ops.sh`
- Replace the static AGENTS=(...) array with dynamic discovery:
  ```bash
  for agent_dir in "$REPO_ROOT/agents"/*/; do
      agent_name=$(basename "$agent_dir")
      # process agent
  done
  ```

**Commit message:** `fix(ops): add inbox-queue to migration, use dynamic agent discovery`

**Review:** Route through Lissandra or Syndra (they raised the findings).

---

### Step 4 — Prune merged branches

Delete local and remote branches that have been fully merged to main.

**Branches to delete:**
- feature/agent-bootstrap
- feature/agent-manager-mcp-improvements
- feature/full-agent-system
- feature/ops-path-mcp
- feature/ops-separation
- feature/tasklist-app
- fix/caitlyn-review-findings

**Commands:**
```
git branch -d <branch>              # local (safe, merged-only)
git push origin --delete <branch>   # remote
```

**Why after Step 3:** In case we need to reference old branch state during the fix. Once fixes are merged, no reason to keep them.

---

### Step 5 — Branch protection on main

**Requires Duong.** Cannot be done via API (permission denied in previous session).

**Recommended rules:**
- Require PR before merging
- Require at least 1 review approval
- No direct pushes to main (except chore(agent) state commits — TBD if exemption needed)
- No force-pushes

**Action:** Flag to Duong via Evelynn. This is a manual GitHub settings step.

---

## Dependencies

```
Step 1 (chore commit) → Step 2 (stash cleanup) → Step 3 (fix PR) → Step 4 (branch prune)
Step 5 is independent — can happen anytime, requires Duong.
```

## Risk

Low across the board. All destructive operations (branch delete, stash drop) target already-merged or orphaned state. The fix PR is a small script change.
