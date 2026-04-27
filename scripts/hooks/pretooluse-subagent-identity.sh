#!/usr/bin/env bash
# scripts/hooks/pretooluse-subagent-identity.sh
#
# ============================================================================
# DEFENSE-IN-DEPTH LAYER — ADVISORY ONLY
#
# This hook operates at PreToolUse time (pre-execve). It sees shell SOURCE,
# not resolved values. Lucian's review of PR #45 identified 9 structural
# bypasses (NEW-BP-4 through NEW-BP-12: line-continuation, backticks, $(...),
# eval, sh -c, bash -c, git commit-tree, $V indirection) that defeat any
# regex scan at this layer — the arms race is unbounded.
#
# PRIMARY GATE:  scripts/hooks/pre-commit-resolved-identity.sh
#   Reads `git var GIT_AUTHOR_IDENT` after all shell expansion — ground truth.
#
# BACKSTOP:      scripts/hooks/pre-push-resolved-identity.sh
#   Reads `git cat-file commit <sha>` — closes the git commit-tree path.
#
# This hook is kept for defense-in-depth: it catches trivial/unobfuscated
# cases and shortens the feedback loop (fires before the commit, not at push).
# It CANNOT be the primary gate.
#
# Reference: architecture/agent-network-v1/git-identity.md
#            plans/approved/personal/2026-04-25-resolved-identity-enforcement.md §2
# ============================================================================
#
# PreToolUse Bash hook: enforce neutral git author identity on ALL subagent worktrees.
#
# Universalises the former pretooluse-work-scope-identity.sh (which was scoped
# to [:/]missmp/ origins only). This hook fires on every "git commit" Bash
# dispatch regardless of repo origin — personal-concern and work-scope worktrees
# are both covered.
#
# When a Bash tool call contains "git commit" and the effective cwd is a git
# repo, this hook rewrites the per-worktree git config to Duong's canonical
# noreply identity:
#   user.name  = Duongntd
#   user.email = 103487096+Duongntd@users.noreply.github.com
#
# Orianna carve-out:
#   If CLAUDE_AGENT_NAME=Orianna OR agent_type resolves to "orianna", the hook
#   exits 0 silently without rewriting. Orianna is the sole deliberate exception
#   whose plan-promotion commits author as orianna@strawberry.local (per
#   .claude/agents/orianna.md). Her commits land only on strawberry-agents main
#   and never reach a work-repo PR.
#
# This is fail-closed: if the config write fails, the hook emits a block JSON
# and exits 2 so the commit does not proceed. Non-git-commit commands and
# non-git-repo cwds pass through silently (exit 0).
#
# Input : JSON on stdin (Claude PreToolUse contract)
# Output: JSON block decision on failure; nothing on pass
# Exit  : 0 = proceed, 2 = block
#
# POSIX-portable bash per Rule 10.
# Plan: plans/approved/personal/2026-04-24-subagent-git-identity-as-duong.md T2
# Supersedes: scripts/hooks/pretooluse-work-scope-identity.sh (work-scope only)

set -uo pipefail

NEUTRAL_NAME="Duongntd"
NEUTRAL_EMAIL="103487096+Duongntd@users.noreply.github.com"

# Fail-closed helper: emit block JSON and exit 2
block() {
  printf '{"decision":"block","reason":"[identity-guard] %s"}\n' "$1"
  exit 2
}

# Orianna exemption: exit 0 silently if identity resolves to Orianna.
# Resolution order mirrors the plan-lifecycle guard: CLAUDE_AGENT_NAME env var first.
if [ "${CLAUDE_AGENT_NAME:-}" = "Orianna" ] || [ "${STRAWBERRY_AGENT:-}" = "Orianna" ]; then
  exit 0
fi

# Read stdin into a variable
INPUT="$(cat)"

# I3: empty stdin → pass-through silently (no payload means no commit context to guard)
if [ -z "$INPUT" ]; then
  exit 0
fi

# Fail-closed: require python3 to be available
if ! command -v python3 >/dev/null 2>&1; then
  block "python3 not found — cannot parse PreToolUse JSON; commit blocked to prevent identity leak."
