#!/bin/sh
# Installs strawberry git hook dispatchers into .git/hooks.
# Each dispatcher verb (pre-commit, pre-push, commit-msg) runs every scripts/hooks/<verb>-*.sh in order.
# Safe to re-run — existing non-managed hooks are preserved inside the dispatcher.
#
# Pre-commit hooks picked up automatically from scripts/hooks/pre-commit-*.sh:
#   pre-commit-agent-shared-rules.sh    — agent identity + CLAUDE.md rule guards
#   pre-commit-artifact-guard.sh        — blocks accidental artifact commits
#   pre-commit-reviewer-anonymity.sh    — blocks agent-system identifiers in work-scope (missmp/) commit msgs
#   pre-commit-secrets-guard.sh         — blocks secrets in committed files
#   pre-commit-staged-scope-guard.sh    — rejects commits that sweep out-of-scope paths (STAGED_SCOPE contract)
#   pre-commit-unit-tests.sh            — runs unit tests for changed packages
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
#   pre-push-tdd.sh                     — TDD gate enforcement
#
# Commit-msg hooks picked up automatically from scripts/hooks/commit-msg-*.sh:
#   commit-msg-no-ai-coauthor.sh        — blocks AI co-author trailers (Claude, Anthropic, etc.)
set -e

REPO_ROOT="$(git rev-parse --show-toplevel)"
HOOKS_SRC="$REPO_ROOT/scripts/hooks"
HOOKS_DIR="$(git rev-parse --git-dir)/hooks"

configured=$(git config core.hooksPath 2>/dev/null || echo "")
if [ -n "$configured" ]; then
  HOOKS_DIR="$configured"
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
