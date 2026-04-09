---
title: CLAUDE.md refinement — split global rules from Evelynn-specific coordinator rules
status: approved
owner: syndra
created: 2026-04-09
---

# CLAUDE.md refinement

## Problem

`C:/Users/AD/Duong/strawberry/CLAUDE.md` has grown to ~127 lines and mixes three distinct audiences:

1. **Evelynn (the top-level session)** — who actually loads this file at the start of every turn because Evelynn has no `.claude/agents/evelynn.md` subagent definition. She *is* the top-level Claude Code process, so the repo-root `CLAUDE.md` functions as her de facto system prompt.
2. **Sonnet subagents** (katarina, fiora, yuumi, poppy, lissandra, shen, etc.) — who are spawned via the `Task` tool. Per Claude Code's subagent semantics, they do **not** inherit the parent's `CLAUDE.md`; they read only their `.claude/agents/<name>.md` file plus whatever that file tells them to read. So 90% of the rules in `CLAUDE.md` are **never seen** by Sonnet agents today — they only matter for whichever process loads the file. The rules that matter for Sonnet agents are already duplicated into each subagent definition (see katarina.md, yuumi.md lines 22-30).
3. **Opus planner subagents** (syndra, swain, pyke, bard) — same deal. They read their subagent definition, not the root `CLAUDE.md`.

This creates three concrete pathologies:

