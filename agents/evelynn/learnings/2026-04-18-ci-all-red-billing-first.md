# CI all-red across every PR simultaneously → check Actions billing FIRST

## Observation

On 2026-04-18 during the dependabot-cleanup workstream, every required check across every open PR (#157, #171, #174, #176) flipped to FAILURE within minutes. All failures had runtime 1-2 seconds. `gh run view --log-failed` returned "log not found" across the board.

First hypothesis was a workflow-file regression from workstream-1 (deployment-pipeline had recently merged `11d4566` to `tdd-gate.yml`). Spent ~15 min investigating that angle before Yuumi pulled the actual GitHub Actions annotation, which read:

> "The job was not started because recent account payments have failed or your spending limit needs to be increased."

Every job was being rejected at queue time, never executing. The 1-2 second runtimes were queue-rejection overhead.

## Rule

**If ALL of the following are true, check GitHub → Settings → Billing & plans BEFORE investigating any workflow file or code change:**

1. Every required check on every open PR is red.
2. Failures happen within ~2 seconds of queuing.
3. `gh run view --log-failed` returns no log or empty output.
4. Main branch itself is also failing.

Condition 4 is the strongest signal — a workflow regression would affect PRs but usually not main's already-passing runs. A billing block affects everything equally.

## Diagnostic shortcut

```bash
gh run view <any-failing-run-id> --json annotations -q '.annotations[].message'
```

If the message mentions "payments" or "spending limit", stop investigating code and escalate to the account owner.

## Cost today

~30 minutes of team time parked while diagnosing. Worth ~2 minutes next time with this learning in place.
