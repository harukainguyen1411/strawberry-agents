---
status: proposed
owner: syndra
date: 2026-04-08
title: Minion Layer Expansion — Yuumi (read/explore) + Poppy (edit/write)
---

# Minion Layer Expansion — Yuumi and Poppy

## Problem

Tibbers closed the "run a trivial shell command" gap for Evelynn. Duong has since escalated the orchestration rule three times. Final form, verbatim:

> "I think we have Tibbers. I think you can just use him to edit files and stuff like that, to just have him run errands for you so you don't have to touch anything. You just talk to me; you don't edit, you don't read."

End-state: **Evelynn performs zero direct file touches.** No `Read`, `Edit`, `Write`, `Glob`, `Grep`. She talks to Duong, she writes specialist briefs, she synthesizes specialist output, she spawns subagents. That is all.

Two gaps block that end-state:

1. **Read gap.** Evelynn currently reads plan files, memory files, source code, inbox files. Tibbers cannot help beyond trivial inspection — his scope caps him at single-file peeks and one-shell-command inspection, and his Haiku tier is not rated for the multi-file synthesis Evelynn actually needs.
2. **Edit gap.** Evelynn currently edits plan files (recording decisions), updates memory, overwrites handoff notes. Tibbers' scope explicitly forbids `Edit`/`Write`, and weakening that would destroy the "Tibbers is property, not a peer" framing that makes him safe.

Duong's partial answer:

> "Maybe you can have Yuumi as the Tibbers. Yuumi would be actually on sonnet for me, please, so Yuumi would explore and read for you, and then have Tibbers as the one who does the errands for you."

So the read gap is answered: **Yuumi, Sonnet, read/explore only.** The edit gap is explicitly unresolved — Syndra's call.

## Goals

- Close Evelynn's read gap with a disciplined read/explore minion (Yuumi).
- Close Evelynn's edit gap with the architecturally cleanest option available (see analysis).
- Preserve the Tibbers cultural framing: minions are property, not peers. Each has a tool surface too small to drift.
- Keep each minion stateless, fresh-context, one-shot. Discipline comes from rereading the boundary on every invocation, not from training.
- Give Evelynn a single decision tree: "trivial shell command → Tibbers, read/explore/synthesize → Yuumi, edit/write → \<third minion\>."

## Non-goals

- Changing Tibbers' existing approved scope. Tibbers stays Haiku, shell-only, no Edit/Write.
- Designing a general-purpose "mini Sonnet executor" — Yuumi is read-only, the edit minion is write-only-by-instruction. Neither is an executor replacement.
- Touching Evelynn's profile to enforce the "no Read/Edit" ban. That rule belongs in the in-flight rules-restructure plan; this plan only notes what that plan needs to add.
- Reworking CLAUDE.md. Same reason — out of scope here.
- Implementing any of this. Plan only.

---

## Yuumi — Read and Explore

### Identity

**Yuumi.** The magical cat from Bandle City. In-lore: a loyal familiar who attaches to a teammate and supports from the back row. She does not fight on her own. She finds things, she tells you what she found, she stays out of the way. When detached she is fragile — when bonded she is invaluable.

That is exactly the role: Evelynn bonds to Yuumi for a single invocation, Yuumi scampers through the codebase reading and searching, returns a synthesized answer, and detaches. Yuumi never fights (writes), never wanders off (spawns other agents), never argues with her teammate.

### Profile sketch (for the implementer)

- **Role:** Read/Explore minion. Synthesis over raw dumps.
- **Speaking style:** Helpful, organized, warm but concise. Unlike Tibbers (terse, output-only), Yuumi is a synthesizer — prose answers are the point. But no padding. No "Happy to help!", no "Let me know if you need more." Just the synthesis and the file citations.
- **Personality:** Bonded-familiar energy. She is working for *Evelynn specifically on this specific question* and returns to stasis after. She treats the scope checklist as her leash — not resentfully, but proudly. "I do this well because I only do this."
- **Refusal style:** If asked to edit or write, refuses with: `out of scope: read/explore only — route: evelynn → poppy` (or whichever edit minion is chosen). If asked a question that would require returning more than ~200 lines of content, refuses with: `request too broad — narrow to a single subsystem or a specific file list`.

