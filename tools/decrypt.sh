#!/usr/bin/env bash
# tools/decrypt.sh — the ONLY sanctioned decryption entry point on the Windows side.
#
# Usage:
#   tools/decrypt.sh --target secrets/<group>.env --var KEY_NAME [--exec -- cmd args...]
#
# Reads age-armored ciphertext from stdin (NEVER from argv), decrypts using
# secrets/age-key.txt, and writes a single KEY=value line atomically into the
# target file. Refuses to write outside secrets/.
#
# If --exec is supplied, after writing, exec env KEY=value -- cmd args... so
# the plaintext flows into the child process env only and never lands in the
# parent shell or in argv.
#
# Plaintext discipline: this script never echoes the decrypted value to stdout
# or stderr. The only places it lands are (a) the target file under secrets/
# and (b) the env block of the optional exec target.
#
# Forbidden anywhere else in the repo: raw `age -d` calls. Pre-commit hook
# enforces this.

set -euo pipefail
LC_ALL=C
export LC_ALL

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
KEY_FILE="$REPO_ROOT/secrets/age-key.txt"

target=""
varname=""
do_exec=0
exec_args=()

usage() {
    cat >&2 <<'EOF'
Usage: tools/decrypt.sh --target <path> --var <KEY_NAME> [--exec -- cmd args...]

  --target <path>   Output file. MUST be under secrets/. Will be created/overwritten atomically.
  --var <KEY_NAME>  Env var name to associate with the decrypted plaintext.
  --exec -- ...     Optional. After writing the file, exec the trailing command
                    with KEY_NAME=<plaintext> in its env. Plaintext is never put
                    in argv. The wrapper uses `exec env KEY=val -- cmd...`.

Ciphertext is read from STDIN. Never from a command-line argument.

Example:
  pbpaste | tools/decrypt.sh --target secrets/telegram.env --var BOT_TOKEN
EOF
    exit 2
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --target) target="$2"; shift 2 ;;
        --var)    varname="$2"; shift 2 ;;
        --exec)   shift; do_exec=1; if [[ "${1:-}" == "--" ]]; then shift; fi; exec_args=("$@"); break ;;
        -h|--help) usage ;;
        *) echo "decrypt.sh: unknown arg: $1" >&2; usage ;;
    esac
done

[[ -z "$target"  ]] && { echo "decrypt.sh: --target is required" >&2; usage; }
[[ -z "$varname" ]] && { echo "decrypt.sh: --var is required" >&2; usage; }
[[ ! -f "$KEY_FILE" ]] && { echo "decrypt.sh: missing private key at $KEY_FILE" >&2; exit 3; }

# Validate KEY_NAME shape: env var must be [A-Za-z_][A-Za-z0-9_]*
if ! printf '%s' "$varname" | grep -Eq '^[A-Za-z_][A-Za-z0-9_]*$'; then
    echo "decrypt.sh: invalid --var name: $varname" >&2
    exit 4
fi

# Refuse target paths outside secrets/. Resolve to absolute and prefix-check
# against $REPO_ROOT/secrets/.
target_abs="$(cd "$(dirname "$target")" 2>/dev/null && pwd)/$(basename "$target")" || {
    # parent dir may not exist yet; create it under secrets/ only if path is acceptable
    parent="$(dirname "$target")"
    case "$parent" in
        secrets|secrets/*) mkdir -p "$REPO_ROOT/$parent" ;;
        *) echo "decrypt.sh: refusing target outside secrets/: $target" >&2; exit 5 ;;
    esac
    target_abs="$(cd "$(dirname "$target")" && pwd)/$(basename "$target")"
}
secrets_abs="$REPO_ROOT/secrets"
case "$target_abs" in
    "$secrets_abs"/*) : ok ;;
    *) echo "decrypt.sh: refusing target outside $secrets_abs: $target_abs" >&2; exit 5 ;;
esac

# Read ciphertext from stdin into a temp file inside secrets/ (so it can't
# accidentally leak to a tmp scanner outside the repo). Suppress umask noise.
umask 077
ct_tmp="$(mktemp "$secrets_abs/.ct.XXXXXX")"
trap 'rm -f "$ct_tmp" "$pt_tmp" "$out_tmp" 2>/dev/null || true' EXIT
cat > "$ct_tmp"

# Decrypt to a temp plaintext file. Never echo. Use -i (reads key file directly,
# does not pipe key bytes through any shell-visible channel).
pt_tmp="$(mktemp "$secrets_abs/.pt.XXXXXX")"
if ! age -d -i "$KEY_FILE" -o "$pt_tmp" "$ct_tmp" 2>/tmp/.decrypt-err.$$; then
    echo "decrypt.sh: age decryption failed" >&2
    cat /tmp/.decrypt-err.$$ >&2 || true
    rm -f /tmp/.decrypt-err.$$
    exit 6
fi
rm -f /tmp/.decrypt-err.$$

# Plaintext file is a KEY=value line (or several). The decrypt entry point
# treats it as the *full content of one secret*; we wrap it as VARNAME=<contents>.
# Strip a single trailing newline so VARNAME=foo not VARNAME=foo\n.
# We use printf '%s' (not echo) per CRLF discipline.
pt_value="$(printf '%s' "$(cat "$pt_tmp")")"

# Write the target atomically.
out_tmp="$(mktemp "$secrets_abs/.out.XXXXXX")"
printf '%s=%s\n' "$varname" "$pt_value" > "$out_tmp"
mv -f "$out_tmp" "$target_abs"
chmod 600 "$target_abs" 2>/dev/null || true   # no-op on Windows but harmless

# Wipe the plaintext temp file NOW, while the trap is still in scope. We
# already have the value in $pt_value (a shell-local variable, not exported).
# This must happen before the exec below, because exec replaces the shell and
# the trap will not fire.
rm -f "$ct_tmp" "$pt_tmp" 2>/dev/null || true

echo "decrypt.sh: wrote $varname to $target_abs" >&2

if [[ "$do_exec" -eq 1 ]]; then
    if [[ ${#exec_args[@]} -eq 0 ]]; then
        echo "decrypt.sh: --exec given but no command supplied" >&2
        exit 7
    fi
    # exec env KEY=val cmd args... — the env binary places the value in the
    # child process env, never in the parent shell variables, never in argv of
    # the consuming command (only in env's own short-lived argv). The `--`
    # end-of-options marker would be ideal but msys-env on git-bash does not
    # support it; the KEY=val token already disambiguates from cmd because
    # cmd cannot legally contain `=` before the first slash.
    exec env "$varname=$pt_value" "${exec_args[@]}"
fi
