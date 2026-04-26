#!/usr/bin/env bash
# scripts/statusline/claude-usage.sh
# Claude Code statusline command — prints a one-line usage summary.
# Reads the statusline JSON from stdin; prints to stdout.
# Never exits non-zero (statusline must not crash Claude Code).
#
# Output format:
#   <model> | ctx <N>% | 5h <P>% (resets HH:MM) | 7d <Q>% (resets <weekday>)
# Missing fields → "--" placeholders.
#
# Wire-up: add to ~/.claude/settings.json:
#   {"statusLine":{"type":"command","command":"<abs-path>/scripts/statusline/claude-usage.sh"}}

set -uo pipefail

# --------------------------------------------------------------------------- #
# Helpers                                                                      #
# --------------------------------------------------------------------------- #

_epoch_to_hhmm() {
  local epoch="$1"
  if date -r "$epoch" +%H:%M 2>/dev/null; then
    return
  fi
  date -d "@$epoch" +%H:%M 2>/dev/null || printf '--:--'
}

_epoch_to_weekday() {
  local epoch="$1"
  if date -r "$epoch" +%a 2>/dev/null; then
    return
  fi
  date -d "@$epoch" +%a 2>/dev/null || printf '---'
}

_color() {
  # $1 = pct (integer or "--"), $2 = text to color
  local pct="$1" text="$2"
  if [ "$USE_COLOR" -eq 0 ] || [ "$pct" = "--" ]; then
    printf '%s' "$text"
    return
  fi
  if [ "$pct" -le 50 ]; then
    printf '\033[32m%s\033[0m' "$text"   # green
  elif [ "$pct" -le 80 ]; then
    printf '\033[33m%s\033[0m' "$text"   # yellow
  else
    printf '\033[31m%s\033[0m' "$text"   # red
  fi
}

# Degraded line used on any parse failure
_degraded() {
  printf '%s\n' '-- | ctx --% | 5h --% | 7d --%'
}

# --------------------------------------------------------------------------- #
# Color detection                                                               #
# --------------------------------------------------------------------------- #
USE_COLOR=0
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  USE_COLOR=1
fi

# --------------------------------------------------------------------------- #
# Read and parse stdin                                                         #
# --------------------------------------------------------------------------- #
RAW_INPUT="$(cat)"

if ! printf '%s' "$RAW_INPUT" | jq . >/dev/null 2>&1; then
  _degraded
  exit 0
fi

_jq() {
  printf '%s' "$RAW_INPUT" | jq -r "$1"
}

MODEL=$(_jq '.model.display_name // "--"')

CTX_RAW=$(_jq '.context_window.used_percentage // empty')
if [ -n "$CTX_RAW" ]; then
  CTX=$(printf '%.0f' "$CTX_RAW" 2>/dev/null || printf '%s' "$CTX_RAW")
else
  CTX="--"
fi

FH_PCT_RAW=$(_jq '.rate_limits.five_hour.used_percentage // empty')
if [ -n "$FH_PCT_RAW" ]; then
  FH_PCT=$(printf '%.0f' "$FH_PCT_RAW" 2>/dev/null || printf '%s' "$FH_PCT_RAW")
else
  FH_PCT="--"
fi

FH_EPOCH=$(_jq '.rate_limits.five_hour.resets_at // empty')
if [ -n "$FH_EPOCH" ]; then
  FH_TIME=$(_epoch_to_hhmm "$FH_EPOCH")
else
  FH_TIME="--:--"
fi

SD_PCT_RAW=$(_jq '.rate_limits.seven_day.used_percentage // empty')
if [ -n "$SD_PCT_RAW" ]; then
  SD_PCT=$(printf '%.0f' "$SD_PCT_RAW" 2>/dev/null || printf '%s' "$SD_PCT_RAW")
else
  SD_PCT="--"
fi

SD_EPOCH=$(_jq '.rate_limits.seven_day.resets_at // empty')
if [ -n "$SD_EPOCH" ]; then
  SD_DAY=$(_epoch_to_weekday "$SD_EPOCH")
else
  SD_DAY="---"
fi

# --------------------------------------------------------------------------- #
# Render                                                                       #
# --------------------------------------------------------------------------- #
FH_PART="$(_color "$FH_PCT" "5h ${FH_PCT}%") (resets ${FH_TIME})"
SD_PART="$(_color "$SD_PCT" "7d ${SD_PCT}%") (resets ${SD_DAY})"

printf '%s | ctx %s%% | %s | %s\n' "$MODEL" "$CTX" "$FH_PART" "$SD_PART"
