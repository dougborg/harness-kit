#!/usr/bin/env bash
# Open or update one pull request that moves a vendored project to the latest
# harness-kit release (ADR 0001). Run by the vendored
# .github/workflows/harness-update.yml, from the project's checkout of its
# default branch, with GH_TOKEN set, and HARNESS_UPDATE_TOKEN when the
# repository has that secret.
#
# 1. Resolve the upstream repository with the vendored
#    .claude/skills/harness/resolve-upstream.sh: $HARNESS_UPSTREAM, then
#    .claude/harness-upstream, then dougborg/harness-kit.
# 2. Read its latest release. When it is not newer than the version in
#    .harness/lock.json, stop: nothing is written.
# 3. Shallow-clone the release tag; fail, writing nothing, unless its plugin
#    manifest is the tag's version. Fetch the tags the config's forks name
#    (for the fork report) and run that release's vendor-snapshot.sh; stop
#    when nothing changed.
# 4. Fail unless every changed path is a file the old or new lock owns,
#    .harness/lock.json, or .claude/settings.json; and, without
#    HARNESS_UPDATE_TOKEN, fail when the change touches a workflow file,
#    which GITHUB_TOKEN can't push, naming the commands that update by hand.
# 5. Commit to branch harness-kit/update, force-push it, and open a PR, or
#    edit the open one, with the release notes, the update report, and the
#    hook entries it changes in .claude/settings.json.
#
# HARNESS_UPDATE_TOKEN, when set, replaces GH_TOKEN for the push and the PR
# calls only; reading the release still uses GH_TOKEN. It is taken out of the
# environment first, so nothing else this runs, the release's scripts
# included, ever sees it.
#
# Clones from ${GITHUB_SERVER_URL:-https://github.com}/<owner>/<repo>.
# Usage: harness-update.sh
# Exit: 0 when up to date or the PR is open; 1 on any failure.
set -euo pipefail

branch=harness-kit/update
die() {
  echo "harness-update: $*" >&2
  exit 1
}
# mention_free: stdin to stdout with a zero-width joiner after each @.
mention_free() { python3 -c 'import sys; sys.stdout.write(sys.stdin.read().replace("@", "@‍"))'; }

[ -f .harness/lock.json ] || die "no .harness/lock.json: not a vendored project"
[ -z "$(git status --porcelain)" ] || die "the working tree is not clean"
base=$(git rev-parse --abbrev-ref HEAD)

# The project's own resolver, from the checked-out default branch: the Claude
# projection ships it beside this script, and the workflow runs this copy.
upstream=$(.claude/skills/harness/resolve-upstream.sh) || die "could not resolve the upstream repository"

# The optional push token leaves the environment before anything runs.
update_token=${HARNESS_UPDATE_TOKEN:-}
unset HARNESS_UPDATE_TOKEN
push_token=${update_token:-${GH_TOKEN:-}}
# pr_gh: gh for the PR calls, as the push token.
pr_gh() {
  if [ -n "$update_token" ]; then GH_TOKEN=$update_token gh "$@"; else gh "$@"; fi
}

# The checkout keeps no credentials (persist-credentials: false), so the
# token reaches git only on the commands that talk to origin, never through
# .git/config, and the release's own scripts run without it. The header is
# appended after any GIT_CONFIG_* entries the caller set, and masked in the
# Actions log; nothing here turns on git tracing.
auth=
if [ -n "$push_token" ]; then
  auth=$(printf 'x-access-token:%s' "$push_token" | base64 | tr -d '\n')
  [ "${GITHUB_ACTIONS:-}" != true ] || echo "::add-mask::$auth"
fi
origin_git() {
  if [ -n "$auth" ]; then
    local n=${GIT_CONFIG_COUNT:-0}
    [[ "$n" =~ ^[0-9]+$ ]] || die "GIT_CONFIG_COUNT is not a number: $n"
    env GIT_CONFIG_COUNT=$((n + 1)) "GIT_CONFIG_KEY_$n=http.extraheader" \
      "GIT_CONFIG_VALUE_$n=AUTHORIZATION: basic $auth" git "$@"
  else
    git "$@"
  fi
}

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
gh api "repos/$upstream/releases/latest" >"$work/release.json"

