# 2026-04-19 PR #35 + #37 Review Fixes

## Context
Jhin posted REQUEST_CHANGES reviews on two open PRs in strawberry-app:
- PR #35 (feat/usage-dashboard-refresh-server): CORS guard missing on GET /health
- PR #37 (feat/usage-dashboard-sbu): `open` not cross-platform, violates CLAUDE.md rule 10

## Key Learnings

### Merge conflict from force-pushed remote branch
The remote feat/usage-dashboard-sbu branch had been force-updated (possibly
by another session or squash). `git push` was rejected. Used `git fetch` +
`git merge origin/...` (per rule 11: always merge, never rebase). Resolved
add/add conflicts by keeping local changes (open_url + test 4) and the
remote's test 3. Committed merge as a separate commit.

### Symlink farm for PATH isolation in shell tests
To stub `open`/`xdg-open`/`start` absent from PATH while still providing
`dirname`, `nohup`, etc. (which live in `/usr/bin` on macOS), built a
synthetic bin dir with `ln -sf` for all `/bin` and `/usr/bin` executables
except the three targets. Used `case` statement in sh loop. Then replaced
`/usr/bin` in PATH with `fakeBin`. This approach works on macOS and avoids
the fragility of filtering PATH entries by regex alone.

### In-flight guard + child tracking in Node HTTP server
- `let building = false` + early 409 is trivial and safe to add as a
  non-blocking suggestion if implementation is < 5 lines
- `let activeChild = null` pattern: set on spawn entry, clear in both
  `close` and `error` callbacks, kill in shutdown handler

### open_url() shell function pattern
Three-way command check in POSIX sh:
```sh
open_url() {
  _url="$1"
  if command -v open >/dev/null 2>&1; then open "$_url"
  elif command -v xdg-open >/dev/null 2>&1; then xdg-open "$_url"
  elif command -v start >/dev/null 2>&1; then start "$_url"
  else printf '...hint...\n' >&2; return 1
  fi
}
```
Using local variable `_url` with underscore prefix avoids collision with
calling-scope variables in sh (no `local` keyword in POSIX sh).

### Test port numbering
Stagger test ports with BASE_PORT + N to avoid collisions across parallel
tests. Used BASE_PORT = 47660 in this codebase.
