#!/usr/bin/env bash
# Regression tests for skills/engineering/wizard/wizard.template.sh: its
# example stage is driven through stdin with a stub `gh`, under every bash
# given in WIZARD_BASHES (default: bash, plus macOS /bin/bash 3.2 if present).
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
template="$repo_root/skills/engineering/wizard/wizard.template.sh"
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT

# A gh stub: authenticated unless STUB_GH_AUTH=fail; `secret set NAME`
# records its stdin in $STUB_GH_DIR/secret-NAME.
mkdir -p "$scratch/bin"
cat >"$scratch/bin/gh" <<'STUB'
#!/usr/bin/env bash
[ "${STUB_GH_AUTH:-ok}" = ok ] || exit 1
case "$1 $2" in
"auth status") exit 0 ;;
"repo view") echo "owner/repo" ;;
"secret set") cat >"$STUB_GH_DIR/secret-$3" ;;
*) exit 1 ;;
esac
STUB
chmod +x "$scratch/bin/gh"
# Browser-opener stubs, so the example stage never opens a real browser tab;
# each records the URL it was asked to open in $STUB_GH_DIR/opened.
cat >"$scratch/bin/open" <<'STUB'
#!/usr/bin/env bash
echo "$1" >>"$STUB_GH_DIR/opened"
STUB
chmod +x "$scratch/bin/open"
for opener in xdg-open wslview explorer.exe; do
  cp "$scratch/bin/open" "$scratch/bin/$opener"
done

bashes=${WIZARD_BASHES:-bash}
if [ -z "${WIZARD_BASHES:-}" ] && [ -x /bin/bash ] && [ "$(command -v bash)" != /bin/bash ]; then
  bashes="bash /bin/bash"
fi

fail=0
check() { # check <name> <condition...>
  local name=$1
  shift
  if "$@"; then
    echo "PASS: $sh $name"
  else
    echo "FAIL: $sh $name"
    fail=1
  fi
}

# run <case> <stdin>: run the wizard in $scratch/<case> (created beforehand
# when it needs setup); sets $rc.
run() {
  local dir="$scratch/$sh_tag/$1"
  mkdir -p "$dir"
  cp "$template" "$dir/w.sh"
  rc=0
  (cd "$dir" && printf '%b' "$2" |
    PATH="$scratch/bin:$PATH" STUB_GH_DIR="$dir" ENV_FILE=.env "$sh" w.sh >"$dir/out" 2>&1) || rc=$?
  case_dir=$dir
}
prep() { mkdir -p "$scratch/$sh_tag/$1"; }

for sh in $bashes; do
  sh_tag=$(basename "$sh")-$RANDOM

  # Fresh run outside git: values land quoted in a 0600 .env; the secret is set.
  run fresh '\npub_1\nsec_2\ny\n'
  check fresh-exit [ "$rc" = 0 ]
  check fresh-env grep -qx "EXAMPLE_PUBLIC_KEY='pub_1'" "$case_dir/.env"
  check fresh-mode [ -n "$(find "$case_dir/.env" -prune -perm 600)" ]
  check fresh-secret [ "$(cat "$case_dir/secret-EXAMPLE_SECRET_KEY")" = sec_2 ]
  check fresh-browser-stubbed grep -q "example.com/settings/api-keys" "$case_dir/opened"

  # B1: inside a git work tree with .env not ignored, it offers to ignore it.
  prep gitignore
  git -C "$scratch/$sh_tag/gitignore" init -q
  run gitignore '\npk\nsk\ny\nn\n'
  check gitignore-exit [ "$rc" = 0 ]
  check gitignore-added git -C "$case_dir" check-ignore -q .env

  # B2: a saved value with an apostrophe survives a rerun that keeps it.
  prep apostrophe
  printf "EXAMPLE_PUBLIC_KEY='pk'\nEXAMPLE_SECRET_KEY='it'\\\\''s'\n" >"$scratch/$sh_tag/apostrophe/.env"
  chmod 600 "$scratch/$sh_tag/apostrophe/.env"
  run apostrophe '\n\n\ny\n'
  check apostrophe-exit [ "$rc" = 0 ]
  check apostrophe-env grep -qx "EXAMPLE_SECRET_KEY='it'\\\\''s'" "$case_dir/.env"
  check apostrophe-secret [ "$(cat "$case_dir/secret-EXAMPLE_SECRET_KEY")" = "it's" ]

  # S2: an empty answer with nothing saved asks again.
  run empty '\n\npk_again\nsk\nn\n'
  check empty-reprompt grep -qx "EXAMPLE_PUBLIC_KEY='pk_again'" "$case_dir/.env"

  # S4: an export-prefixed line is replaced, not duplicated.
  prep export
  printf "export EXAMPLE_PUBLIC_KEY='old'\n" >"$scratch/$sh_tag/export/.env"
  chmod 600 "$scratch/$sh_tag/export/.env"
  run export '\nnew\nsk\nn\n'
  check export-replaced [ "$(grep -c EXAMPLE_PUBLIC_KEY "$case_dir/.env")" = 1 ]
  check export-no-temp [ "$(find "$case_dir" -name '.env.*' | wc -l | tr -d ' ')" = 0 ]

  # S5: an existing world-readable .env is offered chmod 600.
  prep perms
  printf "OTHER=1\n" >"$scratch/$sh_tag/perms/.env"
  chmod 644 "$scratch/$sh_tag/perms/.env"
  run perms '\npk\nsk\ny\nn\n'
  check perms-tightened [ -n "$(find "$case_dir/.env" -prune -perm 600)" ]
  check perms-kept-other grep -qx "OTHER=1" "$case_dir/.env"

  # gh unauthenticated: the secret is listed as still to do.
  STUB_GH_AUTH=fail run noauth '\npk\nsk\ny\n'
  check noauth-skipped grep -q "set it manually: gh secret set EXAMPLE_SECRET_KEY" "$case_dir/out"

  # EOF mid-wizard aborts instead of writing an empty value.
  run eof '\n'
  check eof-aborts [ "$rc" != 0 ]
  check eof-no-env [ ! -e "$case_dir/.env" ]
done

exit "$fail"
