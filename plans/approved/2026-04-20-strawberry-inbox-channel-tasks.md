---
status: approved
owner: aphelios
created: 2026-04-21
date: 2026-04-20
concern: personal
parent_adr: plans/approved/2026-04-20-strawberry-inbox-channel.md
orianna_gate_version: 2
tests_required: true
tags: [inbox, coordinator, hooks, monitor, tasks]
---

# Strawberry inbox watcher — Task Breakdown

Executable task list for
`plans/approved/2026-04-20-strawberry-inbox-channel.md`
(v3.1, Orianna-signed `sha256:d5979…:2026-04-21T03:59:37Z`).

Azir's ADR settles all six v3 gating questions (§10 v3 table). This
breakdown decomposes the approved design into **two commits on one
branch / one PR** — an xfail-test commit (Rakan) followed by an
implementation commit (Viktor) — honouring both the ADR's "single cut"
intent (§10 Q6) and Rule 12's TDD gate (xfail first).

## Scope boundary

This plan is **infrastructure-only**. Every file touched lives in
`~/Documents/Personal/strawberry-agents/` (this repo). **No
`apps/**` change**, so every commit uses `chore:` (CLAUDE.md Rule 5).
The deliverable makes the personal coordinator (Evelynn) observe the
inbox in real time and keeps the Sona-side wiring symmetric
(coordinator-identity resolution chain works for either agent out of
the same script).

## Duong-in-loop blockers

All v3 gating answers are decided (ADR §10 v3 table). **No Duong-blockers
remain**. The breakdown can start the moment this file lands on main.

Two soft assumptions the executors should verify on first read (not
blocking, but flag to Evelynn if either breaks):

| #            | Assumption                                                                                                   | Verify by                                                          |
|--------------|--------------------------------------------------------------------------------------------------------------|--------------------------------------------------------------------|
| A-inbox-1    | Claude Code ≥ v2.1.98 on this machine (Monitor tool available).                                              | `claude --version` against ADR §1 "What *is* available" bullet 1.  |
| A-inbox-2    | `fb1bd4f` is still reachable from main (for recovering `/check-inbox`). Confirmed at breakdown time: yes.   | `git cat-file -e fb1bd4f:.claude/skills/check-inbox/SKILL.md`.     |

## Team composition

| Role                   | Agent  | Scope                                                                    |
|------------------------|--------|--------------------------------------------------------------------------|
| Test implementer       | Rakan  | Task IW.0 — xfail harness under `scripts/hooks/tests/`.                  |
| Complex-track builder  | Viktor | Tasks IW.1 – IW.5 — watcher, bootstrap, skill recovery, settings wiring. |
| Reviewer A             | Senna  | PR review — architecture + hook wiring.                                  |
| Reviewer B             | Lucian | PR review — shell-script correctness + POSIX portability + test harness. |

No executor overlap. Rakan ships IW.0 and hands the branch off; Viktor
picks it up for IW.1 – IW.5 and opens the PR.

## Task summary

**6 tasks total** on a single feature branch. One PR, two commits at
minimum (xfail + impl); additional fixup commits are fine as long as
the xfail-first ordering is preserved (Rule 12).

| #     | Task                                                                      | Owner  | Commit slot | Depends on |
|-------|---------------------------------------------------------------------------|--------|-------------|------------|
| IW.0  | xfail harness — watcher, skill archive flow, retention, regression floor  | Rakan  | commit 1    | —          |
| IW.1  | `scripts/hooks/inbox-watch.sh` — watcher script (Phase 0/1/2 + oneshot)   | Viktor | commit 2    | IW.0       |
| IW.2  | `scripts/hooks/inbox-watch-bootstrap.sh` — SessionStart nudge emitter     | Viktor | commit 2    | IW.0       |
| IW.3  | `.claude/skills/check-inbox/SKILL.md` — recover from `fb1bd4f` + archive  | Viktor | commit 2    | IW.0       |
| IW.4  | `.claude/settings.json` — append SessionStart entry for bootstrap         | Viktor | commit 2    | IW.1–IW.3  |
| IW.5  | Flip `scripts/hooks/tests/inbox-watch-test.sh` green + regression grep    | Viktor | commit 2    | IW.1–IW.4  |

