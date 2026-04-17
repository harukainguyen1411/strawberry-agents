#!/bin/sh
# Installs all strawberry git hooks into .git/hooks (or the configured core.hooksPath).
# Safe to re-run — existing hooks are replaced.
set -e

REPO_ROOT="$(git rev-parse --show-toplevel)"
HOOKS_SRC="$REPO_ROOT/scripts/hooks"
HOOKS_DIR="$(git rev-parse --git-dir)/hooks"

# Allow override via core.hooksPath
configured=$(git config core.hooksPath 2>/dev/null || echo "")
if [ -n "$configured" ]; then
  HOOKS_DIR="$configured"
fi

mkdir -p "$HOOKS_DIR"

install_hook() {
  name="$1"
  src="$HOOKS_SRC/$name.sh"
  dst="$HOOKS_DIR/$name"

  if [ ! -f "$src" ]; then
    echo "[install-hooks] WARNING: $src not found — skipping $name"
    return
  fi

  # If an existing hook is not ours, compose rather than overwrite
  if [ -f "$dst" ] && ! grep -q "strawberry-managed" "$dst" 2>/dev/null; then
    echo "[install-hooks] Composing with existing $name hook"
    tmp=$(mktemp)
    printf '#!/bin/sh\n# strawberry-managed\n' > "$tmp"
    printf '# Existing hook preserved below\n' >> "$tmp"
    cat "$dst" >> "$tmp"
    printf '\n# Strawberry TDD hook\n' >> "$tmp"
    cat "$src" >> "$tmp"
    mv "$tmp" "$dst"
  else
    printf '#!/bin/sh\n# strawberry-managed\n' > "$dst"
    cat "$src" >> "$dst"
  fi

  chmod +x "$dst"
  echo "[install-hooks] Installed $name"
}

install_hook "pre-commit-secrets-guard"
install_hook "pre-commit-artifact-guard"
install_hook "pre-commit-unit-tests"
install_hook "pre-push-tdd"

echo "[install-hooks] Done. Hooks installed to: $HOOKS_DIR"
