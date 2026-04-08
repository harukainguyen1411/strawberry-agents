# 2026-04-08 — Bootstrap-loop validation: build the tool, then immediately use it to close the session that built it

## The pattern

When designing a piece of self-applying infrastructure (a session-close skill, a memory cleaner, a state-archiver), the strongest possible validation is to **build it inside the same session you then use it to close**. The session that produces the tool becomes the first real consumer of the tool. Every gap, every unhandled edge case, every subtle drift between the spec and the reality surfaces immediately because you cannot fake the input — the input *is* the actual conversation that just happened.

## How it surfaced

This session shipped `/end-session` Phase 1 (jsonl cleaner + transcript archive + handoff note + memory refresh + commit) and then immediately invoked the skill on itself. Five distinct gotchas the design hadn't covered came out only because the bootstrap forced real use:

1. **`<local-command-caveat>` tag wasn't in the denylist regex.** Bard's spec listed `<system-reminder>` and `<task-notification>` and `<local-command-stdout>` but missed the bare `<local-command-caveat>` form. The cafe-to-home reference transcript had three of them. Real input found the gap on first run. Katarina patched inline.

2. **Chain-walk threshold (30-minute gap) was too narrow.** The cafe-to-home session had 2-3 hour gaps between jsonl files. The auto-chain assembly couldn't reproduce the reference output without explicit per-file invocation. Spec passed code review; real input broke it.

3. **Secret denylist tripped on the project's public age recipient pubkey.** The spec said "fail loud on private key shapes." Reality: the pattern was loose enough to also catch the public recipient, and the public recipient appears in the actual transcript because we discussed encrypted-secrets architecture mid-session. A purely-synthetic test would have used a fake pubkey and missed this entirely.

4. **`.gitignore` already had `transcripts/` ignored globally.** A purely-conceptual review would not have caught this; staging the first real cleaned transcript hit the wall. Negation rule was added in the implementation, not the design.

5. **`disable-model-invocation: true` blocked the model from auto-firing the skill.** Bard set the flag as a safety. The bootstrap test of "Evelynn invokes the skill she just built" failed at the first Skill tool call because the safety flag did exactly what it was supposed to do. Duong had to explicitly type `/end-session` to invoke it (or flip the flag, which is what we ended up doing). Without the bootstrap test, this would have shipped with no one knowing it required manual invocation only.

## Why it works

A specification is necessarily an abstraction over the inputs it expects. A bootstrap loop refuses the abstraction — the actual messy real-world input is the only test fixture, and that fixture is impossible to fake or simplify. Anything the spec missed, the bootstrap exposes. Anything that "looked right on paper" reveals its gap on first run.

Compare to the alternative: ship the skill, write a synthetic test fixture, mark it green, deploy, wait for the next real session to close, and only then discover the five gotchas. That cycle is days. The bootstrap cycle is *the same session*, in real time, with all the actual context still in your head to fix it.

## When to use this pattern

- **Self-applying tools.** Anything where the tool eventually consumes its own output type. Session-close skills, memory cleaners, state archivers, log condensers, plan-format validators.
- **Format converters.** Building a converter that operates on real production data — use today's actual data for the first run, not a synthetic.
- **Workflow skills.** Skills that orchestrate multiple steps — invoke once on a real workflow, not a contrived example.

## When NOT to use it

- **Destructive operations on shared state.** A skill that deletes prod data should NOT bootstrap-test against prod. Use a sandbox.
- **Multi-day tools.** A tool whose value only emerges over weeks of accumulation can't be bootstrap-validated in one session — but its individual write-step can be.

## Cost

- A single iteration. Build → invoke → fix the gaps it surfaces → re-invoke or accept the gaps as Phase 2 work. The Phase 2 backlog Katarina filed has five entries, all surfaced by the bootstrap. Total bootstrap cost was the time to write the skill plus one execution. The value is five gotchas caught before they would have hit the next session's close blind.

## Connection to other patterns

- **Two-phase plan lifecycle:** the bootstrap is essentially "rough plan → detailed plan → execute → use the output → file Phase 2 refinements." It compresses the validate-and-iterate loop into a single session.
- **Fast-tracking with eyes open:** Duong authorized rough → detailed → execute compression for this skill specifically. Bootstrap testing is what makes that compression safe — the speed comes from validating against real input on the same loop.
