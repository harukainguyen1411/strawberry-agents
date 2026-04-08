---
title: /end-session Skill — Transcript Cleaner + Session Close Orchestrator
status: proposed
owner: bard
created: 2026-04-08
---

# /end-session Skill — Transcript Cleaner + Session Close Orchestrator

> Rough plan. Problems, approach, shape, open questions, failure modes. No file authoring, no implementer assignment. Inherits the skills framework from `plans/approved/2026-04-08-skills-integration.md` and is the planned host for the condenser from Component A of `plans/proposed/2026-04-08-evelynn-continuity-and-purity.md`.

## Problem

Closing a session today is a five-step prose ritual encoded in `agents/memory/agent-network.md` (Session Closing Protocol). Each agent executes it manually from memory. Steps drift, get skipped, and produce uneven output across agents and sessions.

Meanwhile, the native Claude Code harness writes a perfect, lossless transcript of every session to disk:

```
C:/Users/AD/.claude/projects/C--Users-AD-Duong-strawberry/<session-uuid>/*.jsonl
```

Each line is a JSON record (user message, assistant message with text + tool_use blocks, tool_result, system reminders, hook output, etc). Today, **nothing reads these files**. The richest possible source of session ground truth is sitting on disk and being garbage-collected after ~30 days, untouched.

Duong's request, verbatim:

> "we need the jsonl to be cleaned so it's only contains conversation not tool calls. Store it in evelynn transcript for me. It can be a skill (end session), with all the steps above"

The "steps above" = the existing close protocol. So the ask is one packaged skill that:

1. Cleans the current session's `.jsonl` down to just the human-readable user/assistant conversation.
2. Archives the cleaned transcript under `agents/<agent>/transcripts/`.
3. Walks the existing close-session checklist (journal, handoff, memory, learnings, log_session).
4. Becomes the host for the condenser from Syndra's continuity plan once that lands.

Naming note: the approved skills-integration plan already reserves `/close-session` as one of the v1 six skills (a thin checklist wrapper). Duong is now asking for a much heavier `/end-session` that supersedes that v1 sketch. **This plan proposes that `/end-session` replaces `/close-session` in the skill set rather than coexisting.** Two skills with overlapping purpose would be a footgun. See open question Q-5.

## Inheritance from skills-integration

Hard inherits, not re-litigated:

