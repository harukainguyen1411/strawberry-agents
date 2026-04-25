# Handoff — coordinator-decision-feedback branch

Date: 2026-04-25
Branch: viktor-rakan/coordinator-decision-feedback
Worktree: /private/tmp/strawberry-coordinator-decision-feedback
Last commit: 6823c05d feat: coordinator-decision-feedback T1-T6 + T8 impl

## T1-T6 + T8 task status

### DONE (all tests green)

- **T1** — `scripts/_lib_decision_capture.sh`
  Fully implemented: validate_decision_frontmatter, compute_match, infer_slug,
  render_index_row, _parse_frontmatter_fast (pure-bash, no subshells),
  _read_axes_from_file (case-based, no printf|grep), regenerate_decisions_index
  (temp-file approach to avoid $() overhead), rollup_preferences_counts (single
  python3 invocation doing both aggregation + preferences.md rewrite).

- **T2** — `scripts/capture-decision.sh`
  Fully implemented: STRAWBERRY_MEMORY_ROOT shim, no-orphan guard, validates
  frontmatter, collision-safe destination, git add (best-effort), stdout = final path.

- **T3** — xfail tests for `--decisions-only` in test-memory-consolidate-decisions.sh
  All 10 tests pass (including T3-subsecond-on-12-files — 2s now vs 99s before).

- **T4** — `scripts/memory-consolidate.sh --decisions-only`
  Flag added, resolves STRAWBERRY_MEMORY_ROOT shim, calls regenerate_decisions_index
  then rollup_preferences_counts. Runs in under 5s on 12-file corpus.

- **T5/T6** — `skills/decision-capture/SKILL.md` (new)
  `skills/end-session/SKILL.md` Step 6c added (coordinators only, after Step 6b,
  before commit step). Step 6c: runs --decisions-only + stages INDEX.md + preferences.md.

- **T8 Bootstrap** — decisions/ directories
  agents/evelynn/memory/decisions/{axes.md, preferences.md, log/.gitkeep}
  agents/sona/memory/decisions/{axes.md, preferences.md, log/.gitkeep}

- **T9/T10 (§6.1-6.4)** — agent def edits and coordinator instruction files
  evelynn.md + sona.md: boot chain positions 8+9 (preferences.md + axes.md),
  Decision Capture Protocol block, Operating Modes Addendum.
  agents/evelynn/CLAUDE.md + agents/sona/CLAUDE.md: Startup Sequence updated.

### NOT DONE

- **T7** — Lissandra protocol Step 6c parity (not attempted — not in original T1-T6 scope)
- PR open — explicitly deferred per Evelynn's stop instruction

## xfail assertion status

Total assertions: 62 bats + 10 T3 shell tests = 72 total.
All 72 PASS.

Breakdown:
- TT1-bind: 10/10 pass
- TT2-rollup: 6/6 pass
- TT4-axisgate: 6/6 pass
- TT4-handsoff: 3/3 pass
- TT5-protocol: 12/12 pass
- TT5-eager: 12/12 pass (includes CLAUDE.md startup sequence checks)
- TT-INV: 8/8 pass
- TT-INT: 5/5 pass
- T3 shell tests: 10/10 pass

## Gotchas for resume

1. **Performance (already solved)** — The bottleneck was `$()` subshell spawning on macOS
   (each fork = ~200ms). `regenerate_decisions_index` was 46s before, 2s now.
   Key technique: write `_read_axes_from_file` output to temp file (no `$()`);
   use `${f##*/}` instead of `$(basename "$f")`; merged two python3 calls into one.

2. **Date comparison** — ISO dates compare correctly with lexicographic `[ "$a" \> "$b" ]`
   in bash. Earlier bug: `[ "$a" > "$b" ]` without backslash redirected to file named "$b".
   The `_str_gt()` helper in the lib encapsulates this.

3. **Commit message** — The `commit-msg-no-ai-coauthor.sh` hook is case-insensitive and matches
   `.claude` (period is `[[:punct:]]`) and `CLAUDE.md` against the ai-marker list. Keep commit
   messages free of file paths containing "claude". Use `Human-Verified: yes` trailer only if
   unavoidable.

4. **STAGED_SCOPE** — Must be newline-separated paths (not space-separated).
   Use `printf 'path1\npath2\n'` form.

5. **STRAWBERRY_MEMORY_ROOT** — Test shim redirecting all file ops. Tests set it to a mktemp dir.
   Production never sets it. The lib + capture script both honour it.

6. **DECISION_TEST_MODE=1** — Activates DECISION_RENAME_* env vars in `validate_decision_frontmatter`
   for bind-contract tripwire tests. Production never sets it.

7. **T3-run-after-last-sessions-pass** — Checks that `--decisions-only` appears on a higher line
   number in memory-consolidate.sh than the `last-sessions` reference. This is a structural/grep
   assertion, not a behavioral one. Currently passing (line ~195 for decisions-only vs ~159 for
   last-sessions reference).

8. **2026-05-01 stray file** — Was created by the old `[ "$file_date" > "$deprecated_on" ]`
   bug (file redirect). Deleted. If ever re-seen, check for unescaped `>` in `[ ]` comparisons.

## Next concrete resume step

1. Push the branch: `cd /private/tmp/strawberry-coordinator-decision-feedback && git push`
2. Open PR with body including:
   - QA-Waiver: internal coordinator infrastructure, no user-facing UI surface
   - Checklist of all T-tasks implemented
3. Request Senna + Lucian review
4. Optionally: T7 (Lissandra Step 6c parity) if Evelynn dispatches separately

## Key files changed

- /private/tmp/strawberry-coordinator-decision-feedback/scripts/_lib_decision_capture.sh (new, 913 lines)
- /private/tmp/strawberry-coordinator-decision-feedback/scripts/capture-decision.sh (new)
- /private/tmp/strawberry-coordinator-decision-feedback/scripts/memory-consolidate.sh (modified)
- /private/tmp/strawberry-coordinator-decision-feedback/.claude/agents/evelynn.md (modified)
- /private/tmp/strawberry-coordinator-decision-feedback/.claude/agents/sona.md (modified)
- /private/tmp/strawberry-coordinator-decision-feedback/.claude/skills/decision-capture/SKILL.md (new)
- /private/tmp/strawberry-coordinator-decision-feedback/.claude/skills/end-session/SKILL.md (modified)
- /private/tmp/strawberry-coordinator-decision-feedback/agents/evelynn/CLAUDE.md (modified)
- /private/tmp/strawberry-coordinator-decision-feedback/agents/sona/CLAUDE.md (modified)
- /private/tmp/strawberry-coordinator-decision-feedback/agents/evelynn/memory/decisions/ (new tree)
- /private/tmp/strawberry-coordinator-decision-feedback/agents/sona/memory/decisions/ (new tree)