# tag, notes URL, and whether the release is newer than the lock's version.
info=$(python3 - "$work/release.json" .harness/lock.json <<'PY'
import json, re, sys
release = json.load(open(sys.argv[1]))
current = json.load(open(sys.argv[2]))["version"]
def parse(v):
    # Only X.Y.Z releases are followed; a pre-release or build tag is refused.
    m = re.fullmatch(r"v?(\d+)\.(\d+)\.(\d+)", v)
    if not m:
        why = " (a pre-release or build version)" if re.fullmatch(r"v?\d+\.\d+\.\d+[-+].*", v) else ""
        sys.exit(f"harness-update: not a release version{why}: {v}; only vX.Y.Z releases are followed")
    return tuple(map(int, m.groups()))
tag = release["tag_name"]
print(tag, release["html_url"], int(parse(tag) > parse(current)))
PY
)
read -r tag url newer <<<"$info"
# Up to date: exit without touching GitHub. An update PR still open (say, the
# release was vendored by hand) is left as it is, for a person to close; the
# job never closes PRs.
if [ "$newer" != 1 ]; then
  echo "harness-update: the snapshot is up to date with $upstream $tag"
  exit 0
fi

plugin="$work/harness-kit"
git clone -q --depth 1 --branch "$tag" "${GITHUB_SERVER_URL:-https://github.com}/$upstream" "$plugin"
# The release's manifest must be the version its tag names; checked before
# vendoring so a mismatch writes nothing.
manifest=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["version"])' "$plugin/.claude-plugin/plugin.json")
[ "$manifest" = "${tag#v}" ] ||
  die "release $tag has plugin manifest version $manifest, not the tag's ${tag#v}; its manifest doesn't match its tag"

# Forks are compared against the release they were forked from; a tag that
# can't be fetched is reported as not compared.
python3 - <<'PY' >"$work/fork-tags"
import tomllib
config = tomllib.load(open(".harness/config.toml", "rb"))
forks = config.get("forks", {})
print("\n".join(sorted({f"v{v}" for kind in ("skills", "agents") for v in forks.get(kind, {}).values()})))
PY
while IFS= read -r fork_tag; do
  [ -z "$fork_tag" ] || git -C "$plugin" fetch -q --depth 1 origin tag "$fork_tag" 2>/dev/null || true
done <"$work/fork-tags"

git show HEAD:.harness/lock.json >"$work/old-lock.json"
env -u GH_TOKEN -u GITHUB_TOKEN "$plugin/skills/meta/harness/vendor-snapshot.sh" "$plugin" . >"$work/report.md"

git add -A
# As above, an open update PR is left as it is.
if git diff --cached --quiet HEAD; then
  echo "harness-update: the snapshot is already up to date with $upstream $tag"
  exit 0
fi

# The diff guard: the update PR may change only what the snapshot owns.
git diff --cached --name-only --no-renames HEAD >"$work/changed"
python3 - "$work/old-lock.json" .harness/lock.json "$work/changed" <<'PY'
import json, sys
owned = set(json.load(open(sys.argv[1]))["files"]) | set(json.load(open(sys.argv[2]))["files"])
owned |= {".harness/lock.json", ".claude/settings.json"}
changed = open(sys.argv[3]).read().split()
stray = [p for p in changed if p not in owned]
if stray:
    print("harness-update: the update changed paths the snapshot doesn't own:", file=sys.stderr)
    print("\n".join(f"  {p}" for p in stray), file=sys.stderr)
    sys.exit(1)
PY

