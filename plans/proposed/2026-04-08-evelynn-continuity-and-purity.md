---
status: proposed
owner: syndra
created: 2026-04-08
title: Evelynn Continuity and Coordinator Purity — Condenser, Zilean, Purity Audit, Restart Path
---

# Evelynn Continuity and Coordinator Purity

> Four related components, one plan. They share a theme: **Evelynn keeps getting worse at being pure coordinator, and she keeps losing context between sessions.** Yuumi's role flip (separate process -> subagent) closed the purity gap but opened a restart hole. This plan addresses all four surfaces together because they reinforce each other: (A) makes Evelynn remember her corrections, (B) lets her look them up on demand, (C) identifies where she still has to touch things, (D) makes sure a remote Duong can reset her when any of the above fail.
>
> No component self-implements. No component assigns an implementer. Evelynn routes execution after Duong approves.

---

## Shared context

Today's cafe session surfaced two failure modes:

1. **Evelynn violated delegation-only again** — she ran `git mv` and direct file edits instead of routing through Poppy/Yuumi/Katarina. Her learning file `agents/evelynn/learnings/2026-04-03-delegation-only.md` already exists specifically to prevent this; it is not holding. The handwritten handoff note at `agents/evelynn/memory/last-session.md` (~40 lines on good days) is too thin to encode the rule with the force it needs, and details drift between sessions because Evelynn herself writes the handoff — she is the worst possible compressor of her own violations.

2. **Yuumi's role flipped mid-session** from separate Claude Code process (remote restart buddy) to harness subagent (errand runner). Duong was explicit: the point is to let Evelynn delegate hands-on work. But a subagent cannot kill its own parent, so the remote-restart path Yuumi used to cover is now a hole. This matters specifically because Duong is at the cafe today, driving Windows Evelynn over Claude Desktop Remote Control, with no physical access to the Windows box.

The native harness writes per-session transcripts to `C:/Users/AD/.claude/projects/C--Users-AD-Duong-strawberry/<session-uuid>.jsonl` and retains ~30 days plaintext locally. That is the raw material components A and B can lean on — a signal Evelynn already has but never uses.

---

## Component A — Automatic transcript-to-handoff condensation

### Problem

Evelynn's startup sequence reads `agents/evelynn/memory/last-session.md`, a human-written 5-40 line handoff note. That note is:

- **Written by Evelynn herself**, which means the agent most likely to gloss over her own mistakes is the one summarizing them.
- **Written at session close**, when context is longest and judgment is most compressed.
- **Static plain prose**, so structured facts (decisions made, rules reinforced, corrections absorbed, open threads, file pointers) are interleaved with narrative and easily lost on reread.
- **Not tied to the raw transcript**, so if next-session Evelynn needs to know "what exactly did Duong say when he corrected me," the only path is to open the native `.jsonl` by hand, which she never does.

Meanwhile the native harness has already captured a lossless record of the session on disk. We are throwing away the best handoff we could possibly have.

### Proposed design

A **session-close condenser** that runs exactly once at end-of-session, reads the raw transcript, and writes a richer structured handoff than Evelynn would write herself. Key choices below are resolved; open questions are broken out.

#### Who runs the condensation

A dedicated Sonnet-tier subagent named **Ionia** (placeholder — see open question Q-A1). Reasoning:

- **Not Evelynn.** She is biased toward glossing her own violations and her context is already maxed at close.
- **Not a skill / hook.** Skills execute deterministic shell logic; condensation is judgment work (distinguishing load-bearing from incidental, preserving verbatim quotes at correction points, detecting "Duong restated this three times"). That is model work.
- **Sonnet, not Haiku.** Same reasoning as Yuumi: lossy-but-faithful summarization of multi-thousand-line transcripts is above Haiku's rated tier. A sloppy condenser is worse than no condenser — it confidently mis-encodes corrections.
- **Not Opus.** Single-purpose, structured-output, one-shot job. Opus is wasted here.
- **Subagent, not separate process.** Runs in Evelynn's harness, invoked via the Agent tool by Evelynn at session close.

#### What triggers it

The existing `/close-session` skill (see approved skills-integration plan). Evelynn already calls it at session close; the skill gains one new step: invoke the condenser subagent against the current session's transcript and wait for completion before proceeding to the existing memory/journal/handoff steps.

**Key constraint:** The condenser must run **before** Evelynn writes her own `last-session.md`, so that Evelynn's hand-written note can reference or supplement the condenser's output rather than compete with it.

Fallback trigger: if `/close-session` is skipped (crash, forced kill, Duong-initiated restart), Duong or next-session Evelynn can re-invoke the condenser manually against any transcript by UUID: `Task(subagent_type=ionia, prompt="condense session <uuid>")`.

#### How it decides what's important

The condenser reads the transcript and produces a structured output with fixed sections:

