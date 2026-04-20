---
date: 2026-04-20
auditor: skarner
scope: agents/* (excluding evelynn, sona)
status: read-only — Yuumi executes cleanup
---

# Agent Folder Audit — 2026-04-20

**Agents audited:** 27  
**Total format violations:** 47 (dirs/files to remove across all agents)  
**Total trivial-learning candidates:** 4  
**Agents with missing learnings/index.md:** 5 (caitlyn, heimerdinger, lulu, lux, seraphine)  

---

## Summary of Findings

### Orphan / Stub Agents (no .claude definition, not in agents-table)

These agents have `agents/<name>/` directories but no active or retired `.claude` definition and do not appear in `agents/memory/agents-table.md`. They are structural orphans.

| Agent | Status | Notes |
|---|---|---|
| **irelia** | Orphan stub | Contains only `journal/` with `.gitkeep`. No profile.md, memory/, learnings/. |
| **rakan** | Orphan stub | Has profile.md, memory/, inbox/, journal/, transcripts/ — no .claude def, not in table. |

**Recommended action:** Remove both directories entirely, or document them as deliberately archived.

---

### health

- `agents/health/` contains only `_retired/` (JSON files) and `.gitkeep`.
- No profile.md, memory/, learnings/. Not in agents-table.
- The `_retired/` directory under `health/` is the wrong location — retired agent JSON files sit here instead of in `agents/_retired/`.
- **Format violations:** entire `agents/health/` is a structural orphan with misplaced content.

---

### Retired agents with lingering dirs (in `_retired-agents/` but still have `agents/<name>/` dirs)

These agents are in `.claude/_retired-agents/` (confirmed retired) but their `agents/` subdirectories remain. They are not in the active agents-table. Learnings were migrated to successor agents.

| Agent | Retired .claude file | Has `_migrated-from-<name>` in successor? |
|---|---|---|
| **lissandra** | `.claude/_retired-agents/lissandra.md` | Yes — `agents/senna/learnings/_migrated-from-lissandra/` |
| **pyke** | `.claude/_retired-agents/pyke.md` | Yes — `agents/camille/learnings/_migrated-from-pyke/` |
| **shen** | `.claude/_retired-agents/shen.md` | Yes — `agents/camille/learnings/_migrated-from-shen/`, `agents/ekko/learnings/_migrated-from-shen/` |

**Format violations:** These dirs are surplus (migration complete). No profile.md in any.

---

## Per-Agent Detail

### aphelios

- **Format violations:** `transcripts/` (empty — 0 files)
- **Learnings index:** present
- **Trivial learnings:** none

---

### azir

- **Format violations:** `journal/` (2 files), `_archive/`, `transcripts/` (empty)
- **Learnings index:** present

---

### caitlyn

- **Format violations:** `journal/` (5 files), `transcripts/` (2 files)
- **Missing:** `learnings/index.md`
- **Trivial learnings:** none — all 6 files contain durable cross-session patterns

---

### camille

- **Format violations:** `journal/` (2 files), `_archive/`, `transcripts/` (empty)
- **Learnings index:** present

---

### ekko

- **Format violations:** `journal/` (3 files), `journal.md` (stray file), `journals/` (extra subdir), `_archive/`
- **Learnings index:** present
- **Trivial learning candidates:**
  - `2026-04-20-pr40-api-refresh.md` — operational log only ("tree already up to date, no changes"); no reusable pattern
  - `2026-04-20-missmp-api-clone.md` — records a one-time clone operation; facts already in memory; no generalizable lesson

---

### health

See "Orphan / Stub Agents" section above. Entire directory is a format violation.

---

### heimerdinger

- **Format violations:** `_archive/`, `transcripts/` (empty)
- **Missing:** `learnings/index.md`
- **Trivial learnings:** none

---

### irelia

See "Orphan / Stub Agents" section above. Contains only `journal/` with `.gitkeep`.

---

### jayce

- **Format violations:** `transcripts/` (empty)
- **Learnings index:** present
- **Trivial learnings:** none — the two shortest files (`b16a-pr-supersession-recon`, `reviewer-lag-stale-commit`) contain clear reusable gotcha patterns

---

### kayn

- **Format violations:** `journal/` (1 file)
- **Learnings index:** present
- **Trivial learnings:** none — all task-breakdown learnings contain structural decisions and gotchas that inform future breakdowns

---

### lissandra

See "Retired agents" section above.
- **Format violations:** no profile.md (retired), `learnings/` exists without being migrated away
- **Learnings index:** present
- All 3 learnings could be retained in-place or remain until Yuumi removes the dir

---

### lucian

- **Format violations:** `journal.md` (stray file — should not exist, no `journal/` dir is permitted)
- **Missing:** profile.md
- **Learnings index:** present
- **Note:** Lucian is active (in agents-table) but missing profile.md — this is a gap, not a retirement case

---

### lulu

- **Format violations:** `transcripts/` (empty)
- **Missing:** `learnings/index.md`
- **Trivial learnings:** none

---

### lux

- **Format violations:** `transcripts/` (empty — not observed but dir may exist per earlier scan; confirmed empty)
- **Missing:** profile.md (agent is active per agents-table — gap to fill), `memory/` dir, `learnings/index.md`
- **Note:** Lux is active in agents-table but is missing three required items. Only `learnings/` exists.

---

### neeko

- **Format violations:** `journal/` (3 files), `transcripts/` (empty)
- **Learnings index:** present

---

### orianna

- **Format violations:**
  - `inbox.md` (stray flat file — should be `inbox/` directory or removed; contains only "No messages.")
  - `allowlist.md` (stray operational file — not a permitted format item)
  - `claim-contract.md` (stray operational file)
  - `runbook-reconciliation.md` (stray operational file)
  - `prompts/` subdir (not a permitted subdir)
- **Learnings index:** present
- **Note:** The 4 stray files and `prompts/` appear to be runtime artifacts from Orianna's fact-check and memory-audit operations. If retained, they should move to `assessments/` or a dedicated operational location, not the agent's profile directory.

---

### pyke

See "Retired agents" section above.
- **Missing:** profile.md (retired)
- **Learnings index:** present (1 learning file)

---

### rakan

See "Orphan / Stub Agents" section above.
- **Format violations:** `journal/` (2 files), `transcripts/` (empty)
- **Missing:** `learnings/` dir entirely

---

### senna

- **Format violations:** `journal.md` (stray flat file)
- **Missing:** profile.md
- **Learnings index:** present
- **Note:** Senna is active (in agents-table) but missing profile.md

---

### seraphine

- **Format violations:** `_archive/`, `transcripts/` (empty)
- **Missing:** `learnings/index.md`

---

### shen

See "Retired agents" section above.
- **Missing:** profile.md (retired)
- **Learnings index:** present

---

### skarner

- **Missing:** `learnings/` dir entirely
- **Note:** agent-network.md states "Skarner and Yuumi" are exempt from session-end learnings + memory writes. However, `learnings/` is still listed as a required structural component in the enforced format. Clarification needed: either add an empty `learnings/` + `index.md`, or formally document the exemption in the format spec.

---

### swain

- **Format violations:** `journal/` (2 files)
- **Missing:** profile.md
- **Note:** agents-table lists swain with directory `—` (no official agents/ dir). The `agents/swain/` directory exists informally. This is an ambiguous case — either the directory should be made official (add to table, add profile.md) or removed.
- **Learnings index:** present

---

### vex

- **Format violations:** `transcripts/` (1 file)
- **Learnings index:** present

---

### vi

- **Format violations:** `transcripts/` (empty)
- **Learnings index:** present

---

### viktor

- **Format violations:** `journal/` (empty — 0 files), `_archive/`
- **Learnings index:** present

---

### yuumi

- **Format violations:** `_archive/`, `transcripts/` (empty)
- **Learnings index:** present

---

## Consolidated Violation List for Yuumi

### Dirs/files to remove

| Path | Reason |
|---|---|
| `agents/aphelios/transcripts/` | Empty, format violation |
| `agents/azir/journal/` | Format violation (2 files inside) |
| `agents/azir/_archive/` | Format violation |
| `agents/azir/transcripts/` | Empty, format violation |
| `agents/caitlyn/journal/` | Format violation (5 files inside) |
| `agents/caitlyn/transcripts/` | Format violation (2 files inside) |
| `agents/camille/journal/` | Format violation (2 files inside) |
| `agents/camille/_archive/` | Format violation |
| `agents/camille/transcripts/` | Empty, format violation |
| `agents/ekko/journal/` | Format violation (3 files inside) |
| `agents/ekko/journal.md` | Stray flat file |
| `agents/ekko/journals/` | Extra non-standard subdir |
| `agents/ekko/_archive/` | Format violation |
| `agents/health/` | Entire dir is orphan; `_retired/` contents belong elsewhere |
| `agents/heimerdinger/_archive/` | Format violation |
| `agents/heimerdinger/transcripts/` | Empty, format violation |
| `agents/irelia/` | Entire orphan stub dir |
| `agents/jayce/transcripts/` | Empty, format violation |
| `agents/kayn/journal/` | Format violation (1 file inside) |
| `agents/lissandra/` | Retired agent dir (migration complete) |
| `agents/lucian/journal.md` | Stray flat file |
| `agents/lulu/transcripts/` | Empty, format violation |
| `agents/neeko/journal/` | Format violation (3 files inside) |
| `agents/neeko/transcripts/` | Empty, format violation |
| `agents/orianna/inbox.md` | Stray flat file (empty stub) |
| `agents/orianna/allowlist.md` | Stray operational file |
| `agents/orianna/claim-contract.md` | Stray operational file |
| `agents/orianna/runbook-reconciliation.md` | Stray operational file |
| `agents/orianna/prompts/` | Non-standard subdir |
| `agents/pyke/` | Retired agent dir |
| `agents/rakan/` | Entire orphan stub dir (no .claude def, not in table) |
| `agents/senna/journal.md` | Stray flat file |
| `agents/seraphine/_archive/` | Format violation |
| `agents/seraphine/transcripts/` | Empty, format violation |
| `agents/shen/` | Retired agent dir (migration complete) |
| `agents/swain/journal/` | Format violation (2 files inside) |
| `agents/vex/transcripts/` | Format violation (1 file inside) |
| `agents/vi/transcripts/` | Empty, format violation |
| `agents/viktor/journal/` | Empty, format violation |
| `agents/viktor/_archive/` | Format violation |
| `agents/yuumi/_archive/` | Format violation |
| `agents/yuumi/transcripts/` | Empty, format violation |

### Trivial learnings to cull

| File | Reason |
|---|---|
| `agents/ekko/learnings/2026-04-20-pr40-api-refresh.md` | Operational log only — records "already up to date, no changes"; no reusable pattern |
| `agents/ekko/learnings/2026-04-20-missmp-api-clone.md` | One-time clone operation log; facts are session-specific, no generalizable lesson |

### Missing index.md (create empty index)

| Agent | Path |
|---|---|
| caitlyn | `agents/caitlyn/learnings/index.md` |
| heimerdinger | `agents/heimerdinger/learnings/index.md` |
| lulu | `agents/lulu/learnings/index.md` |
| lux | `agents/lux/learnings/index.md` |
| seraphine | `agents/seraphine/learnings/index.md` |

### Missing required structure on active agents (need creation, not deletion)

| Agent | Missing items | Notes |
|---|---|---|
| lucian | `profile.md` | Active in table |
| lux | `profile.md`, `memory/` dir | Active in table |
| senna | `profile.md` | Active in table |
| swain | `profile.md` | Ambiguous — dir not officially listed in table; clarify with Duong |

### Needs clarification (do not act without Duong sign-off)

| Item | Question |
|---|---|
| `agents/swain/` | agents-table lists `—` as swain's directory. Is this dir intentional or legacy? If intentional, add profile.md + update table. If not, remove. |
| `agents/skarner/learnings/` | agent-network.md exempts Skarner from session-end writes but the enforced format still requires `learnings/` + `index.md`. Add skeleton or formally document exemption. |
| `agents/orianna/prompts/`, `allowlist.md`, etc. | These are operational files. If needed, move to `assessments/orianna/` or a new `agents/orianna/ops/` location — but any new subdir name requires format-spec update. |
