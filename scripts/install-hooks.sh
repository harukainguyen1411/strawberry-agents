#!/bin/sh
# Installs strawberry git hook dispatchers into scripts/hooks-dispatchers/ (tracked, in-repo).
# Sets core.hooksPath = scripts/hooks-dispatchers so all worktrees share the same hooks.
# Each dispatcher verb (pre-commit, pre-push, commit-msg) runs every scripts/hooks/<verb>-*.sh in order.
# Safe to re-run — existing non-managed hooks are preserved inside the dispatcher.
#
# Pre-commit hooks picked up automatically from scripts/hooks/pre-commit-*.sh:
#   pre-commit-agent-shared-rules.sh       — agent identity + CLAUDE.md rule guards
#   pre-commit-artifact-guard.sh           — blocks accidental artifact commits
#   pre-commit-feedback-index.sh           — regenerates feedback/INDEX.md when feedback files change (§D6)
#   pre-commit-plan-lifecycle-guard.sh     — commit-phase guard: blocks non-Orianna plan-lifecycle moves (defence-in-depth)
#   pre-commit-resolved-identity.sh        — PRIMARY GATE: blocks persona-named author/committer via git var (resolved identity)
#   pre-commit-reviewer-anonymity.sh       — blocks agent-system identifiers in work-scope (missmp/) commit msgs
#   pre-commit-secrets-guard.sh            — blocks secrets in committed files
#   pre-commit-staged-scope-guard.sh       — rejects commits that sweep out-of-scope paths (STAGED_SCOPE contract)
#   pre-commit-unit-tests.sh               — runs unit tests for changed packages
#   pre-commit-assessments-index-gen.sh    — validates assessment frontmatter + regenerates category INDEX.md on assessment commits (Phase C T16)
#
# NOTE: pre-commit-plan-promote-guard.sh and commit-msg-plan-promote-guard.sh have been
# archived to scripts/hooks/_archive/v2-commit-phase-plan-guards/ by
# plans/approved/personal/2026-04-23-plan-lifecycle-physical-guard.md.
# Plan lifecycle enforcement is now handled exclusively by the PreToolUse hook
# scripts/hooks/pretooluse-plan-lifecycle-guard.sh (wired via .claude/settings.json).
#
# NOTE: pre-commit-zz-plan-structure.sh has been archived to
# scripts/hooks/_archive/v2-plan-structure-lint/ (2026-04-24). Structural plan
# linting is now the responsibility of the Orianna v2 Opus agent gate, which
# applies substance-over-format discipline and deliberately does not block on
# format-only concerns such as bare-filename path references or forward self-refs.
#
# Execution order is alphabetical (ls | sort).
#
# Pre-push hooks picked up automatically from scripts/hooks/pre-push-*.sh:
#   pre-push-resolved-identity.sh       — BACKSTOP: blocks persona-named author/committer via git cat-file (closes commit-tree path)
#   pre-push-tdd.sh                     — TDD gate enforcement
#
# Commit-msg hooks picked up automatically from scripts/hooks/commit-msg-*.sh:
#   commit-msg-no-ai-coauthor.sh        — blocks AI co-author trailers (Claude, Anthropic, etc.)
set -e

# Derive REPO_ROOT from the script's own location (scripts/install-hooks.sh is two levels below root).
# This ensures the script works correctly when invoked from a different working directory
# (e.g. bats test harnesses that run install-hooks.sh in a clean temp repo).
_SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
_SCRIPT_PARENT="$(cd "$_SCRIPT_DIR/.." && pwd)"
# Validate: the script is expected to live at <root>/scripts/install-hooks.sh
# Use the parent of scripts/ as REPO_ROOT; fall back to git rev-parse for safety.
if [ "$(basename "$_SCRIPT_DIR")" = "scripts" ]; then
  REPO_ROOT="$_SCRIPT_PARENT"
else
  REPO_ROOT="$(git rev-parse --show-toplevel)"
fi
HOOKS_SRC="$REPO_ROOT/scripts/hooks"