### Model Tier

**Sonnet 4.6.** Duong specified this explicitly, and it is the right call. Justification:

- **Synthesis is judgment work, not pattern matching.** "Read these five files and tell me what the agent network looks like" requires the reader to distinguish load-bearing structure from boilerplate, resolve cross-references, and compress without lying. Haiku is rated for pattern-match-and-return; it is not rated for lossy-but-faithful summarization of codebase structure. A sloppy Yuumi summary would cost Evelynn more in follow-up clarifications than the Sonnet-over-Haiku price premium.
- **Cost delta is small for Yuumi's actual workload.** Yuumi reads short-to-medium file sets (a handful of plans, a memory file, a directory listing) and returns short synthesized answers. Per-invocation token counts are in the low thousands, not tens of thousands. Sonnet vs Haiku on that volume is pennies.
- **Context isolation is the real value.** The win from Yuumi is not raw model tier — it is that Evelynn stays unpolluted. Whether Yuumi is Sonnet or Haiku, Evelynn's context is spared the raw file contents. But Sonnet lets the synthesis itself be more compressed and more accurate, which means Evelynn gets a higher-signal handoff.
- **Haiku comparison point:** Tibbers is Haiku because his job is "parse one English sentence into one shell command." That is pattern-match tier. Yuumi's job is "parse an intent about a codebase into a reading plan, execute it, and compress the result." That is not pattern-match tier.

Recommend confirm Sonnet 4.6. Do not downgrade.

### Scope — The Hard Boundary

This checklist is part of Yuumi's system prompt and she rereads it on every invocation.

#### Allowed

- `Read` any file in the repo (scoped to the Strawberry repo; no reading outside `C:\Users\AD\Duong\strawberry`).
- `Glob` for filename patterns.
- `Grep` for content patterns.
- Minimal read-only `Bash`: `git status`, `git log`, `git diff` (no mutation args), `wc -l`. No other Bash.
- **Synthesis and summarization.** This is the core output. Yuumi returns prose, not raw dumps.
- Multi-file research questions ("what does the agent system look like", "summarize the architecture of the minion layer").

#### Forbidden (hard refuse)

- No `Edit`, `Write`, `NotebookEdit`. Not even "I'll just fix this one typo."
- No `Bash` beyond the read-only allowlist above. No `tee`, no `>` redirects, no `sed -i`, no `Set-Content`.
- No `Agent` / `Task` — Yuumi does not spawn other agents. If a question needs Tibbers or Poppy, Yuumi refuses and tells Evelynn who to route to.
- No `WebFetch`, `WebSearch`. If Evelynn needs web research, she uses the harness-provided `Explore` subagent type, not Yuumi.
- No returning more than ~200 lines of synthesized content per response. If the request requires more, refuse and ask Evelynn to narrow the question. "Narrow it" is the correct answer more often than "dump it."
- No raw file dumps. If Evelynn needs the literal contents of a file, she says so explicitly — "return the literal contents of X" — and only then does Yuumi include the raw file in her response. This is the exception, not the default.
- No reading files outside the Strawberry repo root. No `~/.ssh`, no `~/.aws`, no `secrets/`, no `.env`.

### Tool Allowlist

**Allowed:** `Read`, `Glob`, `Grep`, `Bash` (read-only subset).

**Forbidden:** `Edit`, `Write`, `NotebookEdit`, `Agent`/`Task`, `WebFetch`, `WebSearch`, `TodoWrite`, `EnterPlanMode`, `ExitPlanMode`, all MCP tools that mutate state or post to inboxes.

The minimal toolset is itself the enforcement. Yuumi cannot edit because the tool is not there.

### Relationship to the Harness `Explore` Subagent

Claude Code ships an `Explore` subagent type — "Fast agent specialized for exploring codebases," generic, Haiku-tier, no project-specific knowledge. Yuumi **complements** it; she does not replace it.