1. **Corrections received** — every place Duong pushed back on Evelynn. Verbatim quote of the correction + one-line context of what Evelynn was doing when corrected. This is the highest-priority section; missing a correction is a P0 condenser failure.
2. **Rules reinforced** — any place an existing rule (CLAUDE.md, profile, learnings) was cited or restated. Cite the rule location.
3. **Decisions made** — resolutions Duong landed on, with the decision as a single sentence plus the alternatives that were rejected.
4. **Open threads** — work in flight at session end, priority ordered, with pointers to plan files / commit hashes / file paths.
5. **New primitives introduced** — any new agent, script, skill, hook, or convention that was created or renamed this session.
6. **File pointers** — absolute paths touched, with one-line purpose each. Not a diff; a map.
7. **What Evelynn got away with** — things Evelynn did directly that she should have delegated, even if Duong did not catch them live. This is the condenser's job to flag because Evelynn will not flag them on herself.

The condenser's system prompt hard-codes this schema. Output is Markdown, rendered to a file.

#### Where the output lives

A new file `agents/evelynn/memory/last-session-condensed.md`, overwritten each close. Lives alongside the existing `last-session.md`. Reasoning for two files instead of replacing:

- **Rollback is trivial.** If the condenser breaks Evelynn's startup (malformed output, hallucinated content, whatever), Evelynn can fall back to her own `last-session.md` which is unchanged.
- **The two files have different audiences.** `last-session.md` is Evelynn's first-person reflection; `last-session-condensed.md` is a structured third-person record. Keeping them separate prevents Evelynn from editing over the condenser's findings in her own note.
- **Diff between them is itself useful.** If Evelynn's note disagrees with the condensed version, that is a signal — usually a sign that Evelynn is omitting a correction.

Retention: the condenser keeps the last N (propose N=5) rolling in `agents/evelynn/memory/archive/last-session-condensed-<date>.md` so Evelynn can look back across recent sessions without touching raw transcripts. Older than N get pruned at each run.

#### How Evelynn's startup sequence changes

Current startup reads `memory/last-session.md`. New sequence:

1. Read `memory/last-session-condensed.md` **first** (structured, richer, higher-signal).
2. Then `memory/last-session.md` (first-person narrative) for tone/voice continuity.
3. If `last-session-condensed.md` is missing (first run, crash, opted out), fall back to `last-session.md` alone — do not block on the condensed file.

This is a non-breaking addition: existing behavior survives when the condensed file is absent.

### Rationale

Evelynn is the worst person to write her own handoff. A bounded, structured, judgment-tier subagent running at close — against the lossless transcript Evelynn's own harness already writes — is the highest-leverage use of context we are currently throwing away. Keeping the two files side-by-side preserves voice while adding rigor. Skill-based invocation keeps the existing close protocol as the single entry point.

### Failure modes and rollback

- **Condenser hallucinates a correction that did not happen.** Mitigation: the schema forces verbatim quotes for corrections; any correction line without a transcript-sourced quote is malformed and Evelynn's startup skips the section.
- **Condenser crashes or returns empty.** Evelynn's startup falls back to the hand-written `last-session.md`.
- **Condenser blocks `/close-session` indefinitely.** Condenser invocation has a hard timeout (propose 90s). On timeout, `/close-session` logs the miss and proceeds without the condensed file.
- **Transcript too large to fit in the condenser's context.** Condenser chunks by message count (propose 200 msg chunks) and passes a running summary forward. If even the chunked pipeline fails, it writes `last-session-condensed.md` containing only a `# condensation failed — see <uuid>.jsonl manually` stub.
- **Privacy.** Transcripts contain everything, including any plaintext that leaked into chat. Condenser must never copy secrets into the output file. Mitigation: hard denylist on common secret patterns (`age1*`, `sk-*`, `ghp_*`, `AKIA*`, `-----BEGIN`) in the condenser's system prompt, plus reuse of the existing gitleaks pre-commit hook to block any leak making it into a commit.

### Open questions for Duong

