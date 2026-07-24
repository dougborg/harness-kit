#!/usr/bin/env bash
# claude-usage-check.sh — read the Claude Code /usage panel non-interactively,
# parse the session + weekly percentages, and report whether we're near a cap.
#
# Two modes:
#   (default / "human")  Print a one-line status to stdout. Exit 0 always.
#   --hook               Emit nothing on stdout unless a threshold is crossed;
#                        when crossed, print a warning suitable for a hook to
#                        surface to the agent. Never blocks (always exit 0).
#
# Threshold: first arg or $CLAUDE_USAGE_WARN_PCT, default 85.
# Throttle:  re-parsing /usage spawns a short-lived `claude -p` each call, so
#            results are cached for $CLAUDE_USAGE_TTL seconds (default 180) in
#            a temp file; within the TTL we reuse the cached numbers.
#
# Parses lines like:
#   Current session: 94% used · resets Jul 23 at 10:20pm (America/Denver)
#   Current week (all models): 65% used · resets Jul 26 at 7pm (America/Denver)
#   Current week (Fable): 82% used · resets Jul 26 at 6:59pm (America/Denver)

set -uo pipefail

MODE="human"
[ "${1:-}" = "--hook" ] && { MODE="hook"; shift; }

THRESHOLD="${1:-${CLAUDE_USAGE_WARN_PCT:-85}}"
TTL="${CLAUDE_USAGE_TTL:-180}"
CACHE="${TMPDIR:-/tmp}/claude-usage-cache.$(id -u).txt"

now=$(date +%s)
raw=""

# Reuse cache if fresh.
if [ -f "$CACHE" ]; then
  # GNU stat uses -c %Y; BSD stat uses -f %m. Try GNU first (this box has nix
  # coreutils), fall back to BSD, then guard that we actually got a number.
  mtime=$(stat -c %Y "$CACHE" 2>/dev/null || stat -f %m "$CACHE" 2>/dev/null || echo 0)
  case "$mtime" in ''|*[!0-9]*) mtime=0 ;; esac
  if [ $((now - mtime)) -lt "$TTL" ]; then
    raw=$(cat "$CACHE")
  fi
fi

# Otherwise fetch fresh. /usage is a local client panel (no model turn), but
# guard with a timeout so a hung CLI never stalls a tool dispatch.
if [ -z "$raw" ]; then
  raw=$(cd / && timeout 30 claude -p "/usage" 2>/dev/null)
  [ -n "$raw" ] && printf '%s' "$raw" >"$CACHE"
fi

if [ -z "$raw" ]; then
  # Couldn't read usage — fail open (never block the agent), but say so in human mode.
  [ "$MODE" = "human" ] && echo "usage: unavailable (could not read /usage)"
  exit 0
fi

pct() { # $1 = grep pattern -> integer percent, or -1
  printf '%s\n' "$raw" | grep -iE "$1" | grep -oE '[0-9]+% used' | grep -oE '[0-9]+' | head -1
}
reset_of() { printf '%s\n' "$raw" | grep -iE "$1" | grep -oE 'resets[^(]*' | head -1 | sed 's/[[:space:]]*$//'; }

session=$(pct 'Current session'); session=${session:--1}
week_all=$(pct 'Current week \(all models\)'); week_all=${week_all:--1}
week_fable=$(pct 'Current week \(Fable\)'); week_fable=${week_fable:--1}

# Highest relevant utilization drives the warning.
worst=-1; worst_label=""
for pair in "session:$session" "weekly(all):$week_all" "weekly(Fable):$week_fable"; do
  label=${pair%%:*}; val=${pair##*:}
  if [ "$val" -gt "$worst" ] 2>/dev/null; then worst=$val; worst_label=$label; fi
done

status="session ${session}% · weekly-all ${week_all}% · weekly-Fable ${week_fable}%"

if [ "$MODE" = "human" ]; then
  echo "usage: $status (warn ≥${THRESHOLD}%)"
  [ "$worst" -ge "$THRESHOLD" ] 2>/dev/null && echo "⚠️  ${worst_label} at ${worst}% — near cap; right-size or defer subagent fan-outs."
  exit 0
fi

# --hook mode: emit a PreToolUse envelope. Always allow (warn-only, fail-open);
# attach additionalContext only when near a cap so the agent sees the warning.
# Unrecognized JSON on exit 0 is treated as normal flow, so this never blocks
# even on an older client that ignores the fields.
if [ "$worst" -ge "$THRESHOLD" ] 2>/dev/null; then
  session_reset=$(reset_of 'Current session')
  warn="⚠️ Budget check before dispatch: ${worst_label} at ${worst}% (${status}). ${session_reset:+Session ${session_reset}. }Right-size or defer subagent fan-outs; if near the session cap, bank remaining work and schedule a wake-up at reset."
  # JSON-escape via a tiny python (present everywhere); fall back to plain text.
  esc=$(printf '%s' "$warn" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))' 2>/dev/null)
  if [ -n "$esc" ]; then
    printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","additionalContext":%s}}\n' "$esc"
  else
    printf '%s\n' "$warn" >&2
  fi
fi
exit 0
