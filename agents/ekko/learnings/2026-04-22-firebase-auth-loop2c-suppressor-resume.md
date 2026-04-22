# 2026-04-22 — Firebase auth loop 2c suppressor resume

## Session type
Resume of paused Op B — suppressor completion + commit on plans/proposed/work/2026-04-22-firebase-auth-loop2c-route-migration.md

## Key learnings

### Global block suppressors do NOT suppress individual line checks
The top-of-file `<!-- orianna: ok — every file-path token... -->` block comment (lines 19-25) does not exempt individual lines from the hook check. Every line is evaluated independently. Each path token on each line needs its own inline suppressor.

### Hook scope is wider than the explicit "remaining violations" list
The pause report listed ~15 bare markers. After fixing those, the commit attempt revealed ~30 more violations in:
- Prose in §2.1 (`main.py` in the "callers in `main.py` currently..." sentence)
- Prose in §2.2 (three `main.py` references in the §2.2 bullet list)
- Prose in §2.4 ("From `main.py` grep on...")
- Prose in §6 Q3 (`main.py` in the open-question text)
- `Files:` fields in T.I.2, T.I.3 — both the bare `auth.py` in task prose AND the qualified `tools/demo-studio-v3/auth.py` in Files: fields are checked
- `Files:` fields in T.I.4, T.I.5, T.I.6 — session_store.py, session.py all needed suppressors
- `Files:` fields in T.M.2–T.M.11 — bare `main.py` in every task
- T.I.4 — `test_conversation_store.py` in DoD prose
- T.V.2 — `tools/demo-studio-v3/tests/**` glob AND `feat/demo-studio-v3` branch name
- T.R.2 — `feat/demo-studio-v3` branch name in DoD

### Iterative commit attempts are the reliable way to find remaining violations
The hook output lists all BLOCK findings per run. Three iterations were needed:
1. First attempt: ~30 blocks
2. Second attempt: 1 block (§6 Q3 `main.py`)
3. Third attempt: clean commit

### `-o <pathspec>` commit flag
`git commit -o plans/proposed/work/<file>` is mandatory for plan-only commits per Evelynn's instruction. Always include.

## Commit SHA
d045852
