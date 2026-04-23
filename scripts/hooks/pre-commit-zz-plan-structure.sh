#!/bin/sh
# pre-commit-zz-plan-structure.sh — Pre-commit structural linter for plan files.
#
# Plan: plans/approved/personal/2026-04-21-plan-prelint-shift-left.md
# Supersedes: scripts/hooks/pre-commit-t-plan-structure.sh
#
# Checks every staged plans/**/*.md (except plans/_template.md and
# plans/archived/**) for structural validity.
#
# Rules enforced (Orianna-parity):
#   1. Canonical `## Tasks` or `## N. Tasks` heading required
#   2. Per-task estimate_minutes: <int in [1,60]> key:value on task line
#   3. Test-task qualifier: xfail/test/regression task title must begin with
#      Write/Add/Create/Update or carry kind: test token
#   4. Cited backtick paths must exist on disk (<!-- orianna: ok --> suppresses)
#   5. Forward self-reference requires <!-- orianna: ok --> suppression
#
# Uses a single awk pass over ALL staged plan files for performance.
# Target: < 200ms for 10 staged plans.
#
# Exit 0 — all staged plan files pass structural checks.
# Exit 1 — one or more staged plan files have BLOCK findings (printed to stderr).
#
# POSIX sh (Rule 10). No gawk extensions.

set -e

# Resolve repo root: prefer git's answer (honours GIT_WORK_TREE env var set by test
# harnesses that run the hook against a temp repo); fall back to script-relative path.
_hook_dir="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo '')"
if [ -z "$REPO_ROOT" ]; then
  REPO_ROOT="$(cd "$_hook_dir/../.." && pwd)"
fi

# 1. Get list of staged plan files (added, copied, modified, renamed).
#    Use --name-status so we can distinguish R (rename) from A/C/M.
#    name-status output: "<status>\t<path>" for A/C/M, "<status>\t<old>\t<new>" for R.
#    Positive path filter: only plans/**/*.md — non-plan .md files (agent defs,
#    docs, learnings, memory) must not be linted even when they carry YAML
#    frontmatter. For R entries the filter matches on the new path.
staged_plans_raw="$(git diff --cached --name-status --diff-filter=ACMR 2>/dev/null | grep -E $'(^[ACM][^\t]*\tplans/.*\\.md$|^R[0-9]*\t[^\t]*\tplans/.*\\.md$)' || true)"

if [ -z "$staged_plans_raw" ]; then
  exit 0
fi

# 2. Filter: exclude template and archived plans; collect absolute paths into a temp file.
#    Also build a rename-map temp file: for R entries record "new_abs\told_rel" so the
#    staged-lines builder can compute a true blob-to-blob diff for renamed plans.
_filter_tmp="$(mktemp /tmp/pre-commit-zz-plan-structure-XXXXXX.tmp)"
_rename_map_tmp="$(mktemp /tmp/pre-commit-zz-rename-map-XXXXXX.tmp)"
trap 'rm -f "$_filter_tmp" "$_rename_map_tmp"' EXIT INT HUP TERM

