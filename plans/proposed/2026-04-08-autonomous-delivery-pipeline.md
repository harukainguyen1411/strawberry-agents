---
title: Autonomous Delivery Pipeline — Discord Issue to Deployed Feature with Preview Tunnels
status: proposed
owner: syndra
created: 2026-04-08
---

# Autonomous Delivery Pipeline

> Rough plan. Alignment-level only. No file diffs, no exact commands, no step-by-step scripts. The detailed execution spec happens after Duong approves this direction.
>
> No component self-implements. No implementer assigned.
>
> **Dependency note:** A parallel Explore task was supposed to drop `assessments/2026-04-08-myapps-snapshot.md` describing the myapps target repo stack. At the time this plan was written the snapshot did not exist. The plan is therefore written at the architectural level without assuming myapps specifics (framework, build command, deploy target). The detailed phase must read the snapshot before picking concrete tools for build/preview/deploy.

---

## Problem

Duong wants a push-button product loop: he types `bug: <X>` or `feature: <Y>` into a Discord channel from his phone, and **everything else happens without him**, up to and including a clickable preview URL posted back to Discord for him to test, and an autonomous production deploy on his `approved` reply.

The loop he described, verbatim-ish:

```
Discord post
   -> GitHub issue auto-filed, labeled, prioritized
   -> Agent team claims the issue
   -> Rough plan drafted, approval gated
   -> Detailed plan drafted, claimed by an executor
   -> Implementation in an isolated worktree, PR opened
   -> Reviewer agent(s) pass the PR
   -> Ephemeral preview environment spun up
   -> Tunnel URL posted back to Discord: "Ready to test: https://..."
   -> Duong tests, replies "approved" or "reject: <reason>"
   -> On approve: merge + autonomous production deploy + confirmation
   -> On reject: issue reopened with feedback, loop re-enters
```

Today the pieces exist in scattered form: the Discord relay bot (`plans/proposed/2026-04-03-discord-cli-integration.md`), the Cloudflare Tunnel transport thinking (`plans/proposed/2026-04-08-cafe-from-home.md`), the two-phase plan lifecycle (`plans/proposed/2026-04-08-plan-lifecycle-protocol-v2.md`), the Evelynn continuity and coordinator-purity work (`plans/proposed/2026-04-08-evelynn-continuity-and-purity.md`), the skills stack, the minion stack, the work-agent isolation model. **None of them connect into a single delivery loop.** This plan is the integration architecture, not any one of those pieces.

The deeper problem is that each transition in that loop is a decision point, and every decision point today lives in Duong's head. To remove Duong from the hot path without losing the quality gates he cares about, the loop needs:

