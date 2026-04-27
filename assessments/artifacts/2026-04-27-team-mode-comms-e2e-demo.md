---
slug: team-mode-comms-e2e-demo
concern: personal
category: artifacts
target: plans/approved/personal/2026-04-27-agent-team-mode-comms-discipline.md
state: complete
status: complete
owner: evelynn
session: e951f0a4
date: 2026-04-27
author: evelynn
demonstrates: plans/approved/personal/2026-04-27-agent-team-mode-comms-discipline.md (T11)
---

# Team-mode comms discipline — end-to-end demo

This is the project's DoD-closing artifact for the
[agent-team-mode-comms-discipline](../../projects/personal/active/agent-team-mode-comms-discipline.md)
project. It satisfies T10's xfail (recorded e2e demo artifact) and the
project's "shipped guidance has been demonstrated end-to-end on a real team in
this repo" DoD bullet.

## Demo metadata

| Field          | Value                                                      |
|----------------|------------------------------------------------------------|
| `team_name`    | `team-mode-comms-e2e-demo`                                 |
| Lead           | Evelynn (this session — coordinator personal-concern)      |
| Teammate 1     | `talon@team-mode-comms-e2e-demo` (editor)                  |
| Teammate 2     | `senna@team-mode-comms-e2e-demo` (reviewer)                |
| Backend        | in-process                                                 |
| Created        | 2026-04-27 13:21:?? UTC (TeamCreate)                       |
| Deleted        | 2026-04-27 13:24:?? UTC (TeamDelete after both shutdown_acks) |
| Wall clock     | ~3 minutes from spawn to clean teardown                    |
| `isActive`     | All members 0 at TeamDelete (no orphans)                   |

## Real task exercised

**Decide what to do with the orphan fixture file** at
`tests/hooks/fixtures/teammate-idle-real-transcript.jsonl`.

Background: Senna's R2 review on PR #111 (the T9 follow-up) approved the PR
but filed a non-blocking NIT — after the F2 fixture replacement landed
(`teammate-idle-real-shape.jsonl`), the original
`teammate-idle-real-transcript.jsonl` had no test consumers. Three options on
the table: delete, symlink, keep.

This is real outstanding repo work — the demo is not a contrived exercise.

## Turn-by-turn transcript

Notation: messages from teammates appear as the lead saw them. Completion
markers preserve the typed-JSON shape Talon and Senna produced. Peer DMs
between Talon and Senna are reconstructed from the lead-side `summary` field
of `idle_notification` events (the Team feature's peer-DM-visibility
mechanism — leads see brief summaries of peer traffic, not full bodies).

### Turn 0 — TeamCreate + spawn

```
TeamCreate(team_name="team-mode-comms-e2e-demo", agent_type="coordinator", ...)
  → team_file_path: ~/.claude/teams/team-mode-comms-e2e-demo/config.json
  → lead_agent_id: team-lead@team-mode-comms-e2e-demo

Agent(subagent_type=Talon, team_name=..., name="talon", run_in_background=true, prompt=<editor brief>)
  → agent_id: talon@team-mode-comms-e2e-demo

Agent(subagent_type=Senna, team_name=..., name="senna", run_in_background=true, prompt=<reviewer brief>)
  → agent_id: senna@team-mode-comms-e2e-demo
```

Both teammates spawned as **real teammates** (`name@team` agent_id format,
not hex one-shot ID). Initial briefs gave each their role, the protocol
contract (typed completion markers, peer-to-peer SendMessage allowed), and
the dual-loop convergence rules.

### Turn 1 — Talon investigates and proposes (peer-to-peer to senna)

`idle_notification` carrying summary field showed Talon's outbound peer DM:

```
{
  "type":"idle_notification",
  "from":"talon",
  "summary":"[to senna] Orphan fixture investigation complete — proposing delete"
}
```