printf '%s\n' "$staged_plans_raw" | while IFS='	' read -r status f1 f2; do
  # f1 = old path (rename) or only path (A/C/M); f2 = new path (rename) or empty.
  # Determine the new path (the file we will lint).
  case "$status" in
    R*) new_rel="$f2" ; old_rel="$f1" ;;
    *)  new_rel="$f1" ; old_rel="" ;;
  esac
  # Apply filters on new_rel
  case "$new_rel" in
    plans/_template.md|plans/archived/*|plans/implemented/*|plans/pre-orianna/*) continue ;;
  esac
  # Block paths with spaces
  case "$new_rel" in
    *\ *) printf '[pre-commit-zz-plan-structure] BLOCK: plan path contains a space (not allowed): %s\n' "$new_rel" >&2; exit 1 ;;
  esac
  new_abs="$REPO_ROOT/$new_rel"
  [ -f "$new_abs" ] || continue
  printf '%s\n' "$new_abs" >> "$_filter_tmp"
  # Record rename mapping (new_abs<TAB>old_rel) for the staged-lines builder.
  if [ -n "$old_rel" ]; then
    printf '%s\t%s\n' "$new_abs" "$old_rel" >> "$_rename_map_tmp"
  fi
done

if [ ! -s "$_filter_tmp" ]; then
  rm -f "$_filter_tmp" "$_rename_map_tmp"
  exit 0
fi

# 3a. Build staged-line map: for each staged plan file, record which absolute
#     line numbers appear in the diff hunk (rule 4 only validates those lines).
#     Format written to temp file: "<abs_path>:<linenum>" (one per line).
#     New files (entire content is staged) include every line via +N,M hunks.
#
#     Rename-aware: for R entries we compute a true blob-to-blob diff between
#     the old blob (HEAD:<old_path>) and the new file content in the index.
#     This yields only lines that actually changed, not the full body.
#     Pure R100 renames produce zero added lines → Rule 4 becomes a no-op.
#     Defensive fallback: if the blob diff fails, we emit a WARN and mark the
#     file as fully-staged (safe baseline matching pre-fix behaviour).
_staged_lines_tmp="$(mktemp /tmp/pre-commit-zz-staged-lines-XXXXXX.tmp)"
trap 'rm -f "$_filter_tmp" "$_rename_map_tmp" "$_staged_lines_tmp"' EXIT INT HUP TERM

_extract_hunk_lines() {
  # Read hunk headers from stdin; write "abs:linenum" lines to stdout.
  # Args: $1 = abs path for output prefix.
  local abs="$1"
  grep '^@@' | \
    while IFS= read -r hunk; do
      # Anchored extraction: `@@ -<old> +<start>[,<count>] @@ <context>`
      # sed -E captures group 1 = start, group 2 = ,count (optional).
      new_part="$(printf '%s' "$hunk" | sed -E 's/^@@ -[^ ]+ \+([0-9]+(,[0-9]+)?) @@.*/\1/')"
      # If sed found no match new_part equals the original hunk line — skip.
      case "$new_part" in @@*) continue ;; esac
      start="$(printf '%s' "$new_part" | cut -d, -f1)"
      count_part="$(printf '%s' "$new_part" | cut -s -d, -f2)"
      count="${count_part:-1}"
      i=0
      while [ "$i" -lt "$count" ]; do
        printf '%s:%d\n' "$abs" "$((start + i))"
        i=$((i + 1))
      done
    done
}

