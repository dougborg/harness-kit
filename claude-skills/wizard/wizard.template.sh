#!/usr/bin/env bash
#
# A wizard walks a human through a manual procedure, step by step.
# Copied from the wizard skill's template. The human runs it in their own
# terminal: it opens browsers, clears the screen, and waits for input.
#
# Everything above the "STAGES" marker is the wizard library: leave it as is.
# Author the per-step stages below the marker.

set -euo pipefail

# ──────────────────────────────────────────────────────────────────────────
# Wizard library: delightful, consistent UX, identical across every wizard.
# ──────────────────────────────────────────────────────────────────────────

if [[ -t 1 ]] && command -v tput >/dev/null 2>&1 && [[ "$(tput colors 2>/dev/null || echo 0)" -ge 8 ]]; then
  BOLD=$(tput bold || true); DIM=$(tput dim || true); RESET=$(tput sgr0 || true)
  BLUE=$(tput setaf 4 || true); GREEN=$(tput setaf 2 || true); YELLOW=$(tput setaf 3 || true)
else
  BOLD=""; DIM=""; RESET=""; BLUE=""; GREEN=""; YELLOW=""
fi

# Author sets this at the top of the stages section.
TOTAL_STAGES=0

_STAGE_INDEX=0
ENV_FILE="${ENV_FILE:-.env}"
WRITTEN_ENV=()    # KEYs written to ENV_FILE this run
WRITTEN_SECRET=() # secret NAMEs set this run
SKIPPED=()        # things we couldn't do (e.g. gh missing)
_ENV_CHECKED=0    # set once ENV_FILE's gitignore and permissions are checked
_TMP=""           # write_env's temp file, removed on exit or Ctrl-C

_cleanup() { if [[ -n "$_TMP" ]]; then rm -f "$_TMP"; fi; }
trap _cleanup EXIT
trap '_cleanup; exit 130' INT TERM

# _clear wipes the terminal so only the current step is on screen. No-op when
# output isn't a terminal, so piped logs stay readable.
_clear() {
  [[ -t 1 ]] || return 0
  if command -v tput >/dev/null 2>&1 && tput clear 2>/dev/null; then return 0; fi
  printf '\033[2J\033[3J\033[H'
}

# banner "Title" shows the opening frame: what this wizard does.
banner() {
  _clear
  printf '\n%s%s  %s%s\n' "$BOLD" "$BLUE" "$1" "$RESET"
  printf '%s  %s stages · values go to %s' "$DIM" "$TOTAL_STAGES" "$ENV_FILE"
  local repo=""
  if command -v gh >/dev/null 2>&1; then
    repo=$(gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null || true)
  fi
  if [[ -n "$repo" ]]; then printf ' · GitHub repo %s (set GH_REPO to change)' "$repo"; fi
  printf '%s\n\n' "$RESET"
  printf '%s  You drive the browser; this wizard tells you exactly what to do and\n' "$DIM"
  printf '  captures the values you copy back. Stop any time with Ctrl-C and re-run\n'
  printf '  later, since it remembers values already saved.%s\n' "$RESET"
  pause "Ready to start?"
}

# stage "Name" clears the screen, then announces a stage and shows progress.
# Clearing keeps only the current step on screen.
stage() {
  _clear
  _STAGE_INDEX=$((_STAGE_INDEX + 1))
  printf '\n%s%s▸ Stage %s/%s · %s%s\n' \
    "$BOLD" "$BLUE" "$_STAGE_INDEX" "$TOTAL_STAGES" "$1" "$RESET"
}

# say "..." prints a plain instruction line.
say()  { printf '  %s\n' "$1"; }
# step "..." is a numbered-feeling action the human takes in the browser.
step() { printf '  %s•%s %s\n' "$BLUE" "$RESET" "$1"; }
note() { printf '  %s%s%s\n' "$DIM" "$1" "$RESET"; }
warn() { printf '  %s⚠ %s%s\n' "$YELLOW" "$1" "$RESET"; }

# open_url URL opens it in the human's browser, cross-platform incl. WSL.
open_url() {
  local url="$1"
  printf '  %s↗ opening%s %s\n' "$GREEN" "$RESET" "$url"
  { if   command -v wslview     >/dev/null 2>&1; then wslview "$url"
    elif command -v explorer.exe >/dev/null 2>&1; then explorer.exe "$url" || true # exits 1 on success
    elif command -v xdg-open    >/dev/null 2>&1; then xdg-open "$url"
    elif command -v open        >/dev/null 2>&1; then open "$url"
    else false; fi
  } >/dev/null 2>&1 || warn "couldn't open a browser, so visit it manually: $url"
}

