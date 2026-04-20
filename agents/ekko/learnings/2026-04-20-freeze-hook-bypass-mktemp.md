# Learnings: freeze hook bypass + mktemp portability

Date: 2026-04-20

## freeze hook COMMIT_EDITMSG resolution

When a pre-commit hook reads `${GIT_DIR}/COMMIT_EDITMSG` and `GIT_DIR` is a relative path
(which is git's default — it returns `.git`, not an absolute path), the lookup fails if the
shell's cwd is not the repo root.

Fix: resolve `GIT_DIR` to an absolute path before constructing the file path:

```sh
_raw_git_dir="${GIT_DIR:-$(git rev-parse --git-dir 2>/dev/null)}"
case "$_raw_git_dir" in
  /*) _abs_git_dir="$_raw_git_dir" ;;
  *)  _abs_git_dir="$(cd "$_raw_git_dir" 2>/dev/null && pwd)" ;;
esac
COMMIT_MSG_FILE="${_abs_git_dir}/COMMIT_EDITMSG"
```

In tests, use `git rev-parse --absolute-git-dir` when building the GIT_DIR env var passed to
hook invocations — this avoids the relative-path trap.

## mktemp portability

`mktemp --suffix=.md` is Linux-only. macOS mktemp requires the template to end in X's:

- BAD (Linux-only): `mktemp --suffix=.md`
- GOOD (POSIX):     `mktemp /tmp/some-prefix-XXXXXX`

If a `.md` extension is needed, add it after: `f=$(mktemp /tmp/prefix-XXXXXX); mv "$f" "$f.md"`.
But for scratch files that don't need a specific extension, the plain template is enough.

## Bug 3 / re-publish status

All 54 plan-publish calls failed with "missing credential file: secrets/google-client-id.env".
The Google OAuth credentials need to be decrypted first (via tools/decrypt.sh from the
encrypted .age blob). This is a session setup step that requires Duong's age key — not a
code bug. The plan-publish.sh fix (Bug 2) is correct; publish just can't run without creds.