while IFS= read -r abs; do
  rel="${abs#$REPO_ROOT/}"

  # Check if this file is a rename by looking up the rename map.
  old_rel=""
  if [ -s "$_rename_map_tmp" ]; then
    old_rel="$(grep -F "$abs	" "$_rename_map_tmp" | cut -f2 | head -1 || true)"
  fi

  if [ -n "$old_rel" ]; then
    # Rename path: compute blob-to-blob diff between HEAD:<old_rel> and the
    # new file content in the index (git show :<new_rel> for the indexed blob).
    # Approach:
    #   1. Extract old blob to a temp file.
    #   2. Extract new index blob to a temp file.
    #   3. diff --no-index --unified=0 old_tmp new_tmp to get hunk headers.
    #   4. Parse hunk headers the same way as the A/M path.
    # Fallback: if git show fails (e.g. file not in HEAD), emit WARN and fall
    # back to the cached diff (overzealous-but-safe baseline).
    _old_tmp="$(mktemp /tmp/pre-commit-zz-old-blob-XXXXXX.tmp)"
    _new_tmp="$(mktemp /tmp/pre-commit-zz-new-blob-XXXXXX.tmp)"
    # Extract old blob from HEAD
    if git show "HEAD:$old_rel" > "$_old_tmp" 2>/dev/null; then
      # Extract new blob from the index (staged version)
      if git show ":$rel" > "$_new_tmp" 2>/dev/null; then
        # diff --no-index exits 1 when files differ (normal), exits 0 when identical,
        # exits 2 on error. We capture the diff output regardless of exit code.
        diff --unified=0 -- "$_old_tmp" "$_new_tmp" 2>/dev/null | \
          _extract_hunk_lines "$abs" >> "$_staged_lines_tmp" || true
      else
        printf '[pre-commit-zz-plan-structure] WARN: could not extract indexed blob for %s; falling back to cached diff\n' "$rel" >&2
        git diff --cached --unified=0 -- "$rel" 2>/dev/null | \
          _extract_hunk_lines "$abs" >> "$_staged_lines_tmp" || true
      fi
    else
      printf '[pre-commit-zz-plan-structure] WARN: could not extract HEAD blob for %s; falling back to cached diff\n' "$old_rel" >&2
      git diff --cached --unified=0 -- "$rel" 2>/dev/null | \
        _extract_hunk_lines "$abs" >> "$_staged_lines_tmp" || true
    fi
    rm -f "$_old_tmp" "$_new_tmp"
  else
    # A/M/C path: use the cached diff directly (existing behaviour).
    # git diff --cached --unified=0 shows only hunk headers with no context.
    # Hunk header format: @@ -old +new_start[,new_count] @@
    # Extract new-side line ranges and enumerate individual line numbers.
    # Parse hunk headers with a single anchored sed — works on BSD and GNU sed.
    # Pattern is anchored to `^@@ -<old> +<new> @@` so the trailing context
    # (which may contain arbitrary `+<digits>` strings) cannot confuse parsing.
    # The gawk 3-arg match() primary + greedy-sed fallback is removed: the
    # primary was dead code on macOS (BSD awk rejects 3-arg match at parse time),
    # and the greedy sed misparses any hunk header whose context contained `+N`.
    git diff --cached --unified=0 -- "$rel" 2>/dev/null | \
      _extract_hunk_lines "$abs" >> "$_staged_lines_tmp" || true
  fi
done < "$_filter_tmp"