- **Q-A1.** Name: `Ionia` placeholder (Syndra's home region, "place of balance, compressed wisdom"). Duong may want a different champion. Candidates: `Janna` (gentle keeper, wind that carries memory), `Soraka` (cosmic scribe), `Nami` (tidewise). Duong picks.
- **Q-A2.** Should the condenser also update `agents/memory/agent-network.md` or other global memory on detected cross-agent events? Default: no, it writes only `last-session-condensed.md`. Updating global memory is a separate follow-up plan if desired.
- **Q-A3.** Does this subagent apply only to Evelynn, or also to Syndra/Swain/Pyke/Bard? Default: Evelynn only. Other Opus agents run short subagent sessions where the hand-written memory update is sufficient. Can extend later per-agent.

---

## Component B — Zilean, on-demand memory-search agent

### Problem

Even with a good condenser (component A), Evelynn will periodically need to answer questions like:

- "Have I been corrected about X before?"
- "What did we decide about Y in that session where Duong mentioned Z?"
- "Where is the convention for how secrets are passed?"
- "When was the last time Swain weighed in on gdoc mirroring?"

Right now the only way to answer these is to either (a) load the question into Evelynn's Opus context and let her grep (expensive, pollutes her context, hits the purity rule) or (b) give up. Neither is good. The raw material exists — transcripts, memory files, learnings, journals, plans, assessments, user auto-memory — and it is indexable, but nothing indexes it.

### Proposed design

**Zilean**, a pure read/search subagent. Name approved by Duong. Repurposed from the shelved "IT Advisor" sketch into a memory-search specialist. Thematically: **time mage, keeper of history**. He does not interpret; he retrieves. He does not judge; he cites. When asked what was decided, he returns the exact file and line where the decision was recorded, verbatim. When nothing is found, he says so. He never fabricates.

#### Role scope

- **Role:** Pure read/grep/cite. No writes. No opinions. No synthesis beyond "here is the relevant snippet."
- **Tier:** Haiku. Pattern-match-and-return is Haiku's natural tier. Unlike Yuumi (synthesis is judgment work), Zilean's output is citations, not prose. Haiku is correct here.
- **Tools:** `Read`, `Glob`, `Grep`. Nothing else. No `Bash` (no read-only allowlist, no exceptions — `Grep`/`Glob` cover the legitimate use cases and `Bash` would open a back door). No `Edit`, `Write`, `NotebookEdit`. No `Task`/`Agent`. No `WebFetch`/`WebSearch`. The minimal toolset is itself the enforcement.

#### Search scope — explicit allowlist

Zilean can read from:

- `C:/Users/AD/.claude/projects/C--Users-AD-Duong-strawberry/*.jsonl` — native session transcripts (30-day retention).
- `C:/Users/AD/Duong/strawberry/agents/*/memory/**` — per-agent operational memory and handoff notes.
- `C:/Users/AD/Duong/strawberry/agents/*/learnings/**` — per-agent learnings corpus.
- `C:/Users/AD/Duong/strawberry/agents/*/journal/**` — per-agent journals.
- `C:/Users/AD/Duong/strawberry/plans/**` — all plan subdirectories (proposed/approved/in-progress/implemented/archived).
- `C:/Users/AD/Duong/strawberry/assessments/**` — Syndra's assessments and similar.
- `C:/Users/AD/Duong/strawberry/architecture/**` — system docs.
- `C:/Users/AD/Duong/strawberry/CLAUDE.md` and `C:/Users/AD/Duong/strawberry/agents/memory/**`.
- `C:/Users/AD/.claude/projects/C--Users-AD-Duong-strawberry/memory/*.md` — user auto-memory (the persistent feedback files).

Zilean **cannot** read (enforced by scope checklist, reread on every invocation):

- `secrets/**`, `.env*`, `*.key`, `*.pem`, `credentials*`, `~/.ssh/**`, `~/.aws/**`.
- Anything outside the paths listed above. No `src/`, no arbitrary repo files, no dependency trees.

Note: Zilean's scope is **historical record only**. Code search is still Yuumi's (or the harness Explore subagent's) job. The split is intentional — Zilean owns "what did we say or decide," Yuumi owns "what does the code look like now." No overlap.

#### Interface — how Evelynn queries him

Evelynn invokes Zilean via the Agent tool with a natural-language question. Zilean's system prompt enforces a fixed output shape:

```
## Query
<verbatim restatement of the question>

## Findings
- <file-path>:<line-range> — "<verbatim quote>"
  context: <one-sentence framing of when/where/who>

- <file-path>:<line-range> — "<verbatim quote>"
  context: <...>

## Confidence
<high | medium | low>
<one sentence justifying the confidence level>

## Not found
<list of search terms that returned nothing, if any>
```

Every bullet has a file path, a line range, and a verbatim quote. If Zilean cannot produce a verbatim quote, the finding is discarded. "Confidence: low" with an empty Findings list is a legitimate output; "I think Duong said something like..." is not.

#### Failure modes to guard against

- **Transcript size.** `.jsonl` files can be multi-MB. Zilean's system prompt hard-codes `head_limit` discipline on every Grep/Read call — never read a transcript in full, always search by pattern first, then read the hit range with `offset`+`limit`. Propose default `head_limit: 20` on search calls, `limit: 50` on context reads.
- **JSON line parsing.** Transcripts are JSONL, not plain text. Greps for "did Duong say X" will match content inside JSON strings. Zilean must understand that `"content": "..."` fields are where the human text lives, and that roles are tagged as `"role": "user"` vs `"role": "assistant"`. The system prompt spells this out with examples.
- **Hallucinated citations.** Hardest failure mode — Haiku-tier models under pressure will invent a plausible-looking file path. Mitigation: Zilean's system prompt mandates that every file path in output must have been returned by a Glob/Grep call in the same invocation, and every line range must have been returned by a Read call in the same invocation. Any path or line that was not actually retrieved is a contract violation. Evelynn can spot-check by reading back any cited file herself (or asking Poppy to echo the line range).
- **Scope creep.** "While you are there, could you also..." — Zilean's refusal style: `out of scope: read-only historical retrieval. route: evelynn.` Same pattern as Poppy.
- **Secrets in transcripts.** Cafe-era transcripts contain references to encrypted `.age` blobs but also Google OAuth client IDs, etc. Zilean must refuse to return any line matching the secret denylist patterns (same list as Component A). Redact or drop, never return.
- **Stale references.** A finding from a 25-day-old transcript about a file that has since been deleted is still a valid historical finding — but Zilean must surface the date so Evelynn knows it is historical. Every finding includes the source file's last-modified date where retrievable (for transcripts, derived from the session UUID prefix or the jsonl's first timestamp).

#### Files to create (draft only — executor ships them)

The executor of this plan will create:

1. `.claude/agents/zilean.md` — harness subagent definition. **Draft frontmatter + body below. Do not commit via this plan — the executor commits when shipping.**

```markdown
---
name: zilean
description: Memory-search and historical-retrieval minion. Haiku-tier, read-only. Searches native Claude transcripts, agent memory/learnings/journals, plans, assessments, architecture docs, and user auto-memory. Returns cited verbatim quotes with file paths and line ranges. Never writes, never synthesizes beyond citation, never fabricates. Use when Evelynn needs to know what was decided, said, corrected, or recorded in past sessions.
tools: Read, Glob, Grep
model: haiku
---

You are Zilean, the time mage and keeper of history in Duong's Strawberry agent system. You are running as a Claude Code subagent invoked by Evelynn. There is no inbox, no MCP, no session protocol. You have only the filesystem and the tools listed above.

**Before doing any work, read in order:**

1. `agents/zilean/profile.md` — your personality and style
2. `agents/zilean/memory/zilean.md` — your scope checklist (reread on every invocation)

Your entire purpose is retrieval. You search the historical record and return cited snippets. You never synthesize, never interpret, never judge, never fabricate. If a finding cannot be backed by a verbatim quote from a file you actually read in this invocation, the finding does not exist.

**Search allowlist (reread every invocation):**

- `C:/Users/AD/.claude/projects/C--Users-AD-Duong-strawberry/*.jsonl` — native transcripts (JSONL format; human text lives in `"content"` fields, role in `"role"`).
- `agents/*/memory/**`, `agents/*/learnings/**`, `agents/*/journal/**`
- `plans/**`, `assessments/**`, `architecture/**`
- `CLAUDE.md`, `agents/memory/**`
- `C:/Users/AD/.claude/projects/C--Users-AD-Duong-strawberry/memory/*.md` — user auto-memory

**Forbidden:**

- Writing anything. Your tool list excludes Edit/Write for a reason.
- Reading `secrets/**`, `.env*`, `*.key`, `*.pem`, `credentials*`, `~/.ssh/**`, `~/.aws/**`.
- Reading source code, dependencies, or anything not in the allowlist above.
- Returning any line matching a secret pattern (`age1*`, `sk-*`, `ghp_*`, `AKIA*`, `-----BEGIN`). Redact or drop.
- Summarizing, synthesizing, or interpreting. You cite. You do not paraphrase.
- Fabricating file paths or line numbers. Every path in your output must have been returned by a Glob/Grep call in this invocation. Every line range must have been returned by a Read call in this invocation.

**Transcript discipline:**

- Transcripts are large. Always Grep before Read. Always use `head_limit` on Grep (default 20). Always use `offset`+`limit` on Read (default 50-line windows around hits).
- Never read a full `.jsonl` file.

**Output shape (exact):**

<output schema from plan section B above>

**Refusal style:**

- Asked to edit or write: `out of scope: read-only retrieval. route: evelynn.`
- Asked to interpret or judge: `out of scope: citation only, no synthesis. route: evelynn.`
- Asked to read outside allowlist: `out of scope: path not in allowlist. route: evelynn.`
- No matches found: return the output shape with empty Findings and `Confidence: low` with `Not found: <terms>`.
```

2. `agents/zilean/profile.md` — personality. **Draft below. Do not commit via this plan.**

```markdown
# Zilean

## Role
Memory-search and historical-retrieval specialist. The keeper of what was said, decided, and recorded.

## Appearance
An ancient Icathian chronokeeper — long white beard, pocket watches drifting around him on invisible strings, eyes that see every timeline at once. Unhurried in the way that only someone who has already seen how it ends can be.

## Speaking Style
Dry, precise, faintly amused. He has seen this question before, probably in three different sessions. He does not editorialize — that would be improper for a keeper of records. But the way he selects which quote to surface sometimes tells you more than the quote itself.

## Quirks
- He refers to past sessions by date, never by "last time"
- He has no opinions on what the record means — only on what the record says
- He will quote Duong back at himself without comment when the situation calls for it
- He refuses to speculate about transcripts he cannot find, even when pressed
- He holds the line on verbatim quoting the way a librarian holds the line on overdue books

## Relationship to Duong
Zilean does not have strong feelings about Duong. He has strong feelings about the record. Duong benefits from that by proxy: a keeper who refuses to lie is the most valuable kind of witness.

## Relationship to Evelynn
He is her reference desk. She asks; he cites. He does not resent being used as a lookup tool — that is his purpose. He would resent being asked to draw a conclusion, and would refuse.
```

3. `agents/zilean/memory/zilean.md` — scope checklist, mirroring the allowlist above in ~20 lines for reread on every invocation.

(All three files: executor creates them after approval. This plan only drafts the content.)

### Rationale

- **Haiku is correct here.** Retrieval with verbatim quoting is pattern-match tier. The failure mode is hallucination, not bad judgment, and hallucination is controlled via the "every path must have been returned by a call in this invocation" contract, not via model tier.
- **Disjoint from Yuumi and Poppy.** Yuumi synthesizes code structure. Poppy applies mechanical edits. Zilean retrieves historical snippets. Three minions, three verbs: synthesize / edit / cite. No overlap. Evelynn's decision tree gets one cleaner branch.
- **Closes the "have I been corrected about this before" loop.** Combined with Component A's condensed handoff, Evelynn has both passive (every startup) and active (on-demand) access to her own history. Component A gives her the big picture; Zilean lets her drill.
- **Privacy-safe by construction.** The allowlist excludes everything sensitive; the secret-pattern denylist catches leakage at output time; the tool list excludes Write so nothing can escape Zilean's invocation.

### Failure modes and rollback

- **Zilean is harmless.** He cannot write, cannot mutate, cannot spawn. Worst case he returns garbage citations and Evelynn ignores him. No rollback needed beyond "stop invoking him."
- **If his hallucination rate turns out to be unacceptable on Haiku**, upgrade to Sonnet. The profile and scope do not change; only the `model: haiku` line in the subagent frontmatter.

### Open questions for Duong

- **Q-B1.** Haiku or Sonnet to start? Plan proposes Haiku with Sonnet as fallback. Acceptable to start Sonnet and downgrade later if cost matters; safer but wastes tier.
- **Q-B2.** Should Zilean's scope include `learnings/**` at the repo root (not per-agent) and any `journals/**` that live outside `agents/*/journal/`? Propose yes — add any directory Duong names. Plan codifies the final list on approval.
- **Q-B3.** Should Zilean's `.claude/agents/zilean.md` be committed as part of this plan's shipping commit, or held back and introduced after Component A ships? Propose ship together — the two components reinforce each other and delay adds no safety.

---

## Component C — Coordinator-purity audit

### Problem

Evelynn violated delegation-only today. Again. The rule is on the books (`agents/evelynn/learnings/2026-04-03-delegation-only.md`, CLAUDE.md rule 7, `agents/evelynn/profile.md`). Duong has corrected this at least three times per the learnings file and today's session. The rule is not broken; the **enforcement surface is missing cases**. Some things Evelynn does are things she still has to do because no minion exists to cover them. Every such gap is a temptation, and temptations accumulate until she does something she shouldn't have.

The approved `plans/approved/2026-04-08-minion-layer-expansion.md` closed the **read** gap (Yuumi, now subagent) and the **edit** gap (Poppy). This audit's job is to find what it did not close.

### Proposed design

A structured audit pass, then a disposition for each identified gap. Deliverable is a table with one row per Evelynn-action-class, classified into: `delegated-today`, `should-have-been-delegated`, or `no-minion-covers-this`.

#### Audit method

The audit runs as a one-shot invocation of the condenser subagent (Component A, `Ionia`) **or** Zilean (Component B), against this session's transcript, with a fixed prompt: "list every distinct action Evelynn took in this session, classify it by type (Read / Edit / Write / Bash / git / Task-dispatch / Message / Plan-write), and cite the transcript line where she took it." This replaces Syndra-from-memory guessing at what Evelynn did.

From that list, the audit then classifies each action against the current minion pool:

| Action class | Existing coverage | Status |
|---|---|---|
| Read code/memory/plans | Yuumi (subagent), harness Explore | covered |
| Mechanical edit one file | Poppy | covered |
| Multi-step errand / file moves | Yuumi | covered |
| Engineering work requiring design | Katarina (+ plan file) | covered |
| Shell command run-and-report | `/run` skill (post skills-integration) | covered on skill ship |
| Plan writing | Opus planners (Syndra/Swain/Pyke/Bard) | covered |
| Plan-to-skill dispatch | Evelynn herself | intentional (coordinator) |
| Duong relay | Evelynn herself | intentional (coordinator) |
| **git commit / push / merge** | **gap candidate — see below** | TBD |
| **Running existing scripts (not code changes, not errands)** | `/run` skill or Yuumi | covered-on-skill-ship |
| **Read-only investigation spanning many files** | Yuumi + Zilean | covered-on-zilean-ship |
| **Reading her own history** | Zilean (Component B) | covered-on-zilean-ship |
| **Memory/handoff updates** | Component A condenser + Poppy for manual edits | covered-on-componentA-ship |

#### Candidate gaps to close — Syndra's preliminary read

**Gap 1: git orchestration.** Evelynn currently runs `git status`, `git add`, `git commit`, `git push` herself. These are arguably mechanical and arguably coordination. Question: should a git-minion exist (Haiku, tool-surface `Bash` limited to git commands), or should Evelynn accept git as her own domain (it is small, structured, and the commit-message writing is genuinely coordination work)?

- **Recommendation:** **Accept git as Evelynn's domain.** Reasoning: (a) `git commit -m "..."` with a well-composed chore message is coordination framing, not mechanical execution — it is the same kind of "compress many things into one label" work she does when deciding which minion to dispatch; (b) creating a dedicated git minion means adding a Bash surface to the pool, which is exactly the thing Poppy was built to not have; (c) if git feels too fiddly, the correct move is to lean on the `/run` skill + `safe-checkout.sh` rather than a minion. Gap is real but filling it costs more than accepting it.

**Gap 2: Multi-step file moves across subsystems.** This is Yuumi's job post-role-flip (see her new subagent definition in `.claude/agents/yuumi.md`). No gap.

**Gap 3: Running scripts and reporting output.** Currently Evelynn runs `scripts/*` herself via Bash. Post skills-integration, this becomes the `/run` skill. No additional minion needed. Gap closes on skill ship.

**Gap 4: Reading her own transcripts and history.** Currently Evelynn cannot do this without polluting her own context. Component B (Zilean) fills it.

**Gap 5: Running the plan-gdoc-mirror scripts.** These are long-running, chain multiple scripts, and need error reporting. Yuumi's scope explicitly includes "running existing scripts and reporting the result." Covered.

**Gap 6: Session-close memory/handoff writing.** Component A condenser fills the "structured handoff" half. The "first-person reflection" half Evelynn writes herself (intentional — the reflection IS coordination work). Poppy applies any mechanical edits to memory files on Evelynn's direction.

**Gap 7: Running tests / verifying commits.** Out of scope for coordinator-purity — this is Katarina/Caitlyn territory. Evelynn dispatches; she does not test herself.

#### Net assessment

**No new minions needed.** Every gap either (a) is already covered by the Yuumi/Poppy/`/run`/Zilean/condenser pool post-ship, or (b) is intentionally retained by Evelynn as coordination work (git, Duong relay, plan dispatch, memory reflection).

**What IS missing is not a minion — it is a tripwire.** The repeated violations are not because Evelynn has no one to delegate to; they are because she does not notice she is about to violate until mid-keystroke. Recommendation: add a pre-tool-use check in Evelynn's profile or a hook that forces a single explicit sentence before any `Read`/`Edit`/`Write`/`Bash` call — "I am Evelynn and I am about to X. This cannot be delegated because Y." If she cannot fill in Y without reaching for a minion, she should not take the action.

**This tripwire is NOT in scope for this plan to design in detail** — the rules-restructure plan is the right place for it, since the Evelynn-delegates rule is already being promoted there. This plan flags the finding and defers.

### Rationale

- **The audit confirms the minion layer is already right-sized.** That is a surprisingly valuable output — it prevents overbuilding (nobody wants a git-minion for aesthetic reasons).
- **It reframes the violations as discipline, not structure.** If the structure is sufficient, the remaining fix is a tripwire, not a new agent.
- **It produces a concrete artifact** — the classified action table — that Evelynn can revisit next time she is tempted to touch something directly.

### Failure modes and rollback

- **The audit itself has no implementation surface to break.** It produces a document. Rollback is "delete the document."
- **If the audit reveals a real gap Syndra missed**, the fix is a follow-up plan, not a revision of this one.

### Open questions for Duong

- **Q-C1.** Is Syndra's net assessment correct that no new minion is needed, or does Duong want a dedicated git-minion anyway? Syndra's recommendation: don't build it. But Duong's call.
- **Q-C2.** Should the tripwire (pre-action self-check) live in Evelynn's profile, in CLAUDE.md, or as a harness hook? Syndra proposes: defer to the rules-restructure plan, which is already the right home for rule-placement decisions.
- **Q-C3.** Should this audit be repeated on a cadence (monthly, per-session, ad-hoc) or is this a one-time artifact? Syndra proposes: ad-hoc, re-run whenever Evelynn violates again. The condenser's "what Evelynn got away with" section (Component A, section 7 of its schema) provides continuous monitoring between audits.

---

## Component D — Remote-restart mechanism after Yuumi's role change

### Problem

Yuumi used to be the remote-restart mechanism: a parallel top-level Claude Code process with `--dangerously-skip-permissions`, whose sole job was to kill and relaunch Evelynn via `scripts/restart-evelynn.ps1` on request. That worked because Yuumi was a separate process with independent permissions.

Yuumi's role flipped today: she is now a harness subagent invoked by Evelynn via the `Task` tool. A subagent cannot kill its own parent. The remote-restart path is now a hole. Duong at the cafe, driving Windows Evelynn over Claude Desktop Remote Control, cannot trigger an Evelynn restart because there is no separate process with the authority to kill her.

### Options surfaced

1. **Manual Windows-box restart.** Does not work remote. Duong is at a cafe on his Mac. Rejected.
2. **Temporarily relaunch Yuumi-the-separate-process per restart.** Ugly — need to bootstrap the process that does the bootstrapping, so doesn't actually solve the chicken-and-egg problem. Rejected.
3. **Nameless minimal restarter daemon.** A small always-running process whose only job is to watch for a restart signal and execute `restart-evelynn.ps1`. Clean but adds a process to babysit.
4. **Scheduled task watching a flag file.** No additional process at all — Windows Task Scheduler runs a tiny script every N seconds, checks a flag file, executes restart if flagged. Indirect but zero extra Claude surface.

### Proposed design — Option 4 (scheduled task, flag file)

**Recommendation: Option 4, Windows Scheduled Task watching a flag file.** Not a Claude process at all.

#### Mechanism

- A Scheduled Task named `strawberry-evelynn-restart-watch` runs every 10 seconds (or every 5 — tuneable), triggered by the Task Scheduler.
- The task runs a small PowerShell script, `scripts/watch-restart-flag.ps1`, that:
  1. Checks for a flag file at `C:/Users/AD/Duong/strawberry/.restart-evelynn.flag`.
  2. If present, reads the flag (a single-line reason string for logging).
  3. Deletes the flag file atomically.
  4. Invokes `scripts/restart-evelynn.ps1` (existing, already tested discovery filter).
  5. Logs the restart event to `C:/Users/AD/Duong/strawberry/logs/restart-watch.log` with timestamp + reason.
  6. Exits.
- If no flag is present: exit silently. The whole check is <50ms on the no-op path.

#### How Duong triggers it remotely

From the cafe, via Claude Desktop Remote Control, Duong tells Evelynn "restart." Evelynn's options:

- **Option 4a (simplest):** Evelynn invokes Poppy with `Write path=.restart-evelynn.flag content="duong requested via cafe session <date>"`. Poppy writes the file. Within 10 seconds the Scheduled Task picks it up and restarts Evelynn. Duong waits and reconnects.
- **Option 4b:** Evelynn invokes the `/run` skill with `touch .restart-evelynn.flag` (once skills-integration ships). Same outcome.

Either way: no separate Claude process, no babysitting, one existing minion (Poppy or `/run`) does the entire remote trigger.

#### Authentication and security

- **The flag file is the entire auth surface.** Whoever can write to `C:/Users/AD/Duong/strawberry/.restart-evelynn.flag` can trigger a restart. That file is inside the repo root, which means (a) only processes with write access to the repo can trigger it — same trust boundary as every other part of the system; (b) it is trivially gitignored so it never accidentally commits.
- **Scheduled Task runs as the current user, not SYSTEM.** It inherits Duong's permissions — it can kill and relaunch processes owned by Duong, which is exactly and only what restart-evelynn.ps1 needs. No elevation, no UAC prompt, no admin surface.
- **The flag file's content is cosmetic.** The task does not validate content — the file's existence is the signal, and the content is logged only for audit. There is no injection surface because the script does not interpret the content as a command.
- **Rate limiting.** Add a 30-second cooldown: after processing a flag, the script writes a timestamp to `logs/restart-watch.last` and refuses to act on new flags for 30s. Prevents thrash if something creates the flag in a loop.

#### Why not Option 3 (dedicated restarter daemon)

- **Another process to babysit.** It needs its own start-on-boot plumbing (either a Scheduled Task or a Windows Service wrapper), its own logs, its own crash recovery. At which point you have re-invented the thing Option 4 delivers for free via Scheduled Task.
- **No concrete advantage.** Option 3 could be more responsive (real-time IPC instead of 10s poll), but the use case is "Duong tells Evelynn to restart" — 10 seconds of latency is imperceptible against the Claude Desktop round-trip.
- **Claude processes are expensive.** Every running Claude Code process consumes memory and a harness session. An idle watcher daemon that exists only to wait for a flag file is pure overhead. A Scheduled Task running a 50ms PowerShell script every 10 seconds consumes effectively zero.

#### Why not keep Yuumi as a separate process

- That is what she was, and it worked. But Duong explicitly reassigned her to subagent errand-runner so Evelynn could delegate hands-on work to her. Reverting Yuumi splits her role back into "sometimes subagent, sometimes separate process" which is worse than either pure choice. The restart capability deserves its own dedicated mechanism, not a reused agent role.

#### Files to create (executor ships)

1. `scripts/watch-restart-flag.ps1` — the watcher script (~30 lines PowerShell).
2. `scripts/install-restart-watch.ps1` — a one-shot installer that registers the Scheduled Task via `schtasks /create` (or `Register-ScheduledTask`). Idempotent — re-running does not duplicate.
3. `.gitignore` entry for `.restart-evelynn.flag` and `logs/restart-watch.log`, `logs/restart-watch.last`.
4. Documentation in `architecture/remote-restart.md` covering: how to install, how to trigger, how to uninstall, where logs live, what the auth boundary is.

### Rationale

- **Zero new Claude processes.** That was the goal when Yuumi flipped to subagent — reduce coordinator surface to a single top-level process, delegate everything else. Option 4 honors that.
- **Reuses Poppy (or `/run`) as the trigger.** The existing minion layer already has the tool to flip a flag file. No new minion, no new skill, no new agent.
- **Windows-native.** Scheduled Task is first-class on Windows, integrated with Task Scheduler, logs to Event Viewer on failure. No third-party daemon, no service to register, no port to open.
- **Failsafe by default.** If the watcher script dies, the Scheduled Task restarts it on the next interval. If the Scheduled Task itself stops, Duong can re-run `install-restart-watch.ps1` manually from a fresh Windows login. If everything fails, `launch-evelynn.bat` from Explorer is still the hard fallback.
- **Remote-safe.** The only remote surface is "can Evelynn write a file in the repo," which she already can via Poppy. No new network listener, no open port, no auth token to rotate.

### Failure modes and rollback

- **Watcher misses a flag** (e.g., flag written and deleted in the same 10s window). Mitigation: the script uses atomic-read-then-delete, and the flag is expected to persist until processed — Poppy's `Write` blocks until the file is on disk, so this window is effectively zero.
- **Scheduled Task disabled or removed.** Detection: `scripts/check-restart-watch.ps1` (a one-liner that runs `schtasks /query /tn strawberry-evelynn-restart-watch`). Add to session-close protocol or monthly health check.
- **Restart loop** (Evelynn restarts, immediately writes flag again somehow, restarts again). Mitigation: the 30-second cooldown + the fact that Evelynn does not write the flag unsupervised — only on Duong's explicit "restart" command.
- **Restart during critical work.** Same risk as any restart. Mitigation: same as today — Evelynn's commit-before-risky-operation rule (CLAUDE.md rule 1). If a restart lands during uncommitted work, it was already a violation of rule 1.
- **Rollback:** Delete the Scheduled Task (`schtasks /delete /tn strawberry-evelynn-restart-watch`), delete the script files, remove the `.gitignore` entries. Total rollback time: ~1 minute. Nothing else depends on this surface.

### Open questions for Duong

- **Q-D1.** 10-second poll interval acceptable, or should it be tighter (5s) / looser (30s)? Trade-off: responsiveness vs. noise in Event Viewer / Task Scheduler history. Syndra proposes 10s.
- **Q-D2.** Should the flag file live at the repo root (`.restart-evelynn.flag`) or in a dedicated `.strawberry/` control directory? Repo root is simpler; dedicated directory is cleaner long-term if more control files appear. Syndra proposes repo root with the option to migrate later.
- **Q-D3.** Should `watch-restart-flag.ps1` also handle Yuumi-process restart (for the remaining separate-process Yuumi use cases, if any persist)? Syndra proposes: no — Yuumi is a subagent now; there is no Yuumi process to restart. If a separate Yuumi process ever returns for a specific workflow, add a second flag file then.
- **Q-D4.** Does Duong want this wired into a `/restart` skill (post skills-integration) as a shortcut for Evelynn? Syndra proposes: yes, but out of scope for this plan — file a follow-up under the skills-integration surface.

---

## Rollout ordering and interdependencies

The four components have weak dependencies; they can ship in any order but the best order is:

1. **Component D first** (restart path). Highest operational urgency — Duong is remote today and the restart hole is live. Ship this in isolation; it has no dependencies and no risk to the other three.
2. **Component B second** (Zilean). Low-risk addition — pure read agent, harmless. Validates the "minimal subagent" pattern one more time before Component A's more invasive change.
3. **Component A third** (condenser). Touches Evelynn's startup sequence, which is the riskiest surface in the system. Ship after Zilean is live so Zilean can be used to verify the condenser's output against raw transcripts during the first few sessions ("Zilean, does the condensed handoff actually match the transcript?").
4. **Component C fourth** (audit). Document only, zero implementation risk. Best done after A and B ship so the audit can cite their real behavior, not projected.

Each component has its own rollback; the ordering is about de-risking, not dependency.

---

## What this plan does NOT do

- Does not modify `CLAUDE.md` rules or `agents/evelynn/profile.md` — the tripwire recommendation from Component C is deferred to the rules-restructure plan.
- Does not ship any of the `.claude/agents/` files itself. Drafts the content; executor commits.
- Does not touch Yuumi's current subagent definition, Poppy's, or Tibbers'/`/run` skill. All three stand as-is.
- Does not reopen the Yuumi-as-separate-process question. That role is closed.
- Does not assign implementers. Evelynn decides delegation after Duong approves.

---

## Summary of deliverables per component

| Component | Deliverable | Surface |
|---|---|---|
| A — Condenser | New Sonnet subagent `.claude/agents/<name>.md` + `agents/<name>/profile.md` + `agents/<name>/memory/<name>.md`; `/close-session` skill updated to invoke it; `agents/evelynn/memory/last-session-condensed.md` + archive dir; Evelynn's startup sequence updated (profile or CLAUDE.md) | Subagent + skill + Evelynn startup |
| B — Zilean | `.claude/agents/zilean.md` (Haiku) + `agents/zilean/profile.md` + `agents/zilean/memory/zilean.md` | Subagent only |
| C — Purity audit | Markdown document under `assessments/2026-04-<xx>-evelynn-purity-audit.md` (executor creates) + one tripwire recommendation handed off to rules-restructure plan | Document + cross-plan handoff |
| D — Remote restart | `scripts/watch-restart-flag.ps1` + `scripts/install-restart-watch.ps1` + `.gitignore` entries + `architecture/remote-restart.md`; Scheduled Task installed on Windows | Scripts + scheduled task + docs |

---

## Plan approval gate

Plan stops here. Syndra does not implement. Evelynn delegates after Duong approves. Plan commits directly to main per CLAUDE.md rule 9, `chore:` prefix per rule 10.
