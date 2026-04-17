#!/usr/bin/env bash
# scripts/hooks/pre-commit-secrets-guard.sh
#
# Pyke Required Edit #8: tooling-level guards for the encrypted-secrets system.
#
# Runs against the staged tree (NOT the working tree) and fails the commit if:
#
#   1. Any staged file outside `secrets/encrypted/` contains the literal
#      `BEGIN AGE ENCRYPTED FILE` armor header. (Catches "I accidentally
#      pasted ciphertext into a memory file" and the inverse "I dumped a
#      decrypted blob to a debug log.")
#
#   2. Any staged file contains a raw `age -d` invocation outside the
#      sanctioned helpers in `tools/decrypt.*` and `scripts/secret-*`.
#      Decryption must go through the helper so the env-var-into-child-process
#      discipline is enforced and so future scrubbers can be added in one place.
#
#   3. Any staged file contains a high-entropy bearer-token-shaped string
#      (sk-..., ghp_..., xoxb-..., xoxp-..., AKIA..., long base64) outside
#      the gitleaks allowlist paths. This is a cheap heuristic backup; the
#      real defense is gitleaks itself.
#
#   4. (Active) If the .age private key file (`secrets/age-key.txt`) exists,
#      decrypt all `secrets/encrypted/*.age` blobs into a tmpfs-style
#      directory inside the repo and scan staged files for any of the
#      decrypted plaintext values. The decrypted directory is wiped
#      unconditionally on exit (including on signals and errors).
#
# Run this from `.git/hooks/pre-commit` (which is just a one-line shim).
#
# Exit codes:
#   0  ok, allow commit
#   1  guard tripped, abort commit
#   2  internal error (missing tools etc.) — does NOT abort commit, prints warning

set -uo pipefail
LC_ALL=C
export LC_ALL

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0

cd "$REPO_ROOT" || exit 0

fail=0
warn() { printf 'pre-commit-secrets-guard: %s\n' "$*" >&2; }
trip() { warn "BLOCK: $*"; fail=1; }

# Collect staged file list (added/modified/copied/renamed). NUL-delimited.
# mapfile requires bash 4+; use read loop for bash 3.2 compatibility (macOS).
staged=()
while IFS= read -r -d '' f; do
    staged+=("$f")
done < <(git diff --cached --name-only --diff-filter=ACMR -z)