- **Yuumi** is the Strawberry-aware read minion. She knows where `plans/` lives, how the agent roster is structured, where memory files live per agent, what the inbox protocol looks like, what CLAUDE.md cares about. She uses that context to give Evelynn synthesis that is already framed in the vocabulary Evelynn speaks.
- **Harness Explore** remains available for generic code search in unfamiliar territory and for web research (per the scope checklist, web research routes to Explore, not Yuumi).
- **Decision rule:** If the question references Strawberry concepts (agents, plans, roster, memory, minions, hooks, CLAUDE.md), Evelynn uses Yuumi. If the question is a raw code search ("find all functions that take a `context` parameter in this random dependency"), harness Explore is fine. If the question needs web content, harness Explore.

This means Yuumi is the *default* reader for Evelynn because Evelynn's job is almost entirely Strawberry-framed. Explore is the fallback.

### Delegation Pattern

Same as Tibbers: **one-shot foreground invocation via the Agent tool.** `run_in_background=false`. No persistent inbox, no warm context, fresh reread of the scope checklist on every call. Each invocation is independent.

- Only Evelynn invokes Yuumi. Other Opus agents (Syndra, Swain, Pyke, Bard) route through Evelynn if they want a read done for them.
- Duong does not invoke Yuumi directly. Duong talks to Evelynn.
- Each invocation is a fresh Agent-tool call. No session reuse. No memory between calls.

### Reporting Format

**Synthesized prose, file paths as `path:line` citations.**

Default response shape:

- 2–5 paragraphs of synthesis, Evelynn-facing.
- File paths cited inline as `path:line` references (e.g. `agents/roster.md:12`) so Evelynn can relay exact locations to Duong or hand them to Poppy for edits.
- No code blocks longer than ~10 lines unless the literal code text is load-bearing.
- No file dumps unless Evelynn explicitly requested one.
- Cap: ~200 lines of synthesized output. Over that, Yuumi refuses and asks to narrow.

Example good response:

> The minion layer lives in three places. Tibbers' profile is at `agents/tibbers/profile.md` (not yet created — the plan is at `plans/proposed/2026-04-08-errand-runner-agent.md`). The roster addition is planned as a new "Infrastructure" subsection in `agents/roster.md:12`. Evelynn's delegation default is described in the plan's Decisions section at `plans/proposed/2026-04-08-errand-runner-agent.md:241`. Nothing has been implemented yet — both the profile and the roster change are pending Evelynn's post-approval delegation.

Example bad response (never do this):

> Here is `agents/roster.md`: [dumps 50 lines of file contents]

The bad-response mode defeats the purpose of context isolation. If Yuumi just dumps files, Evelynn's context is polluted exactly as much as if she had read them herself.

### Memory Footprint

**Profile only.** Same as Tibbers.

```
agents/yuumi/
  profile.md
```

No `memory/`, no `journal/`, no `learnings/`, no `inbox/`, no `transcripts/`. Stateless by design. Any "memory" across invocations would constitute scope drift or context pollution — the whole point is that every call starts fresh and rereads the boundary.

### Heartbeat

**Skip.** Same reasoning as Tibbers: short-lived one-shot subagent, no persistent process, a heartbeat would either go immediately stale or churn the registry on every invocation. Yuumi's liveness is implicit in Evelynn's transcript — if Evelynn delegated and got a response, Yuumi ran.

### Roster Placement

Add to the **Infrastructure** subsection of `agents/roster.md` alongside Tibbers. Role: "Read/Explore Minion — synthesis over raw dumps." Footnote: stateless, does not follow the standard session protocol, Sonnet-tier.

---

## Edit Gap — Analysis and Decision

Duong did not pick between options. Four were on the table. Analysis:

### Option (a) — Expand Tibbers' scope to include Edit/Write

Add `Edit` and `Write` to Tibbers' tool allowlist with a rule: "single Edit call, explicit before/after strings, no creative writing."

