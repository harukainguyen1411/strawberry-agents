---
date: 2026-04-17
author: azir
type: architectural-review
subjects:
  - PR #120 (Jayce, P1.0 deploy script audit)
  - PR #121 (Viktor, P1.1 rename + composite-deploy deprecation comment)
adr: plans/in-progress/2026-04-17-deployment-pipeline.md
audit: assessments/2026-04-17-deploy-script-audit.md
---

# Architectural Review — PRs #120 and #121

Retroactive architectural-alignment pass against the deployment pipeline ADR. Scope: does the merged work honor the ADR's intent? Code-correctness is Jhin's pass; this note is strictly ADR-vs-reality drift.

Severity legend:
- **ADR-amendment-required** — ADR and reality disagree; text must change.
- **minor-clarification** — ADR is usable as-is but a sentence or cross-reference would remove ambiguity for the next reader.
- **clean** — alignment holds.

---

## Q1. Does Jayce's audit (PR #120) surface findings that silently invalidate the ADR?

**Verdict: mostly clean, one minor-clarification, one ADR-amendment-required.**

### F1.1 `composite-deploy.sh` retirement — ADR Phase-2 end-state is unspecified. **(ADR-amendment-required)**

The ADR §1 non-goals explicitly exclude Vite/Hosting web-surface assembly. The audit (§2) confirms `scripts/composite-deploy.sh` is a Vite dist-assembler and is actively invoked by `.github/workflows/release.yml:60` and `.github/workflows/preview.yml:43`. Viktor's deprecation comment buys transitional cover (see Q3), but the ADR never states what happens to the Vite-assembly logic after `release.yml`/`preview.yml` are rewritten in Phase 2. Two silent unknowns:

1. Does Phase-2 `release.yml` keep invoking `composite-deploy.sh`, or does Phase 2 drop the Hosting surface from the release workflow entirely (deferring Hosting to the future web-surface ADR)?
2. If Hosting stays in Phase-2 `release.yml`, the ADR §4 script layout does not allocate a slot for Vite assembly. `scripts/deploy/` is Firebase-surface-shaped; there's no `scripts/build/` or `scripts/assemble/`, and §4 is silent on where non-Firebase build steps live inside the new tree.

The audit (§3) resolves the *near-term* disposition correctly (dormant, commented). It does not resolve the Phase-2 end-state, because that's ADR territory. Without an amendment, Kayn's Phase-2 breakdown will hit this gap when wiring `release.yml`.

**Proposed ADR amendment — append to §4 "Interaction with existing scripts" paragraph, after the sentence ending "…decide during breakdown whether to delete it or carry it forward for a future web-surface addition.":**

> Phase-2 policy for `composite-deploy.sh`: the script stays dormant and carries Viktor's deprecation comment through Phase 2. Phase-2 `release.yml` and `preview.yml` rewrites MUST NOT take a dependency on `composite-deploy.sh`; if those workflows still need Hosting deploys after the Phase-2 rewrite, they continue to call the existing `composite-deploy.sh` **unchanged** and the Hosting surface remains outside the new `scripts/deploy/` tree until the separate web-surface ADR (seam reserved in §1) lands. The new pipeline does not absorb Vite assembly — attempting to do so violates §1 non-goals.

**Proposed ADR amendment — add to §1 non-goals / seams list:**

> - Vite / Firebase Hosting assembly and deploy. Continues via the existing `scripts/composite-deploy.sh` + `release.yml`/`preview.yml` path until a dedicated web-surface ADR supersedes it. This pipeline does not touch the Hosting surface.

### F1.2 Audit §4 path discrepancy — already absorbed via Kayn's `de51b1f`. **(clean)**

Audit §4 flagged `apps/functions/` vs `apps/myapps/functions/` and absence of a `firebase.json` governing Functions. Kayn's `de51b1f` amendment:
- Rewrites ADR path refs to `apps/myapps/functions/`.
- Amends §1a.3 to say "one `firebase.json` per Firebase project" (not per surface) and locates it at `apps/myapps/firebase.json`.
- Adds §4 `cd` + `trap` rule for running the Firebase CLI from `apps/myapps/`.
- Adds P1.1b (Viktor relocates source) and P1.1c (amend `firebase.json` to declare all four surfaces).

Verified against the ADR as it stands on `main`: §1 bullet 1, §1a.3, §1a.5, §3 emulator note, §4 `dl_cd_firebase_root`, §4 precondition 6, and §6 `include-paths` all reflect Option 3. Clean.

### F1.3 `apps/functions/package.json` name `darkstrawberry-functions` vs ADR package name `bee`. **(minor-clarification)**

Audit §4 notes the package in `apps/functions/package.json` is named `darkstrawberry-functions`. ADR §6 "First app" reserves the release-please package name as `bee` with tag format `bee-v1.2.3`. These don't have to match (release-please package names are release-please config, not npm `name`), but the ADR never says that, and a future reader will expect them to line up.

