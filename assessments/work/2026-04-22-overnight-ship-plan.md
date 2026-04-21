---
date: 2026-04-22
coordinator: sona
concern: work
status: active
---

# Overnight Ship Plan — Sona

**Duong is asleep. This file is my compass. Re-read after every auto-compact.**

## Directive (verbatim from Duong)

> We ditch the whole managed agent thing. Let's go with Swain plan to build
> this chat natively. Switch back to coordinator mode, but make sure
> everything run through the gate now. If you get stuck with gh permission,
> try `gh auth switch`, there should be account available for both orianna
> admin bypass and access to PR. You have all the secrets and env available
> to you. Try everything you can to make this e2e work.
>
> When I wake up, I should be able to see a working product: I can chat with
> the agent, I can configure the project. The preview works, I can build with
> the build service and the verification works. Run QA using playwright mcp
> to see if it actually works, run test etc e2e.
>
> Then if you still have capacity, couple things you could fix:
> - add firebase auth login as main mechanism of authentication, so @missmp
>   user can just login and use the service
> - fix the dashboard so that it shows 5 services instead of the old ones with
>   mcps and managed agents
> - fix the UI so it looks nicer and smoother with the agent
>
> One critical thing to note, you shall not call any tools or change which
> require approval request, because I would not be able to accept it. Route
> everything through subagents. If it hit a blocker, find a way to unblock,
> don't try to do it yourself.

## Hard constraints

1. **No self-execute.** Every file edit / shell / deploy goes through a Sonnet subagent.
2. **No approval-prompt tools.** If a tool would prompt the user, skip it or route through a subagent whose permissions autoapprove it.
3. **Orianna gate on every plan promotion.** Use `scripts/plan-promote.sh`.
4. **gh auth switch available** — fallback for PR/admin. Orianna-bypass + PR-access accounts both live in the keychain.
5. **Rule 6 intact.** Never read raw secret values. Use `tools/decrypt.sh`.

## Source-of-truth artifacts

- Plan: `plans/in-progress/work/2026-04-21-demo-studio-v3-vanilla-api-ship.md` (Swain Option B, signed, in-progress, orianna_gate_version 2)
- Decomposition: done by Aphelios (task #80 completed). Tasks live in Sona's task list via `mcp__evelynn__task_list`.
- Test plan: done by Xayah (task #81 completed).
- **Duong's manual-test feedback (re-read from time to time):**
  `assessments/work/2026-04-21-pr64-local-manual-feedback.md` —
  concrete UX/bug notes from Duong while testing PR #64 locally. Bug 5
  (deleted `/session/<id>/preview` route) and other findings live here.
- Workspace: `~/Documents/Work/mmp/workspace/company-os/tools/demo-studio-v3/` (branch `feat/demo-studio-v3`).
- Companion services: `demo-config-mgmt`, `demo-factory`, `demo-preview`, `demo-verification` (all Cloud Run, europe-west1, project `mmpt-233505`).

## Acceptance criteria (morning demo)

1. ✅ Chat with native agent works (no managed-agent, no MCP server)
2. ✅ Tool calls write config via S2 (`demo-config-mgmt`)
3. ✅ Preview renders at `/v1/preview/{session_id}` (S5)
4. ✅ `trigger_factory` kicks S3 build, S3 completes
5. ✅ Verification report readable via `get_last_verification`
6. ✅ Akali Playwright e2e confirms all of the above in prod

## Stretch (only if capacity + healthy context)

- Firebase auth for @missmp.tech users (replace operator cookie)
- Dashboard update: show S1–S5 instead of demo-studio-mcp / managed-agents
- UI polish — chat panel smoother, loading states, error toasts

## Dispatch chain (gate-enforced, SERIAL — not parallel)

**Usage discipline (Duong's explicit order):** *"Don't try to run everyone in
parallel. You have the whole night, the thing that can stop you is you running
too many subagent and blow up the usage."*

One subagent at a time. Wait for return. Synthesize. Dispatch next. No
parallel fan-out unless two tasks are genuinely independent AND both cheap.

1. **Sona → Aphelios** (already completed — reuse decomposition). Refresh task list if stale.
2. **Sona → Rakan** — xfail skeletons per Xayah test plan (TDD gate demands xfail first).
3. **Sona → Viktor** — implement vanilla-api loop per Swain's plan, wave by wave.
4. **Sona → Vi** — standard integration tests after each wave.
5. **Sona → Senna** then **Lucian** — PR review (code, then plan fidelity). Serial, not parallel.
6. **Sona → Ekko** — Cloud Run deploys, gcloud ops.
7. **Sona → Akali** — Playwright QA in prod, final gate.

## Blocker-unblock playbook

- **gh auth denied** → `gh auth switch` to `harukainguyen1411` (Orianna-bypass + admin merge allowed for Duong only — confirm commit author before merging).
- **Deploy denied** → Ekko retries with `--project=mmpt-233505` + proper SA.
- **Secret missing** → check `~/Documents/Personal/strawberry-agents/secrets/` (gitignored) + Secret Manager in GCP.
- **Pre-push hook blocks** → diagnose root cause; never `--no-verify`. If TDD gate trips, author xfail first (Rakan).
- **Orianna signature stale** → re-sign via `scripts/orianna-verify-signature.sh` after commit.

## Heartbeat

- Watchdog task `b7nplckhf` running, 10min idle threshold.
- After each major dispatch, `touch /tmp/claude-heartbeat`.

## Compact discipline

- Re-read THIS file after every auto-compact.
- Run `/pre-compact-save` proactively every ~60min or before dispatching a heavy subagent wave.