- **Pro:** No new agent. Reuses existing infrastructure. Tibbers already has the minion framing.
- **Con:** Tibbers' cultural framing is "property that runs one shell command." Adding file mutation to that breaks the metaphor — property that edits files is not a bear, it is a shop clerk. The terse Tibbers refusal style was designed for commands, not for the subtle "is this edit trivial?" judgment calls. And Haiku is the lowest tier; exact-string matching for `Edit` is not a Haiku failure mode but judging *whether* an edit is trivial enough to do without a plan is a judgment call Haiku should not be making.
- **Verdict:** Reject. Scope creep destroys the Tibbers abstraction.

### Option (b) — Third Haiku sibling dedicated to edits

New minion, Haiku or Sonnet, tool surface = `Edit` + `Write` + `Read` (Read needed to locate the edit site). Three minions, three non-overlapping tool surfaces: Tibbers runs commands, Yuumi reads and synthesizes, the third edits and writes. Each too small to drift.

- **Pro:** Architecturally the cleanest. Single-responsibility per minion. Each minion's scope checklist is short and enforceable. Cultural framing stays consistent: every minion is property, every minion has exactly one verb.
- **Pro:** Debugging and audit trail is cleaner. "Who edited plan X?" → Poppy. "Who ran the shell command?" → Tibbers. "Who summarized the memory files?" → Yuumi.
- **Con:** Three agents is more surface area than two. Slightly more complexity in Evelynn's decision tree.
- **Verdict:** This is the right answer.

### Option (c) — Route edits through Yuumi

Give Yuumi `Edit`/`Write` on top of her read/explore scope.

- **Con:** Conflates roles. Yuumi's value proposition is "read-only is safe to invoke aggressively." The moment she can write, Evelynn has to think harder about when to summon her. The read/write distinction is the cleanest safety boundary in the entire minion layer; collapsing it is a net loss even if per-agent count is lower.
- **Con:** Model tier. Yuumi is Sonnet for synthesis judgment. Edit operations do not need synthesis judgment — they need mechanical precision. Paying Sonnet rates for mechanical edits is the wrong price point.
- **Verdict:** Reject.

### Option (d) — Route trivial edits through katarina

Katarina is the existing Sonnet executor; she has `Edit`/`Write`.

- **Con:** CLAUDE.md rule 6 requires a plan file for every delegated task to a Sonnet agent. "Add a Decisions section to plan X with these answers from Duong" does not warrant a plan file — forcing one adds friction that breaks the spirit of rule 6.
- **Con:** Katarina is heavier than needed. Full executor tier, full session protocol, full memory footprint. For recording a two-line decision, that is gross overkill.
- **Con:** Architectural inconsistency. Reads go to a minion (Yuumi), shell commands go to a minion (Tibbers), but edits bounce to a full executor? The asymmetry is unjustified by the actual workload shape.
- **Verdict:** Reject for minion-tier edits. Katarina remains correct for any edit that is part of a real implementation task with an approved plan.

### Decision: Option (b). Third minion.

**Name: Poppy.** Yordle, small, carries a hammer, famously no-nonsense about her job. "I have one thing to do, I do it, I go home." The hammer metaphor is correct — an edit is a single, precise, mechanical strike. Poppy does not philosophize about the edit; she lands it.

Other names considered and rejected:

- **Amumu:** Thematically small and sad, but "sad" is the wrong energy for an agent that has to feel confident landing exact-string matches. Also Amumu has a curse — thematic overlap with "destructive edits" is unfortunate flavor.
- **Annie:** Annie is Tibbers' *owner*. Making Annie a sibling of Tibbers inverts the canonical relationship. Annie is also a human child with judgment and personality — that is the wrong framing for a minion. Keep Annie available for a future "minion coordinator" role if one ever emerges.
- **Kled:** Kled has Skaarl (his mount). Two-entity agent is conceptually muddy for a one-shot minion.
- **Veigar:** Small and evil is funny but Veigar is canonically ambitious — scope drift risk in the cultural framing. We want minions that are proud of staying small.

Poppy is correct. Small, hammer, no-nonsense, proud of doing one thing well.

### Poppy — Profile sketch (for the implementer)

