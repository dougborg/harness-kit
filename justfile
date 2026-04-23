# harness-kit development recipes

# Run local validation and lint checks
check: validate lint-shell lint-md hygiene

# Validate plugin manifest and structure
validate:
    claude plugin validate .

# Lint shell scripts with ShellCheck
lint-shell:
    find skills -name '*.sh' -exec shellcheck {} +

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