1. **A machine-readable event spine** — something every stage emits on and listens to, so the loop is observable and recoverable.
2. **Explicit gate policy** — which transitions are automatic, which wait for a human, and how the gate is expressed in Discord (not in a file browser, not in a terminal).
3. **Concurrency discipline** — multiple issues may be in flight, and the host running agents is finite (Duong's Windows box, possibly the Hetzner VPS). Without a scheduler, this turns into a fork bomb of Claude processes.
4. **A kill switch Duong can reach from his phone** — if the loop goes feral, he needs to stop it from Discord without opening a laptop.

---

## Context

Load-bearing facts from the existing system:

- **Windows box is the agent runtime.** Claude Code instances, MCP servers, secrets, worktrees — all on Windows. The VPS runs the Discord relay and event bridge (per the discord-cli-integration plan), not the agent workers themselves. "Local agents" in Duong's ask maps to Windows.
- **Two-phase planning is in flight.** Rough -> approved -> detailed -> ready -> in-progress -> implemented, per plan-lifecycle-protocol-v2. This pipeline must slot into that lifecycle, not bypass it. Every issue produces two plan files over its lifetime, not one.
- **Evelynn is coordinator-only.** Per evelynn-continuity-and-purity, Evelynn never touches files directly — Yuumi reads, Poppy edits, Sonnet executors implement. The pipeline's "agent team per issue" has to compose from this pool, not replace it.
- **Plans commit direct to main. Implementation goes through PR.** Rule 9. The pipeline's plan drafts commit to main without gates beyond the rough/detailed split; the code PR is where the review + preview + approve loop lives.
- **Commit prefix is `chore:` everywhere on main.** Rule 10. The pipeline's automated commits inherit this.
- **Secrets never land in committed files.** Rule 4. All deploy credentials, tunnel tokens, GitHub tokens for the bot, Firebase CI tokens — everything goes through `secrets/` or env vars, fetched via `tools/decrypt.sh`.
- **Cafe path may or may not exist yet.** The Cloudflare Tunnel work (`cafe-from-home`) is still proposed. If it lands before this pipeline, the preview tunnels can reuse the same Cloudflare account; if not, this pipeline might pick a simpler stand-alone tunnel (e.g., `cloudflared` ephemeral `*.trycloudflare.com`) for previews, since previews are short-lived and per-PR, not long-lived remote access.
- **myapps stack is unknown at write time.** See Dependency note above. Detailed phase reads the snapshot.

---

## Proposed approach

The pipeline decomposes into **seven subsystems** glued by a single event bus and a single state store. Each subsystem has a clear input/output contract and can be built, tested, and replaced independently. The whole thing runs as a set of long-running processes on the VPS + Windows box, coordinated through git (the state store) and the Discord + GitHub APIs (the user-facing surfaces).

### The seven subsystems

**1. Intake — Discord to GitHub Issue**

Input: a Discord message in a designated channel with a parseable prefix (`bug:`, `feature:`, `question:`, or a slash command). Output: a GitHub issue in the myapps repo with labels (`type/bug` | `type/feature` | `type/question`), a priority guess, and the originating Discord user + message link in the issue body.

Approach options for "what creates the issue":

- **(a)** Extend the existing discord-relay bot on the VPS (from `discord-cli-integration.md`). It already listens to Discord, already has a token. Adding a "parse intake messages and call GitHub API" path is a small extension, not a new service. **Recommended default.**
- **(b)** A Discord slash command registered to a new tiny Cloudflare Worker / HTTP endpoint. More work, more moving parts, no real benefit over (a) except that slash commands get Discord-native UI.
- **(c)** Let Evelynn read intake messages and call the GitHub API herself. **Rejected** — coordinator purity. Evelynn does not directly touch external services; that's what the relay bot is for.

Parsing: intentionally dumb at the bot layer. The bot extracts `prefix`, `title` (first line), `body` (rest), `author_handle`. A classifier step (see subsystem 3) can later refine label and priority using an LLM call, but the bot itself does not call Claude; it just files the issue.

Rate limiting and abuse: the intake channel should be a single-user channel (Duong only) for MVP. Later, a role-gate for trusted contributors. Anyone outside the role gets ignored with a reaction emoji, not a reply. Rate limit at the bot layer: max N issues per hour per user, with overflow queued or reacted-to with a "slow down" emoji.

**2. Event bus — the glue**

Every transition in the loop emits an event. Every subsystem reads the events it cares about. This is the seam that makes the pipeline observable, debuggable, and recoverable after a crash.

Options for the bus substrate:

- **(a) Filesystem + inotify-style watchers.** Events are JSON files in a directory. Workers poll or use `fs.watch`. Matches the style of the discord-cli-integration plan (file-based event queue). **Recommended default** — simplest, git-friendly for audit, no new infra.
- **(b) Redis pub/sub.** More real-time, but adds a dependency nobody else in the stack uses.
- **(c) GitHub itself as the bus.** Use issue labels, PR labels, and issue comments as state transitions; workers poll the GitHub API. Pros: no new infra, the state is already where Duong looks. Cons: GitHub rate limits, and comment-parsing is fragile.

The recommended shape is **(a) filesystem bus on the VPS for cross-process events, plus (c) GitHub labels as the durable state of record for each issue**. Filesystem bus = fast-path signaling; GitHub labels = source of truth a human can audit. If filesystem state diverges from GitHub state, GitHub wins and the filesystem is rebuilt on boot by polling GitHub.

Event types (rough, not exhaustive): `issue.created`, `plan.rough.drafted`, `plan.rough.approved`, `plan.detailed.drafted`, `plan.detailed.ready`, `pr.opened`, `pr.reviewed.pass`, `pr.reviewed.fail`, `preview.up`, `preview.down`, `approval.requested`, `approval.granted`, `approval.rejected`, `deploy.started`, `deploy.succeeded`, `deploy.failed`, `issue.closed`, `pipeline.aborted`, `pipeline.killswitch`.

**3. Triage and dispatch — Issue to Agent Team**

Input: an `issue.created` event. Output: a `plan.rough.drafted` event and a rough plan file committed to `plans/proposed/`.

This is where the pipeline picks up the issue and decides what to do with it. Two sub-steps:

- **Classifier.** A single small Claude call (Haiku tier; fits the minion stack's philosophy) reads the issue body, outputs a JSON verdict: `{type: bug|feature|chore|question, risk: low|medium|high, scope: single-file|multi-file|cross-cutting, confidence: 0..1, rationale: "..."}`. This is *advisory* data that informs the gate policy below. It is not a decision on its own.
- **Dispatcher.** Takes the classifier output and the issue and spawns the planning phase. Two structural options:
  - **(A) Standing Evelynn.** A long-running Evelynn Claude Code process on Windows watches the event bus, and when an `issue.created` lands, she delegates the rough plan to the appropriate Opus (Syndra / Swain / Pyke / Bard) per existing rules. This matches today's mental model exactly. **Recommended default.**
  - **(B) Per-issue Evelynn spawn.** A fresh Evelynn process is launched per issue, lives only until the issue is done, then exits. Cleaner state isolation but wastes token budget on re-priming Evelynn each time. Rejected for MVP.

The classifier's `risk` field feeds the gate policy (subsystem 7). It does not pick the team.

**4. Plan drafting — lives inside the existing two-phase lifecycle**

No new machinery here. Evelynn delegates to an Opus per the existing rules. The Opus writes a rough plan using the `draft-plan` skill (from plan-lifecycle-protocol-v2), commits to `plans/proposed/` on main. Event emitted: `plan.rough.drafted`.

Gate (Duong or auto — see subsystem 7) moves it to `plans/approved/`. Event: `plan.rough.approved`. Evelynn delegates the detailed phase. Opus writes detailed spec via `detailed-plan` skill, promotes to `plans/ready/`. Event: `plan.detailed.ready`.

The **key integration point** is that the existing plan-lifecycle protocol already handles this, *unchanged*. This pipeline just watches the filesystem transitions and emits events accordingly. No new drafting surface.

**5. Execution — Sonnet executor on a per-issue worktree**

Input: a `plan.detailed.ready` event. Output: a PR against myapps' main branch, tagged with the issue number, authored by the Sonnet executor, committed via `scripts/safe-checkout.sh` (Rule 5).

Concurrency discipline:

- Each issue gets its own worktree under a standard path (e.g., `worktrees/issue-<N>/`). Branch naming: `auto/issue-<N>-<slug>`.
- A global concurrency cap (recommended **2 simultaneous active issues** on the Windows box for MVP, bumpable after measuring token burn and CPU load). Issues beyond the cap queue in the bus and wait for a slot.
- PR conflicts between concurrent issues are allowed to happen naturally — if issue-42 merges first and issue-43 conflicts, the executor rebases via merge (Rule: never rebase) and re-runs. If it can't auto-resolve, the PR is marked `pipeline/conflict` and escalated back to Evelynn, who may delegate to a fullstack agent for manual resolution.

PR opened -> event `pr.opened`.

**6. Review, Preview, and Feedback — the test loop**

Input: `pr.opened`. Output: a Discord message with a preview URL, and either `approval.granted` or `approval.rejected` after Duong's reply.

Three things happen in parallel once a PR is open:

**Reviewer agents.** Lissandra and Rek'Sai are the existing PR reviewers. They review the PR, post review comments, and emit `pr.reviewed.pass` or `pr.reviewed.fail`. On fail, the executor is re-invoked with the review comments as context and tries again; if it fails twice, escalate to Evelynn. On pass, the preview pipeline proceeds.

**Preview environment.** The build-and-host approach depends on myapps' stack (pending snapshot). Three shapes in order of preference:

- **(a) Firebase Hosting preview channels.** If myapps is Firebase-hosted (high likelihood per prior memory), this is free, native, purpose-built for per-PR previews, already gets a signed URL, and Firebase handles hosting + TLS. **Recommended default if myapps is Firebase.** The URL itself is the Firebase-provided preview channel URL; no separate tunnel needed. The pipeline does not need to touch `cloudflared` for previews at all if this path works.
- **(b) Local dev server on the Windows box + `cloudflared` ephemeral tunnel (`*.trycloudflare.com`).** No Firebase needed, works for any stack that can serve on localhost. Tunnel is per-PR, spawned on PR open, killed on PR close or preview timeout. Ephemeral hostnames are fine for this since the URL only needs to live for the duration of Duong's test session.
- **(c) Per-PR Docker container on the VPS.** Heaviest. Reserve for stacks Firebase can't serve and where localhost-on-Windows is too fragile.

Whichever path is picked, the preview subsystem emits `preview.up` with the URL, or `preview.failed` with an error.

**Discord notification and approval listener.** On `preview.up`, the relay bot posts a threaded message in the intake channel tagged to the original issue: "Issue #N ready to test: <url>. Reply `approved` or `reject: <reason>`." The bot listens for the next message from Duong in that thread. Parses verdict, emits `approval.granted` or `approval.rejected`.

Approval timeout: if no reply within T (default 24 hours, configurable), the pipeline pauses the issue in an `awaiting-approval` state, preview is torn down to save resources, and Evelynn is pinged. Duong can still approve later; the preview is just re-spun on demand.

Rejection: the reject reason is written as a comment on the GitHub issue, the issue is reopened (or stays open with a `needs-rework` label), and the loop re-enters at subsystem 4 (new rough plan is usually not needed; a new detailed-plan revision is). The reviewer layer may or may not re-run depending on how deep the rework is — detailed phase decides.

**Preview auth.** The preview URL leaks are a real risk. Two options:

- **(a)** Firebase preview channels support basic auth or IAP-equivalent controls — use those if available.
- **(b)** Cloudflare Tunnel previews can sit behind Cloudflare Access with a 24h JWT — same identity provider as the cafe path if that plan lands first.
- **(c)** Signed-URL token in the path. Weak but simple.

Recommendation: whichever auth story is native to the chosen preview substrate. Don't build a custom auth layer for previews.

**7. Gate policy — who approves what, and when**

This is the most load-bearing design choice in the plan. The pipeline has three natural gates:

- **G1: rough plan approval.** `plans/proposed/` -> `plans/approved/`. Today: manual file move by Duong.
- **G2: code PR approval.** Post-preview, pre-merge. Duong's "approved" reply in Discord.
- **G3: production deploy approval.** Post-merge, pre-push-live. Can be the same as G2 or separate.

Per Duong's autonomy ask ("escalate only on critical decisions"), not all three gates should always require a human. A sensible policy, keyed off the classifier's `risk` verdict:

| Risk | G1 (rough plan) | G2 (preview approve) | G3 (deploy) |
|---|---|---|---|
| low | auto-approve after N minutes idle | manual (Discord) | auto on G2 |
| medium | manual | manual | auto on G2 |
| high | manual | manual | manual, separate Discord reply |

"Auto-approve G1 after N minutes idle" means: if nobody (Duong, Evelynn, another Opus) has objected in Discord within a grace window, the pipeline moves the rough plan to `approved/` itself. This is controversial; alternative is to keep G1 always-manual and accept slower low-risk issues. Open question for Duong below.

Gate expression in Discord: approval is a Discord reply in the threaded issue conversation, not a file move. For G1 specifically, "approval" can also happen by Duong typing `approve rough <issue>` or reacting with a designated emoji. The relay bot translates the reaction or reply into the actual `plan-promote.sh` call or file move server-side. **Duong never opens a terminal.**

Kill switch: a message `killswitch` (or a specific emoji on the pipeline status message) emits `pipeline.killswitch`. Every worker checks for this event on each iteration and exits cleanly. All in-flight worktrees are left in place (not auto-deleted) for post-mortem. Only Duong or Evelynn can clear the killswitch.

---

## Rough shape / components

1. **Intake extension to the discord-relay bot** — parse intake messages, call GitHub API to file issues with labels, emit `issue.created` on the bus. New module in `apps/discord-relay/`. Depends on the discord-cli-integration plan being implemented first, OR this pipeline shipping a minimal relay itself if that plan stalls.
2. **Event bus substrate** — filesystem queue on the VPS + GitHub-labels state of record. No new service, just conventions and a small library that workers import.
3. **Classifier** — a single Claude Haiku prompt, stateless, invoked per issue, outputs JSON. Probably implemented as a Claude skill or a tiny wrapper script the dispatcher calls.
4. **Dispatcher loop** — a long-running watcher (probably on the VPS, calling into the Windows box via the cafe-from-home tunnel if that plan lands, or running directly on Windows if not). Reads events, invokes Evelynn appropriately.
5. **Per-issue worktree convention** — naming, lifecycle, cleanup. Extends `scripts/safe-checkout.sh`. Concurrency cap enforced by a simple counter file or lock directory.
6. **Preview builder** — per-stack, pluggable. MVP assumes Firebase and implements the Firebase preview channel path. Other stacks are later work.
7. **Tunnel manager** — only needed if preview builder isn't using Firebase previews. Spawns `cloudflared` per PR, tracks URL, kills on PR close. Independent of the cafe-from-home long-lived tunnel.
8. **Approval listener** — part of the relay bot, not a new service. Translates Discord replies and reactions into bus events.
9. **Gate policy module** — a small config file (YAML/JSON) the dispatcher reads, plus runtime checks against classifier output. Designed to be tunable without code changes.
10. **Kill switch** — a special event type all workers check. Extremely simple to implement; hardest part is the discipline of *every* worker actually checking it.
11. **Deploy driver** — whatever `firebase deploy --only hosting --token $FIREBASE_TOKEN` or equivalent looks like for myapps. Called on `approval.granted` for low/medium risk, or on explicit G3 for high risk. Token fetched via `tools/decrypt.sh`. Emits `deploy.succeeded` or `deploy.failed` back to Discord.
12. **Abuse/rate-limiting** — intake-channel allowlist (MVP: Duong-only), bot-side rate limit on issues per hour, and a cost budget circuit breaker (see failure modes below).
13. **CLAUDE.md additions** — new rule or paragraph documenting the pipeline's existence so agents picked up by it know what shape they're in. Minor.
14. **Integration with Evelynn's continuity work** — Zilean + the session condenser + the Scheduled Task restart path from `evelynn-continuity-and-purity.md` are load-bearing here because the dispatcher has to survive Evelynn restarts gracefully. The dispatcher's state must be in git (issues) or on disk (bus events), not in Evelynn's conversation memory.

---

## MVP — smallest end-to-end slice

The smallest version that delivers real value:

**MVP scope.**
- Intake: Discord message -> GitHub issue. Manual labels only (no classifier yet).
- One issue at a time. Concurrency cap = 1.
- Gate policy: **every gate manual.** G1 = Duong moves file. G2 = Duong "approved" reply in Discord. G3 = same as G2 (no separate production gate for MVP).
- Preview: Firebase preview channel if myapps is Firebase; otherwise single `cloudflared` ephemeral tunnel pointing at a local dev server on Windows. No auth on preview URL beyond the URL being unguessable.
- No classifier, no auto-approval, no reviewer-retry loop. Reviewer agents still run; on fail, the PR is flagged and the pipeline pauses pending Evelynn.
- Deploy: manual button, i.e., Duong types `deploy` in Discord after merge. This is still "autonomous" from Duong's phone — he never opens a terminal — but keeps the production push human-gated while the stack is young.
- Kill switch: implemented from day one. Non-negotiable.
- No abuse protection beyond "intake channel is Duong-only."

**What MVP does not include:**
- Classifier / auto-approve low-risk.
- Multi-issue concurrency.
- Reviewer-retry loop.
- Auto-deploy to prod on approval.
- Fancy preview auth.
- Multi-stack preview builder (Firebase only).
- Multiple agent teams running in parallel.

**Why this slice.** It exercises every subsystem at the thinnest possible layer: intake, bus, dispatcher, worktree, executor, reviewer, preview, approval, deploy. Duong feels the full loop from his phone on the first real issue. Every gap is a knob to widen later, not a missing subsystem to build from scratch. The concurrency cap of 1 means all the nastiest bugs (worktree collision, PR conflict, bus state divergence under load) are postponed until the single-issue loop is actually stable.

**Phased ramp after MVP.**
- Phase 2: classifier + auto-approve G1 for low-risk + auto-deploy on G2 for low/medium risk.
- Phase 3: concurrency cap to 2, then measured ramp.
- Phase 4: reviewer-retry loop, abuse protection, multi-stack preview support.
- Phase 5: secondary stacks beyond myapps, if the model earns its keep.

---

## Open questions for Duong

These are the ones where Duong's preference genuinely shifts the design, not the ones where Evelynn can pick a sensible default.

1. **Auto-approve G1 for low-risk issues — yes or no?** This is the single biggest autonomy knob in the design. "Yes" removes Duong from the planning-phase gate for typos, small CSS fixes, copy changes, etc., and lets the pipeline actually run hands-off. "No" keeps Duong in the loop on every single plan, which means the pipeline is mostly a ticket queue with nice automation. Recommendation: yes for `type/bug` + `risk:low` + `scope:single-file` only, with N=15 minute idle window. Your call — this is the whole autonomy story.
2. **Autonomous production deploy on approval — yes or no, and with what safety net?** Once Duong says `approved` in Discord, should the pipeline merge and deploy straight to prod? Firebase Hosting has instant rollback, which makes "deploy aggressively, roll back if it breaks" defensible. Recommendation: yes for low/medium risk, with a 30-second `/undo` window in Discord and a rollback path that's a single Discord reply. High-risk issues get a separate G3 approval. Your call — this is the second-biggest autonomy knob.
3. **Which subsystems live on the VPS vs Windows?** Intake and relay are obviously VPS (long-running, public-internet-facing). Agent workers are obviously Windows (where Claude Code, MCP, worktrees, secrets live). But the dispatcher, event bus, and classifier could live on either. Recommendation: **dispatcher + bus on the VPS, classifier on the VPS** (single small Haiku call), **agent execution on Windows**. This means the VPS needs to be able to *trigger* work on Windows, which requires the cafe-from-home transport (or a simpler VPS-to-Windows command channel) to exist first. **Hard dependency question:** does this pipeline ship *after* cafe-from-home, or does it ship with its own minimal VPS-to-Windows channel (e.g., a file the VPS writes to a git repo that a Windows watcher polls)?
4. **Preview auth tolerance.** Are you okay with unguessable-URL-only protection for preview environments in MVP? The alternative is Cloudflare Access in front of every preview, which requires the cafe-from-home plan to land first and adds a login step every time you click a preview link from Discord. Recommendation: unguessable URL only for MVP, tighten in Phase 2.
5. **Cost budget circuit breaker.** The failure mode "agent loop spews PRs and burns tokens" is real. What's the dollar cap at which the pipeline automatically halts and pings you? Recommendation: a daily cap (say $20/day for the agent layer) that, when crossed, auto-killswitches the pipeline. Your call on the number.
6. **myapps stack snapshot.** The `assessments/2026-04-08-myapps-snapshot.md` file was supposed to land before this plan. It did not. Detailed phase is blocked on that snapshot for the preview subsystem specifically. Should Evelynn delegate a snapshot pass to Yuumi now, or wait for the parallel explore task to finish?
7. **Agent team shape — per-issue spawn vs. standing pool.** I recommended "standing Evelynn delegates per-issue to existing agents" for MVP. The alternative, "spawn a fresh Opus+Sonnet+reviewer team per issue and kill on close," has cleaner state isolation but 5-10x the token cost per issue because every team re-primes from profile. Confirm the recommendation or push back.
8. **Is the intake channel multi-user later, or always Duong-only?** MVP is Duong-only. Phase 2+ could accept issues from trusted contributors (role-gated Discord users). That changes the classifier (can't fully trust inputs anymore) and the gate policy (can't auto-approve from untrusted intake). Confirm the long-term direction so the classifier and gate modules are designed for it from the start rather than retrofitted.

---

## Duong Decisions — 2026-04-08 cafe session

Duong answered four of the open questions directly and one is absorbed by Evelynn. Detailed phase must reflect these decisions.

- **Q1 — Auto-approve planning gate → YES, label-gated.** Duong explicit: "It should be auto-approved. Or have a tag with auto-able, something like that." Introduce a GitHub label (exact name is detail-phase — candidates: `auto-ok`, `autonomous`, `auto:safe`) that marks an issue as eligible for autonomous pickup end-to-end. Unlabeled issues still go through manual planning gates. The label can be applied manually by Duong on the issue, or automatically by a classifier on intake (detail-phase decides which).
- **Q2 — Deploy pipeline shape → full canary with auto-rollback.** Duong explicit spec:
  1. Merge PR → deploy to staging
  2. Run full test suite on staging
  3. If staging green → deploy to production
  4. Run production smoke tests
  5. If production tests green → mark task complete and notify Discord
  6. **At any step, if anything fails → revert immediately** (automatic rollback of the failing environment, no human in the loop for the revert itself)

  This replaces the earlier "merge + deploy" simplification. Detail phase must specify: what "all tests" means on staging (Playwright E2E? unit? both?), what "production smoke tests" means (subset of E2E hitting the live URL? synthetic health checks?), and the exact rollback mechanism per environment (Firebase Hosting rollback via `firebase hosting:rollback`, Firestore rollback via... what? flag for open question).
- **Q3 — Control plane location → GCP.** Duong explicit: "have everything on Google infrastructure." Control plane runs on GCP (Cloud Run / Cloud Functions / Cloud Build — detail phase picks the specific services). VPS option rejected. Windows-only option rejected. See Q5 for how this interacts with agent execution.
- **Q5 — Billing → subscription plan only, never Claude API.** Duong explicit: "everything should run on the subscription plan, no API for claude." Agent work runs through Claude Code CLI against his Team plan seats, never via API keys. Dollar-cap circuit breaker is therefore not the right primitive — the constraint is a hard "no API calls" rule enforced at the agent-spawn layer. Detail phase must design a preflight check that blocks any agent that would call an Anthropic API endpoint.

  **Tension with Q3 flagged and absorbed by Evelynn:** "Everything on GCP" + "subscription-only" creates a structural conflict — subscription-plan Claude runs via the `claude` CLI which requires a machine logged into an Anthropic seat. Evelynn's absorbed resolution: **control plane on GCP, agent execution on the Windows box for MVP, burst to a GCE VM (counting as an additional seat on the Team plan) later if parallelism becomes the bottleneck.** Resolved 2026-04-08 by Duong — see the dual-mode runtime bullet below.
- **Agent runtime → dual-mode local + GCE VM.** Duong clarified the subscription-vs-GCP tension directly: "I would normally have a machine running the CLI, but we also need a cloud option for auto. When I go to sleep and I close the machine or something like that, we need to have a cloud machine that can run the CLI, and of course it would be on Google." Concrete shape:
  - **Local mode (interactive):** Windows or Mac box runs Claude Code CLI during active hours. Primary when Duong is at it.
  - **Cloud mode (autonomous):** Always-on GCE VM on GCP, running Claude Code CLI, authenticated to the Team plan under `harukainguyen1411` (per the main-account directive). Primary for label-gated autonomous work. Takes over when the local box is asleep/closed/offline.
  - **One extra Team-plan seat** for the GCE VM is budgeted as unavoidable; the alternative (pipeline halting overnight) defeats the purpose.
  - **Primary/secondary arbitration:** cloud VM is always primary for autonomous pipeline work. Local box is primary for interactive work Duong initiates. Both must respect the filesystem-event-bus + GitHub-label state-of-record so they don't double-pick the same issue.
  - **MVP VM shape:** always-on, small instance (e2-small class), with cost revisit if it becomes painful. Scheduled start-stop is phase 2+.
  - **Bootstrap:** `claude login` run once interactively with harukainguyen1411 credentials. Detailed phase must spec the exact provisioning flow.
  - Also update the tension note below: the tension is now **resolved** — control plane on GCP Cloud Run/Functions, agent execution on GCE VM (cloud) + local box (interactive), both subscription-backed.
- **Q4 — Preview auth → absorbed by Evelynn.** Unguessable tunnel URL only for MVP; revisit if the Discord channel ever has non-Duong members.
- **Q6 — myapps snapshot → resolved.** Snapshot exists at `assessments/2026-04-08-myapps-snapshot.md`. Note caveat: snapshot incorrectly claimed myapps lives in `apps/myapps/` inside strawberry. Actual source of truth is standalone `github.com/Duongntd/myapps`; the strawberry copy is a divergent duplicate that needs its own investigation plan (out of scope here).
- **Q7 — standing Evelynn vs per-issue team → absorbed by Evelynn.** Standing-Evelynn for MVP per Syndra's cost recommendation. Revisit if state coupling to Evelynn's restart story becomes painful.
- **Q8 — multi-user intake → absorbed by Evelynn.** Deferred to phase 2+.

## Rollback / failure-mode sketch

**Failure modes the design must survive:**

- **Agent loops / runaway token burn.** Mitigation: cost budget circuit breaker (open question 5), kill switch reachable from Discord, and a hard per-issue token cap (no single issue allowed to consume more than X tokens across all its planning + execution + review; if exceeded, the issue is auto-escalated to Evelynn with a `budget-exceeded` label and paused). Classic halting problem — we can't detect a loop in general, but we can bound total spend per unit of work.
- **PR flood / duplicate issues.** Rate limit at the intake layer. Dedupe: if an `issue.created` comes in with a title that fuzzy-matches an open issue, comment on the existing issue instead of filing a new one. Heuristic, imperfect, good enough for MVP.
- **Preview environment stuck up forever.** Every preview has a TTL (recommend 6 hours default). After TTL, the preview is torn down, regardless of approval state. Re-approvable on demand.
- **Approval listener misparses.** The approval parser is strict: exact words `approved` or `reject: <reason>`, case-insensitive. Anything ambiguous is replied to with a clarification request, not silently misinterpreted.
- **Deploy fails halfway.** Deploy driver must be idempotent and emit `deploy.failed` with the error. Pipeline pings Duong in Discord with the error text and the rollback instructions. No automatic retry without explicit Duong reply.
- **Event bus state divergence.** GitHub labels are the source of truth. On worker startup, rebuild filesystem bus state by polling GitHub. Filesystem state is a cache, not the truth.
- **The Windows box reboots / crashes mid-issue.** Evelynn's continuity work (`evelynn-continuity-and-purity.md`) handles Evelynn's restart; the pipeline's concern is that worktrees are left on disk and the dispatcher can resume by reading the event bus + GitHub state on restart. No in-memory state that isn't also on disk or in git.
- **Dispatcher crashes while an agent is mid-execution.** The agent has its own claude-code process and finishes the work independently. Dispatcher reconciles on restart by reading the PR state from GitHub.
- **Secret leaks into preview URL or Discord message.** The intake-to-issue path sanitizes user input (per discord-cli-integration's sanitization rules). Preview URLs should never embed secrets — the tunnel auth and Firebase token stay on the server side. CI/CD tokens for deploy live in encrypted secrets; the pipeline reads them via `tools/decrypt.sh` at call time and never logs them.

**Rollback of the pipeline itself:**

Everything is additive. Rollback means stopping the dispatcher process, disabling the intake path on the relay bot, and leaving any in-flight worktrees / PRs in place for manual resolution. No data is destroyed. The plan-lifecycle protocol and the existing agent pool are unaffected — they just lose the Discord-driven intake and return to Evelynn-driven intake. One-afternoon rollback, recoverable state.

---

## Cross-references

- `plans/proposed/2026-04-03-discord-cli-integration.md` — the relay bot and event-file pattern this pipeline extends. If implemented first, this pipeline is a sibling app on the same infra.
- `plans/proposed/2026-04-08-cafe-from-home.md` — the tunnel transport underneath the dispatcher's VPS-to-Windows channel, and potentially the auth layer in front of preview URLs. Cross-references the Cloudflare Tunnel architecture; this pipeline can reuse that account.
- `plans/proposed/2026-04-08-plan-lifecycle-protocol-v2.md` — the two-phase planning lifecycle every issue passes through. This pipeline assumes v2 is in force and the new skills exist.
- `plans/proposed/2026-04-08-evelynn-continuity-and-purity.md` — Evelynn restart / Zilean / session-condenser mechanics that make the dispatcher resilient across Evelynn restarts. Load-bearing for reliability.
- `plans/approved/2026-04-08-skills-integration.md` — the skill-preload mechanism the classifier and draft/detailed skills rely on.
- `plans/approved/2026-04-08-minion-layer-expansion.md` — Yuumi (reads) and Poppy (mechanical edits) in the agent pool the dispatcher composes from.
- `plans/approved/2026-04-05-myapps-task-list.md` — the existing task list for myapps. This pipeline's first real issues will likely come from that list.

---

## Out of scope

- Anything specific to myapps' framework, build command, or deploy target. Detailed phase reads the snapshot.
- The cafe-from-home tunnel itself. That's a separate plan; this one consumes its output if available.
- Multi-project pipelines. MVP is myapps only. Adding a second repo later is deliberate future work.
- Agent identity for the intake channel (i.e., inviting contributors beyond Duong). Phase 2+ consideration.
- Custom preview-auth layer. Use whatever the preview substrate provides natively.
- Reviewer-retry loop, PR conflict auto-resolution, and similar "make it really smart" features beyond MVP.
- Production-deploy rollback automation beyond "one Discord reply triggers the provider's native rollback."
- Implementation of any of the above. This rough plan names the shape; the detailed phase specs it.