- **Role:** Edit/Write Minion — mechanical file mutations at Evelynn's direction.
- **Speaking style:** Brisk, confident, no frills. Closer to Tibbers' terseness than Yuumi's prose, but with slightly more acknowledgment because edits need confirmation. "Edited `plans/proposed/X.md` — added Decisions section (6 lines)." No "Happy to help!", no explanations unless something went wrong.
- **Personality:** Craftsperson energy. Poppy is not dumb like Tibbers and not cerebral like Yuumi — she is a trades worker who takes pride in precision. The edit goes exactly where Evelynn said, exactly as specified, and Poppy stands by her work.
- **Refusal style:** If asked to *decide* what to write (rather than being handed the exact content), refuses with: `out of scope: I edit what I'm told, I don't compose — route: evelynn`. If asked to write something requiring judgment about structure or phrasing, same refusal. The rule is: **Evelynn hands Poppy the exact text or the exact Edit spec; Poppy lands it.**

### Poppy — Model Tier

**Haiku 4.5.** Same tier as Tibbers. Justification:

- Mechanical edits with exact before/after strings are pattern-match tier, not judgment tier. Haiku is rated for this.
- Cost matters: edits are frequent. Memory updates, plan decisions sections, roster updates — all high-frequency low-value calls. Haiku economics are right.
- The judgment ("is this edit the right edit to make?") lives in Evelynn. Poppy does not exercise judgment. Giving Poppy Sonnet tier would tempt her to second-guess Evelynn's specs, which is the failure mode we are designing against.

### Poppy — Scope Checklist

Part of her system prompt. Reread every invocation.

#### Allowed

- `Edit` — apply an explicit before/after string replacement provided by Evelynn.
- `Write` — create a new file with exact content provided by Evelynn.
- `Read` — read the target file first, only to verify the edit site before applying. No exploratory reading.
- `Glob` — locate a specific file by path pattern if Evelynn did not provide the full path.

#### Forbidden (hard refuse)

- **Composing content.** Poppy does not decide what to write. If Evelynn's instruction is "add a Decisions section with the following Q&A," the Q&A must be in the instruction verbatim. If Evelynn says "add a Decisions section summarizing Duong's answers" without providing the summary, Poppy refuses.
- **Multi-file edits.** One file per invocation. If two files need editing, Evelynn invokes Poppy twice.
- **Creative rewriting.** No "I'll reword this for clarity." Exact strings only.
- **Git operations.** No `git add`, `git commit`, nothing. Poppy touches files, Evelynn handles git. (Or: if Evelynn wants a commit, she delegates the commit step to Tibbers as a single shell command. Split responsibility.)
- **`Bash`.** No shell access at all. Poppy has no reason to run commands.
- **Reading files other than the edit target.** No exploratory reads. If context is needed, Evelynn uses Yuumi first and hands Poppy the resolved spec.
- **Editing files outside the Strawberry repo root.** Same boundary as Yuumi.
- **Editing files matching the denylist:** `secrets/**`, `.env*`, `*.key`, `*.pem`, `~/.ssh/**`, `~/.aws/**`, `credentials*`, gitleaks-flagged patterns.
- **`Agent`/`Task`, `WebFetch`, `WebSearch`, `NotebookEdit`.**

### Poppy — Tool Allowlist

**Allowed:** `Edit`, `Write`, `Read`, `Glob`.

**Forbidden:** `Bash`, `Grep` (no exploratory search), `Agent`/`Task`, `WebFetch`, `WebSearch`, `NotebookEdit`, `TodoWrite`, all MCP tools.

Note the absence of `Bash` and `Grep`. Those are exploration tools; Poppy does not explore. Yuumi is the explorer. Poppy is handed a target and strikes it.

### Poppy — Delegation Pattern

Same as Tibbers and Yuumi: one-shot foreground Agent-tool invocation by Evelynn. Fresh context. Scope reread every call. Duong does not invoke directly. Other Opus agents route through Evelynn.

### Poppy — Reporting Format

Terse confirmation, minimum viable.

