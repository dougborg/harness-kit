#!/usr/bin/env bash
# Lint every Markdown file with the one pinned markdownlint-cli2 version, so
# `just lint-md` and CI's Markdown lint job can't disagree (#138). Config comes
# from .markdownlint.json. Pass --fix to fix what can be fixed.
set -euo pipefail

version="0.23.2"
cd "$(dirname "${BASH_SOURCE[0]}")/.."
exec npx --yes "markdownlint-cli2@${version}" "$@" "**/*.md" "#node_modules"
