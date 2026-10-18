#!/usr/bin/env bash
# Print the path of a Python 3.11 or later (one with tomllib), for the harness
# scripts that read .harness/config.toml. Tries, in order: python3, so an
# active virtualenv or pinned toolchain wins when it is new enough; then
# python3.14 down to python3.11 on PATH; then a Python uv already has, through
# `uv run --no-project --no-python-downloads --python '>=3.11'`; and only then
# lets uv download one, which needs the network and leaves a uv-managed Python
# behind. macOS's system python3 is 3.9, so there this usually lands on a
# versioned python3 or on uv.
#
# Usage: find-python.sh
# Exit: 0 with the path on stdout; 1, naming what to install, when none is
#       found.
set -euo pipefail

for py in python3 python3.14 python3.13 python3.12 python3.11; do
  if path=$(command -v "$py") && "$path" -c 'import tomllib' 2>/dev/null; then
    echo "$path"
    exit 0
  fi
done
if command -v uv >/dev/null; then
  for downloads in --no-python-downloads ""; do
    # shellcheck disable=SC2086 # an empty $downloads is meant to vanish
    if path=$(uv run --no-project $downloads --python '>=3.11' \
      python -c 'import sys; print(sys.executable)' 2>/dev/null) && [ -n "$path" ]; then
      echo "$path"
      exit 0
    fi
  done
fi
{
  echo "find-python: needs Python 3.11 or later (for tomllib) and found none: python3"
  echo "is older or missing, no python3.11 to python3.14 is on PATH, and uv (if"
  echo "installed) provided none. Install one, for example \`brew install python@3.13\`,"
  echo "or install uv (https://docs.astral.sh/uv/), which fetches a Python itself."
} >&2
exit 1