fi

# Extract tool_name (fail-closed on parse error)
TOOL_NAME="$(printf '%s' "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_name',''))" 2>/dev/null)" || block "JSON parse failure on tool_name — commit blocked to prevent identity leak."

if [ "$TOOL_NAME" != "Bash" ]; then
  exit 0
fi

# Extract command (fail-closed on parse error)
COMMAND="$(printf '%s' "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('command',''))" 2>/dev/null)" || block "JSON parse failure on command — commit blocked to prevent identity leak."

# ---------------------------------------------------------------------------
# shlex-based identity scanner (round 4 structural fix — replaces regex scanner)
#
# Senna found that regex scanning of the raw command string is defeated by:
#   NEW-BP-1: Shell-special chars (;|&) inside quoted -c values
#   NEW-BP-2: Quote char immediately after = in GIT_*_NAME=, or leading space
#             inside quoted value
#   NEW-BP-3: Persona name as middle/trailing token in multi-word quoted value
#
# Fix: tokenize with python shlex.split(), which strips quotes and handles shell
# special chars exactly as git's execve call sees them. Regex check is then
# performed on clean token values, not the raw command string.
#
# Command is passed via SHLEX_CMD env var (stdin is used for Python script code).
# ---------------------------------------------------------------------------

# Write the Python scanner to a tempfile to avoid quoting gymnastics.
_SCANNER_TMP="$(mktemp /tmp/pretooluse-scanner.XXXXXX.py)"
cat > "$_SCANNER_TMP" << 'PYEOF'
import os, sys, re, shlex

PERSONA_NAMES = [
    'Akali','Aphelios','Azir','Caitlyn','Camille','Ekko','Evelynn',
    'Heimerdinger','Jayce','Karma','Kayn','Lissandra','Lucian','Lulu','Lux',
    'Neeko','Orianna','Rakan','Senna','Seraphine','Skarner','Sona','Soraka',
    'Swain','Syndra','Talon','Vi','Viktor','Xayah','Yuumi',
]

# Word-boundary pattern: blocks "Viktor", "Viktor Kesler", "The Viktor" but
# not "Victoria", "Viktor2", "MyViktor".
PERSONA_RE = re.compile(
    r'\b(' + '|'.join(re.escape(n) for n in PERSONA_NAMES) + r')\b',
    re.IGNORECASE,
)

command = os.environ.get('SHLEX_CMD', '')

# Fast pre-check: if command doesn't contain "git" and "commit" at all, pass.
if 'git' not in command or 'commit' not in command:
    sys.exit(0)

try:
    tokens = shlex.split(command)
except ValueError:
    # Unterminated quotes etc — can't parse; pass through (no false block)
    sys.exit(0)

# Check whether this is a git commit invocation.
git_idx = None
for i, tok in enumerate(tokens):
    if tok == 'git':
        git_idx = i
        break

if git_idx is None:
    sys.exit(0)

# Scan tokens after "git" for "commit" (allowing flags before it)
has_commit = False
for tok in tokens[git_idx + 1:]:
    if tok == 'commit':
        has_commit = True
        break
    # Stop scanning at shell separator tokens
    if tok in (';', '|', '&&', '||', '&'):
        break

if not has_commit:
    sys.exit(0)

# It's a git commit command. Scan all tokens for identity overrides.

def check_email_value(val):
    return '@strawberry.local' in val

def check_name_value(val):
    return bool(PERSONA_RE.search(val))

# ENV VAR tokens: appear as leading tokens before "git" (shell env prefix syntax)
env_var_prefixes_email = ('GIT_AUTHOR_EMAIL=', 'GIT_COMMITTER_EMAIL=')
env_var_prefixes_name  = ('GIT_AUTHOR_NAME=', 'GIT_COMMITTER_NAME=')