**Xfail-first ordering (Rule 12):** IW.0 MUST be the first commit on
the branch. IW.1 – IW.5 land in a second commit (or squash-amenable
series of fixups) that flips the harness green.

**Parallel window:** inside IW.1 – IW.5 the tasks are sequential by
dependency (watcher → bootstrap → skill → settings → green). No
intra-phase parallelism; a single Viktor session runs them in order.

## Branch, PR, commits

- **Branch name:** `inbox-watch-v3`
- **Created via:** `scripts/safe-checkout.sh inbox-watch-v3` (Rule 3 —
  never raw `git checkout`).
- **Base:** `main` at the SHA on which this breakdown is committed.
- **Commit prefix:** `chore:` on all commits (Rule 5 — no `apps/**`).
- **Do NOT** `--no-verify`, `--no-gpg-sign`, or skip hooks (Rule 14).
- **Do NOT** rebase (Rule 11) — if branch drifts behind main, merge.
- **PR target:** `harukainguyen1411/strawberry-agents` `main`
  (`gh pr create --base main --head inbox-watch-v3`).

### PR shell (for Viktor to paste, verbatim body)

```
gh pr create --base main --head inbox-watch-v3 \
  --title "chore: strawberry inbox watcher — Monitor-driven real-time inbox delivery" \
  --reviewer Duongntd \
  --body "$(cat <<'EOF'
## Summary
- Ship `scripts/hooks/inbox-watch.sh` — POSIX-portable Monitor target; Phase 0 archive cleanup, Phase 1 boot sweep, Phase 2 live watch (fswatch → inotifywait → 3 s poll).
- Ship `scripts/hooks/inbox-watch-bootstrap.sh` — SessionStart `additionalContext` nudge, resume/clear/compact short-circuit, `.no-inbox-watch` opt-out.
- Recover `.claude/skills/check-inbox/SKILL.md` from `fb1bd4f` and extend with archive-to-`inbox/archive/YYYY-MM/` semantics + `read_at` frontmatter.
- Append one `SessionStart` entry to `.claude/settings.json`.

Implements `plans/approved/2026-04-20-strawberry-inbox-channel.md`
(v3.1; Orianna signature `sha256:d5979…:2026-04-21T03:59:37Z`).

## Test plan
- [ ] `bash scripts/hooks/tests/inbox-watch-test.sh` exits 0 (watcher sweep + archive + retention + regression cases).
- [ ] Acceptance §5 items 1, 2, 3, 5, 11 pass against a live Evelynn session (manual; report → `assessments/qa-reports/2026-04-…-inbox-watch.md`).
- [ ] `grep -rn "strawberry-inbox" .claude/plugins` → no matches.
- [ ] `grep -rn 'channelsEnabled\|--channels\|development-channels' scripts .claude` → no matches.
- [ ] `scripts/hooks/inbox-nudge.sh` does not exist.
- [ ] Pre-push TDD gate green (xfail commit precedes impl commit on branch).

Reviewers: @Senna (architecture) + @Lucian (shell + POSIX).
EOF
)"
```

- **Merge policy:** Rule 18 — Viktor does NOT merge his own PR. Senna
  and Lucian review. Duong or another approver with write merges once
  CI is green and both reviewers have approved.

---

## IW.0 — xfail harness (Rakan)

**Repo:** `strawberry-agents`
**Commit slot:** commit 1 (xfail, first on branch)
**ADR refs:** §5 (acceptance items 1–12), "Test plan" section,
§3.2 (Phase 0/1/2), §3.4 (check-inbox archive flow).