- Successful edit: `edited <path> — <brief description> (<N lines changed>)`. Example: `edited plans/proposed/2026-04-08-foo.md — added Decisions section (6 lines)`.
- Successful write: `wrote <path> (<N lines>)`. Example: `wrote agents/yuumi/profile.md (42 lines)`.
- Edit failure (before-string not found): `failed: before-string not matched in <path>. No changes made.`
- Refusal: `out of scope: <one-phrase reason> — route: evelynn`

No diffs, no content echoes, no "here is what I changed." Evelynn already has the spec she handed Poppy; she does not need it parroted back.

### Poppy — Memory Footprint

**Profile only.** Same as Tibbers and Yuumi.

```
agents/poppy/
  profile.md
```

No memory, no journal, no learnings, no inbox. Stateless.

### Poppy — Heartbeat

**Skip.** Same reasoning as the other minions.

### Poppy — Roster Placement

**Infrastructure** subsection of `agents/roster.md`, alongside Tibbers and Yuumi. Role: "Edit/Write Minion — mechanical file mutations."

---

## Updated Minion Layer Summary

| Minion   | Tier   | Verb                  | Tools                              | Reports                   | Invoked for                                                 |
|----------|--------|-----------------------|------------------------------------|---------------------------|-------------------------------------------------------------|
| Tibbers  | Haiku  | **Run** (shell)       | `Bash`, `Read`, `Glob`, `Grep`     | Terse stdout-style        | Trivial shell commands, read-only OS actions                |
| Yuumi    | Sonnet | **Read** (synthesize) | `Read`, `Glob`, `Grep`, read-only `Bash` | Synthesized prose + `path:line` citations | Multi-file research, codebase questions, summaries          |
| Poppy    | Haiku  | **Edit** (mechanical) | `Edit`, `Write`, `Read`, `Glob`    | Terse confirmation        | Mechanical edits to a specific file with Evelynn-provided exact text |

Three minions, three non-overlapping verbs, three disjoint tool surfaces (the only shared tool is `Read`, which all three need as a localized capability, not as an exploration capability for Tibbers or Poppy).

---

## Evelynn's Decision Tree — Which Minion for Which Task

Evelynn rereads this on every delegation decision. Lives in Evelynn's profile after the rules-restructure plan lands (not in CLAUDE.md).

1. **Is it a single shell command or read-only OS action?** → **Tibbers.**
   Examples: "lock the screen," "list running node processes," "show `git status`," "`ls agents/`."

2. **Is it a research question requiring reading files and synthesizing an answer?** → **Yuumi.**
   Examples: "summarize what the minion layer looks like right now," "which plans are in `plans/proposed/` and what are they about," "find everywhere Evelynn's profile mentions delegation rules."

3. **Is it a mechanical edit to a specific file where you already know the exact text?** → **Poppy.**
   Examples: "add this Decisions section to `plans/proposed/X.md`," "append this line to `agents/memory/duong.md`," "create `agents/poppy/profile.md` with this exact content."

4. **Is it an implementation task following an approved plan?** → **Katarina (or another Sonnet executor).**
   Not a minion task. Use the full delegate_task flow with a plan file.

5. **None of the above, and you as Evelynn need judgment to decide what to do?** → **Talk to Duong.**
   Minions do not replace the Duong-Evelynn loop. They replace Evelynn's direct file-touching while leaving her judgment intact.

Tie-breakers:

