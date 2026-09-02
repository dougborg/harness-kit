#!/usr/bin/env bash
# Regression tests for validate-hooks-schema.sh (issue #16).
#
# Each fixture under scripts/shared/testdata/ is a miniature plugin root. The
# validator is invoked from inside the fixture directory (its duplicate-
# registration guard is cwd-sensitive) and the exit code is asserted:
#
#   valid/                     minimal valid hooks.json           -> exit 0
#   bad-no-wrapper/            no top-level "hooks" key           -> non-zero
#   bad-event-not-array/       event type maps to an object       -> non-zero
#   bad-handler-missing-hooks/ handler lacks inner "hooks" array  -> non-zero
#   bad-command-shape/         wrong type / empty command string  -> non-zero
#   bad-duplicate-registration/ hooks.json at auto-discovery path
#                              AND plugin.json declares "hooks"   -> non-zero
#   bad-invalid-json/          file is not parseable JSON         -> non-zero
#   clean-cwd/                 manifest declares "hooks" but no
#                              hooks/hooks.json exists at cwd, so
#                              the duplicate check must not fire  -> exit 0
#   no-hooks-file/             plugin without any hooks.json      -> exit 0

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
validator="$script_dir/validate-hooks-schema.sh"
testdata="$script_dir/testdata"

fail=0

# run_case <fixture-name> <pass|fail> <hooks-path-relative-to-fixture>
run_case() {
  name="$1"
  expectation="$2"
  target="$3"

  if [ ! -d "$testdata/$name" ]; then
    echo "FAIL: $name — fixture directory $testdata/$name is missing"
    fail=1
    return
  fi

  actual=0
  (cd "$testdata/$name" && "$validator" "$target" >/dev/null 2>&1) || actual=$?

  if [ "$expectation" = "pass" ]; then
    if [ "$actual" -eq 0 ]; then
      echo "PASS: $name (exit 0, as expected)"
    else
      echo "FAIL: $name — expected exit 0, got exit $actual"
      fail=1
    fi
  else
    if [ "$actual" -ne 0 ]; then
      echo "PASS: $name (exit $actual, non-zero as expected)"
    else
      echo "FAIL: $name — expected non-zero exit, got exit 0"
      fail=1
    fi
  fi
}

run_case valid pass hooks/hooks.json
run_case bad-no-wrapper fail hooks/hooks.json
run_case bad-event-not-array fail hooks/hooks.json
run_case bad-handler-missing-hooks fail hooks/hooks.json
run_case bad-command-shape fail hooks/hooks.json
run_case bad-duplicate-registration fail hooks/hooks.json
run_case bad-invalid-json fail hooks/hooks.json
run_case clean-cwd pass elsewhere/hooks.json
run_case no-hooks-file pass hooks/hooks.json

if [ "$fail" -ne 0 ]; then
  echo "ERROR: hooks validator regression tests failed" >&2
  exit 1
fi
echo "✓ all hooks validator regression tests passed"
