# Learning: plan-authoring survival kit for `pre-commit-zz-plan-structure.sh`

Date: 2026-04-21
Topic: 4 non-obvious failure modes when committing a Swain-tier ADR to `plans/proposed/`

## Context

Authored a 528-line complex-concern plan (`2026-04-21-demo-studio-v3-vanilla-api-ship.md`). First commit attempt failed with 33 BLOCK findings + a hard awk I/O crash. Took 4 iterations to pass. Each iteration exposed a distinct gate mechanism.

## Gotcha 1 — Suppressor literal is full 22 chars, not a pattern

`pre-commit-zz-plan-structure.sh` (and `fact-check-plan.sh`) both suppress a line using `awk index($0, "<!-- orianna: ok -->") > 0`. The match is for the **complete 22-character string** `<!-- orianna: ok -->` — NOT the pattern `<!-- orianna: ok ... -->`.

Narration-style suppressors like `<!-- orianna: ok — reason here -->` do NOT match because the em-dash interrupts the literal. Must append the bare `<!-- orianna: ok -->` separately OR close the narration with `... -->` and then a second `<!-- orianna: ok -->` on the same line.

Pattern that works (file header blanket + inline):

```
<!-- explanation of paths --> <!-- orianna: ok -->
```

## Gotcha 2 — Directory-path getline crashes awk

Any backtick-quoted token ending in `/` (e.g. `plans/proposed/work/`, `company-os/tools/X/`) triggers `awk: i/o error` exit 2 — a HARD CRASH, not a BLOCK finding — because the hook uses `getline _ < full_path` and macOS awk refuses to open a directory. Error surfaces as:

```
awk: i/o error occurred on <full/path/to/dir>
 input record number N, file <plan-file>
 source line number M
```

Suppressor MUST go on the same line BEFORE the hook tries the getline (which happens if `<!-- orianna: ok -->` is not found first). Previously discovered by Ekko (2026-04-21-plan-structure-hook-directory-io-error).

## Gotcha 3 — `## Tasks` section is mandatory even for orchestration-only ADRs

The hook enforces Rule 1: canonical `## Tasks` or `## N. Tasks` heading must exist. Swain-tier plans that delegate task decomposition to Aphelios/Kayn cannot simply omit it — they must include a coord-level task list (T.COORD.1, T.COORD.2, ...) with `estimate_minutes:` on every entry. Estimate values must stay under 60 (§D4 enforcement).

Azir's plans use this pattern; adopt directly. Example:

```
## Tasks

Orchestration-level coordination only. No phase decomposition here. <!-- orianna: ok -->

- [ ] **T.COORD.1** — ... kind: coord | estimate_minutes: 30
- [ ] **T.COORD.2** — ... kind: coord | estimate_minutes: 20 <!-- orianna: ok -->
```

## Gotcha 4 — Hook scans ALL staged plan files, not just yours

The pre-commit hook walks every plan in `git diff --cached --name-only`. If a concurrent agent has staged their own `plans/proposed/work/<other>.md`, YOUR commit dies on THEIR BLOCK findings. Workaround:

```bash
git reset HEAD -- plans/proposed/work/<other>.md  # unstages everything
git add plans/proposed/work/<your>.md              # re-stage ONLY yours
```

Then retry. Check `git status` before commit — if a `?? plans/proposed/...` entry appears that is not yours, leave it untracked and commit only your own file.

## Lesson

A Swain-tier plan is not "done" until the commit hook clears. Budget 15–20 min for the fact-check / lint loop after the last structural edit. Iterate: stage → `git add` → `bash scripts/hooks/pre-commit-zz-plan-structure.sh` → fix BLOCK findings one loop at a time. Do NOT try to anticipate all 4 gotchas up-front — the fastest path is to let the hook tell you what it wants.

## Reusable checklist for Swain next time

1. Every backtick-quoted prospective path gets `<!-- orianna: ok -->` at end of its line.
2. Every directory reference (trailing `/`) especially needs it — crash vs block.
3. Include a `## Tasks` section with ≥1 T.COORD.N task, each with `estimate_minutes:` ≤60.
4. Use `bash scripts/hooks/pre-commit-zz-plan-structure.sh` as the iteration loop, not a real `git commit` attempt (avoids side-effects on other agents' staged files).
5. Before commit, `git status` to verify only your file is staged.
