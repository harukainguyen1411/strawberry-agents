---
status: approved
concern: personal
owner: karma
created: 2026-04-25
tests_required: true
complexity: quick
orianna_gate_version: 2
tags: [hooks, plan-lifecycle, bashlex, ast-walker, false-positive, reviewer]
related:
  - scripts/hooks/pretooluse-plan-lifecycle-guard.sh
  - scripts/hooks/_lib_bash_path_scan.py
  - scripts/hooks/tests/test-pretooluse-plan-lifecycle-guard.sh
  - agents/sona/learnings/2026-04-24-plan-lifecycle-guard-blocks-sona.md
  - agents/lucian/learnings/2026-04-24-pr35-identity-leak-fix-fidelity.md
  - agents/lucian/learnings/2026-04-24-pr43-rule-19-commit-phase-guard.md
  - agents/lucian/learnings/2026-04-24-pr39-coordinator-boot-unification-fidelity.md
architecture_impact: bugfix
---

# Plan-lifecycle guard — fix bashlex parse-error false positive on quoted-delimiter heredocs

## 1. Context

`scripts/hooks/pretooluse-plan-lifecycle-guard.sh` invokes `_lib_bash_path_scan.py` (a bashlex AST walker) on every `Bash` tool invocation that mentions the substring `plans`. The walker already filters by `_MUTATING_VERBS` and a `_MUTATING_GIT_SUBVERBS = {mv, rm}` allowlist, so `git commit -m "...plans/approved/..."` does **not** false-positive on path collection. The user-reported failure is a **different mechanism**: bashlex's heredoc parser raises on quoted-delimiter heredocs (`<<'EOF'`) when the command string is fed in as a one-shot, producing `here-document at line 0 delimited by end-of-file (wanted "'EOF'")`. The scanner exits 3, the guard fails closed, the agent sees a generic block message.

Reproducer (verified locally 2026-04-25):

```bash
gh pr review 47 --body "$(cat <<'EOF'
addresses plans/approved/personal/foo.md
EOF
)"
```

→ scanner exits 3 → guard rejects with "bash AST scanner exited 3 — denied (fail-closed)".

This pattern is the canonical reviewer-verdict shape used by Lucian, Senna, Aphelios, and Sona. It has produced the entrenched `--body-file /tmp/...md` workaround visible across 14+ Lucian learnings on 2026-04-23 → 2026-04-24. The workaround works but burns a Write call per review and pollutes `/tmp`. Path-collection scope is already correct; the only bug is the parse-failure handling.

## 2. Decision

Replace the blanket `exit 3 → fail-closed` policy with a **two-stage parse strategy**: try bashlex first; on parse error, fall back to a *conservative substring scan* that only flags protected-path tokens when they are immediately preceded by a known mutating verb (`mv`, `cp`, `rm`, `tee`, `touch`, `install`, `ln`, `rsync`, `truncate`, `mkdir`, `rmdir`, or `git mv` / `git rm`) on the same logical line, OR when they appear as a redirect target (`>`, `>>` immediately before the path token). All other occurrences of `plans/approved/...` etc. — heredoc bodies, `--body` / `--message` / `-m` argument strings, comments, command substitutions whose outer command is read-only — are permitted.