**Proposed ADR amendment — append to §6 "First app" bullet (after "Tag format `bee-v1.2.3`."):**

> The release-please package name `bee` is independent of the npm `name` field in `apps/myapps/functions/package.json` (currently `darkstrawberry-functions`). release-please `include-paths` + `package-name` in the manifest are the binding; npm `name` is not renamed by this ADR.

### F1.4 Audit §1 catalog of `scripts/deploy.sh` callers. **(clean)**

All five callers listed are documentation or archived inbox entries. No active runtime caller broken by Viktor's rename. The ADR's reservation of `scripts/deploy.sh` for the new dispatcher (§4) is safe.

---

## Q2. Does Viktor's rename (PR #121) honor §1a and §4?

**Verdict: clean on §1a, minor-clarification on §4 / Rule 10.**

### F2.1 The path `scripts/deploy.sh` is freed cleanly. **(clean)**

ADR §4 reserves `scripts/deploy.sh` as the new canonical dispatcher. PR #121 renames the existing Discord-relay script to `scripts/deploy-discord-relay-vps.sh`. The slot is free. Rename preserves git history (`similarity index 100%`). `architecture/infrastructure.md:66` was updated to the new name in the same diff.

### F2.2 `scripts/deploy-discord-relay-vps.sh` at top level — Rule 10 POSIX-portability concern. **(minor-clarification)**

The question raised: VPS-specific logic in top-level `scripts/` where Rule 10 mandates POSIX-portable (mac + Git Bash on Windows) scripts.

Analysis: Rule 10 mandates that scripts under `scripts/` (outside `scripts/mac/` / `scripts/windows/`) must be **runnable** on both platforms. It does not prohibit scripts that target a Linux VPS from living at top level, as long as the script itself is POSIX-bash-portable. The script body is `git pull`, `npm install`, `pm2 start`, `pm2 save` — all POSIX-bash. The fact that the `runner` user, `/home/runner/data/`, and PM2 only exist on the Hetzner VPS is an *environment* constraint, not a *script syntax* constraint. The script parses and runs the same on macOS; it just fails because the VPS env isn't present. That's fine under Rule 10 as written.

So it is not a violation. **But** the ADR is silent on where VPS-deploy scripts "belong" in the tree, and the existence of `scripts/deploy-discord-relay-vps.sh` at the same level as the future `scripts/deploy.sh` Firebase dispatcher invites confusion. The ADR §4 script layout diagram does not include VPS scripts at all; the reader won't know whether the Discord-relay script is inside or outside the pipeline's scope.

**Proposed ADR amendment — append to §4 script-layout diagram (as a comment under the tree or as a trailing note):**

> Note: `scripts/deploy-discord-relay-vps.sh` (the Hetzner-VPS Discord-relay PM2 restart script, renamed in P1.1 from the previous `scripts/deploy.sh`) is **outside** this pipeline. It deploys the Discord-relay VPS, not a Firebase surface, and does not participate in the test gate / audit log / smoke test contract. A future reorg may move it under `scripts/vps/` — not required now.

This is a clarification, not a rule change. No task rework needed.

### F2.3 The rename does not conflict with any future-intended script path. **(clean)**

The ADR §4 tree reserves: `scripts/deploy.sh`, `scripts/deploy/_lib.sh`, `scripts/deploy/project.sh`, `scripts/deploy/functions.sh`, `scripts/deploy/storage-rules.sh`, `scripts/deploy/smoke.sh`, `scripts/deploy/revert.sh`, `scripts/test-functions.sh`, `scripts/test-storage-rules.sh`, `scripts/test-all.sh`. `scripts/deploy-discord-relay-vps.sh` collides with none.

### F2.4 Deprecation comment on `composite-deploy.sh`. **(clean)**

The comment added at line 2: `# DEPRECATED: kept for .github/workflows/{release,preview}.yml; superseded by scripts/deploy/*.sh per plans/in-progress/2026-04-17-deployment-pipeline.md §4.` is factually correct against ADR §1 non-goals, §4 layout, and the audit §3 disposition. It does not change behavior. Active CI callers (`release.yml:60`, `preview.yml:43`, `package.json:17`) still invoke it. No breakage.

One nit (not a finding, not blocking): the comment points to `scripts/deploy/*.sh` as the superseder, but `composite-deploy.sh` is Vite/Hosting assembly, and per F1.1 the new `scripts/deploy/` tree does **not** supersede Hosting assembly at all — it ignores it. The comment is slightly wrong in the direction of making `scripts/deploy/*.sh` sound broader than it is. Optional: Viktor can adjust in a follow-up to `superseded for Firebase-surface deploys by scripts/deploy/*.sh; Hosting-surface disposition deferred to a future web-surface ADR`. Not worth a PR on its own.

---

## Q3. Is the dormant-with-deprecation-comment approach architecturally correct?

**Verdict: correct for Phase 1; ADR-amendment-required to make the Phase-2 end-state explicit.**

