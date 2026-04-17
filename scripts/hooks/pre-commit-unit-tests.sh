#!/bin/sh
# Runs unit tests for TDD-enabled packages that have staged changes.
# No-ops for packages without tdd.enabled:true in package.json.
set -e

STAGED=$(git diff --cached --name-only 2>/dev/null) || exit 0
[ -z "$STAGED" ] && exit 0

# Collect unique package roots that have staged changes
PKGS=""
for f in $STAGED; do
  dir=$(dirname "$f")
  while [ "$dir" != "." ] && [ "$dir" != "/" ]; do
    pkg_json="$dir/package.json"
    if [ -f "$pkg_json" ]; then
      # Check for tdd.enabled: true marker
      if command -v node >/dev/null 2>&1; then
        enabled=$(node -e "try{const p=require('./$pkg_json');process.stdout.write(String(p.tdd&&p.tdd.enabled===true))}catch(e){process.stdout.write('false')}" 2>/dev/null)
      else
        enabled=$(grep -q '"tdd"' "$pkg_json" && grep -q '"enabled".*true' "$pkg_json" && echo "true" || echo "false")
      fi
      if [ "$enabled" = "true" ]; then
        # Add dir to list if not already present
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
  pkg_json="$pkg/package.json"
  if [ -f "$pkg_json" ]; then
    echo "[pre-commit] Running unit tests for $pkg"
    if command -v node >/dev/null 2>&1; then
      test_cmd=$(node -e "try{const p=require('./$pkg_json');process.stdout.write(p.scripts&&p.scripts['test:unit']||'')}catch(e){}" 2>/dev/null)
    fi
    if [ -z "$test_cmd" ]; then
      echo "[pre-commit] No test:unit script in $pkg/package.json — skipping"
      continue
    fi
    (cd "$pkg" && sh -c "$test_cmd") || FAILED=1
  fi
done
IFS="$OLD_IFS"

if [ "$FAILED" -ne 0 ]; then
  echo "[pre-commit] Unit tests failed. Fix failures or use TDD-Waiver trailer (Duong only)."
  exit 1
fi
