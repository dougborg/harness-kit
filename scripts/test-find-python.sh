#!/usr/bin/env bash
# Tests for skills/meta/harness/find-python.sh: on a PATH whose python3 is a
# stub reporting 3.9 (no tomllib, as on macOS), it picks a newer interpreter
# from PATH, then one uv provides, and otherwise fails naming what to install.
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
finder="$repo_root/skills/meta/harness/find-python.sh"
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT

real_python=$(command -v python3)
"$real_python" -c 'import tomllib' || {
  echo "test-find-python: needs a python3 with tomllib (3.11+) on PATH" >&2
  exit 1
}

# bin <name>: a directory holding only bash and the stub interpreters the
# case adds, so nothing else on the machine's PATH is found.
bin() {
  local d="$scratch/$1"
  mkdir -p "$d/shadow"
  ln -s "$(command -v bash)" "$d/bash"
  echo 'raise ImportError("No module named tomllib (stub Python 3.9)")' >"$d/shadow/tomllib.py"
  echo "$d"
}
# old_python3 <dir>: a python3 that reports 3.9 and can't import tomllib.
old_python3() {
  cat >"$1/python3" <<SH
#!/bin/sh
case "\$1" in --version | -V) echo "Python 3.9.6"; exit 0 ;; esac
PYTHONPATH="$1/shadow" exec "$real_python" "\$@"
SH
  chmod +x "$1/python3"
}

fail=0
# expect <name> <want exit> <dir> <text the output must contain>
expect() {
  local out got
  set +e
  out=$(PATH="$3" "$3/bash" "$finder" 2>&1)
  got=$?
  set -e
  if [ "$got" -ne "$2" ]; then
    echo "FAIL: $1: exit $got, want $2"
    printf '%s\n' "$out" | sed 's/^/  | /'
    fail=1
  elif ! grep -qF -- "$4" <<<"$out"; then
    echo "FAIL: $1: output lacks '$4'"
    printf '%s\n' "$out" | sed 's/^/  | /'
    fail=1
  else
    echo "PASS: $1"
  fi
}

d=$(bin new-python3)
ln -s "$real_python" "$d/python3"
expect python3-new-enough 0 "$d" "$d/python3"

d=$(bin versioned)
old_python3 "$d"
ln -s "$real_python" "$d/python3.12"
expect versioned-over-old-python3 0 "$d" "$d/python3.12"

# uv run prints the interpreter it chose; the stub runs the real one.
d=$(bin uv)
old_python3 "$d"
cat >"$d/uv" <<SH
#!/bin/sh
[ "\$*" = "run --no-project --python >=3.11 python -c import sys; print(sys.executable)" ] || exit 9
exec "$real_python" -c 'import sys; print(sys.executable)'
SH
chmod +x "$d/uv"
expect uv-over-old-python3 0 "$d" "$("$real_python" -c 'import sys; print(sys.executable)')"

d=$(bin none)
old_python3 "$d"
expect none-fails 1 "$d" "needs Python 3.11 or later"
expect none-names-install 1 "$d" "uv"

exit $fail
