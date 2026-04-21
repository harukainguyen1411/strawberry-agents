#!/usr/bin/env bash
# One-time admin promotion: memory-consolidation plan in-progress -> implemented.
#
# Purpose: all 12 tasks (T1 xfails through T12 dogfood evidence at commit
# 682a976) landed on main. Routine `scripts/plan-promote.sh` blocked because
# `pre-commit-zz-plan-structure.sh` Rule-4 fires on every path-shaped token in
# the full file body when git mv surfaces the whole file as an added hunk.
# Root-cause fix is queued as `plans/proposed/personal/2026-04-21-pre-lint-rename-aware.md`
# (Karma #79). This script unblocks the specific promotion via the admin-only
# `Orianna-Bypass:` trailer (Rule 19).
#
# Must be run by Duong from the `harukainguyen1411` admin identity. The
# pre-commit hook rejects agent-identity bypass attempts.
#
# Usage:
#   bash scripts/oneoffs/2026-04-21-admin-promote-memory-plan.sh

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

SRC="plans/in-progress/personal/2026-04-21-memory-consolidation-redesign.md"
DST_DIR="plans/implemented/personal"
DST="${DST_DIR}/2026-04-21-memory-consolidation-redesign.md"

# Preflight
if ! command -v gh >/dev/null; then
  echo "gh CLI required" >&2
  exit 1
fi

ACTIVE_LOGIN="$(gh api user --jq .login 2>/dev/null || true)"
if [ "$ACTIVE_LOGIN" != "harukainguyen1411" ]; then
  echo "✘ Active gh login is '${ACTIVE_LOGIN:-<none>}'." >&2
  echo "  This script must run under the harukainguyen1411 admin identity." >&2
  echo "  Switch: gh auth switch -u harukainguyen1411" >&2
  exit 1
fi

if [ ! -f "$SRC" ]; then
  echo "✘ Source plan not at $SRC — already promoted?" >&2
  exit 1
fi

if [ ! -d "$DST_DIR" ]; then
  mkdir -p "$DST_DIR"
fi

# Sync main before touching anything
git pull --ff-only origin main

# Ensure clean working tree (abort if stray stage exists — prevents sweep-up)
if [ -n "$(git status --porcelain)" ]; then
  echo "✘ Working tree not clean. Stash or commit pending changes first:" >&2
  git status --short >&2
  exit 1
fi

# Move the file
git mv "$SRC" "$DST"

# Flip status in the frontmatter (portable sed)
if command -v gsed >/dev/null; then
  gsed -i 's/^status: in-progress$/status: implemented/' "$DST"
else
  sed -i.bak 's/^status: in-progress$/status: implemented/' "$DST" && rm -f "${DST}.bak"
fi

# Confirm status flipped
if ! grep -q "^status: implemented$" "$DST"; then
  echo "✘ status: implemented not found after sed — frontmatter may have non-standard shape." >&2
  echo "  Fix manually, then re-run:"
  echo "    $(basename "$0")"
  exit 1
fi

git add "$DST"

# Commit with admin bypass trailer. Do NOT pass --no-verify; the
# pre-commit hook must still run (the bypass trailer is the contract the hook
# checks for).
git commit -m "chore: promote 2026-04-21-memory-consolidation-redesign to implemented

All 12 tasks landed on main. Evidence trail:
  T1  xfails               — commit 26eb0d4
  T2  _lib_last_sessions_index.sh — commit bc01a9c
  T3  archive-policy xfails — (in chain)
  T4  memory-consolidate.sh rewrite — commit 7fa1f33
  T5  end-session xfails    — (in chain)
  T6  end-session Step 6b   — commit 133cc39
  T7  Lissandra Step 6b parity — commit c5ddf1b
  T8  bootstrap open-threads.md + INDEX.md — commit 6935a98
  T9  boot rewrites + filter-last-sessions.sh deletion — commit 5f519dd
  T10 CLAUDE.md startup + agent-network consumption — commit 24d238f
  T11 architecture/coordinator-memory.md — commit 66111f9
  T12 dogfood evidence — commit 682a976

Orianna-Bypass: All impl complete. Body-hash signature re-sign chain blocked
by pre-commit-zz-plan-structure Rule-4 firing on full file body when git mv
surfaces whole plan as added hunk (PR #15 scoping only covers regular edits,
not renames). Rename-aware hook fix queued as Karma #79 plan
2026-04-21-pre-lint-rename-aware.md. Admin bypass is the surgical unblock
for this one promotion."

git push origin main

echo
echo "✓ Promoted. Final path: $DST"
echo "  Commit: $(git rev-parse HEAD)"
