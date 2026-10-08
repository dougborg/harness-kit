# harness-kit development recipes

# Run every check. CI runs the same four groups, one job each, so the list of
# checks lives only here.
check: validate-all lint-shell lint-md hygiene

# CI job "Validate plugin": manifests, projections, and every test script
validate-all: validate validate-codex validate-hooks tests

# Every regression test script
tests: test-hooks test-cross-host-hooks test-poll-review test-poll-ci test-sub-issue-frontier test-retro-nudge test-codex-agents test-wizard test-rebase-preflight test-pr-threads test-validate-codex test-codex-install

# Exercise rebase preflight against throwaway repos with a local bare origin
test-rebase-preflight:
    ./scripts/test-rebase-preflight.sh

# Exercise pr-threads.sh against a stub gh serving 250 paged threads
test-pr-threads:
    ./scripts/test-pr-threads.sh

# Break validate-codex.sh's layout guards in scratch copies and expect failures
test-validate-codex:
    ./scripts/test-validate-codex.sh

# Validate plugin manifest and structure
validate:
    claude plugin validate .

# Validate Codex packaging, agents, and generated Claude projection
validate-codex:
    ./scripts/validate-codex.sh

# Validate plugin hooks.json schema shape (minimal, catches missing top-level hooks key)
validate-hooks:
    ./scripts/validate-hooks-schema.sh hooks/hooks.json

# Run validate-hooks-schema.sh regression tests against fixtures in scripts/testdata/
test-hooks:
    ./scripts/test-hooks-schema.sh

# Exercise host-specific hook semantics
test-cross-host-hooks:
    ./scripts/test-cross-host-hooks.sh

# Exercise poll-review.sh decision logic against canned GraphQL responses
test-poll-review:
    ./scripts/test-poll-review.sh

# Exercise poll-ci.sh against canned check, run, and required-check lists
test-poll-ci:
    ./scripts/test-poll-ci.sh

# Exercise the sub-issue frontier grouping against a canned parent
test-sub-issue-frontier:
    ./scripts/test-sub-issue-frontier.sh

# Test the Stop-hook retro nudge
test-retro-nudge:
    ./scripts/test-retro-nudge.sh

# Exercise the Codex agent generator against fixture agents
test-codex-agents:
    ./scripts/test-generate-codex-agents.sh

# Drive the wizard skill's template through its example stage
test-wizard:
    ./scripts/test-wizard-template.sh

# Install the repository through an isolated Codex marketplace/profile
test-codex-install:
    ./scripts/test-codex-plugin-install.sh

# Lint shell scripts with ShellCheck: the sources, not the generated copies in
# claude-skills/ (CI job "ShellCheck")
lint-shell:
    find skills scripts hooks -type f -name '*.sh' -exec shellcheck {} +

# Lint markdown files (CI job "Markdown lint")
lint-md *args:
    ./scripts/lint-md.sh {{args}}

# Check file hygiene: trailing whitespace and a final newline (CI job "File hygiene")
hygiene:
    #!/usr/bin/env bash
    set -euo pipefail
    fail=0
    # error <file> <line> <message>: a plain line, plus an inline PR
    # annotation when running under GitHub Actions.
    error() {
        echo "ERROR: $1${2:+:$2}: $3"
        if [ "${GITHUB_ACTIONS:-}" = true ]; then echo "::error file=$1${2:+,line=$2}::$3"; fi
        fail=1
    }
    while IFS=: read -r f line _; do
        error "${f#./}" "$line" "Trailing whitespace"
    done < <(grep -rn '[[:blank:]]$' --include='*.md' --include='*.sh' --include='*.yml' --include='*.json' . 2>/dev/null || true)
    while IFS= read -r f; do
        if [ -s "$f" ] && [ "$(tail -c1 "$f" | wc -l)" -eq 0 ]; then
            error "${f#./}" "" "Missing final newline"
        fi
    done < <(find . -name '.git' -prune -o \( -name '*.md' -o -name '*.sh' -o -name '*.yml' -o -name '*.json' \) -print)
    exit $fail