**What:** Create the unit harness **before any implementation
exists**, so it fails loudly (xfail) and the pre-push TDD gate is
satisfied (Rule 12). The harness is a POSIX bash script that sets up
fixture directories under `$(mktemp -d)`, invokes the (not-yet-existing)
scripts, and asserts on stdout lines and on-disk state.

**Files touched (NEW):** <!-- orianna: ok -->
- `scripts/hooks/tests/inbox-watch-test.sh` — main harness, xfail-gated.

**Acceptance (xfail semantics):**
- Script is executable (`chmod +x`) and starts with `#!/usr/bin/env bash`
  + `set -euo pipefail`.
- Top of file: `# xfail: implements plans/approved/2026-04-20-strawberry-inbox-channel.md` comment.
- Script defines one test per §5 item it covers, each as a bash
  function (`test_boot_sweep_emits_one_line_per_pending`,
  `test_line_format_contract`, `test_identity_resolution_chain`,
  `test_no_inbox_watch_opt_out_short_circuits`,
  `test_archive_subdir_not_swept`,
  `test_frontmatter_without_status_never_emits`,
  `test_status_read_never_emits`,
  `test_archive_retention_deletes_files_older_than_7_days`,
  `test_archive_retention_prunes_empty_month_buckets`,
  `test_archive_retention_preserves_fresh_files`,
  `test_archive_cleanup_noop_when_archive_dir_absent`,
  `test_check_inbox_moves_pending_to_archive_yyyy_mm`,
  `test_check_inbox_archive_fallback_to_mtime_when_no_timestamp`,
  `test_regression_no_channels_artifacts`,
  `test_regression_no_inbox_nudge_sh`,
  `test_regression_no_user_prompt_submit_inbox_entry`,
  `test_regression_no_v2_nudge_phrasing`).
- All test functions marked xfail by bracketing each body in
  `if ! { <real assertion>; }; then printf 'XFAIL: %s\n' "$FUNCNAME"; return 0; fi; printf 'XPASS (unexpected): %s\n' "$FUNCNAME"; return 1`
  — so the harness **passes** today (every test xfails as expected)
  and flips to a real PASS once Viktor lands the implementation.
  Viktor will strip the xfail wrapper in IW.5.