- **Scope:** project skill, lives at `.claude/skills/end-session/SKILL.md`. Project-scoped per skills-integration phase 1 layout.
- **Format:** `SKILL.md` with YAML frontmatter + markdown body. Supporting files (the cleaner script, schema docs) live alongside under `.claude/skills/end-session/`.
- **Invocation:** slash command `/end-session [agent-name]`. `disable-model-invocation: true` — only the user (or an agent acting on Duong's "end session" instruction) ends a session, the model never auto-fires this.
- **Allowed tools:** `Bash Read Write Edit Glob`. Needs Bash for the cleaner pipeline and (Mac-only) the `log_session` MCP shell. Needs Read/Write/Edit for journal/handoff/memory updates. Glob for session UUID discovery.
- **Preload:** added to Evelynn's `skills:` frontmatter list (replacing `close-session` if Q-5 resolves "supersede"). Not preloaded by Sonnet implementers — they use the lighter variant per Q-3.
- **Reference enforcement:** `scripts/verify-skill-refs.sh` (from skills-integration phase 1) covers this skill the same way it covers the others.

## Cross-reference to the condenser plan

Component A of `plans/proposed/2026-04-08-evelynn-continuity-and-purity.md` specifies a Sonnet subagent (placeholder name `Ionia`) that reads a session transcript and writes a structured `last-session-condensed.md` handoff. That plan names `/close-session` as the trigger and adds one new step: invoke the condenser before Evelynn writes her own handoff.

This plan is the **host** for that step. Ordering inside `/end-session` (see step list below) places the condenser invocation immediately after transcript cleaning and before journal/handoff. The condenser reads the *cleaned* transcript Markdown, not the raw `.jsonl` — that is a new constraint this plan is asserting on the condenser:

- Cheaper input (no JSON parsing inside the condenser, no tool_use noise).
- Same source-of-truth file Evelynn's startup will reference, so the condenser's citations are stable.
- If the cleaner produces a faithful Markdown rendering, the condenser becomes a pure summarization step over plain text.

If Component A ships first and the condenser is already wired to read raw `.jsonl`, this plan asks Syndra to flip it to the cleaned Markdown input. Coordination flag — not a blocker, both files exist post-cleaning.

If Component A has not shipped when `/end-session` is implemented, the skill degrades gracefully: skip the condenser step, log "condenser not yet available", proceed to the human-written handoff. Phase 1 of this plan does not depend on Component A landing first.

## The cleaner — jsonl → Markdown pipeline

### What stays

- `role: user` messages where the `content` is plain text (or a content block of `type: text`) and the text is **not** a system reminder or auto-injected context block.
- `role: assistant` messages where the `content` array contains any `type: text` block. Concatenate text blocks in order.

### What gets stripped

- All `type: tool_use` blocks (the assistant's tool invocations).
- All `role: tool` / `tool_result` records.
- All `<system-reminder>...</system-reminder>` wrappers in user content (these are auto-injected context, not Duong's words).
- Auto-prepended context blocks: `# claudeMd`, `# currentDate`, `# gitStatus`, `# Memory Index`, the `<env>` block, and any other harness-injected envelope. The cleaner needs a denylist of opening tokens that mark a synthetic block.
- `type: thinking` blocks (extended thinking output is internal reasoning, not conversation).
- Empty messages, whitespace-only messages, hook-injected status messages.
- Binary content in tool blocks (images, PDFs) — strip entirely. Do not even mention "(image redacted)"; leave nothing.

### Output format

A single Markdown file per session, structured as:

```markdown
# Session <uuid-short> — <YYYY-MM-DD> — <agent>

> Cleaned transcript. Tool calls, tool results, system reminders, and auto-injected context blocks have been stripped. Only user prompts and assistant prose remain.
>
> Source: <absolute path to source jsonl(s)>
> Cleaned at: <ISO timestamp>
> Message count: <user N, assistant M>

---

## Duong

<verbatim user text>

## Evelynn

<verbatim assistant text>

## Duong

<verbatim user text>

## Evelynn

<verbatim assistant text>

...
```

Speaker name for the assistant side comes from the `agent-name` argument to the skill (default: `evelynn`). User side is always `Duong` per personal-system convention.

### Implementation sketch (do not implement here)

Two reasonable engines, both viable:

- **`jq` + bash** — small, no dependencies beyond `jq` and bash, fast on multi-MB files. Hard to read, hard to maintain, but matches the existing `scripts/` style.
- **Python script** — `scripts/clean-jsonl.py` with `json` stdlib only. More maintainable, easier to extend with edge-case handling, easier to unit-test. Still zero non-stdlib dependencies.

**Recommendation: Python.** The denylist for system-reminder tokens, the content-block traversal, and the speaker rotation logic all benefit from real control flow. This is not a one-liner. Flag as Q-1 if Duong wants to override.

The script signature would be roughly:

```
python scripts/clean-jsonl.py \
  --session <uuid|auto> \
  --agent <name> \
  --out <path>
```

`--session auto` discovers the most-recent-mtime `.jsonl` in the current project's session directory. `--out` defaults to `agents/<agent>/transcripts/<YYYY-MM-DD>-<uuid-short>.md`.

The skill body invokes this script via Bash and then Read/Edits the output if any post-processing is needed (probably none).

### Edge cases — named, not solved

- **Sessions split across multiple `.jsonl` files** (rotation, crash + resume). The cleaner takes a directory and concatenates in mtime order, deduping by message UUID if present.
- **Mixed content blocks in one assistant message** (text + tool_use + text). Concatenate the text blocks in order, drop the tool_use, do not insert a separator — the concatenation should read as one paragraph.
- **Very long sessions** (10k+ messages, 50MB+ jsonl). Cleaner streams line-by-line and writes incrementally. No full-file load. Cap output at some sane max (propose 2MB Markdown) and append a `> truncated at <N> messages` footer if exceeded. Q-2.
- **Tool results that quote user content back** (e.g. a `Read` tool result containing a user file with text in it). These get stripped as tool_result blocks — we lose the user-file content, but that is correct because it was not part of the conversation.
- **Multi-turn tool loops** where the assistant says nothing of substance for ten turns straight. The cleaned output will have long gaps between assistant text blocks. This is correct — the silence is real.
- **Assistant text that references tool output by line number** ("see line 23 of the file I just read"). The reference becomes orphaned in the cleaned transcript. Acceptable — the cleaned transcript is for human reading and condenser input, not for replay.
- **Subagent invocations within the parent transcript.** When Evelynn invokes a Task/Agent tool, the subagent's entire conversation lives inside Evelynn's `.jsonl` as `tool_use` (the spawn) and `tool_result` (the subagent's final message) records. Both get stripped under the current rules. **The subagent's interior conversation is lost** unless we add a special case. See the subagent caveat section below. Q-4.
- **System reminders that wrap real user text.** Some user messages legitimately contain `<system-reminder>` blocks (e.g. the harness sometimes injects "Today's date is X" *into* a user message rather than as a separate envelope). The cleaner must strip the reminder block but preserve the user's actual text from the same message.

## Storage

### Path

`agents/<agent>/transcripts/<YYYY-MM-DD>-<uuid-short>.md`

For Evelynn specifically: `agents/evelynn/transcripts/2026-04-08-a3f9b2.md`. Coexists with the existing `agents/evelynn/journal/` directory without confusion:

| Directory | Contents | Author | Purpose |
|---|---|---|---|
| `journal/` | First-person reflections | The agent | Voice, mood, what it felt like |
| `transcripts/` | Verbatim cleaned conversation | The cleaner script | Ground truth, condenser input |
| `memory/last-session.md` | 5-10 line handoff | The agent | Quick startup read |
| `memory/last-session-condensed.md` | Structured handoff | Condenser subagent (Component A) | Rich startup read |

Four files per session is on the edge of too many. The justification is each has a different audience and a different write-er, so collapsing them recreates the existing problem (Evelynn writes her own everything, and is the worst summarizer of her own mistakes — Syndra's framing). The `transcripts/` directory is the new addition and the lowest-cost member: it is mechanically generated and overwriting one is harmless because the source `.jsonl` is the real source of truth.

### Commit policy

Duong said "store it," which reads as committed. Recommendation:

- **Default: commit cleaned transcripts.** They are the only persistent record once the native `.jsonl` is garbage-collected (~30 days).
- **Hard guard: gitleaks pre-commit hook already runs on staged files.** If a cleaned transcript trips it, the commit fails and Duong/Evelynn intervene before retry. Same protection as everywhere else.
- **Soft guard: the cleaner script applies the same secret denylist as the condenser** (`age1*`, `sk-*`, `ghp_*`, `AKIA*`, `-----BEGIN`) before writing. Any line matching is rewritten as `[redacted: <pattern>]`. This is belt-and-suspenders — it should never fire because secrets shouldn't be in transcripts in the first place, but transcripts have a way of capturing things you didn't expect.
- **Retention:** unlike the condensed handoffs (which Syndra's plan prunes to last 5), transcripts accumulate. This is by design — the whole point is having the historical record. Reassess quarterly if the directory gets unwieldy.

Open question Q-6: should transcripts be in a separate gitignored "personal archive" tree instead of committed? Default proposal is committed; flagging because transcripts contain everything Duong typed in the session and that is more exposure than memory/journal files.

## The full close flow the skill orchestrates

Eleven steps, in order. Each tagged **auto** (skill runs deterministically, no agent prompt) or **agent** (skill prompts the invoking agent for input or judgment).

1. **Heartbeat / session mark** — *auto*. Record close timestamp for the agent. No-op on Windows if heartbeat infrastructure isn't running.
2. **Discover the source `.jsonl`** — *auto*. Either from `$ARGUMENTS` (if Duong passed a UUID) or by mtime in the session directory. Validates the file exists and is non-empty.
3. **Clean transcript** — *auto*. Run `scripts/clean-jsonl.py` against the source. Validate the output is non-empty and well-formed.
4. **Archive cleaned transcript** — *auto*. Write to `agents/<agent>/transcripts/<date>-<uuid-short>.md`. Stage for commit.
5. **Run condenser (Component A)** — *auto if available, skip with notice otherwise*. Invoke the Ionia subagent (or whatever it ends up named) via the Task tool, pass the cleaned transcript path, wait for `agents/<agent>/memory/last-session-condensed.md` to be written. Hard timeout per Component A's spec (90s). On timeout or absent subagent, log "condenser unavailable, proceeding without" and continue.
6. **Journal append** — *agent*. Skill prompts: "Append your reflection for this session to `journal/<platform>-<date>.md`." The agent writes the journal entry inline (not a transcript copy — first-person voice). Skill validates that *something* was written, doesn't validate content.
7. **Handoff note** — *agent*. Skill prompts: "Overwrite `memory/last-session.md` with a 5-10 line handoff. The condensed file is at `last-session-condensed.md` if you need a structured reference." Agent writes it.
8. **Memory refresh** — *agent*. Skill prompts: "Update `memory/<name>.md` if anything material changed this session. Stay under 50 lines, prune stale info." Optional — agent may decline if nothing changed.
9. **Learnings** — *agent*. Skill prompts: "If this session produced a generalizable lesson, write it to `learnings/<date>-<topic>.md` and add it to `learnings/index.md`." Optional.
10. **Commit + push** — *auto*. Single commit with `chore:` prefix containing: cleaned transcript, journal entry, handoff note, memory update, any new learnings. Single push. Per CLAUDE.md rules 1, 9, 10. The skill validates the commit message prefix and refuses to proceed otherwise.
11. **`log_session` MCP call** — *auto, Mac-only*. Detect platform; on Mac call `log_session` with the agent/platform/model/notes. On Windows skip with a notice.
12. **Final report** — *auto*. Print a one-paragraph summary: cleaned transcript path, condenser status, commit hash, log_session status. Skill exits.

(Twelve steps in practice; Duong said "all the steps above" which I read as the existing five-step prose protocol, plus the new transcript step, plus the obvious housekeeping. This is the rough fan-out.)

Step 5 is the integration point with Component A. Steps 6-9 are the existing protocol from `agent-network.md` Session Closing Protocol, lifted into a skill-driven checklist. Steps 1-4 and 10-12 are new.

## Who runs the skill — the genericity question

Three candidate shapes:

**(a) Generic, parameterized.** `/end-session [agent-name]` works for any agent. Routes outputs to `agents/<name>/transcripts/`, `agents/<name>/journal/`, etc. Default `agent-name` to `evelynn` if omitted.

**(b) Evelynn-only.** `/end-session` is hard-coded to write to Evelynn's directories. Other agents have a simpler close ritual (the existing prose protocol or a stripped-down skill).

**(c) Two skills.** `/end-session` for Evelynn (full protocol with transcript cleaning + condenser) and `/end-subagent-session` for Sonnet workers (lighter — skip the condenser, skip the transcript archive, just commit and report).

**Recommendation: (c).** Reasoning:

- The condenser is expensive and only justified for top-level sessions where the transcript is rich. A Sonnet subagent's "session" is one Task tool invocation that lives inside Evelynn's transcript anyway — running a condenser on it is redundant.
- Sonnet subagents don't have their own `.jsonl` files (they run inside the parent's process). The transcript cleaner has nothing to operate on for them. Forcing them through the same skill creates skip-paths which create silent failures.
- The five protocol steps (journal, handoff, memory, learnings, log_session) are still valuable for Sonnet subagents — those should live in `/end-subagent-session`.
- Two skills preserve the v1 vs full distinction cleanly: `/end-session` is the heavyweight Opus-coordinator close, `/end-subagent-session` is the lightweight worker close.

This contradicts my initial lean toward (a). The subagent caveat below is what flipped it.

Q-3: pick (a), (b), or (c). Bard's recommendation is (c).

## Subagent caveat — read this carefully

Sonnet subagents (Katarina, Yuumi, Poppy, etc) invoked via the Task tool **do not have their own `.jsonl` files**. They run inside the parent Claude Code session. Their entire conversation — system prompt, user prompt, assistant turns, tool calls — is recorded as a single `tool_use` + `tool_result` pair in the parent's transcript. The subagent's interior conversation is opaque to the cleaner's current rules and gets stripped along with all other tool calls.

Two consequences:

1. **`/end-session` only meaningfully applies to top-level Claude Code sessions** (Evelynn's primary session, or a standalone session Duong opens). Subagents need `/end-subagent-session` (option (c) above), which does not run the cleaner.

2. **The cleaned transcript loses all subagent work.** If Evelynn delegates a 30-minute task to Katarina, the cleaned transcript shows Evelynn's brief and Evelynn's "thanks, that's done" and nothing in between. For the condenser, this is mostly fine — it summarizes Evelynn's session, and Katarina's interior is Katarina's business. For human readers wanting to understand "what actually happened in that delegation," it's a gap.

   **Optional v2 enhancement (not in this plan's scope):** the cleaner could be taught to recognize Task/Agent tool blocks and emit a synthetic `## <agent>` section containing the subagent's final message (the `tool_result`). That at least preserves the *outcome* of the delegation. Flag for future, do not include in phase 1.

## Phasing

Duong's "implement in phases" mode is on. Three phases.

### Phase 1 — Ship: cleaner + archive + protocol orchestration (no condenser)

- Author `scripts/clean-jsonl.py` per the spec above.
- Author `.claude/skills/end-session/SKILL.md` walking the eleven-step protocol, with step 5 (condenser) stubbed as "skip with notice — Component A not yet shipped."
- Author `.claude/skills/end-subagent-session/SKILL.md` (the Sonnet variant — steps 6-12 only, no transcript cleaning).
- Update Evelynn's profile `skills:` list to include `end-session` (and remove `close-session` if Q-5 = supersede).
- Update Sonnet implementer profiles to include `end-subagent-session`.
- Update `agents/memory/agent-network.md` Session Closing Protocol to point at the skill instead of restating prose.
- Update `architecture/agent-system.md` skills section per skills-integration phase 1.
- Manual test on one Evelynn session and one Katarina subagent session.

### Phase 2 — Wire in the condenser (depends on Component A landing)

- Component A from the continuity plan ships the Ionia (or whatever name) subagent.
- Update `/end-session` step 5 from "skip with notice" to "invoke condenser, wait, fall back on timeout."
- Verify the condenser reads the cleaned Markdown rather than raw `.jsonl` — coordinate with Syndra.
- Verify Evelynn's startup sequence reads `last-session-condensed.md` first per Component A's plan.
- Soak for two weeks.

### Phase 3 — Nice-to-haves

- Subagent transcript preservation (the v2 cleaner enhancement above).
- Multi-session search across the `transcripts/` directory (becomes Zilean's job per Component B of the continuity plan — likely no work for this skill).
- Transcript deduplication / dead-link cleanup if directory growth becomes a problem.
- Auto-trigger: hook the skill into a "session about to close" signal if the harness ever exposes one. Currently Duong has to type `/end-session`. That's fine.

## Failure modes (named, not all solved)

- **Cleaner produces empty output.** All assistant turns were tool calls (rare but possible — e.g. Evelynn spent the whole session running mechanical commands). Skill detects empty output and writes a stub transcript with a header note. Does not abort the close flow.
- **Cleaner crashes** (malformed jsonl, unknown content block type, encoding issue). Skill catches the failure, logs the path of the offending source file, writes a stub transcript noting "cleaner failed: <reason>", continues to the protocol steps. Loses the transcript for that session — acceptable, the source `.jsonl` survives 30 days.
- **Wrong session UUID auto-discovered.** Mtime heuristic picks the wrong file (e.g. a background session is more recent than the one being closed). Mitigation: skill prints the source path before cleaning and asks the agent to confirm if there's ambiguity. Q-7.
- **Condenser hallucinates or hangs** — handled per Component A's failure modes section. This skill's only job is the timeout and the fallback path.
- **Pre-push hook rejects the commit** because the message prefix is wrong, or because gitleaks fires on the cleaned transcript. Skill aborts at step 10, leaves the working tree dirty, prints the error and exits. Agent recovers manually. **Important:** the partial work (transcript, journal, handoff) is preserved on disk but uncommitted. CLAUDE.md rule 1 ("never leave work uncommitted before any git operation that changes the working tree") becomes relevant — Duong/agent must finish the commit before doing anything else.
- **`log_session` MCP unreachable on Mac.** Skip the call with a notice; the rest of the close completes. Not a blocker.
- **Skill body grows past sane size.** Eleven steps with discipline rules and dynamic context could blow past 200 lines. If it does, factor the rules into a `reference.md` alongside `SKILL.md` and reference it from the body — supported by skills layout.
- **Two agents end sessions concurrently.** Both try to commit. The git working tree is shared. One of them races the other and the second fails the push. Skill detects push failure, retries once after a fetch, escalates to the agent if retry also fails. (Covered by general git discipline, not unique to this skill — but the close protocol is the most likely place to hit it.)

## The three biggest design tradeoffs

1. **Two skills vs one (Q-3).** Tempting to ship a single generic `/end-session` to keep the skill surface smaller. The subagent caveat forces the split — Sonnet workers genuinely need a different shape, and pretending otherwise creates silent skip-paths inside one bloated skill. Cost: an extra skill in the project surface. Benefit: each skill is honest about what it does.

2. **Cleaned-Markdown vs raw-jsonl as condenser input.** The continuity plan's Component A currently spec'd raw `.jsonl` as the condenser's input. This plan asks Syndra to flip it to the cleaned Markdown. Tradeoff: condenser becomes simpler (no JSON parsing) and the chain of trust is cleaner (one source file, multiple consumers), but the condenser now depends on the cleaner being correct. If the cleaner drops something the condenser would have flagged, the condenser will never see it. Mitigation: cleaner is mechanical and auditable, plus condenser can fall back to raw `.jsonl` for spot-checks.

3. **Commit cleaned transcripts vs gitignored personal archive (Q-6).** Committed gives durability past the 30-day jsonl retention and makes Zilean's future memory-search job possible. Gitignored gives privacy — transcripts contain everything Duong typed. The plan defaults to committed because that's the only reading consistent with "store it for me," but flags it for explicit Duong sign-off because the privacy impact is non-trivial.

## Open questions for Duong

1. **Q-1 — Cleaner engine.** Python (recommended) or jq+bash? Maintainability vs zero-dep purity.
2. **Q-2 — Output size cap.** Cap cleaned transcript at 2MB Markdown? Higher? Unlimited and trust git to compress?
3. **Q-3 — Skill genericity.** (a) one generic skill, (b) Evelynn-only, or (c) two skills (Bard's recommendation)?
4. **Q-4 — Subagent transcript preservation.** Strip subagent interiors entirely (phase 1 default), or include the subagent's final `tool_result` as a synthetic section (phase 3)? If yes-eventually, lock in the schema now or defer?
5. **Q-5 — Supersession of `/close-session`.** Skills-integration approved `/close-session` as a v1 skill. Does this `/end-session` plan **replace** that line item, or is `/close-session` a separate lighter sibling? Bard recommends replace — two skills with the same purpose is a footgun. Confirm.
6. **Q-6 — Commit policy for transcripts.** Committed (default) or gitignored personal archive? Privacy vs durability.
7. **Q-7 — Wrong-session detection.** Should the skill print the discovered source path and require explicit confirmation when the auto-discovery is ambiguous (multiple recent jsonls), or proceed silently and trust the mtime heuristic?
8. **Q-8 — Phase 1 ship date relative to Component A.** Phase 1 is designed to ship without the condenser. Confirm that's acceptable, or should this skill wait for Component A so the condenser is wired from day one?
9. **Q-9 — Should `/end-session` also handle the case where Duong types "end session" in chat (autonomous mode)?** The skill is `disable-model-invocation: true`, so the model can't auto-fire it from a natural-language instruction. That means Evelynn would have to recognize "end session" and explicitly call the skill. Acceptable — same pattern as other user-only skills — but worth confirming.

## Out of scope

- Authoring the skill files or the cleaner script (implementer task post-approval).
- Building the condenser subagent (Component A of the continuity plan).
- Updating individual agent profiles' `skills:` lists (one PR per agent post-approval).
- Multi-session search across `transcripts/` (Zilean's job, Component B of continuity plan).
- A skill for re-cleaning historical jsonl files retroactively (if Duong wants this, separate plan).
- Telemetry on skill invocation counts, condenser timing, etc.
- Anything that touches `CLAUDE.md` rules directly.

## Success criteria

- `/end-session` exists in `.claude/skills/`, discoverable via slash menu, gated to user invocation.
- `scripts/clean-jsonl.py` produces faithful Markdown from a real session jsonl, validated against three test sessions of varying length.
- Evelynn's profile preloads the skill; one full close cycle ships a cleaned transcript, journal, handoff, memory update, and commit in a single command.
- `/end-subagent-session` (if Q-3 = c) ships in parallel and is preloaded in implementer profiles.
- `agents/memory/agent-network.md` Session Closing Protocol references the skill instead of restating prose.
- Phase 1 ships independent of the condenser; Phase 2 wires in the condenser without breaking Phase 1 sessions.
- Zero secrets leaked in committed transcripts (gitleaks + cleaner denylist).
- One full Evelynn close per day produces a transcript file Duong can `cat` and read like a conversation.