# 3. Single awk pass over all plan files (POSIX awk — no ENDFILE extension).
#    Tracks file boundaries via FNR==1 to flush per-file state.
_awk_rc=0
awk -v REPO_ROOT="$REPO_ROOT" -v STAGED_LINES_FILE="$_staged_lines_tmp" '
  BEGIN {
    # Load staged-line map from temp file into staged[filepath SUBSEP linenum]=1.
    # Rule 4 uses this to skip validation on lines not in the staged diff.
    while ((getline _sl < STAGED_LINES_FILE) > 0) {
      # _sl is "abs_path:linenum"
      _colon = length(_sl)
      while (_colon > 0 && substr(_sl, _colon, 1) != ":") _colon--
      if (_colon > 1) {
        _slpath = substr(_sl, 1, _colon - 1)
        _slnum  = substr(_sl, _colon + 1) + 0
        staged[_slpath SUBSEP _slnum] = 1
      }
    }
    close(STAGED_LINES_FILE)
  }

  function flush_file(fname,    i, path, cmd, rc) {
    if (!_started) return

    # --- Rule 1: canonical ## Tasks heading required ---
    if (!has_canonical_tasks) {
      if (has_task_variant) {
        print "[lib-plan-structure] BLOCK: no canonical ## Tasks heading found (variant: " task_variant_found " is not accepted)" > "/dev/stderr"
      } else {
        print "[lib-plan-structure] BLOCK: missing required ## Tasks section" > "/dev/stderr"
      }
      file_fail = 1
    }

    # --- Frontmatter checks ---
    if (!has_status) {
      print "[lib-plan-structure] BLOCK: missing required frontmatter field: `status:`" > "/dev/stderr"
      file_fail = 1
    }
    if (!has_concern) {
      print "[lib-plan-structure] BLOCK: missing required frontmatter field: `concern:`" > "/dev/stderr"
      file_fail = 1
    }
    if (!has_owner) {
      print "[lib-plan-structure] BLOCK: missing required frontmatter field: `owner:`" > "/dev/stderr"
      file_fail = 1
    }
    if (!has_created) {
      print "[lib-plan-structure] BLOCK: missing required frontmatter field: `created:`" > "/dev/stderr"
      file_fail = 1
    }
    if (!has_tests_required) {
      print "[lib-plan-structure] BLOCK: missing required frontmatter field: `tests_required:`" > "/dev/stderr"
      file_fail = 1
    }

    # --- Test plan check ---
    if (tests_required_val != "false" && tests_required_val != "False" && tests_required_val != "FALSE") {
      if (!has_test_plan_content) {
        print "[lib-plan-structure] BLOCK: tests_required is true but `## Test plan` section is missing or empty" > "/dev/stderr"
        file_fail = 1
      }
    }

    if (file_fail) {
      print "[pre-commit-zz-plan-structure] BLOCKED: " fname > "/dev/stderr"
      total_fail++
    }
  }

  function reset_file(fname,    parts, n, i, slug) {
    flush_file(prev_file)
    # Reset per-file state
    in_fm = 0; fm_open = 0; fm_done = 0
    in_tasks = 0; in_test_plan = 0; in_code_fence = 0
    has_status = 0; has_concern = 0; has_owner = 0
    has_created = 0; has_tests_required = 0
    tests_required_val = "true"
    has_test_plan_content = 0
    has_canonical_tasks = 0; has_task_variant = 0; task_variant_found = ""
    hours_flagged = 0; days_flagged = 0; weeks_flagged = 0
    hparen_flagged = 0; dparen_flagged = 0
    file_fail = 0
    prev_file = fname
    _started = 1

    # Derive plan_slug and plan_phase from filename for rule 5
    # fname is absolute path like .../plans/<phase>/<concern>/<slug>.md
    # or .../plans/<phase>/<slug>.md
    plan_slug = ""
    plan_phase = ""
    # Extract relative portion after REPO_ROOT/plans/
    rel = fname
    prefix = REPO_ROOT "/plans/"
    if (index(rel, prefix) == 1) {
      rel = substr(rel, length(prefix) + 1)
      # rel is now e.g. "proposed/personal/2026-04-21-foo.md"
      # Extract phase (first path component)
      slash = index(rel, "/")
      if (slash > 0) {
        plan_phase = substr(rel, 1, slash - 1)
        rest = substr(rel, slash + 1)
        # slug is the final filename without .md extension
        last_slash = 0
        for (i = 1; i <= length(rest); i++) {
          if (substr(rest, i, 1) == "/") last_slash = i
        }
        if (last_slash > 0) {
          slug_file = substr(rest, last_slash + 1)
        } else {
          slug_file = rest
        }
        # Remove .md extension
        if (substr(slug_file, length(slug_file) - 2) == ".md") {
          plan_slug = substr(slug_file, 1, length(slug_file) - 3)
        } else {
          plan_slug = slug_file
        }
      }
    }
  }

  FNR == 1 { reset_file(FILENAME) }

  # --- Code fence tracking ---
  /^```/ { in_code_fence = !in_code_fence }

  # --- Frontmatter parsing ---
  FNR == 1 && /^---[[:space:]]*$/ { fm_open = 1; in_fm = 1; next }
  in_fm && /^---[[:space:]]*$/ { in_fm = 0; fm_done = 1; next }

  in_fm {
    if ($0 ~ /^status:/) {
      v = $0; sub(/^status:[[:space:]]*/, "", v); gsub(/^[[:space:]]+|[[:space:]]+$/, "", v)
      if (length(v) > 0) has_status = 1
    }
    if ($0 ~ /^concern:/) {
      v = $0; sub(/^concern:[[:space:]]*/, "", v); gsub(/^[[:space:]]+|[[:space:]]+$/, "", v)
      if (length(v) > 0) has_concern = 1
    }
    if ($0 ~ /^owner:/) {
      v = $0; sub(/^owner:[[:space:]]*/, "", v); gsub(/^[[:space:]]+|[[:space:]]+$/, "", v)
      if (length(v) > 0) has_owner = 1
    }
    if ($0 ~ /^created:/) {
      v = $0; sub(/^created:[[:space:]]*/, "", v); gsub(/^[[:space:]]+|[[:space:]]+$/, "", v)
      if (length(v) > 0) has_created = 1
    }
    if ($0 ~ /^tests_required:/) {
      v = $0; sub(/^tests_required:[[:space:]]*/, "", v); gsub(/^[[:space:]]+|[[:space:]]+$/, "", v)
      sub(/[[:space:]]*#.*$/, "", v)
      if (length(v) > 0) { has_tests_required = 1; tests_required_val = v }
    }
    next
  }

  !fm_done { next }

  # --- Section tracking (Rule 1 detection) ---
  /^## Tasks[[:space:]]*$/ || /^## [0-9]+\. Tasks[[:space:]]*$/ {
    has_canonical_tasks = 1
    in_tasks = 1; in_test_plan = 0; next
  }
  /^## Task[[:space:]]/ || /^## Tasks[[:space:]]*[([]/ {
    # Variant heading — record it but do not set has_canonical_tasks
    if (!has_task_variant) {
      task_variant_found = $0
      sub(/^## /, "", task_variant_found)
    }
    has_task_variant = 1
    in_tasks = 0; in_test_plan = 0; next
  }
  /^## Test plan[[:space:]]*$/ {
    in_test_plan = 1; in_tasks = 0; next
  }
  /^## / {
    in_tasks = 0; in_test_plan = 0; next
  }

  # --- ## Test plan content ---
  in_test_plan && /[^[:space:]]/ && !/^#/ { has_test_plan_content = 1 }

  # --- ## Tasks validation ---
  in_tasks && !in_code_fence {
    line = $0
    # Strip inline backtick spans for prose checks
    prose = line
    while (match(prose, /`[^`]*`/)) {
      prose = substr(prose, 1, RSTART-1) substr(prose, RSTART+RLENGTH)
    }

    # Task entry lines
    if (prose ~ /^- \[[ xX]\]/) {
      if (prose !~ /estimate_minutes:/) {
        print "[lib-plan-structure] BLOCK: task entry missing estimate_minutes: field (§D4): " line > "/dev/stderr"
        file_fail = 1
      } else {
        val = prose
        sub(/.*estimate_minutes:[[:space:]]*/, "", val)
        if (match(val, /^[0-9]+/)) {
          n = substr(val, 1, RLENGTH) + 0
          if (n < 1) {
            print "[lib-plan-structure] BLOCK: estimate_minutes: " n " is below minimum (1): " line > "/dev/stderr"
            file_fail = 1
          } else if (n > 60) {
            print "[lib-plan-structure] BLOCK: estimate_minutes: " n " exceeds maximum (60); task must be decomposed (§D4): " line > "/dev/stderr"
            file_fail = 1
          }
        } else if (match(val, /^-[0-9]+/)) {
          n = substr(val, 1, RLENGTH) + 0
          print "[lib-plan-structure] BLOCK: estimate_minutes: " n " is negative (must be 1-60): " line > "/dev/stderr"
          file_fail = 1
        } else {
          print "[lib-plan-structure] BLOCK: estimate_minutes value is not an integer in task: " line > "/dev/stderr"
          file_fail = 1
        }
      }

      # --- Rule 3: test-task title qualifier ---
      # Check if the task title contains xfail, test, or regression after the em-dash
      # Pattern: "- [ ] **Tx** — <qualifier> ..." where qualifier is xfail/test/regression
      # Only trigger if the FIRST WORD after the em-dash matches (case-insensitive)
      title_part = prose
      sub(/^- \[[ xX]\][[:space:]]*\*\*[^*]*\*\*[[:space:]]*[—-][[:space:]]*/, "", title_part)
      # Get the first word of title_part
      first_word = title_part
      sub(/[[:space:]].*/, "", first_word)
      # Lowercase first_word for comparison
      fw_lower = first_word
      fw_lower = tolower(first_word)
      if (fw_lower == "xfail" || fw_lower == "test" || fw_lower == "regression") {
        # This is a test-task. Check: approved verb OR kind: test
        # Approved verbs: Write, Add, Create, Update (first word check)
        # Since first_word IS the qualifier, the task violates rule 3 unless:
        # (a) it carries "kind: test" or (b) ... wait, first_word IS the qualifier word.
        # Rule 3 says: task title begins with one of {Write,Add,Create,Update} OR carries kind:test.
        # "title begins with" means the very first word after the em-dash is the approved verb.
        # If first_word is xfail/test/regression, it is NOT an approved verb.
        # So rule 3 blocks unless kind: test is present.
        if (prose !~ /kind:[[:space:]]*test/) {
          print "[lib-plan-structure] BLOCK: test-task qualifier (" first_word ") requires title to begin with Write/Add/Create/Update, or carry kind: test: " line > "/dev/stderr"
          file_fail = 1
        }
      }
    }

    # Banned unit literals (outside backtick spans)
    if (!hours_flagged && prose ~ /\bhours\b/) {
      print "[lib-plan-structure] BLOCK: alternative time unit \"hours\" found in ## Tasks section; use estimate_minutes only (§D4)" > "/dev/stderr"
      file_fail = 1; hours_flagged = 1
    }
    if (!days_flagged && prose ~ /\bdays\b/) {
      print "[lib-plan-structure] BLOCK: alternative time unit \"days\" found in ## Tasks section; use estimate_minutes only (§D4)" > "/dev/stderr"
      file_fail = 1; days_flagged = 1
    }
    if (!weeks_flagged && prose ~ /\bweeks\b/) {
      print "[lib-plan-structure] BLOCK: alternative time unit \"weeks\" found in ## Tasks section; use estimate_minutes only (§D4)" > "/dev/stderr"
      file_fail = 1; weeks_flagged = 1
    }
    if (!hparen_flagged && prose ~ /[0-9][[:space:]]*h\)/) {
      print "[lib-plan-structure] BLOCK: alternative time unit \"h)\" found in ## Tasks section; use estimate_minutes only (§D4)" > "/dev/stderr"
      file_fail = 1; hparen_flagged = 1
    }
    if (!dparen_flagged && prose ~ /[0-9][[:space:]]*\(d\)/) {
      print "[lib-plan-structure] BLOCK: alternative time unit \"(d)\" found in ## Tasks section; use estimate_minutes only (§D4)" > "/dev/stderr"
      file_fail = 1; dparen_flagged = 1
    }
  }

  # --- Rules 4 & 5: backtick path checks (outside frontmatter, code fences) ---
  # --- Rule T11.c: reason-required on new <!-- orianna: ok --> markers (staged lines only) ---
  fm_done && !in_code_fence {
    line = $0

    # Determine suppression state.
    # Both bare and reason forms suppress the path-existence check (rule 4/5).
    # Only NEW staged lines are checked for the reason-required rule (T11.c).
    suppressed = 0
    if (index(line, "<!-- orianna: ok") > 0) {
      suppressed = 1
    }

    # T11.c: reject bare <!-- orianna: ok --> (without reason) on staged lines only.
    # A bare marker: "<!-- orianna: ok -->" with NO non-empty text between "ok" and "-->".
    # A reason marker: "<!-- orianna: ok -- <text> -->" with at least one non-space char after "--".
    # Already-committed lines (not in staged[]) are grandfathered.
    #
    # Detection: if the line contains "<!-- orianna: ok -->" (the exact bare form),
    # AND the line does NOT match the reason-form pattern "<!-- orianna: ok -- [^ ]",
    # AND this line is newly staged → BLOCK.
    if ((FILENAME SUBSEP NR in staged) && index(line, "<!-- orianna: ok -->") > 0) {
      # Check if ANY reason form also exists on this line.
      # reason pattern: <!-- orianna: ok -- (at least one non-space, non-closing char after "-- ")
      # Allow any non-space first char including leading dash (F5).
      # Plan: plans/in-progress/personal/2026-04-22-orianna-speedups-pr19-fast-follow.md F5
      has_reason_form = (line ~ /<!-- orianna: ok -- [^ ]/)
      # Suppression exemption: if the line contains a backtick-quoted path token
      # (i.e., the marker is used to suppress Rule 4 or Rule 5), the bare form is
      # accepted — the presence of the suppressed path is its own implicit reason.
      has_backtick_token = (index(line, "`") > 0)
      if (!has_reason_form && !has_backtick_token) {
        print "[lib-plan-structure] BLOCK (T11.c): bare <!-- orianna: ok --> requires a reason suffix. Use: <!-- orianna: ok -- <reason> -->. See plans/in-progress/personal/2026-04-21-orianna-gate-speedups.md T11.c. Line: " line > "/dev/stderr"
        file_fail = 1
      }
    }

    # Extract all backtick-quoted tokens from the line
    rest = line
    while (match(rest, /`[^`]+`/)) {
      token = substr(rest, RSTART + 1, RLENGTH - 2)
      rest = substr(rest, RSTART + RLENGTH)

      # Rule 4: path-like token detection
      # A path token: contains a "." (with extension) OR contains "/"
      # AND does not start with http/https
      # AND is not a pure flag/option like --option
      is_path = 0
      if (index(token, "http://") == 1 || index(token, "https://") == 1) {
        is_path = 0
      } else if (substr(token, 1, 1) == "-") {
        is_path = 0  # flag/option
      } else if (substr(token, 1, 1) == "/") {
        is_path = 0  # absolute path — not validated (repo-relative only)
      } else if (token ~ /^[-a-zA-Z0-9_.\/]+[.][a-zA-Z0-9]+$/ || (index(token, "/") > 0 && token !~ /[[:space:]]/)) {
        is_path = 1
      }

      if (is_path && !suppressed) {
        # Rule 5: forward self-reference check
        # If token matches plans/<other-phase>/.../<plan_slug>.md where other-phase != plan_phase
        if (plan_slug != "" && plan_phase != "") {
          slug_with_ext = plan_slug ".md"
          # Check if token ends with our slug
          if (substr(token, length(token) - length(slug_with_ext) + 1) == slug_with_ext) {
            # Token references our slug. Check if it is a different phase.
            # Token like "plans/approved/personal/2026-04-21-foo.md"
            if (index(token, "plans/") == 1) {
              token_rest = substr(token, 7)  # after "plans/"
              slash_pos = index(token_rest, "/")
              if (slash_pos > 0) {
                token_phase = substr(token_rest, 1, slash_pos - 1)
                if (token_phase != plan_phase) {
                  print "[lib-plan-structure] BLOCK: forward self-reference to " token " (add <!-- orianna: ok --> to suppress): " line > "/dev/stderr"
                  file_fail = 1
                  continue
                }
              }
            }
          }
        }

        # Rule 4: check path exists on disk — only for lines in the staged diff.
        # Lines that were not modified in this commit are grandfathered: they
        # may contain legacy prose with path-like tokens that predate this hook.
        # (staged[] was populated in BEGIN from STAGED_LINES_FILE.)
        if (!(FILENAME SUBSEP NR in staged)) {
          # This line is not in the staged diff; skip rule-4 for it.
        } else {
          full_path = REPO_ROOT "/" token
          # Avoid shell-command injection: use awk file-read attempt instead of
          # piping through a subshell.  getline returns -1 on open failure (file
          # absent or unreadable) and >= 0 on success.  close() is a no-op when
          # getline returned -1 so it is safe to call unconditionally.
          _gl_rc = (getline _ < full_path)
          if (_gl_rc >= 0) { exists = "y"; close(full_path) } else { exists = "n" }
          if (exists != "y") {
            print "[lib-plan-structure] BLOCK: cited path does not exist: " token " (add <!-- orianna: ok --> to suppress for prospective paths): " line > "/dev/stderr"
            file_fail = 1
          }
        }
      }
    }
  }

  END {
    flush_file(prev_file)
    if (total_fail > 0) {
      print "[pre-commit-zz-plan-structure] Fix the BLOCK findings above before committing." > "/dev/stderr"
      exit 1
    }
    exit 0
  }
' $(tr '\n' ' ' < "$_filter_tmp") || _awk_rc=$?

exit "$_awk_rc"