This preserves fail-closed semantics for the genuine attack/violation surface (an actual `mv plans/approved/foo plans/in-progress/` written inside a heredoc-wrapped script that bashlex can't parse) while allowing the 99% case (a reviewer body string mentioning a plan path).

Rationale for not "just fix bashlex": bashlex is a third-party library with a known parse limitation on heredoc-with-quoted-delimiter passed as a one-shot string. We do not own it, and patching upstream is out of scope. The fallback is the lower-risk path.

## 3. Tasks

- **T1.** Add a `--strict-paths-only` mode to `_lib_bash_path_scan.py`. <!-- orianna: ok -->
  - kind: implementation
  - estimate_minutes: 25
  - files: `scripts/hooks/_lib_bash_path_scan.py`
  - detail: Introduce a function `scan_conservative(command: str) -> list[str]` that does NOT use bashlex. It splits the command on shell metacharacters (`;`, `&&`, `||`, `|`, newline) into pseudo-statements, then for each statement: (a) tokenize on whitespace; (b) if `tokens[0]` matches a mutating verb (or `tokens[0..1]` matches `git mv` / `git rm`), emit every subsequent token that contains `/` after stripping quotes; (c) scan for redirect operators (`>`, `>>`) and emit the immediately-following token. The walker's existing `normalize_path` is reused. Add a CLI flag `--mode=conservative` to switch from bashlex AST mode to this scan.
  - DoD: `python3 scripts/hooks/_lib_bash_path_scan.py --mode=conservative` reads from stdin and emits exactly the protected-path candidates per the rules above; bashlex is NOT imported in conservative mode.

- **T2.** Wire the two-stage parse strategy into the guard. <!-- orianna: ok -->
  - kind: implementation
  - estimate_minutes: 15
  - files: `scripts/hooks/pretooluse-plan-lifecycle-guard.sh`
  - detail: When the bashlex scanner exits 3 (parse error), do NOT exit 2. Instead, invoke `_lib_bash_path_scan.py --mode=conservative` on the same command. Collect its output and run the same `is_protected_path` loop. Any other non-zero exit code from the bashlex scanner remains fail-closed. The bashlex scanner's exit-3 message goes to stderr at debug level only (prefixed `[plan-lifecycle-guard:debug]`) so we keep diagnostic visibility without a user-facing rejection.
  - DoD: A `gh pr review --body "$(cat <<'EOF' ... plans/approved/... EOF)"` invocation passes the guard; an `mv plans/approved/foo plans/in-progress/foo` invocation embedded inside an unparseable wrapper still blocks via the conservative pass.

- **T3.** Extend the test suite with the FP corpus and the must-still-block corpus.
  - kind: test
  - estimate_minutes: 20
  - files: `scripts/hooks/tests/test-pretooluse-plan-lifecycle-guard.sh`
  - detail: Add named cases for each scenario in §4 below. Each FP case asserts exit 0 (allowed); each violation case asserts exit 2 (blocked). Cases must run under both bashlex-available and bashlex-unavailable modes (the latter forces conservative-only — set `PYTHON3_CMD` to a stub that fails the `import bashlex` check, OR add an env switch the guard honors).
  - DoD: `bash scripts/hooks/tests/test-pretooluse-plan-lifecycle-guard.sh` passes; new cases visible in test output.

- **T4.** Update reviewer-agent learnings to drop the `--body-file` workaround as default.
  - kind: docs
  - estimate_minutes: 5
  - files: `agents/lucian/learnings/index.md`
  - detail: Append a note to the index entry that the heredoc-body workaround is no longer required as of this plan's merge. Do NOT delete the historical learning files (audit trail). Sona/Aphelios learnings are global-scoped and need no edit; the index pointer is sufficient.
  - DoD: `agents/lucian/learnings/index.md` carries a one-line "superseded" note pointing to this plan's implemented copy.

## 4. Test plan

Test cases live in `scripts/hooks/tests/test-pretooluse-plan-lifecycle-guard.sh`. The file already exercises the guard via real hook-payload JSON; new cases follow the same shape.

### 4.1 Must allow (false-positive corpus)

These are the patterns Sona / Aphelios / Lucian have hit. Each must exit 0:

1. `gh pr review N --body "$(cat <<'EOF' ... plans/approved/personal/foo.md ... EOF)"` — quoted-delimiter heredoc.
2. `gh pr review N --body "$(cat <<EOF ... plans/in-progress/personal/foo.md ... EOF)"` — bare-delimiter heredoc.
3. `gh pr comment N --body "Per plans/approved/personal/foo.md, ..."` — inline string body.
4. `git commit -m "$(cat <<'EOF' ... refers to plans/implemented/personal/foo.md ... EOF)"` — commit-message heredoc.
5. `git commit -m "fix per plans/approved/personal/foo.md"` — inline commit message.
6. `cat plans/approved/personal/foo.md` — read-only access.
7. `grep -r "TBD" plans/approved/` — read-only recursive grep.
8. `ls plans/in-progress/personal/` — directory listing.
9. `printf '%s\n' "see plans/archived/personal/foo.md"` — printf with format string.

### 4.2 Must still block (regression corpus from PR #31 and Senna C1-C4 / B1-B7 rounds)

Each must exit 2:

1. `mv plans/approved/personal/foo.md plans/in-progress/personal/foo.md` — direct mv.
2. `cp plans/approved/personal/foo.md plans/archived/personal/foo.md` — direct cp.
3. `rm plans/in-progress/personal/foo.md` — direct rm.
4. `git mv plans/approved/personal/foo.md plans/in-progress/personal/foo.md` — git subverb mv.
5. `echo "x" > plans/approved/personal/new.md` — redirect creating new file.
6. `tee plans/approved/personal/new.md <<<"x"` — tee write.
7. `touch plans/in-progress/personal/new.md` — touch.
8. `eval "mv plans/approved/personal/foo plans/archived/personal/foo"` — eval re-parse.
9. `bash -c "mv plans/approved/personal/foo plans/archived/personal/foo"` — bash -c re-parse.
10. `dest=plans/in-progress/personal/foo.md; mv plans/approved/personal/foo.md "$dest"` — variable resolution.
11. `mv plans/approved/personal/foo.md plans/archived/personal/foo.md` issued from inside a heredoc-wrapping script that fails bashlex parse — must trip the conservative fallback (verify by injecting an unparseable prefix that triggers exit 3, then ensuring the conservative scanner still extracts the `mv` paths).

The §4.2 invariants are the contract: any genuine plan-lifecycle write attempt by a non-Orianna agent must block, regardless of whether bashlex parses cleanly.

## 5. Migration

After T1-T3 land, the `--body-file /tmp/<slug>.md` reviewer workaround becomes optional rather than mandatory. No active script in `scripts/` hardcodes the workaround — it lives only in agent muscle memory and the Lucian learnings. T4 records the supersession; agents will pick it up via normal learning rotation. No code rollback required.

The bashlex dependency stays in place for the primary path. If we later decide to drop bashlex entirely, that is a follow-up plan, not in scope here.

## 6. Open questions

- None blocking. Karma confidence: high. The fix scope is narrow (one Python function, one shell branch, test additions).

## 7. References

- `scripts/hooks/_lib_bash_path_scan.py` — current AST walker, `_MUTATING_VERBS` allowlist already correct for path collection.
- `scripts/hooks/pretooluse-plan-lifecycle-guard.sh` lines 192-198 — the `exit 3 → exit 2` site this plan changes.
- Lucian learnings 2026-04-23 / 2026-04-24 (14 entries) document the workaround surface area.
- PR #31 history (commits `ffd5dd97`, `01d03c0e`, `94f3ccdd`, `efe9a42f`) defined the original AST walker invariants reproduced in §4.2.

## Orianna approval

- **Date:** 2026-04-25
- **Agent:** Orianna
- **Transition:** proposed → approved
- **Rationale:** Owner is named (karma), scope is narrow and concrete (one Python function, one shell branch, enumerated test corpus), and DoD is testable per task. The two open questions in §6 are deemed answered with Karma's recommended defaults — two-stage parse strategy and leaving the 14 historical Lucian workaround learnings as audit trail. tests_required is honored by T3, which extends the existing harness with both FP and must-still-block corpora. Lean and well-bounded; ready for in-progress on next promotion.