- **Duplication drift.** Rules 1, 4, 5, 10 are paraphrased inside every Sonnet agent definition. When CLAUDE.md changes, the subagent definitions don't, and they silently diverge. The rules-restructure plan (S15) already flagged this; the Opus planner gets to see the source-of-truth but the executors see stale copies.
- **Wrong audience.** Rules 2, 3, 18 ("Evelynn coordinates only", "delegated tasks report to Evelynn", "always prefer roster agents") are pure coordinator instructions. They belong to Evelynn alone — no Sonnet agent needs to read them because Sonnet agents don't delegate. Putting them in the shared "Critical Rules" block sells them as universal when they are not.
- **Reference noise.** Sections `File Structure`, `Key Scripts`, `Plugins`, `PR Rules`, `Operating Modes`, `Startup Sequence` are load-bearing for Evelynn (she's the one routing and deciding) and useless for a subagent whose scope is "read plan X, edit file Y, commit". The subagent's context window pays for content it cannot act on — except it doesn't, because subagents don't read it. So the only reader paying the cost is Evelynn herself, and she pays it on every single top-level turn.

Net: the file is a ~127-line preamble loaded on every Evelynn turn, 40% of which is universal truths that should be hard-coded elsewhere, 30% of which is Evelynn-specific and should be framed as such, and 30% of which is reference material that doesn't need to be in the system prompt at all.

## Proposed structure

Three-tier split driven by **who actually loads what**:

### Tier 1 — Repo-root `CLAUDE.md` (lean, global)

Keep only rules that are genuinely universal *and* that Evelynn needs in-context to route correctly. Target: ≤60 lines. Sections:

- **Scope** (1 line) — personal system, work goes elsewhere.
- **Critical Rules — global** (the invariants every writer of this codebase must know, whether it's Evelynn making a routing decision or a human opening the repo)
  - Rule 1: never leave work uncommitted
  - Rule 4: no secrets in committed files
  - Rule 5: use `git worktree` / `scripts/safe-checkout.sh`
  - Rule 10: `chore:` / `ops:` commit prefix only
  - Rule 11: never run raw `age -d`
  - Rule 12: use `scripts/plan-promote.sh` for plan moves
  - Rule 14: use `/end-session` / `/end-subagent-session` to close
  - Rule 15: every agent definition declares its model
  - Rule 17: scripts outside `scripts/mac/` and `scripts/windows/` must be POSIX-portable
- **Agent Routing** (greeting mechanic) — unchanged, short.
- **Operating Modes** (autonomous vs direct) — unchanged, short.
- **File Structure** — trimmed to a one-line-per-folder reference table.
- **Pointer to** `agents/evelynn/CLAUDE.md` — one line: "If you are the top-level coordinator session, also read `agents/evelynn/CLAUDE.md` for coordinator-specific rules."

What gets cut: Startup Sequence (moves to Evelynn's CLAUDE.md — nobody else follows it verbatim anyway, subagents have their own startup list in their definition file), Key Scripts table (moves to `architecture/key-scripts.md`), Plugins table (moves to `architecture/plugins.md`), Session Closing pointer (redundant with rule 14), PR Rules (moves to `architecture/pr-rules.md`), Secrets Policy (redundant with rule 4/11).

### Tier 2 — `agents/evelynn/CLAUDE.md` (coordinator-specific)

New file. Loaded by Evelynn explicitly (via a one-line pointer in Tier 1 and a bootstrapping read step). Contains everything that is Evelynn's job and no other agent's:

- Rule 2: delegated tasks — tracking via delegation JSON
- Rule 3: report task completion to Evelynn (this one is actually **Sonnet-facing**, but since Sonnet agents don't read root CLAUDE.md anyway, its only live home should be inside every subagent definition — see Tier 3 — and Evelynn's copy here is purely so she knows what to expect from subagents reporting back)
- Rule 6: Sonnet agents must never work without a plan file (Evelynn enforces this at delegation time)
- Rule 7: plan approval gate & Opus execution ban
- Rule 8: plan writers never assign implementers (Evelynn is the one who decides delegation)
- Rule 9: plans go directly to main, never via PR
- Rule 13: never end your session after completing a task
- Rule 16: MCPs only for external system integration (decision rests with Evelynn/Swain)
- Rule 18: Evelynn coordinates only — never executes
- Rule 19: always prefer roster agents over native subagent types
- **Startup Sequence** — Evelynn's ordered read list, since it's hers specifically
- **PR Rules** — Evelynn routes PR work, so she needs the checklist in-context
- **Delegation decision tree** — which agent for which work (pulls from current `agents/roster.md` + the three-minion distinction: Yuumi reads, Poppy edits, Katarina engineers)
- **Session Closing coordination** — when Evelynn is allowed to ask other agents to close

Target: 80–120 lines. This is Evelynn's full coordinator playbook.

### Tier 3 — Per-subagent `.claude/agents/<name>.md` (executor-specific, already exists)

Already the pattern. Each file already contains the rules the executor actually needs:
- chore: prefix commits
- no uncommitted work
- no secrets in committed files
- use `safe-checkout.sh` for branches
- implementation via PR, plans direct to main
- for Sonnet executors: must reference a plan file
- for Sonnet executors: report completion to Evelynn (this is where rule 3 actually lives in practice)

**Action for Tier 3:** instead of hand-copying rule text into each subagent file (today's status quo), each subagent file gets a short **"Authoritative rules"** reference block pointing at repo-root `CLAUDE.md` sections by anchor. Keep the 4–6 most load-bearing rules inline (because subagents don't get the root file auto-loaded) but de-duplicate the prose and ensure every subagent's inline copy says the same thing. A small lint script (`scripts/lint-subagent-rules.sh`, future, out of scope for this plan) can diff them later.

### Tier 4 — `architecture/` reference docs (moved out of CLAUDE.md)

- `architecture/key-scripts.md` — the Key Scripts table, plus any newer scripts (plan-publish, lint-subagent-rules, etc.)
- `architecture/plugins.md` — the Plugins table with longer descriptions, sub-agent access notes, and the "call ToolSearch first" gotcha
- `architecture/pr-rules.md` — PR template expectations, author line, docs checklist

These are Evelynn's references-on-demand, not things she needs in her startup preamble.

## What moves where — concrete mapping

| Current CLAUDE.md content | Destination |
|---|---|
| Rule 1 (uncommitted work) | Tier 1 root |
| Rule 2 (delegation JSON) | Tier 2 evelynn |
| Rule 3 (report to Evelynn) | Tier 2 evelynn + inlined in every subagent def (Tier 3) |
| Rule 4 (no secrets in commits) | Tier 1 root |
| Rule 5 (git worktree) | Tier 1 root |
| Rule 6 (Sonnet needs plan file) | Tier 2 evelynn + inlined in Sonnet subagent defs |
| Rule 7 (plan gate, Opus ban) | Tier 2 evelynn + inlined in Opus planner subagent defs (syndra, swain, pyke, bard) |
| Rule 8 (writers don't assign) | Tier 2 evelynn + Opus planner defs |
| Rule 9 (plans direct to main) | Tier 1 root (short) |
| Rule 10 (chore: prefix) | Tier 1 root |
| Rule 11 (no raw `age -d`) | Tier 1 root |
| Rule 12 (plan-promote.sh) | Tier 1 root |
| Rule 13 (don't end session on task done) | Tier 2 evelynn + Tier 3 subagent defs (both need it) |
| Rule 14 (use /end-session) | Tier 1 root |
| Rule 15 (agent model declaration) | Tier 1 root |
| Rule 16 (MCPs for external only) | Tier 2 evelynn |
| Rule 17 (POSIX portability) | Tier 1 root |
| Rule 18 (Evelynn never executes) | Tier 2 evelynn |
| Rule 19 (prefer roster agents) | Tier 2 evelynn |
| Scope | Tier 1 root |
| Agent Routing | Tier 1 root |
| Operating Modes | Tier 1 root |
| Startup Sequence | Tier 2 evelynn |
| Session Closing (pointer) | folded into rule 14 in Tier 1 |
| Git Rules | split: "never rebase" + "uncommitted" stay Tier 1; "avoid shell approval prompts" moves to Tier 2 evelynn (very Evelynn-specific habit) |
| PR Rules | Tier 4 `architecture/pr-rules.md`, Tier 2 evelynn links to it |
| Secrets Policy (prose) | removed, covered by rules 4 + 11 |
| File Structure | Tier 1 root (condensed) |
| Key Scripts | Tier 4 `architecture/key-scripts.md`, Tier 2 evelynn links to it |
| Plugins | Tier 4 `architecture/plugins.md`, Tier 2 evelynn links to it |

## Migration steps

1. **Create `architecture/key-scripts.md`, `architecture/plugins.md`, `architecture/pr-rules.md`** with the extracted content (verbatim cut-and-paste first; polish later).
2. **Create `agents/evelynn/CLAUDE.md`** with the Tier 2 content. Add a top banner: "This file is the coordinator-specific addendum to the repo-root CLAUDE.md. Evelynn reads both; other agents read neither."
3. **Rewrite repo-root `CLAUDE.md`** to the Tier 1 shape. Target ≤60 lines. Leave a final section "Evelynn-specific rules: see `agents/evelynn/CLAUDE.md`."
4. **Audit the ten existing `.claude/agents/*.md` subagent definitions** for rule drift against the new Tier 1 + Tier 2 set. Fix each to contain the inlined rules it actually needs (Sonnet executors get the executor subset; Opus planners get the planner subset). This is a Poppy-scope mechanical pass *after* someone (Katarina) designs the canonical inline block.
5. **Update cross-references** in `agents/memory/agent-network.md`, `agents/roster.md`, and any plan/assessment that links to specific CLAUDE.md rule numbers. Rule numbers will shift — consider switching to stable **anchor names** (`#rule-chore-commit-prefix`) rather than numbered rules, so future renumbering doesn't break links.
6. **Verify Evelynn actually loads `agents/evelynn/CLAUDE.md`.** Claude Code does not auto-discover subdirectory CLAUDE.md files for the top-level session (it only traverses upward from the CWD, not into subdirs). So the root CLAUDE.md must contain an explicit instruction: "If you are Evelynn (default top-level session with no greeting), also read `agents/evelynn/CLAUDE.md` before proceeding." Test this by starting a fresh session with no greeting and confirming Evelynn reads both files in her startup sequence. **This is the single biggest implementation risk** — if the pointer doesn't reliably fire, Tier 2 is invisible.
7. **Update `CLAUDE.md` references in the `claude-md-management:revise-claude-md` skill** so it knows about the split and targets the right file when making updates.
8. **Run a smoke test**: ask Evelynn (fresh session) to describe her critical rules. She should recite both tiers. Spawn a Sonnet subagent (fresh task) and ask it to do the same — it should recite its inlined subset and say it does not load CLAUDE.md.

## Tradeoffs

**Pro:**
- Evelynn's preamble drops from ~127 lines to ≤60 lines + explicit pointer. Roughly 30% context savings on every top-level turn, which compounds over the day.
- Rule ownership becomes legible. "Why is 'Evelynn never executes' in Critical Rules that Sonnet agents supposedly follow?" stops being a valid question.
- Subagent rule drift can now be lint-checked because there's a single canonical source-of-truth block to diff against.
- Reference material (scripts, plugins, PR rules) moves to `architecture/` where it belongs — discoverable via grep, not paid for on every turn.

**Con / risks:**
- **Subdirectory CLAUDE.md auto-discovery is untested in this repo.** Claude Code's documented behavior is upward traversal from CWD, not downward into subdirs. We must rely on an explicit pointer in the root file — if Evelynn sometimes forgets to follow the pointer, Tier 2 rules get silently skipped. Mitigation: make the pointer the **first** line after the frontmatter, phrased as a hard rule, and spot-check with a fresh session after migration.
- **Rule number churn** breaks any doc that cites "rule 14" etc. Mitigation: switch to anchor-name references during the migration (#rule-end-session-skill). Big find-and-replace job across `plans/`, `assessments/`, `architecture/`, and agent memory files.
- **Per-subagent inlining is manual today.** Until a lint script exists (future plan), the ten subagent files will drift again. Mitigation: make the inline block a single HTML-comment-delimited region in each subagent file so a future script can regex-replace it wholesale.
- **Harder for humans to find a rule.** Right now someone opening CLAUDE.md sees everything. Post-split they see Tier 1 and have to know Tier 2 exists. Mitigation: the root file's pointer is explicit, and the split mirrors how the codebase is *already* organized (agents/<name>/ for per-agent stuff).
- **One more file to maintain.** `agents/evelynn/CLAUDE.md` joins `agents/evelynn/profile.md` and `agents/evelynn/memory/evelynn.md`. Acceptable — they have distinct purposes (rules vs personality vs state).

## Open questions for Duong

1. **Anchor-name migration**: are you OK switching doc references from "rule 14" to "#rule-end-session-skill" wholesale? It's the right fix but touches ~30 files.
2. **Tier 4 grouping**: do you want `architecture/key-scripts.md`, `architecture/plugins.md`, `architecture/pr-rules.md` as three files, or one combined `architecture/references.md`? Three files are cleaner to grep; one file is easier to maintain.
3. **Evelynn's profile vs Evelynn's CLAUDE.md**: should coordinator-specific *rules* live in `agents/evelynn/CLAUDE.md` (this plan) or fold into `agents/evelynn/profile.md`? I recommend the split — profile.md is personality/tone, CLAUDE.md is rules/invariants. But if you want a single Evelynn file, we collapse them.
4. **Subagent inline block canonicalization**: do you want that lint-script scaffolded now (adds scope, slows this plan by ~1 extra PR) or deferred as a follow-up plan? I recommend deferred — ship the split first, lint later.
