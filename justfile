# harness-kit development recipes

# Run local validation and lint checks
check: validate validate-codex validate-hooks test-hooks test-cross-host-hooks test-codex-install lint-shell lint-md hygiene

# Validate plugin manifest and structure
validate:
    claude plugin validate .

# Validate Codex packaging, agents, and generated Claude projection
validate-codex:
    ./scripts/validate-codex.sh

# Validate plugin hooks.json schema shape (minimal, catches missing top-level hooks key)
validate-hooks:
    ./scripts/shared/validate-hooks-schema.sh hooks/hooks.json

# Run validate-hooks-schema.sh regression tests against fixtures in scripts/shared/testdata/
test-hooks:
    ./scripts/shared/test-hooks-schema.sh

# Exercise host-specific hook semantics
test-cross-host-hooks:
    ./scripts/test-cross-host-hooks.sh

# Install the repository through an isolated Codex marketplace/profile
test-codex-install:
    ./scripts/test-codex-plugin-install.sh

# Lint shell scripts with ShellCheck (-type f skips the shared-script symlinks)
lint-shell:
    find skills scripts -type f -name '*.sh' -exec shellcheck {} +

# Lint markdown files
lint-md:
    markdownlint .

# Check file hygiene (trailing whitespace + final newline)
hygiene:
    #!/usr/bin/env bash
    set -euo pipefail
    fail=0
    if grep -rn '[[:blank:]]$' --include='*.md' --include='*.sh' --include='*.yml' --include='*.json' . 2>/dev/null; then
        echo "ERROR: Trailing whitespace found"; fail=1
    fi
    while IFS= read -r f; do
        if [ -s "$f" ] && [ "$(tail -c1 "$f" | wc -l)" -eq 0 ]; then
            echo "ERROR: Missing final newline in $f"; fail=1
        fi
    done < <(find . -name '.git' -prune -o \( -name '*.md' -o -name '*.sh' -o -name '*.yml' -o -name '*.json' \) -print)
    exit $fail