The deprecation-comment approach is the right call in isolation:
- ADR §1 non-goals exclude the Vite/Hosting surface.
- The ADR §4 layout does not allocate a slot for Vite assembly.
- Deleting `composite-deploy.sh` now would break `release.yml` and `preview.yml` immediately.
- Leaving it dormant with an in-code pointer to the ADR preserves the escape hatch and is cheap.

**The gap** (already covered under F1.1): the ADR assumes Phase-2 workflow rewrites for `release.yml` / `preview.yml` without specifying whether those rewrites inherit, drop, or rewire the `composite-deploy.sh` dependency. Without the F1.1 amendment, Kayn's Phase-2 breakdown must make that call implicitly, which is exactly the kind of silent scope-creep this ADR exists to prevent.

The proposed F1.1 amendment resolves the question by writing "don't touch Hosting in Phase 2; keep calling `composite-deploy.sh` unchanged; Hosting migration needs its own ADR" into the plan. That preserves Phase 2's tight scope (Firebase Functions + Storage rules + release-please + staging + auto-revert) and keeps the Hosting surface out until someone writes the web-surface ADR.

---

## Q4. Other ADR-vs-reality drift from PR #120 / #121 diffs.

### F4.1 Audit §5 recommendation "Viktor should also update `architecture/infrastructure.md`" — done correctly. **(clean)**

PR #121 diff updates the exact line the audit called out (`architecture/infrastructure.md:66`).

### F4.2 `apps/myapps/functions/` does not yet exist on `main`; P1.1b is still open. **(informational — not a finding)**

PR #121 renamed `scripts/deploy.sh` but did not relocate Functions source (that is P1.1b's scope per `de51b1f`). The ADR paths referencing `apps/myapps/functions/` will only be true-to-filesystem after P1.1b merges. This is expected sequencing — flagging only so that Kayn/Jhin don't mistake it for drift.

### F4.3 Audit §5 row 3 says "Add comment at `scripts/composite-deploy.sh` line 2". **(clean)**

PR #121 added the comment at line 2, preserving the shebang on line 1. Structurally correct.

### F4.4 ADR §4 precondition 5 ("Bare `firebase deploy` fails a static grep check"). **(informational — not a finding, flag for Kayn/Jhin)**

The audit §2 notes `composite-deploy.sh` prints `To deploy: npx firebase-tools deploy --only hosting` as a string literal (not an invocation). If the `_lib.sh` static grep check for bare `firebase deploy` is implemented naively (e.g., `grep -r "firebase deploy"` across `scripts/`), the literal string inside `composite-deploy.sh` will false-positive. Kayn's P1.2 `_lib.sh` work needs to scope the grep either to `scripts/deploy/` only, or to real invocations (whitespace-boundary + shell-context). Not an ADR change — a breakdown note.

### F4.5 Task file `plans/in-progress/2026-04-17-deployment-pipeline-tasks.md` cross-reference in `de51b1f`. **(clean)**

Spot-checked: `de51b1f` claims Tasks P1.4, P1.8, P1.9, P1.12, P2.15, P2.16 were rewired onto P1.1b/P1.1c. That's a task-file concern, out of scope for this architectural review (Kayn's responsibility), but the ADR cross-references are consistent.

---

## Summary — required changes

| ID | Severity | What |
|----|----------|------|
| F1.1 | **ADR-amendment-required** | Add Phase-2 end-state for `composite-deploy.sh`: stays dormant, Phase-2 workflow rewrites do not absorb Vite assembly, Hosting migration is a separate future ADR. Amend §4 "Interaction with existing scripts" and add a bullet to §1 non-goals/seams. Verbatim amendment text in F1.1 above. |
| F1.3 | **minor-clarification** | Add to §6 "First app" that release-please package name `bee` is independent of npm `name` (`darkstrawberry-functions`). Verbatim in F1.3. |
| F2.2 | **minor-clarification** | Add a note to §4 script-layout diagram that `scripts/deploy-discord-relay-vps.sh` is outside the pipeline scope. Verbatim in F2.2. |

All three amendments are pure-documentation; no task rework implied. F1.1 is the only one that would change Kayn's Phase-2 breakdown if left unamended, because it removes an ambiguous decision from Kayn's plate.

No code changes required in PR #120 or PR #121. Both are architecturally aligned once the three ADR amendments above land.

---

## Handoff

- **To Kayn:** absorb F1.1 / F1.3 / F2.2 amendments into the ADR via a `chore:` commit directly to `main` (Rule 4). Amendments are verbatim-ready above.
- **To Jhin:** F4.4 is a breakdown note for P1.2 `_lib.sh` — the bare-`firebase deploy` static grep must be scoped to avoid false-positive on `composite-deploy.sh`'s docstring. Not a code-correctness finding in the current PRs; flag for when P1.2 lands.
- **To team-lead (Evelynn):** no rework of PR #120 or PR #121 needed. Both merged-as-is are ADR-compliant once the three text amendments land.