# pause "msg" waits for the human to confirm they've done the manual part.
pause() {
  printf '  %s%s%s ' "$DIM" "${1:-Press Enter to continue}" "$RESET"
  read -r _ || true
}

# confirm "question" is a y/N gate; returns success on yes. Under set -e a
# bare `confirm` aborts the wizard on "no", so always write it as
# `if confirm "..."; then ...; fi`.
confirm() {
  local reply=""
  printf '  %s? %s [y/N] ' "$YELLOW" "$1"
  read -r reply || true
  [[ "$reply" =~ ^[Yy] ]]
}

# _existing KEY: current value of KEY in ENV_FILE, if any, with write_env's quoting undone.
_existing() {
  [[ -f "$ENV_FILE" ]] || return 1
  local line value sq="'\\''" q="'"
  line=$(grep -E "^(export )?${1}=" "$ENV_FILE" | tail -n1) || return 1
  value="${line#*=}"
  # $q, not \', so bash 3.2 (macOS) doesn't keep the backslash.
  if [[ "$value" == \'*\' ]]; then value="${value:1:${#value}-2}"; value="${value//"$sq"/$q}"; fi
  printf '%s' "$value"
}

# ask KEY "Prompt" reads a value into $KEY. Offers the existing .env value as
# a default on re-runs (Enter keeps it), and asks again on an empty answer
# with nothing saved. Visible input (non-secret), edited with Readline. At
# EOF it fails, which deliberately aborts the wizard under set -e.
ask() {
  local key="$1" prompt="$2" current input s=$'\001' e=$'\002' p rc
  current=$(_existing "$key" || true)
  # Readline needs the colour codes wrapped in \001..\002 to place the cursor.
  p="  $s$BOLD$e$prompt$s$RESET$e "
  if [[ -n "$current" ]]; then p+="$s$DIM${e}[Enter keeps current]$s$RESET$e "; fi
  while true; do
    input="" rc=0
    read -e -r -p "$p" input || rc=1
    if (( rc )) && [[ -z "$input" ]]; then return 1; fi
    if [[ -z "$input" ]]; then input="$current"; fi
    if [[ -n "$input" ]]; then break; fi
    warn "a value is required"
  done
  printf -v "$key" '%s' "$input"
}

# ask_secret KEY "Prompt" is like ask, but input is hidden.
ask_secret() {
  local key="$1" prompt="$2" current input rc
  current=$(_existing "$key" || true)
  while true; do
    if [[ -n "$current" ]]; then
      printf '  %s%s%s %s[Enter keeps current]%s ' "$BOLD" "$prompt" "$RESET" "$DIM" "$RESET"
    else
      printf '  %s%s%s ' "$BOLD" "$prompt" "$RESET"
    fi
    input="" rc=0
    read -rs input || rc=1
    printf '\n'
    if (( rc )) && [[ -z "$input" ]]; then return 1; fi
    if [[ -z "$input" ]]; then input="$current"; fi
    if [[ -n "$input" ]]; then break; fi
    warn "a value is required"
  done
  printf -v "$key" '%s' "$input"
}

# _check_env_file runs before the first write: it offers to gitignore
# ENV_FILE inside a git work tree, and to tighten an existing file that
# others can read.
_check_env_file() {
  if (( _ENV_CHECKED )); then return 0; fi
  _ENV_CHECKED=1
  local dir base rc loose
  dir=$(dirname "$ENV_FILE") base=$(basename "$ENV_FILE")
  if command -v git >/dev/null 2>&1 &&
    git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    rc=0
    git -C "$dir" check-ignore -q -- "$base" || rc=$?
    if (( rc == 1 )); then
      warn "$ENV_FILE isn't gitignored, so the secrets in it could be committed."
      if confirm "Add $base to $dir/.gitignore?"; then
        printf '/%s\n' "$base" >>"$dir/.gitignore"
        printf '  %s✓ ignored%s %s\n' "$GREEN" "$RESET" "$ENV_FILE"
      fi
    fi
  fi
  if [[ -e "$ENV_FILE" ]]; then
    loose=$(find -L "$ENV_FILE" -prune \( -perm -040 -o -perm -004 \) 2>/dev/null || true)
    if [[ -n "$loose" ]]; then
      warn "$ENV_FILE is readable by other users."
      if confirm "Restrict it to you (chmod 600)?"; then chmod 600 "$ENV_FILE"; fi
    fi
  fi
}

# write_env KEY VALUE upserts KEY='VALUE' into ENV_FILE, replacing any
# existing KEY= or export KEY= line. Idempotent. Creates ENV_FILE at mode
# 0600 and keeps an existing file's mode. It builds the new file beside the
# old and renames it into place, so Ctrl-C never leaves a half-written file;
# a symlinked ENV_FILE is written through instead.
write_env() {
  local key="$1" value="$2" sq="'\\''"
  _check_env_file
  [[ -e "$ENV_FILE" ]] || (umask 077 && : > "$ENV_FILE")
  _TMP=$(mktemp "$ENV_FILE.XXXXXX")
  cp -p "$ENV_FILE" "$_TMP"
  grep -vE "^(export )?${key}=" "$ENV_FILE" > "$_TMP" || true
  printf "%s='%s'\n" "$key" "${value//\'/$sq}" >> "$_TMP"
  if [[ -L "$ENV_FILE" ]]; then
    cat "$_TMP" > "$ENV_FILE"
    rm -f "$_TMP"
  else
    mv -f "$_TMP" "$ENV_FILE"
  fi
  _TMP=""
  WRITTEN_ENV+=("$key")
  printf '  %s✓ wrote%s %s → %s\n' "$GREEN" "$RESET" "$key" "$ENV_FILE"
}

# set_secret NAME VALUE sets a GitHub Actions repo secret via gh, on the
# current directory's repo or GH_REPO when set. The value goes in on stdin,
# so gh's error output never contains it. Falls back to a warning (and
# records it) if gh is unavailable, unauthenticated, or refuses.
set_secret() {
  local name="$1" value="$2" err
  if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
    if err=$(printf '%s' "$value" | gh secret set "$name" 2>&1 >/dev/null); then
      WRITTEN_SECRET+=("$name")
      printf '  %s✓ set%s GitHub secret %s\n' "$GREEN" "$RESET" "$name"
      return
    fi
    note "gh: $err"
  fi
  SKIPPED+=("GitHub secret $name (set it manually: gh secret set $name)")
  warn "skipped GitHub secret $name: gh not ready; set it later"
}

# set_var NAME VALUE sets a GitHub Actions repo variable (non-secret).
set_var() {
  local name="$1" value="$2" err
  if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
    if err=$(gh variable set "$name" --body "$value" 2>&1 >/dev/null); then
      printf '  %s✓ set%s GitHub variable %s\n' "$GREEN" "$RESET" "$name"
      return
    fi
    note "gh: $err"
  fi
  SKIPPED+=("GitHub variable $name")
  warn "skipped GitHub variable $name, gh not ready; set it later"
}

# finish clears, then shows a closing summary of everything configured.
finish() {
  _clear
  printf '\n%s%s  ✓ Setup complete%s\n' "$BOLD" "$GREEN" "$RESET"
  if (( ${#WRITTEN_ENV[@]} )); then note "wrote ${#WRITTEN_ENV[@]} value(s) to $ENV_FILE: ${WRITTEN_ENV[*]}"; fi
  if (( ${#WRITTEN_SECRET[@]} )); then note "set ${#WRITTEN_SECRET[@]} GitHub secret(s): ${WRITTEN_SECRET[*]}"; fi
  if (( ${#SKIPPED[@]} )); then
    printf '\n'; warn "still to do by hand:"
    for s in "${SKIPPED[@]}"; do note "  - $s"; done
  fi
  printf '\n'
}

# ──────────────────────────────────────────────────────────────────────────
# STAGES: author this section. One stage() per step the human takes.
# Replace the example below. Set TOTAL_STAGES to match the stages you write.
# ──────────────────────────────────────────────────────────────────────────

TOTAL_STAGES=1

banner "Stripe setup"

# ── Example stage: replace with your real steps ───────────────────────────
stage "Stripe: API keys"
say "We'll grab your Stripe test keys and store them for local dev + CI."
open_url "https://dashboard.stripe.com/test/apikeys"
step "On the API keys page, copy the Publishable key (starts pk_test_)."
ask STRIPE_PUBLISHABLE_KEY "Paste the publishable key:"
step "Click 'Reveal test key' on the Secret key row, then copy it."
ask_secret STRIPE_SECRET_KEY "Paste the secret key:"
write_env STRIPE_PUBLISHABLE_KEY "$STRIPE_PUBLISHABLE_KEY"
write_env STRIPE_SECRET_KEY "$STRIPE_SECRET_KEY"
# confirm gates with `if`: a bare confirm would abort the wizard on "no".
if confirm "Also store the secret key as a GitHub Actions secret for CI?"; then
  set_secret STRIPE_SECRET_KEY "$STRIPE_SECRET_KEY"
fi
# ──────────────────────────────────────────────────────────────────────────

finish