Lead-side observation: peer DM visibility working. Lead sees the summary,
not the full body — exactly the design described in the runbook §Peer-to-peer
SendMessage section.

### Turn 2 — Senna pre-verifies and concurs (peer-to-peer to talon AND task_done to lead)

Senna's sequence:

1. Pre-verified independently before Talon's message landed (the brief
   permitted this). Confirmed orphan status by grepping the codebase for
   references to `teammate-idle-real-transcript.jsonl`: zero test scripts,
   zero runtime scripts, zero plan references.

2. Replied peer-to-peer to talon (visible via Senna's idle_notification
   summary):

```
{
  "type":"idle_notification",
  "from":"senna",
  "summary":"[to talon] Concur with delete verdict"
}
```

3. Sent typed completion marker to lead:

```
{
  "type":"task_done",
  "ref":"orphan-fixture-review",
  "summary":"Reviewed talon's verdict; concurred with DELETE. Independently pre-verified orphan status (zero test/script references) before talon's message; verdict matches my R2 NIT recommendation. No pushback iterations needed."
}
```

### Turn 3 — Talon receives concurrence, sends converged marker to lead

```
{
  "type":"task_done",
  "ref":"orphan-fixture-converged",
  "summary":"Final verdict: DELETE; senna concurred. Both sides independently confirmed zero consumers of tests/hooks/fixtures/teammate-idle-real-transcript.jsonl — no test scripts, no runtime scripts, no plans reference it as input. It was a misnamed byte-identical duplicate of the conformant fixture (Senna R1 F3), superseded by teammate-idle-real-shape.jsonl in PR #111. Symlink ruled out as the target is not the active fixture. Clean delete is the correct housekeeping action."
}
```

Demo work complete. Convergence achieved in zero iterations (clean
concurrence, no pushback rounds needed).

### Turn 4 — Lead initiates shutdown handshake (parallel)

```
SendMessage(to="talon", message={"type":"shutdown_request","reason":"..."})
  → request_id: shutdown-1777296197265@talon

SendMessage(to="senna", message={"type":"shutdown_request","reason":"..."})
  → request_id: shutdown-1777296198751@senna
```

### Turn 5 — Both teammates shutdown_approved

Talon ack arrived first (~13:23:20 UTC):

```
{
  "type":"shutdown_approved",
  "requestId":"shutdown-1777296197265@talon",
  "from":"talon",
  "paneId":"in-process",
  "backendType":"in-process"
}
```

System notification of clean termination followed:

```
{"type":"teammate_terminated","message":"talon has shut down."}
```

Senna ack arrived ~40 seconds later (~13:23:59 UTC) with matching request_id
echo (`shutdown-1777296198751@senna`). The latency between the two
acks is consistent with each teammate handling the shutdown_request on its
own next turn — not a protocol failure, just the in-process backend's
event-loop scheduling.

### Turn 6 — TeamDelete

```
TeamDelete()
  → success: true
  → "Cleaned up directories and worktrees for team team-mode-comms-e2e-demo"
```

No orphaned `isActive: true` members. Clean teardown.

## Decision captured (for the actual task — separate from the demo)

**Verdict on the orphan fixture**: DELETE. Both teammates independently
confirmed zero consumers; symlink ruled out as the path doesn't point to a
useful target; the file was a misnamed duplicate from PR #111 R1, superseded
in R2. Clean delete is correct housekeeping.

**Action**: Will be filed as a small Yuumi errand or rolled into the next
hooks-area cleanup pass. Not landed as part of this artifact — the artifact
is the demo, not the cleanup commit.

## Protocol observations (validating the runbook)

- ✅ **SendMessage Contract** — substantive teammate output went via
  SendMessage, not terminal. Both teammates referred to peers by name
  (`senna`, `talon`, `team-lead`) per the runbook.
- ✅ **Completion-Marker Protocol** — every task-completing turn carried a
  typed marker. Peer-to-peer between Talon and Senna; task_done to lead from
  both. No silent completions.