- Harness exits 0 when every test xfails as expected, non-zero if any
  test unexpectedly passes (which will only happen once implementation
  lands — that's the flip point for IW.5).
- Fixtures:
  - `fixture/inbox-empty/` — empty inbox, archive absent.
  - `fixture/inbox-one-pending/` — single `status: pending` file with
    `timestamp: 2026-04-21T14:23:00Z`, `from: sona`, `priority: high`.
  - `fixture/inbox-mixed/` — one pending + one file with
    `status: read` (must not be emitted); `archive/2026-03/stale.md`
    with mtime backdated 10 days (`touch -t 202604110000` or
    `touch -d '10 days ago'`; use the POSIX `-t` form with a
    date that is unambiguously > 7 days before today's
    `date +%Y%m%d%H%M`).
  - `fixture/inbox-no-identity/` — no `CLAUDE_AGENT_NAME`,
    no `STRAWBERRY_AGENT`, stripped `.agent` — assert exit 0 +
    empty stdout.
  - `fixture/inbox-opt-out/` — `.no-inbox-watch` sentinel present at
    the fake repo root; assert Phase 0 does NOT run (place a stale
    archived file and verify it survives).
- Line-format assertion uses the regex from the ADR §3.2 contract:
  `^INBOX: [^ ]+\.md — from [^ ]+ — [a-z]+$` (em-dash `—`, U+2014 —
  **not** a hyphen). Harness must match bytes, not just visually.
- `INBOX_WATCH_ONESHOT=1` is set for every watcher invocation inside
  the harness (Phase 0 + Phase 1 only; no Phase 2 live-watch path is
  exercised in unit tests — that's manual acceptance §5 item 2).
- Regression greps are plain `grep -rn` invocations wrapped in
  assertions (`! grep -rn …` ⇒ expected to exit 1).

**DoD:**
- `bash scripts/hooks/tests/inbox-watch-test.sh` exits **0** on a
  clean checkout where `inbox-watch.sh` does NOT yet exist — because
  every test xfails as expected. This is the Rule-12 xfail commit's
  green signal.
- Pre-push hook accepts the commit (xfail commit references plan path
  in the header comment — `pre-push-tdd.sh` matches on
  `plans/approved/2026-04-20-strawberry-inbox-channel`).

**Commit message:**
```
chore: xfail harness for inbox watcher — pre-impl

Adds scripts/hooks/tests/inbox-watch-test.sh with the full test
matrix (watcher sweep, line format, identity chain, opt-out,
archive flow, 7-day retention, regression greps) guarded as xfail.
Flip to green in the follow-up impl commit.

Refs plans/approved/2026-04-20-strawberry-inbox-channel.md.
```

**Blockers:** none.
**Depends on:** — (first commit on branch).
**Hand-off:** Rakan pushes commit 1 to `inbox-watch-v3`, then posts a
line to `agents/viktor/inbox/` (via `/agent-ops send viktor …`)
notifying of branch readiness.

---

## IW.1 — Watcher script (Viktor)

**Repo:** `strawberry-agents`
**Commit slot:** commit 2 (impl)
**ADR refs:** §3.2 (Phase 0/1/2), §4.2 (timing), §4.4 (retention),
§3.6 (launcher), §5 items 1, 6, 7, 8, 11, 12.

**What:** Implement `scripts/hooks/inbox-watch.sh` per ADR §3.2,
verbatim phase order: Phase 0 (archive cleanup) → Phase 1 (pending
sweep) → Phase 2 (live watch). POSIX-portable (Rule 10).

**Files touched (NEW):** <!-- orianna: ok -->
- `scripts/hooks/inbox-watch.sh`

**Implementation anchors (map each to the ADR):**

| Anchor                                                           | ADR location                   |
|------------------------------------------------------------------|--------------------------------|
| `#!/usr/bin/env bash` + `set -eu` (no pipefail in POSIX dash)    | Rule 10; ADR §3.2 "POSIX-portable bash" |
| Coordinator-identity chain: env → `.claude/settings.json .agent` | §3.2 "Coordinator identity resolution" |
| `.no-inbox-watch` check **before Phase 0**                       | §3.2 "Opt-out"; §4.4 "Opt-out interaction" |
| Phase 0 `find … -mtime +7 -delete` then empty-dir prune          | §3.2 Phase 0 block; §4.4       |
| Phase 0 stderr-suppress missing-archive case                     | §3.2 "The `2>/dev/null` suppresses noise" |
| Phase 1 flat glob on `inbox/*.md` (archive excluded by shape)    | §3.2 Phase 1                   |
| Per-file filter: only emit when `status: pending`                | §3.2 Phase 1 + Phase 2         |
| Line format: `INBOX: <filename> — from <sender> — <priority>`    | §3.2 Line format block, §10 v3 Q3 |
| Phase 2 detection order: fswatch → inotifywait → poll (3 s)      | §3.2 Phase 2                   |
| `INBOX_WATCH_ONESHOT=1` runs Phase 0 + Phase 1 only, then exits  | §3.2 "One-shot mode"           |
| No internal restart loop on `fswatch`/`inotifywait` exit         | §3.2 "Lifecycle"               |
| No extra stdout output beyond `INBOX:` lines (noisy-monitor risk) | §6 "Noisy-monitor auto-kill"  |

**Acceptance:**
- Running against `fixture/inbox-empty/` with `INBOX_WATCH_ONESHOT=1`
  prints nothing and exits 0.
- Running against `fixture/inbox-one-pending/` prints **exactly one
  line** matching the line-format regex.
- Running against `fixture/inbox-mixed/` prints exactly one line
  (pending only; `status: read` suppressed); stale archive file
  is deleted; fresh archive file survives; empty month-bucket dir
  pruned; non-empty bucket retained.
- `.no-inbox-watch` present → exit 0 immediately; stale archive file
  **survives** (Phase 0 did NOT run).
- No coordinator identity resolvable → exit 0, empty stdout.
- `CLAUDE_AGENT_NAME=nonexistent` + no such agent dir → exit 0, empty
  stdout.
- Script has **no** `set -x`, no `echo "debug: …"`, no stray lines on
  stdout other than `INBOX:` events.

**DoD:**
- Harness from IW.0 passes all watcher-case tests (xfail → XPASS is
  the signal; Viktor strips the xfail wrapper in IW.5 once every
  script is in place).
- `shellcheck scripts/hooks/inbox-watch.sh` clean (SC2086 tolerated
  only where POSIX word-splitting is intentional; document with
  inline `# shellcheck disable=…` + reason).
- Script is executable (`chmod +x`).

**Blockers:** none.
**Depends on:** IW.0 (harness must exist to verify).

---

## IW.2 — Bootstrap hook (Viktor)

**Repo:** `strawberry-agents`
**Commit slot:** commit 2 (impl)
**ADR refs:** §3.3, §3.5, §5 items 5, 6, 8.

**What:** Implement
`scripts/hooks/inbox-watch-bootstrap.sh` — the SessionStart hook
target that emits `hookSpecificOutput.additionalContext` instructing
the coordinator to invoke `Monitor` on its first turn.

**Files touched (NEW):** <!-- orianna: ok -->
- `scripts/hooks/inbox-watch-bootstrap.sh`

**Implementation anchors:**

| Anchor                                                                                        | ADR location   |
|-----------------------------------------------------------------------------------------------|----------------|
| Read stdin JSON; if `.source != "startup"` exit 0 silently                                     | §3.5 bullet 1  |
| `source ∈ {resume, clear, compact}` → no re-bootstrap (delegated to existing hook + this one) | §3.3 paragraph 1, §6 "Session compact" |
| Identity chain (same three sources as watcher)                                                 | §3.3 bullet 3, §3.5 |
| `.no-inbox-watch` → exit 0                                                                     | §3.5 bullet 3  |
| Emit single JSON object with `hookSpecificOutput.hookEventName=SessionStart` + `additionalContext` | §3.3 bullet 2, §3.5 bullet 4 |
| `additionalContext` text matches the ADR §3.3 template (verbatim: `INBOX WATCHER: invoke the Monitor tool on your first action with: / command: bash scripts/hooks/inbox-watch.sh / description: Watch <agent>'s inbox for new messages. / Events will surface as INBOX: … notifications. When you see one, run /check-inbox to read and archive the message.`) | §3.3 bullet 2 |

**Acceptance:**
- `echo '{"source":"startup"}' | CLAUDE_AGENT_NAME=evelynn bash
  scripts/hooks/inbox-watch-bootstrap.sh` prints valid JSON with
  `hookSpecificOutput.additionalContext` containing the substring
  `invoke the Monitor tool` AND `bash scripts/hooks/inbox-watch.sh`
  AND the agent name `evelynn` (lowercased).
- `echo '{"source":"resume"}' | …` → exit 0, empty stdout.
- `echo '{"source":"clear"}' | …` → exit 0, empty stdout.
- `echo '{"source":"compact"}' | …` → exit 0, empty stdout.
- `echo '{"source":"startup"}' | …` (no identity) → exit 0, empty
  stdout.
- `.no-inbox-watch` present → exit 0, empty stdout regardless of
  source.
- `jq -e .` validates the emitted JSON.

**DoD:** harness bootstrap cases flip from XFAIL → XPASS.
**Blockers:** none.
**Depends on:** IW.0.

---

## IW.3 — `/check-inbox` skill — recover + archive semantics (Viktor)

**Repo:** `strawberry-agents`
**Commit slot:** commit 2 (impl)
**ADR refs:** §3.4, §4.1, §5 items 3, 4, 11.

**What:** Recover `.claude/skills/check-inbox/SKILL.md` from commit
`fb1bd4f` (`git show fb1bd4f:.claude/skills/check-inbox/SKILL.md`),
then rewrite the disposition step to **archive** read messages under
`inbox/archive/<YYYY-MM>/` with `status: read` + `read_at:` — NOT the
v1 in-place status flip.

**Files touched (NEW — recovered):** <!-- orianna: ok -->
- `.claude/skills/check-inbox/SKILL.md`

**Implementation anchors:**

| Anchor                                                                                | ADR location |
|---------------------------------------------------------------------------------------|--------------|
| Recovery source: `git show fb1bd4f:.claude/skills/check-inbox/SKILL.md`               | §3.4 "Recover … from `fb1bd4f`" |
| Identity resolution: same three-way chain                                              | §3.4 "Identity resolution" |
| Per-pending-file flow: display → rewrite frontmatter → mkdir bucket → mv               | §3.4 bullets 1–4 |
| YYYY-MM derived from `timestamp:` frontmatter                                          | §3.4 bullet 3 |
| Fallback to file mtime when `timestamp:` absent                                        | §3.4 bullet 3 + §6 "Frontmatter without `timestamp:`" |
| Concurrency: `mv` fails when source gone → skip & continue (no abort)                  | §3.4 "Concurrency" |
| Post-condition: `inbox/` has zero `status: pending` files                              | §3.4 bullet 5, §5 item 3(a) |
| `read_at` is ISO-8601 UTC (`date -u +%Y-%m-%dT%H:%M:%SZ`)                              | §3.4 bullet 2, §5 item 3(b) |

**Acceptance:**
- Given a fixture inbox with one pending message whose frontmatter
  has `timestamp: 2026-04-21T14:23:00Z`, running `/check-inbox` (via
  the harness which exercises the skill's documented steps as a
  shell equivalent) yields:
  - `inbox/` contains zero `status: pending` files.
  - `inbox/archive/2026-04/<original-filename>` exists.
  - Archived file has `status: read` and `read_at:` matching the
    regex `^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$`.
- Given a fixture message with **no** `timestamp:` field but with
  mtime in April 2026, the archive path lands in `2026-04/` (mtime
  fallback).
- During the rewrite, the brief `status: pending → read` edit does
  **not** trigger a second `INBOX:` emission from a running watcher
  (covered by the harness's "filter discipline" case; skill must
  write the `read` status **before** the `mv` so a watcher racing
  the move sees `status: read`).

**DoD:** harness skill-archive cases flip from XFAIL → XPASS.
**Blockers:** none.
**Depends on:** IW.0.

---

## IW.4 — `.claude/settings.json` wiring (Viktor)

**Repo:** `strawberry-agents`
**Commit slot:** commit 2 (impl)
**ADR refs:** §3.5, §5 item 10.

**What:** Append a second `SessionStart.hooks` entry that runs
`scripts/hooks/inbox-watch-bootstrap.sh`. Leave the existing
resume-suppression entry in place and **before** the new one (order
matters — ADR §3.3 bullet 1).

**Files touched:**
- `.claude/settings.json` (edit only — append one entry to the
  `SessionStart.hooks[0].hooks` array).

**Implementation anchors:**

| Anchor                                                                                          | ADR location |
|-------------------------------------------------------------------------------------------------|--------------|
| New entry: `{"type":"command","command":"bash scripts/hooks/inbox-watch-bootstrap.sh"}`         | §3.5         |
| Do **NOT** add `UserPromptSubmit` entry referencing inbox anything                              | §3.5, §5 item 10 |
| Do **NOT** add `PreToolUse` entry for inbox                                                      | §3.5         |
| JSON remains valid (`jq -e . .claude/settings.json`)                                             | —            |

**Acceptance:**
- Diff shows **only** the new hook entry added (no reformatting, no
  reordering of unrelated keys — Karpathy "surgical changes").
- `jq -e '.hooks.SessionStart[0].hooks | length' .claude/settings.json`
  returns `2` (was `1`).
- `jq -e '.hooks.SessionStart[0].hooks[1].command' .claude/settings.json`
  returns the exact string `"bash scripts/hooks/inbox-watch-bootstrap.sh"`.
- `jq -e '.hooks | to_entries[] | select(.key=="UserPromptSubmit")' .claude/settings.json`
  returns nothing OR returns an entry with no inbox-related command.

**DoD:** `bash scripts/hooks/test-hooks.sh` (or whatever the existing
local hooks test runner is) still passes; `jq -e .` validates the
file.
**Blockers:** none.
**Depends on:** IW.1, IW.2 (the scripts they add must exist on disk
before the hook entry references them, else the first SessionStart
that fires the hook 500s).

---

## IW.5 — Flip xfail harness green (Viktor)

**Repo:** `strawberry-agents`
**Commit slot:** commit 2 (impl; same commit as IW.1 – IW.4, or a
fixup squashed in before push)
**ADR refs:** §5 (acceptance §5 items 1–12), "Test plan" bullets 1–4.

**What:** Remove the xfail-wrapper from every test function in
`scripts/hooks/tests/inbox-watch-test.sh`. Every assertion now runs
directly; harness exits 0 iff the implementation is correct.

**Files touched:**
- `scripts/hooks/tests/inbox-watch-test.sh` (edit).

**Acceptance:**
- `bash scripts/hooks/tests/inbox-watch-test.sh` exits 0 with no
  `XFAIL:` lines and no `XPASS:` lines; only `PASS:` output per test
  case.
- Regression greps inside the harness all return the expected-empty
  result:
  - `! grep -rn 'strawberry-inbox' .claude/plugins` (dir absent or
    no hits).
  - `! grep -rn 'channelsEnabled\|--channels\|development-channels' scripts .claude`.
  - `! grep -rn 'UserPromptSubmit' .claude/settings.json | grep -i inbox`.
  - `! test -f scripts/hooks/inbox-nudge.sh`.
  - `! grep -rn 'pending message(s)\. Run /check-inbox to read them\.' scripts/hooks/`.
- `shellcheck scripts/hooks/tests/inbox-watch-test.sh` clean.

**DoD:**
- CI (whatever local hook invokes test harnesses under
  `scripts/hooks/tests/`) green. Pre-commit unit-test hook (Rule 14)
  does not block.
- Pre-push TDD hook (Rule 12) accepts the push because the xfail
  commit (IW.0) precedes this impl commit on the same branch and
  references the plan path.

**Commit message (for the squashed impl commit):**
```
chore: strawberry inbox watcher — Monitor-driven real-time inbox

Implements the v3.1 plan:
  - scripts/hooks/inbox-watch.sh (Phase 0 cleanup + Phase 1 sweep +
    Phase 2 live watch; fswatch → inotifywait → 3 s poll fallback).
  - scripts/hooks/inbox-watch-bootstrap.sh (SessionStart nudge).
  - .claude/skills/check-inbox/SKILL.md (recovered from fb1bd4f and
    extended with archive-to-inbox/archive/YYYY-MM/ semantics +
    read_at frontmatter).
  - .claude/settings.json — one new SessionStart.hooks entry.
  - Flips scripts/hooks/tests/inbox-watch-test.sh to fully green.

Implements plans/approved/2026-04-20-strawberry-inbox-channel.md.
```

**Blockers:** none.
**Depends on:** IW.1, IW.2, IW.3, IW.4.

---

## Execution order (tl;dr for Evelynn)

```
IW.0 (Rakan, commit 1 on inbox-watch-v3)
  └── IW.1 (Viktor) ─┐
  └── IW.2 (Viktor) ─┤
  └── IW.3 (Viktor) ─┴─ IW.4 (Viktor) ── IW.5 (Viktor, flip green) ── PR open
```

Single branch. Two commit slots. One PR. Two reviewers (Senna + Lucian).

## Acceptance-gate cross-reference

| Task | Satisfies ADR §5 items | Satisfies ADR "Test plan" bullets |
|------|------------------------|------------------------------------|
| IW.0 | — (scaffolds the checks for everything below) | Unit-level, retention, archive-flow, regression (all as xfails) |
| IW.1 | 1, 6, 7, 8, 11, 12     | Unit-level, archive-retention       |
| IW.2 | 5, 6, 8                | Unit-level                          |
| IW.3 | 3, 4, 11               | archive-flow                        |
| IW.4 | 5, 9, 10               | Regression floor                    |
| IW.5 | (flip) 1, 3, 5, 6, 7, 8, 10, 11, 12 | All four harness sections  |

Acceptance §5 items **2** (live mid-session delivery) and **9**
(no Channels/MCP/dev-flag regressions — partially covered by IW.5's
greps, but the no-Channels live test needs a real session) are
manual-only; they land in the E2E report archived under
`assessments/qa-reports/2026-04-…-inbox-watch.md` referenced from the
PR body. Evelynn + Sona each run one E2E turn; report links both.

## Rollback

- **Pre-merge:** close PR, delete branch; no system state changes.
- **Post-merge, pre-prod-usage:** revert the merge commit; no database
  state to roll back.
- **Post-merge, post-first-boot:**
  - Delete `scripts/hooks/inbox-watch.sh`,
    `scripts/hooks/inbox-watch-bootstrap.sh`, `.claude/skills/check-inbox/`
    (or `touch .no-inbox-watch` for an instant local disable).
  - Remove the new `SessionStart.hooks` entry from `.claude/settings.json`.
  - No data loss: messages remain in `agents/<coord>/inbox/**` as
    `status: pending`; archived messages remain under
    `inbox/archive/YYYY-MM/`. Both are static markdown files.
  - The 7-day archive TTL is only enforced when the watcher boots, so
    rolling back the watcher **freezes** archive retention — same
    state as `.no-inbox-watch` opt-out. Acceptable.

## Open questions for Aphelios (OQ-K#)

- **OQ-K1 — fswatch install cadence.** The ADR assumes `fswatch` is
  already installed on Duong's Mac (Homebrew). It's not validated in
  this plan; the poll fallback (3 s) is the fallback if absent. If
  Evelynn wants sub-second live delivery as a floor (not an
  aspiration), a separate plan should add an Orianna-gated install
  step. Not blocking for this breakdown; Viktor ships all three code
  paths.
- **OQ-K2 — line-format em-dash robustness.** The contract uses
  `—` (U+2014). If anyone copy-pastes the pattern through a tool
  that normalizes to a hyphen, the watcher filter regex fails open
  (no emission) rather than fails closed. Acceptable for v3, but
  worth a sentinel test in the harness — **covered** by IW.0's
  `test_line_format_contract` byte-level regex.

---

## Sign-off

This breakdown was prepared by Aphelios on 2026-04-21 against
Azir's v3.1 plan
(`plans/approved/2026-04-20-strawberry-inbox-channel.md`) with
Orianna signature `sha256:d5979ae9013e1af1748366f0f0b837047082730681eb35a9640b7abcbee90e4a:2026-04-21T03:59:37Z`.

No ADR changes were made in the process of producing this
breakdown. All `<!-- orianna: ok -->` markers on prospective paths
from the ADR are propagated above onto the matching task entries.