# Default: write dispatchers into the tracked in-repo directory so all worktrees
# of this clone share them automatically via core.hooksPath.
HOOKS_DIR="$REPO_ROOT/scripts/hooks-dispatchers"

# Honor an explicit manual override — if core.hooksPath is already set to something
# other than our default, respect it.  If unset or already pointing at our default,
# set (or confirm) it idempotently.
configured=$(git config --local core.hooksPath 2>/dev/null || echo "")
if [ -n "$configured" ] && [ "$configured" != "scripts/hooks-dispatchers" ]; then
  echo "[install-hooks] core.hooksPath manually overridden to '$configured' — using that path."
  HOOKS_DIR="$configured"
else
  # Set or confirm the repo-local core.hooksPath to our tracked directory.
  # This is idempotent; re-running is safe.
  git config core.hooksPath "scripts/hooks-dispatchers"
  echo "[install-hooks] core.hooksPath set to: scripts/hooks-dispatchers"
fi

mkdir -p "$HOOKS_DIR"

# install_dispatcher <verb>
# Writes .git/hooks/<verb> that:
#   1. Runs any pre-existing non-managed hook content (preserved verbatim).
#   2. Runs each scripts/hooks/<verb>-*.sh found at call-time, passing all args.
# If a prior managed dispatcher exists it is replaced cleanly.
install_dispatcher() {
  verb="$1"
  dst="$HOOKS_DIR/$verb"
  tmp=$(mktemp)

  cat > "$tmp" <<DISPATCHER
#!/bin/sh
# strawberry-managed dispatcher for $verb
# Writes to scripts/hooks-dispatchers/$verb (tracked in-repo).
# Re-run install-hooks.sh to regenerate.
set -e
REPO_ROOT="\$(git rev-parse --show-toplevel)"
HOOKS_SRC="\$REPO_ROOT/scripts/hooks"
DISPATCHER

  # Preserve existing non-managed hook body
  if [ -f "$dst" ] && ! grep -q "strawberry-managed" "$dst" 2>/dev/null; then
    echo "[install-hooks] Preserving existing $verb hook"
    cat >> "$tmp" <<'PRESERVED'
# --- existing hook preserved ---
PRESERVED
    # Strip the shebang from the existing file before inlining
    tail -n +2 "$dst" >> "$tmp"
    printf '\n# --- end existing hook ---\n' >> "$tmp"
  fi

  # Dispatcher loop: run every <verb>-*.sh sub-hook in sorted order
  cat >> "$tmp" <<'LOOP'
_rc=0
for _sub in $(ls "$HOOKS_SRC"/*.sh 2>/dev/null | sort); do
  _base=$(basename "$_sub")
  case "$_base" in
    VERB-*.sh)
      "$_sub" "$@" || _rc=$?
      ;;
  esac
done
exit $_rc
LOOP

  # Substitute the actual verb into the pattern
  sed -i.bak "s/VERB/$verb/g" "$tmp" && rm -f "$tmp.bak"

  mv "$tmp" "$dst"
  chmod +x "$dst"
  echo "[install-hooks] Installed $verb dispatcher"
}

install_dispatcher "pre-commit"
install_dispatcher "pre-push"
install_dispatcher "commit-msg"

# Also write a .git/hooks/pre-commit shim for backward-compatibility with tools
# that check .git/hooks/ directly (e.g. test harnesses and IDEs that pre-date
# core.hooksPath). The shim delegates to scripts/hooks-dispatchers/pre-commit.
# pre-commit-feedback-index is automatically picked up by the dispatcher above.
_git_hooks_dir="$REPO_ROOT/.git/hooks"
if [ -d "$_git_hooks_dir" ]; then
  _git_pre_commit="$_git_hooks_dir/pre-commit"
  _tmp_shim=$(mktemp)
  cat > "$_tmp_shim" <<'SHIM'
#!/bin/sh
# strawberry compatibility shim — delegates to scripts/hooks-dispatchers/pre-commit
# Wired by scripts/install-hooks.sh alongside pre-commit-feedback-index and other hooks.
#
# Recursion guard: when core.hooksPath=scripts/hooks-dispatchers git already invoked
# the dispatcher directly via that path.  The shim must not re-invoke it — that would
# compose shim→dispatcher→shim→... infinitely.  Detect this by checking core.hooksPath.
_root="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
_hooks_path="$(git config --get core.hooksPath 2>/dev/null || echo '')"
# Resolve to absolute for comparison (core.hooksPath may be relative)
case "$_hooks_path" in
  /*) _abs_hooks_path="$_hooks_path" ;;
  "")  _abs_hooks_path="" ;;
  *)   _abs_hooks_path="$_root/$_hooks_path" ;;
esac
_dispatcher_dir="$_root/scripts/hooks-dispatchers"
if [ "$_abs_hooks_path" = "$_dispatcher_dir" ]; then
  # Dispatcher was already invoked by git via core.hooksPath — exit cleanly.
  exit 0
fi
_dispatcher="$_dispatcher_dir/pre-commit"
if [ -x "$_dispatcher" ]; then
  exec "$_dispatcher" "$@"
fi
# Fallback: dispatcher not yet built — run sub-hooks directly
_src="$_root/scripts/hooks"
_rc=0
for _sub in $(ls "$_src"/pre-commit-*.sh 2>/dev/null | sort); do
  "$_sub" "$@" || _rc=$?
done
exit $_rc
SHIM
  mv "$_tmp_shim" "$_git_pre_commit"
  chmod +x "$_git_pre_commit"
  echo "[install-hooks] Installed .git/hooks/pre-commit compatibility shim"
fi

# Install Python dependencies for the PreToolUse guard (bashlex AST walker).
# Best-effort: warn on failure but do not abort hook installation.
if command -v pip3 >/dev/null 2>&1; then
  pip3 install --user -r "$HOOKS_SRC/requirements.txt" >/dev/null 2>&1 \
    || printf '[install-hooks] WARNING: pip3 install bashlex failed — run: pip3 install bashlex\n' >&2
else
  printf '[install-hooks] WARNING: pip3 not found — install Python3 and run: pip3 install bashlex\n' >&2
fi

echo "[install-hooks] Done. Hook dispatchers installed to: $HOOKS_DIR"
echo "[install-hooks] Sub-hooks active: $(ls "$HOOKS_SRC"/*.sh 2>/dev/null | xargs -n1 basename | tr '\n' ' ')"

# ---------------------------------------------------------------------------
# Smoke test stanza — run hook test suites to confirm installation is sound.
# Runs the resolved-identity test suites and the commit-msg no-AI-coauthor suite.
# Failures are reported fail-loud but do not abort the installer (tests may be
# incompatible with environments lacking git or bash).
# ---------------------------------------------------------------------------
echo ""
echo "[install-hooks] Running hook smoke tests..."
_smoke_fail=0

run_smoke() {
  _test_file="$1"
  if [ ! -f "$_test_file" ]; then
    printf '[install-hooks] SMOKE WARNING: test file not found: %s\n' "$_test_file" >&2
    return
  fi
  _result=$(bash "$_test_file" 2>&1)
  _rc=$?
  if [ $_rc -eq 0 ]; then
    # Extract the OK summary line
    _summary=$(printf '%s' "$_result" | tail -1)
    printf '[install-hooks] SMOKE OK: %s — %s\n' "$(basename "$_test_file")" "$_summary"
  else
    printf '[install-hooks] SMOKE FAIL: %s\n' "$(basename "$_test_file")" >&2
    printf '%s\n' "$_result" | sed 's/^/  /' >&2
    _smoke_fail=1
  fi
}

run_smoke "$REPO_ROOT/tests/hooks/test_pre_commit_resolved_identity.sh"
run_smoke "$REPO_ROOT/tests/hooks/test_pre_push_resolved_identity.sh"
run_smoke "$REPO_ROOT/tests/hooks/test_commit_msg_no_ai_coauthor.sh"

if [ "$_smoke_fail" -ne 0 ]; then
  printf '[install-hooks] WARNING: one or more smoke tests failed — see above\n' >&2
else
  echo "[install-hooks] All smoke tests passed."
fi