if [[ ${#staged[@]} -eq 0 ]]; then
    exit 0
fi

# ---------------------------------------------------------------------------
# Guard 1: BEGIN AGE ENCRYPTED FILE outside secrets/encrypted/
# ---------------------------------------------------------------------------
# Self-meta paths that legitimately mention the armor header in comments,
# vendored libraries, or policy files.
header_allowlist_pattern='^(secrets/encrypted/|tools/age-bundle\.js$|scripts/hooks/pre-commit-secrets-guard\.sh$|\.gitleaks\.toml$|secrets/README\.md$|architecture/security-debt\.md$|plans/|agents/.*/learnings/|agents/.*/journal/|CLAUDE\.md$)'
for f in "${staged[@]}"; do
    if [[ "$f" =~ $header_allowlist_pattern ]]; then continue; fi
    # Use git show to read the staged blob, not the working tree.
    if git show ":$f" 2>/dev/null | grep -Fq 'BEGIN AGE ENCRYPTED FILE'; then
        trip "$f contains 'BEGIN AGE ENCRYPTED FILE' but is outside secrets/encrypted/"
    fi
done

# ---------------------------------------------------------------------------
# Guard 2: raw `age -d` outside the sanctioned helpers
# ---------------------------------------------------------------------------
allowed_decrypt_pattern='^(tools/decrypt\.|scripts/secret-|scripts/hooks/pre-commit-secrets-guard\.sh|plans/|architecture/|secrets/README\.md|CLAUDE\.md$|agents/.*/learnings/|agents/.*/journal/|agents/.*/memory/.*\.md$|agents/.*/transcripts/|tools/age-bundle\.js$)'
for f in "${staged[@]}"; do
    if [[ "$f" =~ $allowed_decrypt_pattern ]]; then continue; fi
    case "$f" in
        .git/*|.gitleaks.toml) continue ;;
    esac
    # Match `age -d` only on lines that aren't comment-only. We strip leading
    # whitespace + comment markers (`#`, `//`) before testing so prose like
    # "# we never call age -d here" doesn't trip the guard.
    if git show ":$f" 2>/dev/null \
        | sed -E 's/^[[:space:]]*(#|\/\/).*$//' \
        | grep -Eq '(^|[[:space:]"`'\''(])age[[:space:]]+-d([[:space:]]|$)'; then
        trip "$f calls raw 'age -d' — use tools/decrypt.sh instead"
    fi
done

# ---------------------------------------------------------------------------
# Guard 3: known bearer-token shapes outside gitleaks allowlist
# ---------------------------------------------------------------------------
# Patterns we explicitly look for. Cheap heuristic; gitleaks does the heavy
# lifting in CI / standalone runs.
token_patterns='(sk-[A-Za-z0-9_-]{20,}|ghp_[A-Za-z0-9]{30,}|gho_[A-Za-z0-9]{30,}|xox[bp]-[A-Za-z0-9-]{20,}|AKIA[0-9A-Z]{16})'
allowlist_pattern='^(secrets/encrypted/|secrets/recipients\.txt$|tools/encrypt\.html$|tools/encrypt\.html\.sha256$|tools/age-bundle\.js$|plans/|agents/.*/journal/|agents/.*/learnings/|\.gitleaks\.toml$|scripts/hooks/pre-commit-secrets-guard\.sh$)'
for f in "${staged[@]}"; do
    if [[ "$f" =~ $allowlist_pattern ]]; then continue; fi
    if git show ":$f" 2>/dev/null | grep -Eq "$token_patterns"; then
        trip "$f contains a string shaped like a real bearer token (sk-/ghp_/xoxb-/AKIA...)"
    fi
done

# ---------------------------------------------------------------------------
# Guard 4: scrub-and-detect against decrypted secret values
# ---------------------------------------------------------------------------
# Only runs if age binary + private key + at least one .age blob exist.
KEY_FILE="$REPO_ROOT/secrets/age-key.txt"
if command -v age >/dev/null 2>&1 && [[ -f "$KEY_FILE" ]]; then
    # Use a tmpfs-like dir under the repo so it never traverses /tmp scanners.
    scratch="$(mktemp -d "$REPO_ROOT/secrets/.scrub.XXXXXX" 2>/dev/null || true)"
    if [[ -n "$scratch" && -d "$scratch" ]]; then
        # shellcheck disable=SC2064
        trap "rm -rf '$scratch' 2>/dev/null" EXIT INT TERM HUP

        # Decrypt every blob (including subdirs) into the scratch area.
        while IFS= read -r -d '' blob; do
            outfile="$scratch/$(printf '%s' "${blob#secrets/encrypted/}" | tr '/' '_').plain"
            age -d -i "$KEY_FILE" -o "$outfile" "$blob" 2>/dev/null || continue
        done < <(git ls-files -z 'secrets/encrypted/*.age')

        # Build the value list. Each line of each plain file is a candidate
        # secret. We split on '=' and take the right-hand side (handles
        # KEY=value lines), and we also keep the whole line as a fallback
        # for raw-blob secrets.
        values_file="$scratch/.values"
        : > "$values_file"
        for plain in "$scratch"/*.plain; do
            [[ -f "$plain" ]] || continue
            # Extract RHS of KEY=value lines
            grep -E '^[A-Za-z_][A-Za-z0-9_]*=' "$plain" 2>/dev/null \
                | sed -E 's/^[^=]+=//' >> "$values_file" || true
            # Also include the full file contents trimmed (raw single-secret blob)
            tr -d '\r\n' < "$plain" >> "$values_file"
            printf '\n' >> "$values_file"
        done

        # Filter: skip empty and very-short values to avoid trivial matches.
        sort -u "$values_file" 2>/dev/null | awk 'length($0) >= 8' > "$scratch/.values.uniq"

        if [[ -s "$scratch/.values.uniq" ]]; then
            for f in "${staged[@]}"; do
                # Don't scan the encrypted blobs themselves (their plaintext
                # is the value we're looking for; obviously the cipher contains it).
                case "$f" in
                    secrets/encrypted/*) continue ;;
                    secrets/age-key.txt) continue ;;
                esac
                # grep -F -f against the staged blob; tee /dev/null suppresses match output
                if git show ":$f" 2>/dev/null | grep -Fqf "$scratch/.values.uniq"; then
                    trip "$f contains a string matching a known decrypted secret value"
                fi
            done
        fi

        # Scrub the scratch area immediately (trap also covers signal exit).
        rm -rf "$scratch" 2>/dev/null || true
        trap - EXIT INT TERM HUP
    fi
fi

if [[ "$fail" -ne 0 ]]; then
    warn "commit blocked. fix the above and re-stage."
    exit 1
fi
exit 0