# GITHUB_TOKEN can't push a workflow change; HARNESS_UPDATE_TOKEN can. Without
# it, say exactly how to update by hand, in the log and the job summary.
workflows=$(grep '^\.github/workflows/' "$work/changed" || true)
if [ -n "$workflows" ] && [ -z "$update_token" ]; then
  server=${GITHUB_SERVER_URL:-https://github.com}
  docs="$server/$upstream/blob/$tag/skills/meta/harness/vendoring.md#the-update-workflow"
  {
    echo "harness-update: $tag changes $(echo "$workflows" | paste -sd, - | sed 's/,/, /g'), which GITHUB_TOKEN can't push."
    echo "Add a HARNESS_UPDATE_TOKEN repository secret so the job can deliver it, or update by hand"
    echo "from a clean checkout of the default branch, then commit and open the PR:"
    echo
    # shellcheck disable=SC2016 # the commands are printed, not run
    echo '    release=$(mktemp -d)'
    echo "    git clone --depth 1 --branch $tag $server/$upstream \"\$release\""
    # shellcheck disable=SC2016
    echo '    "$release"/skills/meta/harness/vendor-snapshot.sh "$release" .'
    echo
    echo "Docs: $docs"
  } >"$work/manual.md"
  cat "$work/manual.md" >&2
  [ -z "${GITHUB_STEP_SUMMARY:-}" ] || cat "$work/manual.md" >>"$GITHUB_STEP_SUMMARY"
  exit 1
fi

from=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["version"])' "$work/old-lock.json")
title="chore(harness): update harness-kit snapshot to ${tag#v}"
{
  echo "Updates the vendored harness-kit snapshot from $from to ${tag#v}: [release notes]($url)."
  echo
  echo "This PR changes only the snapshot's files, \`.harness/lock.json\`, and the"
  echo "harness hook entries in \`.claude/settings.json\`; the workflow refuses to push"
  echo "anything else. It was opened with \`GITHUB_TOKEN\`, so \`pull_request\`"
  echo "workflows don't start on their own: close and reopen it to run CI."
  echo
  echo "<details><summary>Release notes</summary>"
  echo
  # A zero-width joiner after each @ keeps the release's and the config's
  # text from mentioning anyone: the notes and the report, which names forks.
  python3 -c 'import json,sys; print((json.load(open(sys.argv[1])).get("body") or "(none)")[:40000])' \
    "$work/release.json" | mention_free
  echo
  echo "</details>"
  echo
  mention_free <"$work/report.md"
  # Hook entries run commands on every session, so list each one that changed.
  # Event, matcher, and commands are shown exactly, in code spans and fences
  # longer than any backtick run they hold; mentions don't fire in code.
  python3 - "$work/old-lock.json" .harness/lock.json <<'PY'
import json, re, sys
old, new = (json.load(open(p)).get("hooks", {}).get("claude", {}) for p in sys.argv[1:3])
def ticks(s, least):
    return "`" * max(least, max((len(r) for r in re.findall(r"`+", s)), default=0) + 1)
def span(s):
    pad = " " if s[:1] == "`" or s[-1:] == "`" else ""
    return f"{ticks(s, 1)}{pad}{s}{pad}{ticks(s, 1)}"
out = []
for event in sorted(set(old) | set(new)):
    for label, a, b in (("removed", old, new), ("added", new, old)):
        for entry in a.get(event, []):
            if entry not in b.get(event, []):
                matcher = f" (matcher {span(str(entry['matcher']))})" if entry.get("matcher") else ""
                cmds = "\n".join(str(h.get("command", "")) for h in entry.get("hooks", []))
                fence = ticks(cmds, 3)
                out.append(f"- {label} {span(str(event))}{matcher}:\n\n  {fence}text")
                out.extend(f"  {line}" for line in cmds.split("\n"))
                out.append(f"  {fence}\n")
print("\n## Hook changes\n")
if out:
    print("This update changes the harness hook entries in `.claude/settings.json`,"
          " which run on every session. Review each command:\n")
    print("\n".join(out))
else:
    print("This update changes no harness hook entries in `.claude/settings.json`.")
PY
} >"$work/body.md"

git switch -q -C "$branch"
git -c user.name='github-actions[bot]' \
  -c user.email='41898283+github-actions[bot]@users.noreply.github.com' commit -q -m "$title"
# Don't push a new commit with the same content as the branch already has.
if origin_git fetch -q origin "$branch" 2>/dev/null &&
  [ "$(git rev-parse 'FETCH_HEAD^{tree}')" = "$(git rev-parse 'HEAD^{tree}')" ]; then
  echo "harness-update: $branch already holds this update"
else
  origin_git push -q --force origin "HEAD:refs/heads/$branch"
fi

pr=$(pr_gh pr list --head "$branch" --base "$base" --state open --json number --jq '.[0].number // empty')
if [ -n "$pr" ]; then
  pr_gh pr edit "$pr" --title "$title" --body-file "$work/body.md"
  echo "harness-update: updated PR #$pr"
else
  pr_gh pr create --head "$branch" --base "$base" --title "$title" --body-file "$work/body.md"
fi
