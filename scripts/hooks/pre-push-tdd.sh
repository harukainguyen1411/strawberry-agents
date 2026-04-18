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
REPO_ROOT="$(git rev-parse --show-toplevel)"

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
        if ! command -v node >/dev/null 2>&1; then
          echo "[pre-push] ERROR: node not found. node is required by the TDD hook." >&2
          exit 1
        fi
        abs_pkg_json="$REPO_ROOT/$pkg_json"
        enabled=$(node -e "try{const p=require('$abs_pkg_json');process.stdout.write(String(p.tdd&&p.tdd.enabled===true))}catch(e){process.stdout.write('false')}" 2>/dev/null)
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

  # Rule 1: verify at least one xfail test commit exists before any impl commit.
  # Write SHAs to a temp file so the loop runs in the current shell (no subshell exit swallowing).
  _sha_list=$(mktemp)
  git log "$range" --format="%H" 2>/dev/null > "$_sha_list"
  xfail_found=""
  while IFS= read -r sha; do
    if git show "$sha" --unified=0 2>/dev/null | grep -qE '(test\.fail|it\.failing|@pytest\.mark\.xfail|# xfail:)'; then
      xfail_found="yes"
      break
    fi
  done < "$_sha_list"
  rm -f "$_sha_list"

  if [ -z "$xfail_found" ]; then
    impl_files=$(printf '%s\n' "$changed_files" | grep -vE '(\.test\.|\.spec\.|_test\.|/tests?/)' | grep -vE '\.(md|json|yml|yaml|sh)$' || true)
    if [ -n "$impl_files" ]; then
      echo "[pre-push] ERROR: Rule 1 violation — no xfail test commit found before implementation."
      echo "  Affected packages: $tdd_pkgs"
      echo "  Add an xfail test commit first, or use TDD-Waiver: trailer (Duong only)."
      exit 1
    fi
  fi

  # Rule 2: regression test required for bug-fix commits.
  # Iterate via temp file so exit codes propagate in the current shell.
  _sha_list2=$(mktemp)
  git log "$range" --format="%H" 2>/dev/null > "$_sha_list2"
  rule2_violation=""
  rule2_sha=""
  test_files_in_range=$(git diff --name-only "$range" 2>/dev/null | grep -E '(\.test\.|\.spec\.|_test\.|/tests?/)' || true)
  while IFS= read -r sha; do
    commit_msg=$(git log -1 --format="%B" "$sha")
    case "$commit_msg" in *"TDD-Trivial:"*|*"TDD-Waiver:"*) continue ;; esac
    # Match bug keywords in subject line only to avoid false positives on "debugging" / "budget"
    subject=$(printf '%s' "$commit_msg" | head -1)
    case " $subject " in
      *" bug "*|*" bugfix "*|*" regression "*|*" hotfix "*)
        if [ -z "$test_files_in_range" ]; then
          rule2_violation="yes"
          rule2_sha="$sha"
          break
        fi
        ;;
    esac
  done < "$_sha_list2"
  rm -f "$_sha_list2"

  if [ -n "$rule2_violation" ]; then
    echo "[pre-push] ERROR: Rule 2 violation — bug-fix commit lacks regression test."
    echo "  Commit: $rule2_sha"
    echo "  Add a regression test commit, or use TDD-Waiver: trailer (Duong only)."
    exit 1
  fi

done

exit 0
