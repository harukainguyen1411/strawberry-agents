---
status: proposed
concern: personal
owner: karma
created: 2026-04-25
tests_required: true
complexity: quick
orianna_gate_version: 2
tags: [hooks, posttooluse, agent-dispatch, akali, lucian, qa-discipline]
related:
  - .claude/agents/akali.md
  - .claude/agents/lucian.md
  - .claude/settings.json
  - scripts/hooks/posttooluse-monitor-arm-sentinel.sh
  - agents/sona/memory/open-threads.md
architecture_impact: none
---

# Akali QA-discipline hooks — Lucian/UI dispatch reminder + Akali no-chat-only rule + verify-claims reminder

## Context

Sona escalated this twice (first 2026-04-23, again 2026-04-25 after PR #32 cycles). Failure pattern observed across PRs #114, #75, and #32: Akali ran QA, was blocked from writing the `.md` report, returned findings as chat-text only, and Sona absorbed those findings as ground truth — across a `/compact` boundary in the PR #32 case — then dispatched a fix-planner against cited `<file>:<line>` claims that did not match reality (`tool_dispatch.py:127` and `main.py:5` were named in chat but the lines did not contain the cited symbols). Two coupled discipline gaps: (1) Lucian-only review on UI/user-flow PRs without a paired Akali QA pass per Rule 16; (2) coordinator absorbing Akali subagent output (chat or report) as ground truth without verifying file:line claims against the actual files.

Three fixes ship together as the "QA-discipline hook bundle". (a) Lucian→Akali reminder hook — PostToolUse on Agent dispatch where `subagent_type=lucian` and the dispatch description signals UI/user-flow context, emits a reminder to also dispatch Akali. (b) Akali chat-only-findings hard refusal — agent-def prompt-layer rule under a new "Reporting discipline" section: if the report write is blocked by any guard, Akali surfaces the block to the coordinator and refuses to paraphrase findings into chat. (c) Coordinator verify-claims reminder hook — PostToolUse on Agent dispatch where `subagent_type=akali`, emits "verify her cited file:line claims before dispatching any fix-planner".

This is the same shape as the deliberation-primitive failure mode (literal directive vs. goal) and the watcher-arm-directive bug (parallel Karma plan in flight). Pattern: hook-backed enforcement of coordinator-discipline rules. Do NOT unify with the watcher-arm or deliberation-primitive plans — this one is QA-specific and ships independently. Single PR; reviewers Senna + Lucian; QA-Waiver acceptable (no UI surface touched).

## Decision

1. **Fix 1 — Lucian→Akali UI-PR reminder (PostToolUse hook).** Add `scripts/hooks/posttooluse-agent-lucian-akali-reminder.sh`. Read JSON from stdin, exit 0 if `tool_name != "Agent"` or `subagent_type != "lucian"`. UI/user-flow detection: check the dispatch `description` field and (when present) `prompt` field for substrings indicating a UI surface — `ui`, `dashboard`, `apps/web`, `apps/dashboard`, `apps/demo-studio`, `playwright`, `figma`, `user flow`, `route`, `auth flow`, `form`. If any matches, emit a `hookSpecificOutput.additionalContext` reminder: "REMINDER: Rule 16 — UI/user-flow PRs require an Akali Playwright run + Figma diff before merge. Confirm Akali has been (or is being) dispatched on this PR; if not, dispatch her now (`subagent_type=akali`)." Description-substring is the cheapest reliable signal — PR labels and full-diff inspection require gh API calls and add latency to every Lucian dispatch. False positives (Lucian dispatched on a UI-adjacent non-UI PR) are tolerable; the reminder is informational, not blocking. Wire into `.claude/settings.json` PostToolUse Agent matcher as a second hook in the existing block (alongside the inline TaskCreate-reminder jq one-liner at line 141).

2. **Fix 2a — Akali chat-only-findings hard refusal (agent-def).** Edit `.claude/agents/akali.md`. Add a new `## Reporting discipline` section after `## Output convention` (around line 44) with three sub-rules: (R1) QA findings MUST land in `assessments/qa-reports/<slug>.md` — never in chat-text response only; (R2) if the report write is blocked by any guard (plan-lifecycle, inbox-write, secrets, sandbox), Akali MUST surface the exact guard message + the intended report content's first 200 chars to the coordinator and STOP — do not paraphrase, do not summarize, do not relay verdict in chat; (R3) the coordinator owns the unblock decision. This is a prompt-layer rule with a structural test: a regex search for the section heading + each sub-rule keyword.

3. **Fix 2b — Coordinator verify-claims reminder on Akali dispatch (PostToolUse hook).** Add `scripts/hooks/posttooluse-agent-akali-verify-reminder.sh`. Read JSON from stdin, exit 0 if `tool_name != "Agent"` or `subagent_type != "akali"`. Emit `hookSpecificOutput.additionalContext`: "REMINDER: Akali findings (chat or report) are subagent output — trust-but-verify. Before dispatching any fix-planner against her cited `<file>:<line>` claims, read each cited line and confirm the named symbol is actually there. PR #32 / PR #114 / PR #75 all hit ghost-mode citations." Wire alongside Fix 1 in the same PostToolUse Agent block in `.claude/settings.json`.

The two new hooks coexist with the existing inline `jq -r '...TaskCreate for subagent...'` one-liner at settings.json:141. All three Agent PostToolUse hooks fire in series; each is a no-op for non-matching `subagent_type` and emits its own `hookSpecificOutput`. JSON merging across multiple hooks in the same matcher block is handled by the framework (each hook prints its own JSON; the framework concatenates `additionalContext` strings).

## Tasks

### T1 — xfail tests (TDD, Rule 12)

- kind: test
- estimate_minutes: 30
- files: `scripts/hooks/tests/posttooluse-agent-lucian-akali-reminder.test.sh` (new), `scripts/hooks/tests/posttooluse-agent-akali-verify-reminder.test.sh` (new), `scripts/hooks/tests/akali-agent-def-reporting-discipline.test.sh` (new). <!-- orianna: ok -- prospective paths, created by this plan -->
- detail: Three test scripts, one per fix. (a) Lucian-reminder test: feed five JSON payloads via stdin — (i) `tool_name=Agent, subagent_type=lucian, description="review PR #32 dashboard UI"` → expect `additionalContext` containing "Rule 16" and "Akali"; (ii) `subagent_type=lucian, description="review PR #99 apps/web auth flow"` → expect reminder fires; (iii) `subagent_type=lucian, description="review PR #50 hook script refactor"` → expect NO reminder (no UI keyword); (iv) `subagent_type=senna, description="review PR #32 dashboard"` → expect NO reminder (wrong subagent); (v) `tool_name=Bash` → expect NO output. (b) Akali-verify-reminder test: three payloads — (i) `subagent_type=akali` → expect "verify" + "file:line" in additionalContext; (ii) `subagent_type=lucian` → no output; (iii) `tool_name=Bash` → no output. (c) Akali agent-def test: `grep -q '## Reporting discipline'` on `.claude/agents/akali.md` plus three keyword greps (`assessments/qa-reports`, `MUST surface`, `do not paraphrase`). All three test scripts run red against current state (hooks don't exist, akali.md section absent). Commit references plan slug `2026-04-25-akali-qa-discipline-hooks` for TDD-gate.
- DoD: `bash scripts/hooks/tests/posttooluse-agent-lucian-akali-reminder.test.sh` and the other two test scripts execute and report all assertions failing (xfail floor). No regression in existing hook tests. Commit prefix `chore:`.

### T2 — Implement Lucian→Akali reminder hook

- kind: code
- estimate_minutes: 20
- files: `scripts/hooks/posttooluse-agent-lucian-akali-reminder.sh` (new). <!-- orianna: ok -- prospective path, created by this plan -->
- detail: POSIX-portable bash (Rule 10). Read stdin JSON via `jq` with grep fallback (mirror `posttooluse-monitor-arm-sentinel.sh` style). Extract `tool_name`, `tool_input.subagent_type`, `tool_input.description`, `tool_input.prompt`. Exit 0 silently if `tool_name != "Agent"` or `subagent_type != "lucian"`. UI-keyword check: case-insensitive substring search across `description` + `prompt` for the keyword set listed in §Decision Fix 1. If match, emit JSON: `{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"<reminder text>"}}`. If no match, exit 0 silently. Set executable bit. Header comment block per repo convention (purpose, input, output, plan-slug reference).
- DoD: After T2 alone, all five assertions in the Lucian-reminder test pass. Other two test scripts still red.

### T3 — Implement Akali verify-claims reminder hook

- kind: code
- estimate_minutes: 15
- files: `scripts/hooks/posttooluse-agent-akali-verify-reminder.sh` (new). <!-- orianna: ok -- prospective path, created by this plan -->
- detail: POSIX-portable bash. Same structure as T2: read stdin, exit 0 if not Agent or not akali. On match emit the verify-claims reminder JSON described in §Decision Fix 2b. Header comment includes the PR #32 / #114 / #75 ghost-citation context.
- DoD: After T3, all three assertions in the akali-verify-reminder test pass.

### T4 — Wire both hooks into settings.json PostToolUse Agent matcher

- kind: code
- estimate_minutes: 10
- files: `.claude/settings.json`
- detail: In the `PostToolUse` array, locate the existing Agent matcher block (currently lines 137–144 — single inline jq hook for TaskCreate reminder). Append two additional hook entries in the same `hooks` array: `{"type": "command", "command": "bash scripts/hooks/posttooluse-agent-lucian-akali-reminder.sh"}` and `{"type": "command", "command": "bash scripts/hooks/posttooluse-agent-akali-verify-reminder.sh"}`. Preserve the existing TaskCreate inline hook unchanged. Validate JSON with `jq . .claude/settings.json > /dev/null`.
- DoD: `jq .` parses settings.json without error. Manual smoke: `printf '{"tool_name":"Agent","tool_input":{"subagent_type":"lucian","description":"review PR #32 dashboard UI"}}' | bash scripts/hooks/posttooluse-agent-lucian-akali-reminder.sh | jq .` returns valid JSON containing the reminder.

### T5 — Add Reporting discipline section to akali.md

- kind: code
- estimate_minutes: 15
- files: `.claude/agents/akali.md`
- detail: Insert a new `## Reporting discipline` section between the existing `## Output convention` (ends line 43) and `## Prod QA auth — demo-studio-v3` (line 45). Section content: three numbered rules per §Decision Fix 2a — (1) findings MUST land in `assessments/qa-reports/<slug>.md`, never chat-text-only; (2) if the report write is blocked by any guard (plan-lifecycle, inbox-write, secrets, sandbox), surface the exact guard message + intended report content's first 200 chars to the coordinator and STOP — do not paraphrase, do not summarize, do not relay the PASS/FAIL verdict in chat; (3) the coordinator owns the unblock decision. Add a one-line cross-reference: "Rationale: PR #32 / PR #114 / PR #75 ghost-citation pattern; coordinator absorbed chat-text findings as ground truth across `/compact`."
- DoD: After T5, all four assertions in the akali agent-def test pass. Existing Hard Rules section unchanged. `<!-- include: _shared/no-ai-attribution.md -->` block at end of file unchanged.

### T6 — Manual smoke + memory note

- kind: ops
- estimate_minutes: 10
- files: `agents/karma/memory/karma.md` (append session note)
- detail: Run all three new test scripts — confirm green. Run two end-to-end smokes: (a) `printf '{"tool_name":"Agent","tool_input":{"subagent_type":"lucian","description":"review PR #32 dashboard UI Wave D"}}' | bash scripts/hooks/posttooluse-agent-lucian-akali-reminder.sh` — expect Rule 16 reminder JSON; (b) `printf '{"tool_name":"Agent","tool_input":{"subagent_type":"akali","description":"QA PR #32"}}' | bash scripts/hooks/posttooluse-agent-akali-verify-reminder.sh` — expect verify-claims reminder JSON. Capture both outputs in PR description. Append memory note to `agents/karma/memory/karma.md` recording the QA-discipline hook bundle pattern (Rule 16 reminder + chat-only refusal + verify-claims reminder) and link to PR #.
- DoD: All tests green; smoke transcripts in PR body; memory shard appended.

## Test plan

Tests cover three invariants this plan ships:

1. **Lucian→Akali reminder fires iff subagent=lucian AND description signals UI/user-flow.** Protected by five test cases in `posttooluse-agent-lucian-akali-reminder.test.sh` covering positive (UI keyword present), negative (no UI keyword), wrong-subagent, and wrong-tool-name paths. If a future change drops the lucian-subagent gate or the UI keyword check, the relevant case fires.

2. **Akali verify-claims reminder fires iff subagent=akali.** Protected by three test cases in `posttooluse-agent-akali-verify-reminder.test.sh`. If a future change broadens or narrows the gate, tests fire.

3. **Akali agent-def carries the chat-only-findings hard refusal.** Protected by four grep assertions in `akali-agent-def-reporting-discipline.test.sh` — section heading present, plus the three keyword anchors (`assessments/qa-reports`, `MUST surface`, `do not paraphrase`). If a future copy-edit removes the rule or weakens the wording, tests fire.

Out of scope: Lucian agent-def changes (his behaviour is unchanged — only the reminder fires when the framework dispatches him); the existing TaskCreate inline reminder hook (preserved untouched); PR-label-based UI detection (description-substring chosen for cheapness — see §Decision); Sona/Evelynn coordinator-side prompt rules (this plan is hook + Akali-def only; coordinator-discipline lives in the coordinator def files and is a separate plan if Sona escalates).

## References

- `agents/sona/memory/open-threads.md` lines 303–307 — Sona's prior 2026-04-23 escalation
- `agents/sona/memory/open-threads.md` line 40 — PR #32 T.P1.16 Akali ghost-citation incident
- `plans/proposed/personal/2026-04-25-watcher-arm-directive-source-gate.md` — sibling plan on hook-backed coordinator-discipline enforcement (literal-vs-goal pattern)
- `scripts/hooks/posttooluse-monitor-arm-sentinel.sh` — reference style for new PostToolUse hooks
- `.claude/settings.json` lines 137–144 — existing PostToolUse Agent matcher block