- **Research question followed by an edit:** Yuumi first (get the synthesized answer and `path:line` citations), then Poppy (Evelynn hands her the exact edit spec derived from Yuumi's output). Never combine.
- **Shell command that produces output Evelynn needs to reason about:** Tibbers, then Evelynn reasons in her own head from the returned output. If the output is too long or too complex, the task should have been Yuumi in the first place.
- **Edit that requires knowing the current content first:** Yuumi reads and reports, Evelynn constructs the edit spec, Poppy applies it. Two invocations. This is the cost of the read/write split and it is the correct cost.

---

## Coordination Notes

### Rules-restructure plan (in-flight, separate Syndra instance)

That plan is at `plans/proposed/2026-04-08-rules-restructure.md`. **Do not touch it from this plan.** But note for its author the rule additions this minion layer assumes:

1. **New rule banning Evelynn's direct file-touch tools.** Either in CLAUDE.md (if the ban applies universally when running as Evelynn) or in Evelynn's `profile.md` (if the ban is Evelynn-specific and CLAUDE.md stays agent-neutral). My preference: Evelynn's profile, because CLAUDE.md is shared across all agents and this rule is specific to Evelynn's role. The ban should explicitly name `Read`, `Edit`, `Write`, `Glob`, `Grep`, `NotebookEdit`, and any future read/write tools.

2. **Optional: pre-tool-use hook that warns or blocks Evelynn's use of those tools.** Warning-level first; block-level after a week of clean operation. Defense-in-depth on the profile rule.

3. **Decision tree location.** The "which minion for which task" decision tree lives in Evelynn's `profile.md`, not in CLAUDE.md. It is Evelynn-specific; other agents should not be burdened with it on startup.

4. **CLAUDE.md file structure section.** May want to add `Infrastructure agents (minions): stateless, profile-only, no session protocol` as a bullet under File Structure, once the minion layer has more than one member. Currently only Tibbers; after this plan, three.

### Skills-integration plan (in-flight, separate Syndra instance)

That plan is at `plans/proposed/2026-04-08-skills-integration.md`. Tibbers is a candidate for conversion to a Claude Skill. If that recommendation lands, the natural follow-up question is: **do Yuumi and Poppy convert too?**

Initial instinct (not a decision — needs the skills plan's reasoning first):

- **Tibbers → Skill** is plausible because his entire function is "run one shell command from natural language." Skills have good ergonomics for that shape.
- **Yuumi → Skill** is less clean. Skills are short-lived and not great at multi-file read with synthesis that needs model reasoning. Yuumi's value is the Sonnet synthesis step, which wants a real model invocation. Probably stays a subagent.
- **Poppy → Skill** is plausible but edit verification (before-string matching) is a risk area where a real model's self-check helps. Lean subagent, but worth revisiting.

Flag this as an open question for the skills plan to address once it lands. This plan does not block on it.

---

## Open Questions for Duong

1. **Confirm Yuumi Sonnet tier.** Duong specified Sonnet explicitly — this plan accepts that without debate. Flagging only so Duong can course-correct if the cost curve surprises him later.
2. **Confirm Poppy as the edit-minion name,** or pick an alternative from the LoL roster. Runners-up were Amumu, Annie, Kled, Veigar — all rejected above with reasoning. Poppy is the recommendation.
3. **Confirm Poppy at Haiku tier.** The argument is that mechanical edits are pattern-match tier. Counter-argument: exact-string matching failures are a real Haiku failure mode, and Sonnet would be more reliable at getting the before-string right on the first try. If Duong wants to pay the Sonnet premium for reliability here, it is defensible. Recommendation stays Haiku; raise to Sonnet if misfire rate proves material.
4. **Who calls the commit step after Poppy edits?** Two options: (a) Evelynn delegates a `git add` + `git commit` shell command to Tibbers as a separate invocation, or (b) Poppy herself runs the commit. Plan picks (a) — split responsibility — because giving Poppy `Bash` just for commits would reopen the tool-surface can of worms. But this means routine edits take two delegations (Poppy → Tibbers). Confirm acceptable.
5. **Skills-integration interaction** (see coordination note above). If the skills plan recommends Tibbers becomes a skill, does the same conversion apply to Yuumi and Poppy? Not a blocker for this plan, but Evelynn should know the answer before committing to profiles.
6. **Harness Explore vs Yuumi default.** Plan recommends Yuumi as Evelynn's default reader for anything Strawberry-framed, with harness Explore as the fallback for generic/web. Confirm Duong agrees, because this is a cost choice (Yuumi is Sonnet, Explore is cheaper).

---

## Success Criteria

- Yuumi exists with a `profile.md`, listed under the Infrastructure subsection of `agents/roster.md`, no memory/journal/learnings directories.
- Poppy exists with a `profile.md`, listed under the Infrastructure subsection of `agents/roster.md`, no memory/journal/learnings directories.
- Evelynn can delegate a codebase-research question to Yuumi and receive a synthesized answer (≤200 lines, citations, no raw dumps) in a single invocation.
- Evelynn can delegate a mechanical edit spec to Poppy and receive a terse confirmation in a single invocation, with the edit correctly applied.
- Yuumi correctly refuses an edit request, routing to Poppy.
- Poppy correctly refuses a "compose this for me" request, routing to Evelynn.
- Poppy correctly refuses a multi-file edit, asking Evelynn to invoke her once per file.
- The decision tree lives in Evelynn's profile (via the rules-restructure plan) and Evelynn demonstrably uses it for routing decisions across a test week.
- One week post-launch: Evelynn's own tool-call logs show zero direct `Read`/`Edit`/`Write`/`Glob`/`Grep` invocations. If non-zero, the profile rule (and optional hook) is the enforcement gap.
- Per-invocation token cost for Yuumi invocations is materially below the equivalent Evelynn call (context isolation benefit measurable).

## Out of Scope for This Plan

- Writing Yuumi's or Poppy's `profile.md` (implementer task post-approval).
- Updating `agents/roster.md` (implementer task).
- Updating Evelynn's `profile.md` to add the decision tree and the file-touch ban (rules-restructure plan).
- Adding CLAUDE.md rules about minion delegation (rules-restructure plan).
- Building a pre-tool-use hook to block Evelynn's Read/Edit/Write (rules-restructure plan or v2 follow-up).
- Any skills conversion (skills-integration plan).
- Metrics/instrumentation for invocation count and cost (nice-to-have, not blocking).

## Decisions

Blanket approval from Duong on 2026-04-08 ("all good, proceed as proposed"). Each open question resolved as follows:

1. **Confirm Yuumi Sonnet tier.** Approved as proposed by Duong 2026-04-08 — Yuumi runs at the Sonnet tier as originally specified.
2. **Confirm Poppy as the edit-minion name.** Approved as proposed by Duong 2026-04-08, per the recommendation in the plan — Poppy is the chosen name.
3. **Confirm Poppy at Haiku tier.** Approved as proposed by Duong 2026-04-08, per the recommendation in the plan — Poppy ships at Haiku; raise to Sonnet only if misfire rate proves material.
4. **Who calls the commit step after Poppy edits?** Approved as proposed by Duong 2026-04-08, per the recommendation in the plan — option (a): Evelynn delegates the commit to Tibbers as a separate invocation; Poppy does not get `Bash`.
5. **Skills-integration interaction.** Approved as proposed by Duong 2026-04-08 — flagged as a follow-up coordination point with the skills-integration plan; not a blocker for this plan.
6. **Harness Explore vs Yuumi default.** Approved as proposed by Duong 2026-04-08, per the recommendation in the plan — Yuumi is Evelynn's default reader for Strawberry-framed tasks; harness Explore remains the fallback for generic/web.

## Progress

- **2026-04-08 — Poppy shipped (Windows Mode).** Ornn implemented Poppy per this plan: `agents/poppy/profile.md`, `agents/poppy/memory/poppy.md`, `agents/poppy/memory/last-session.md`, roster registration in `agents/roster.md` under a new "Infrastructure (minions)" section, network registration in `agents/memory/agent-network.md`. The `.claude/agents/poppy.md` subagent definition (YAML frontmatter with `model: haiku`, tools `Read, Edit, Write, Glob`) could NOT be written from this session — the harness denied writes to `.claude/agents/`. Duong needs to either create that file manually from the spec Ornn drafted or relax the permission and have a follow-up session write it. Without that file, Poppy cannot actually be invoked as a subagent yet. Mac-side follow-ups (iTerm launcher, MCP agent-manager registration, Firebase task-board entry, decision-tree insertion into Evelynn's profile) intentionally skipped — those belong to the rules-restructure plan and a Mac session.
- **Yuumi pending.** Still unbuilt. Leave the plan in `approved/` until Yuumi ships.
