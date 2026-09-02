#!/usr/bin/env bash
# claude-usage-check.sh — read the Claude Code /usage panel non-interactively,
# parse the session + weekly percentages, and report whether we're near a cap.
#
# Two modes:
#   (default / "human")  Print a one-line status to stdout. Exit 0 always.
#   --hook               Emit nothing on stdout unless a threshold is crossed;
#                        when crossed, emit a PreToolUse JSON envelope carrying
#                        additionalContext only. Never blocks (always exit 0),
#                        and never sets permissionDecision — an "allow" would
#                        skip the interactive permission prompt for the call,
#                        which a warn-only hook must not do.
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
# The per-model weekly line's label varies by plan/model ((Fable), (Opus), ...),
# so any "Current week (<model>)" line that isn't "(all models)" is considered
# and the highest one wins.

set -uo pipefail

MODE="human"
[ "${1:-}" = "--hook" ] && { MODE="hook"; shift; }

# Codex loads Claude-compatible plugin hooks and marks its input with turn_id.
# This workflow measures Claude quota only, so silently skip it under Codex.
if [ "$MODE" = "hook" ] && [ ! -t 0 ]; then
  hook_input=$(cat)
  case "$hook_input" in
  *'"turn_id"'*) exit 0 ;;
  esac
fi

THRESHOLD="${1:-${CLAUDE_USAGE_WARN_PCT:-85}}"
# A non-numeric threshold would make every comparison silently false; fall back.
case "$THRESHOLD" in '' | *[!0-9]*) THRESHOLD=85 ;; esac
TTL="${CLAUDE_USAGE_TTL:-180}"
CACHE="${TMPDIR:-/tmp}/claude-usage-cache.$(id -u).txt"

now=$(date +%s)
raw=""

# Reuse cache if fresh.
if [ -f "$CACHE" ]; then
  # GNU stat uses -c %Y; BSD stat uses -f %m. Try GNU first (this box has nix
  # coreutils), fall back to BSD, then guard that we actually got a number.
  mtime=$(stat -c %Y "$CACHE" 2>/dev/null || stat -f %m "$CACHE" 2>/dev/null || echo 0)
  case "$mtime" in '' | *[!0-9]*) mtime=0 ;; esac
  if [ $((now - mtime)) -lt "$TTL" ]; then
    raw=$(cat "$CACHE")
  fi
fi

# Otherwise fetch fresh. /usage renders as a local client panel (no model turn),
# though that behavior is undocumented for print mode — so guard with a timeout,
# pin the cheapest model, and cap turns in case a future version routes the text
# to the model instead of the panel. Cache only output that parsed as a usage
# panel, so an error blob never becomes cached "truth".
if [ -z "$raw" ]; then
  raw=$(cd / && timeout 30 claude -p "/usage" --model haiku --max-turns 1 2>/dev/null)
  case "$raw" in
  *"% used"*) printf '%s' "$raw" >"$CACHE" ;;
  *) raw="" ;;
  esac
fi

if [ -z "$raw" ]; then
  # Couldn't read usage — fail open (never block the agent), but say so in human mode.
  [ "$MODE" = "human" ] && echo "usage: unavailable (could not read /usage)"
  exit 0
fi

line_of() { printf '%s\n' "$raw" | grep -iE "$1" | head -1; }
pct_of() { printf '%s\n' "$1" | grep -oE '[0-9]+% used' | grep -oE '[0-9]+' | head -1; }
reset_of() { printf '%s\n' "$1" | grep -oE 'resets[^(]*' | head -1 | sed 's/[[:space:]]*$//'; }

session_line=$(line_of 'Current session')
week_all_line=$(line_of 'Current week \(all models\)')
session=$(pct_of "$session_line")
session=${session:--1}
week_all=$(pct_of "$week_all_line")
week_all=${week_all:--1}

# Per-model weekly line(s): any "Current week (<model>)" except "(all models)".
week_model=-1
week_model_label="model"
week_model_line=""
while IFS= read -r line; do
  [ -z "$line" ] && continue
  label=$(printf '%s' "$line" | grep -oE '\([^)]*\)' | head -1 | tr -d '()')
  [ "$label" = "all models" ] && continue
  val=$(pct_of "$line")
  if [ -n "$val" ] && [ "$val" -gt "$week_model" ]; then
    week_model=$val
    week_model_label=$label
    week_model_line=$line
  fi
done <<EOF
$(printf '%s\n' "$raw" | grep -iE 'Current week')
EOF

if [ "$session" -lt 0 ] && [ "$week_all" -lt 0 ] && [ "$week_model" -lt 0 ]; then
  [ "$MODE" = "human" ] && echo "usage: unavailable (unparseable /usage output)"
  exit 0
fi

# Highest relevant utilization drives the warning; keep its own reset time.
worst=-1
worst_label=""
worst_reset=""
for pair in "session:$session" "weekly(all):$week_all" "weekly(${week_model_label}):$week_model"; do
  label=${pair%%:*}
  val=${pair##*:}
  if [ "$val" -gt "$worst" ]; then
    worst=$val
    worst_label=$label
  fi
done
case "$worst_label" in
session) worst_reset=$(reset_of "$session_line") ;;
"weekly(all)") worst_reset=$(reset_of "$week_all_line") ;;
*) worst_reset=$(reset_of "$week_model_line") ;;
esac

# Omit lines the panel didn't have (e.g. no per-model weekly on some plans).
status=""
[ "$session" -ge 0 ] && status="session ${session}%"
[ "$week_all" -ge 0 ] && status="${status:+$status · }weekly-all ${week_all}%"
[ "$week_model" -ge 0 ] && status="${status:+$status · }weekly-${week_model_label} ${week_model}%"

if [ "$MODE" = "human" ]; then
  echo "usage: $status (warn ≥${THRESHOLD}%)"
  [ "$worst" -ge "$THRESHOLD" ] 2>/dev/null && echo "⚠️  ${worst_label} at ${worst}% (${worst_reset:-reset time unknown}) — near cap; right-size or defer subagent fan-outs."
  exit 0
fi

# --hook mode: emit a PreToolUse envelope carrying additionalContext only when
# near a cap. No permissionDecision — exit 0 without one leaves the normal
# permission flow untouched (warn-only). Note: plain non-JSON stdout/stderr is
# silently ignored for PreToolUse, so if no JSON encoder is available we skip
# the warning entirely rather than pretend to emit one.
# The trailing sentence is deliberate: a bare percentage reads like a
# remaining-context countdown, which is the documented trigger for winding down
# early — so name the resource and rule that reading out.
if [ "$worst" -ge "$THRESHOLD" ] 2>/dev/null; then
  warn="⚠️ Budget check before dispatch: ${worst_label} at ${worst}% (${status}). ${worst_reset:+${worst_label} ${worst_reset}. }Right-size or defer subagent fan-outs; if near the session cap, bank remaining work and schedule a wake-up at reset."
  warn="${warn} This is your usage quota, not your context window — you have ample context remaining, so do not stop, summarize, hand off, or suggest a new session on account of it; continue the work."
  esc=$(printf '%s' "$warn" | jq -Rs . 2>/dev/null) ||
    esc=$(printf '%s' "$warn" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))' 2>/dev/null)
  if [ -n "${esc:-}" ]; then
    printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":%s}}\n' "$esc"
  fi
fi
exit 0