- ✅ **Peer-to-peer SendMessage** — the editor → reviewer dual loop
  converged peer-to-peer without lead arbitration. Lead saw summaries via
  idle_notification, not full peer body content. Exactly the design intent.
- ✅ **Conditional self-close** — neither teammate self-closed after their
  task_done. Both stayed alive until the lead's shutdown_request → ack
  handshake. This was the failure mode the runbook revision targeted; both
  teammates exhibited the corrected behavior.
- ✅ **shutdown_request → shutdown_ack handshake** — both ack'd with
  matching request_ids, correct field name (`requestId` per Claude Code's
  current schema, not `request_id` — runbook should reflect this).
- ✅ **Clean TeamDelete** — no orphaned `isActive: true` after all
  shutdown_acks landed.

## Caveats and learnings

### Caveat 1 — Demo-shaped, not stress-tested

The demo task was small (verdict-only, no PR cycle, ~3 minutes wall clock,
single iteration round). It validates the **happy-path** of the protocol but
does NOT exercise:

- Pushback / disagreement rounds (talon and senna concurred immediately)
- Stale-task drift (no task was re-dispatched after a teammate marked it
  complete)
- Rate-limit-induced silence (earlier in the same coordinator session, a
  Talon teammate appeared to "silently shutdown" before responding ~1h40m
  later — that was a rate-limit artifact masquerading as protocol failure;
  the demo did not reproduce that condition)
- Hook detection (the T9 hook's idle-without-marker warning was not
  triggered because every teammate emitted markers on every relevant turn)

Cross-session validation against these conditions remains future work.

### Caveat 2 — Field name discrepancy

Runbook §Completion-Marker Protocol uses `request_id` (snake_case) as the
field name on shutdown_response. Claude Code's actual schema returns
`requestId` (camelCase). Both observed acks in this demo used the camelCase
form. The runbook should be updated to match real schema.

### Caveat 3 — Per-team TaskList scoping

When the lead created the demo team via TeamCreate, the TaskList scope
shifted — task IDs reset to `1` and `2` for the new team's tasks, and the
prior team's task entries (PR #110 / #111 tracking) became inaccessible from
the current scope. This is undocumented behavior of the team-context model:
**tasks are per-team, not per-session**. Worth folding into the runbook.

### Caveat 4 — Idle-notification shape

Two notable things observed about `idle_notification` events:

1. They carry a `summary` field when peer DM activity occurred in the
   teammate's last turn (peer DM visibility for the lead). When no peer DM
   occurred, the field is absent. The runbook should document this.
2. Multiple identical idle_notifications can fire in close succession
   (Senna fired two within 3 seconds at the start of her session). Lead
   should treat these as informational — no protocol response required.

## Conclusion

The protocol works on the happy path. T10's xfail is satisfied by this
artifact (team_name, lead identity, ≥2 teammates, turn-by-turn transcript
with markers, clean shutdown handshake, no orphaned `isActive: true`). The
parent project's DoD bullet "shipped guidance has been demonstrated
end-to-end on a real team in this repo" is met.

Three caveats above (field-name mismatch, TaskList scoping, idle_notification
shape documentation) are folded back into the runbook in a separate small
follow-up — not blocking the parent project's promotion to `implemented`.

---

**Cross-references:**

- Project: `projects/personal/active/agent-team-mode-comms-discipline.md`
- Plan: `plans/approved/personal/2026-04-27-agent-team-mode-comms-discipline.md`
- Follow-up plan: `plans/approved/personal/2026-04-27-team-mode-t9-followups.md` (merged in PR #111)
- PR #110 (T1-T10 ship): https://github.com/harukainguyen1411/strawberry-agents/pull/110 (merge commit `0737035b`)
- PR #111 (T9 follow-up): https://github.com/harukainguyen1411/strawberry-agents/pull/111 (merge commit `2c4cd330`)
