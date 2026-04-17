#!/bin/sh
# Pre-push hook enforcing TDD rules 1 and 2 for TDD-enabled packages.
#
# Rule 1: xfail test must precede any implementation commit on branch.
# Rule 2: bug-fix commits must be accompanied by a regression test commit.
#
# Grandfathered packages (no tdd.enabled:true in package.json) are skipped.
set -e

REMOTE="$1"
URL="$2"

# Read the ref list from stdin: <local-ref> <local-sha> <remote-ref> <remote-sha>
while read local_ref local_sha remote_ref remote_sha; do
  # Skip deletions
  [ "$local_sha" = "0000000000000000000000000000000000000000" ] && continue

  # Determine range
  if [ "$remote_sha" = "0000000000000000000000000000000000000000" ]; then
    # New branch — compare against merge-base with main
    base=$(git merge-base "$local_sha" main 2>/dev/null || echo "")
    if [ -z "$base" ]; then
      range="$local_sha"
    else
      range="$base..$local_sha"
    fi
  else
    range="$remote_sha..$local_sha"
  fi

  # Collect TDD-enabled packages touched in this range
  changed_files=$(git diff --name-only "$range" 2>/dev/null) || continue
  [ -z "$changed_files" ] && continue

  tdd_pkgs=""
  for f in $changed_files; do
    dir=$(dirname "$f")
    while [ "$dir" != "." ] && [ "$dir" != "/" ]; do
      pkg_json="$dir/package.json"
      if [ -f "$pkg_json" ]; then
        if command -v node >/dev/null 2>&1; then
          enabled=$(node -e "try{const p=require('./$pkg_json');process.stdout.write(String(p.tdd&&p.tdd.enabled===true))}catch(e){process.stdout.write('false')}" 2>/dev/null)
        else
          enabled=$(grep -q '"tdd"' "$pkg_json" && grep -q '"enabled".*true' "$pkg_json" && echo "true" || echo "false")
        fi
        if [ "$enabled" = "true" ]; then
          case "$tdd_pkgs" in
            *"|$dir|"*) ;;
            *) tdd_pkgs="$tdd_pkgs|$dir|" ;;
          esac
        fi
        break
      fi
      dir=$(dirname "$dir")
    done
  done

  [ -z "$tdd_pkgs" ] && continue

  # Check for TDD-Waiver trailer on the tip commit
  tip_msg=$(git log -1 --format="%B" "$local_sha")
  case "$tip_msg" in
    *"TDD-Waiver:"*) echo "[pre-push] TDD-Waiver trailer detected — skipping TDD checks." ; continue ;;
  esac

  # Rule 1: verify at least one xfail test commit exists before any impl commit
  # We look for commits that add xfail markers (test.fail / it.failing / @pytest.mark.xfail)
  xfail_found=$(git log "$range" --format="%H %s" | while read sha msg; do
    git show "$sha" --unified=0 2>/dev/null | grep -qE '(test\.fail|it\.failing|@pytest\.mark\.xfail|# xfail:)' && echo "yes" && break
  done)

  if [ -z "$xfail_found" ]; then
    # Only block if there are non-test implementation files changed
    impl_files=$(echo "$changed_files" | grep -vE '(\.test\.|\.spec\.|_test\.|/tests?/)' | grep -vE '\.(md|json|yml|yaml|sh)$' || true)
    if [ -n "$impl_files" ]; then
      echo "[pre-push] ERROR: Rule 1 violation — no xfail test commit found before implementation."
      echo "  Affected packages: $tdd_pkgs"
      echo "  Add an xfail test commit first, or use TDD-Waiver: trailer (Duong only)."
      exit 1
    fi
  fi

  # Rule 2: regression test required for bug-fix commits
  git log "$range" --format="%H %s %b" | while read sha rest; do
    commit_msg=$(git log -1 --format="%B" "$sha")
    case "$commit_msg" in
      *bug*|*bugfix*|*regression*|*hotfix*)
        # Allow TDD-Trivial for docs-only
        case "$commit_msg" in *"TDD-Trivial:"*) continue ;; esac
        case "$commit_msg" in *"TDD-Waiver:"*) continue ;; esac
        # Check if a test file was modified in this range before or at this commit
        test_files=$(git diff --name-only "$range" 2>/dev/null | grep -E '(\.test\.|\.spec\.|_test\.|/tests?/)' || true)
        if [ -z "$test_files" ]; then
          echo "[pre-push] ERROR: Rule 2 violation — bug-fix commit lacks regression test."
          echo "  Commit: $sha"
          echo "  Add a regression test commit, or use TDD-Waiver: trailer (Duong only)."
          exit 1
        fi
        ;;
    esac
  done || exit 1

done

exit 0
