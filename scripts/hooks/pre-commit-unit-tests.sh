#!/bin/sh
# Runs unit tests for TDD-enabled packages that have staged changes.
# No-ops for packages without tdd.enabled:true in package.json.
set -e

STAGED=$(git diff --cached --name-only 2>/dev/null) || exit 0
[ -z "$STAGED" ] && exit 0

REPO_ROOT="$(git rev-parse --show-toplevel)"

if ! command -v node >/dev/null 2>&1; then
  echo "[pre-commit] ERROR: node not found. node is required by the TDD hook. Install Node.js to proceed." >&2
  exit 1
fi

# Collect unique package roots that have staged changes
PKGS=""
for f in $STAGED; do
  dir=$(dirname "$f")
  while [ "$dir" != "." ] && [ "$dir" != "/" ]; do
    pkg_json="$dir/package.json"
    if [ -f "$REPO_ROOT/$pkg_json" ]; then
      # Use absolute path to avoid CWD-relative require() failures when
      # git invokes the hook from a subdirectory (e.g. cd dashboards/server && git commit)
      abs_pkg_json="$REPO_ROOT/$pkg_json"
      enabled=$(node -e "try{const p=require('$abs_pkg_json');process.stdout.write(String(p.tdd&&p.tdd.enabled===true))}catch(e){process.stdout.write('false')}" 2>/dev/null)
      if [ "$enabled" = "true" ]; then
        case "$PKGS" in
          *"|$dir|"*) ;;
          *) PKGS="$PKGS|$dir|" ;;
        esac
      fi
      break
    fi
    dir=$(dirname "$dir")
  done
done

if [ -z "$PKGS" ]; then
  exit 0
fi

FAILED=0
OLD_IFS="$IFS"
IFS="|"
for pkg in $PKGS; do
  [ -z "$pkg" ] && continue
  abs_pkg_json="$REPO_ROOT/$pkg/package.json"
  if [ -f "$abs_pkg_json" ]; then
    echo "[pre-commit] Running unit tests for $pkg"
    test_cmd=$(node -e "try{const p=require('$abs_pkg_json');process.stdout.write(p.scripts&&p.scripts['test:unit']||'')}catch(e){}" 2>/dev/null)
    if [ -z "$test_cmd" ]; then
      echo "[pre-commit] No test:unit script in $pkg/package.json — skipping"
      continue
    fi
    (cd "$REPO_ROOT/$pkg" && npm run test:unit --if-present) || FAILED=1
  fi
done
IFS="$OLD_IFS"

if [ "$FAILED" -ne 0 ]; then
  echo "[pre-commit] Unit tests failed. Fix failures or use TDD-Waiver trailer (Duong only)."
  exit 1
fi
