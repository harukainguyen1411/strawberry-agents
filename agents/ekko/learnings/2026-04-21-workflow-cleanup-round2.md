# Workflow Cleanup Round 2 — 2026-04-21

## Context

Deleted 4 more vestigial workflows from strawberry-agents, opened PR #10, re-triggered PR #7 CI, and produced the final branch-protection payload doc.

## Key Learnings

### gh run rerun loop fix
`gh run rerun` must be called with one run ID per invocation. When using a loop, save IDs to a file and use `while IFS= read -r run_id; do ... done < file` — not a `for` loop over a multi-line command substitution, which can produce newline-joined strings that parse as a single invalid ID.

### branch-protection.json is a doc, not live config
`.github/branch-protection.json` has no effect on GitHub's actual branch protection. It's a documentation artifact. When deleting a workflow that its `contexts` array references, update the JSON doc in the same commit to avoid confusing future audits — but this is a prose cleanup, not a functional requirement.

### PR #9 (auto-rebase.yml) merged while working
When merging the payload doc commit to main, remote had advanced due to PR #9 merging. Pattern: always `git fetch origin main && git merge origin/main` before pushing to main when other PRs are in flight on the same repo.

### Check name source of truth
GitHub registers check names from the `name:` field of each job in a workflow, NOT from the job key. `tdd-gate.yml` job key `xfail-first` with `name: xfail-first check` registers as `xfail-first check`. Always verify against both the YAML and live `gh pr checks` output before writing them into branch-protection required_status_checks.

### Orphan audit interpretation
grep results for deleted workflow names fall into two categories:
- Active: workflow_call chains, workflow_run triggers, scripts that invoke the workflow filename — BLOCKING, must resolve before deleting
- Prose: plans, memory files, learnings, doc JSON — non-blocking, clean up as time allows

For this session: only `.github/branch-protection.json` (doc, cleaned up in same commit) and agent memory/learnings prose (non-blocking). No active callers.
