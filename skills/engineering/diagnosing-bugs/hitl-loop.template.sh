#!/usr/bin/env bash
# Human-in-the-loop reproduction loop for the diagnosing-bugs skill.
# Copy this file, edit the steps between the markers, and run it. The agent
# runs the script; the person follows the prompts in their terminal.
#
#   step "<instruction>"        show an instruction, wait for Enter
#   capture VAR "<question>"    show a question, read the answer into VAR
#
# Captured values print as KEY=VALUE at the end for the agent to read. They
# appear in the agent's transcript, so capture observations only, and leave
# signing in to the person as a `step`.

set -euo pipefail

step() {
  printf '\n>>> %s\n' "$1"
  read -r -p "    [Enter when done] " _
}

capture() {
  local var="$1" question="$2" answer
  printf '\n>>> %s\n' "$question"
  read -r -p "    > " answer
  printf -v "$var" '%s' "$answer"
}

# --- edit below ---------------------------------------------------------

step "Open the app at http://localhost:3000 and sign in."
capture ERRORED "Click 'Export'. Did it throw an error? (y/n)"
capture ERROR_MSG "Paste the error message (or 'none'):"

# --- edit above ---------------------------------------------------------

printf '\n--- Captured ---\n'
printf 'ERRORED=%s\n' "$ERRORED"
printf 'ERROR_MSG=%s\n' "$ERROR_MSG"
