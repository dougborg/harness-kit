# harness-kit development recipes

# Run all checks (mirrors CI)
check: validate lint-shell lint-md

# Validate plugin manifest and structure
validate:
    claude plugin validate .

# Lint shell scripts with ShellCheck
lint-shell:
    shellcheck skills/**/*.sh

# Lint markdown files
lint-md:
    markdownlint '**/*.md'
