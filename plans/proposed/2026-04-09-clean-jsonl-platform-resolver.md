---
status: proposed
owner: evelynn
created: 2026-04-09
title: clean-jsonl.py platform-aware project-dir resolver
---

# clean-jsonl.py — platform-aware project-dir default

> Detailed executor spec. Small, scoped, reversible. Written to unblock `/end-session` on Mac, which is currently broken because `scripts/clean-jsonl.py` hard-codes the Windows project-dir path.

## Problem

`scripts/clean-jsonl.py` line 28 defines:

```python
DEFAULT_PROJECT_DIR_WINDOWS = pathlib.Path(
    "C:/Users/AD/.claude/projects/C--Users-AD-Duong-strawberry/"
)
```

Line 513 uses it as the `--project-dir` argparse default:

```python
parser.add_argument("--project-dir", default=str(DEFAULT_PROJECT_DIR_WINDOWS))
```

This was correct for the Windows session where Phase 1 was built. It's wrong on Mac — tonight's `/end-session evelynn` probe failed with `CLEANER: project dir not found: C:/Users/AD/.claude/projects/C--Users-AD-Duong-strawberry/`. The script needs a platform-aware default that picks the right project dir at runtime.

## Fix specification

### Step 1 — Replace the constant

Delete lines 28–30 (`DEFAULT_PROJECT_DIR_WINDOWS = pathlib.Path(...)` and its closing paren).

Replace with a small helper function, placed directly after the `CHAIN_GAP_SECONDS` constant (around line 27). Exact body:

```python
def _default_project_dir() -> pathlib.Path:
    """Return the Claude Code project dir for this repo on the current platform.

    On macOS and Linux, Claude Code stores session jsonl under
    ``~/.claude/projects/<slugified-repo-path>/``. The slug is produced by
    replacing every filesystem separator in the absolute repo path with a
    dash and prefixing a dash — e.g. ``/Users/duongntd99/Documents/Personal/strawberry``
    becomes ``-Users-duongntd99-Documents-Personal-strawberry``.

    On Windows, Claude Code uses the drive-letter + dash convention under
    ``%USERPROFILE%\\.claude\\projects\\``.

    The function resolves the repo root via ``git rev-parse --show-toplevel``
    and constructs the slug from that. Falls back to the current working
    directory if git is unavailable.
    """
    try:
        import subprocess
        repo_root = subprocess.check_output(
            ["git", "rev-parse", "--show-toplevel"],
            stderr=subprocess.DEVNULL,
        ).decode().strip()
        repo_path = pathlib.Path(repo_root)
    except (subprocess.CalledProcessError, FileNotFoundError, OSError):
        repo_path = pathlib.Path.cwd()

    home = pathlib.Path.home()
    projects_root = home / ".claude" / "projects"

    if sys.platform == "win32":
        # Windows: drive letter + dashes, e.g. C--Users-AD-Duong-strawberry
        drive = repo_path.drive.rstrip(":")  # "C:" -> "C"
        tail = str(repo_path)[len(repo_path.drive):].replace("\\", "-").replace("/", "-")
        slug = f"{drive}-{tail}" if tail.startswith("-") else f"{drive}--{tail}"
        return projects_root / slug

    # macOS / Linux: leading dash + dash-separated path
    slug = "-" + str(repo_path).lstrip("/").replace("/", "-")
    return projects_root / slug
```

### Step 2 — Update the argparse default

On line 513 (after Step 1's replacement may have shifted numbering, grep for the line), change:

```python
parser.add_argument("--project-dir", default=str(DEFAULT_PROJECT_DIR_WINDOWS))
```

to:

```python
parser.add_argument("--project-dir", default=str(_default_project_dir()))
```

### Step 3 — Verify with a dry test

After the edit, run the cleaner against the current Evelynn session using auto discovery:

```bash
python scripts/clean-jsonl.py --agent evelynn --session auto --out /tmp/resolver-test.md
```

**Expected outcome:** the cleaner either (a) writes a transcript to `/tmp/resolver-test.md` and exits 0, OR (b) emits a normal chain-walk or "no session found" message that clearly references a MAC-style path under `/Users/duongntd99/.claude/projects/-Users-duongntd99-Documents-Personal-strawberry/`, not the old `C:/Users/AD/...` path.

**Failure outcome:** the cleaner again reports a Windows path → resolver is broken, STOP, do not commit.

After the test, `rm -f /tmp/resolver-test.md`.

### Step 4 — Sanity-check the Windows branch doesn't regress

The Windows code path can't be exercised on a Mac, but you can at least confirm the Windows slug logic doesn't crash when simulated. Run:

```bash
python3 -c "
import pathlib, sys
sys.platform = 'win32'
# mimic a Windows repo root
repo_path = pathlib.Path('C:/Users/AD/Duong/strawberry')
drive = repo_path.drive.rstrip(':')
tail = str(repo_path)[len(repo_path.drive):].replace('\\\\', '-').replace('/', '-')
slug = f'{drive}-{tail}' if tail.startswith('-') else f'{drive}--{tail}'
print(slug)
"
```

**Expected:** prints `C--Users-AD-Duong-strawberry` — matches the old hard-coded Windows default. If it differs, the Windows slug logic is wrong; STOP and escalate.

(This is a portability smoke-test, not a full Windows test. Real Windows validation happens the next time Evelynn is invoked on Windows.)

### Step 5 — Commit

Stage ONLY `scripts/clean-jsonl.py` (explicit `git add <path>`, no `-A`). Commit with exactly:

```
chore: katarina clean-jsonl platform-aware project-dir resolver
```

Do not amend, do not squash, do not use `--no-verify`.

### Step 6 — Push

```bash
git push origin main
```

If the pre-push hook rejects the commit, STOP and report. Do not retry with `--no-verify` or any workaround.

### Step 7 — Plan promotion

After the commit lands successfully, promote this plan through the lifecycle:

```bash
bash scripts/plan-promote.sh plans/in-progress/2026-04-09-clean-jsonl-platform-resolver.md implemented
```

(Evelynn will have promoted it from proposed → approved → in-progress before spawning you; your job at this step is only the final in-progress → implemented transition.)

## Out of scope

- Refactoring any other cleaner logic. Only the project-dir default changes.
- Adding CLI flags or config options beyond what exists.
- Fixing any other platform-specific assumptions in the script (e.g. line endings, filesystem case sensitivity) — file follow-up plans if you spot them.
- Testing chain-walk behavior — that's covered by the cleaner's own unit tests if they exist, and by the `/end-session` exit test.

## Verification checklist

- [ ] `scripts/clean-jsonl.py` no longer contains the string `DEFAULT_PROJECT_DIR_WINDOWS`
- [ ] New `_default_project_dir()` function is present
- [ ] argparse default calls `_default_project_dir()`
- [ ] Step 3 dry test succeeded OR failed with a Mac path in the error (not a Windows path)
- [ ] Step 4 Windows simulation prints `C--Users-AD-Duong-strawberry`
- [ ] Single commit with `chore:` prefix
- [ ] Push succeeded
- [ ] Plan promoted to `implemented/`

## Final report

List the commit SHA, whether the dry test passed, any non-fatal observations, and confirm promotion to implemented. If any step surprised you, STOP and report rather than improvising.