for tok in tokens:
    for pfx in env_var_prefixes_email:
        if tok.startswith(pfx):
            val = tok[len(pfx):]
            if check_email_value(val):
                sys.stdout.write('{"decision":"block","reason":"[identity-guard] Blocked: GIT_AUTHOR_*/GIT_COMMITTER_* env var override with persona identity (@strawberry.local). Remove the env var override."}\n')
                sys.exit(2)
    for pfx in env_var_prefixes_name:
        if tok.startswith(pfx):
            val = tok[len(pfx):]
            if check_name_value(val):
                sys.stdout.write('{"decision":"block","reason":"[identity-guard] Blocked: GIT_AUTHOR_NAME or GIT_COMMITTER_NAME env var set to persona name. Remove the env var override; identity is managed by the universal hook."}\n')
                sys.exit(2)

# -c KEY=VALUE tokens: git -c user.email=X  or  git -c user.name=X
for i, tok in enumerate(tokens):
    if tok == '-c' and i + 1 < len(tokens):
        kv = tokens[i + 1].strip()
        if '=' in kv:
            key, val = kv.split('=', 1)
            key = key.strip()
            if key == 'user.email' and check_email_value(val):
                sys.stdout.write('{"decision":"block","reason":"[identity-guard] Blocked: inline git -c user.email= override with persona identity (@strawberry.local). Remove the -c override; identity is managed by the universal hook."}\n')
                sys.exit(2)
            if key == 'user.name' and check_name_value(val):
                sys.stdout.write('{"decision":"block","reason":"[identity-guard] Blocked: inline git -c user.name= override with persona name. Remove the -c override; identity is managed by the universal hook."}\n')
                sys.exit(2)

# --author flag: --author=VALUE (one token) or --author VALUE (two tokens)
author_value = None
for i, tok in enumerate(tokens):
    if tok.startswith('--author='):
        author_value = tok[len('--author='):].strip()
        break
    if tok == '--author' and i + 1 < len(tokens):
        author_value = tokens[i + 1].strip()
        break

if author_value is not None:
    if check_email_value(author_value):
        sys.stdout.write('{"decision":"block","reason":"[identity-guard] Blocked: git commit --author with persona identity (@strawberry.local). Remove the --author flag; identity is managed by the universal hook."}\n')
        sys.exit(2)
    if check_name_value(author_value):
        sys.stdout.write('{"decision":"block","reason":"[identity-guard] Blocked: git commit --author with persona name. Remove the --author flag; identity is managed by the universal hook."}\n')
        sys.exit(2)

sys.exit(0)
PYEOF

SCANNER_OUTPUT="$(SHLEX_CMD="$COMMAND" python3 "$_SCANNER_TMP" 2>/dev/null)"
SCANNER_EXIT=$?
rm -f "$_SCANNER_TMP"

if [ "$SCANNER_EXIT" -eq 2 ]; then
  printf '%s\n' "$SCANNER_OUTPUT"
  exit 2
elif [ "$SCANNER_EXIT" -ne 0 ]; then
  block "shlex scanner exited $SCANNER_EXIT — commit blocked to prevent identity leak."
fi

# Resolve effective cwd: try tool_input.cwd then fall back to $PWD
CWD="$(printf '%s' "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('cwd',''))" 2>/dev/null)" || block "JSON parse failure on cwd — commit blocked to prevent identity leak."
if [ -z "$CWD" ]; then
  CWD="${PWD:-}"
fi

if [ -z "$CWD" ] || [ ! -d "$CWD" ]; then
  exit 0
fi

# Check if cwd is inside a git repo (exit 0 if not — no origin required)
if ! git -C "$CWD" rev-parse --git-dir >/dev/null 2>&1; then
  exit 0
fi

# Universal: enforce neutral identity on all git repos (no origin gate)
if ! git -C "$CWD" config --local user.name "$NEUTRAL_NAME" 2>/dev/null; then
  printf '{"decision":"block","reason":"[identity-guard] Failed to set user.name in worktree — commit blocked to prevent identity leak."}\n'
  exit 2
fi

if ! git -C "$CWD" config --local user.email "$NEUTRAL_EMAIL" 2>/dev/null; then
  printf '{"decision":"block","reason":"[identity-guard] Failed to set user.email in worktree — commit blocked to prevent identity leak."}\n'
  exit 2
fi

# Success — config rewritten, proceed silently
exit 0
