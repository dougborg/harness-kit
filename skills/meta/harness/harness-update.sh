#!/usr/bin/env bash
# Open or update one pull request that moves a vendored project to the latest
# harness-kit release (ADR 0001). Run by the vendored
# .github/workflows/harness-update.yml, from the project's checkout of its
# default branch, with GH_TOKEN set.
#
# 1. Resolve the upstream repository: $HARNESS_UPSTREAM, then
#    .claude/harness-upstream, then dougborg/harness-kit.
# 2. Read its latest release. When it is not newer than the version in
#    .harness/lock.json, stop: nothing is written.
# 3. Shallow-clone the release tag, fetch the tags the config's forks name
#    (for the fork report), and run that release's vendor-snapshot.sh.
#    Fail unless the vendored version is the tag's; stop when nothing changed.
# 4. Fail unless every changed path is a file the old or new lock owns,
#    .harness/lock.json, or .claude/settings.json; and fail when the change
#    touches a workflow file, which GITHUB_TOKEN can't push.
# 5. Commit to branch harness-kit/update, force-push it, and open a PR, or
#    edit the open one, with the release notes, the update report, and the
#    hook entries it changes in .claude/settings.json.
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

[ -f .harness/lock.json ] || die "no .harness/lock.json: not a vendored project"
[ -z "$(git status --porcelain)" ] || die "the working tree is not clean"
base=$(git rev-parse --abbrev-ref HEAD)

upstream=${HARNESS_UPSTREAM:-}
if [ -z "$upstream" ] && [ -f .claude/harness-upstream ]; then
  upstream=$(tr -d '[:space:]' <.claude/harness-upstream)
fi
upstream=${upstream:-dougborg/harness-kit}
[[ "$upstream" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] || die "not an owner/repo: $upstream"

# The checkout keeps no credentials (persist-credentials: false), so the
# token reaches git only on the commands that talk to origin, never through
# .git/config, and the release's own scripts run without it.
origin_git() {
  if [ -n "${GH_TOKEN:-}" ]; then
    GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=http.extraheader \
      GIT_CONFIG_VALUE_0="AUTHORIZATION: basic $(printf 'x-access-token:%s' "$GH_TOKEN" | base64 | tr -d '\n')" \
      git "$@"
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
if [ "$newer" != 1 ]; then
  echo "harness-update: the snapshot is up to date with $upstream $tag"
  exit 0
fi

plugin="$work/harness-kit"
git clone -q --depth 1 --branch "$tag" "${GITHUB_SERVER_URL:-https://github.com}/$upstream" "$plugin"
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

# The release's manifest must be the version its tag names.
vendored=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["version"])' .harness/lock.json)
[ "$vendored" = "${tag#v}" ] ||
  die "release $tag vendored version $vendored, not the tag's ${tag#v}; its plugin manifest doesn't match its tag"

git add -A
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
workflows = [p for p in changed if p.startswith(".github/workflows/")]
if workflows:
    print("harness-update: this release changes " + ", ".join(workflows) + ", which GITHUB_TOKEN"
          " can't push. Run the update locally and open the PR yourself: vendor-snapshot.sh"
          " from a clone of the release tag (see .claude/skills/harness/vendoring.md).", file=sys.stderr)
    sys.exit(1)
PY

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
  # A zero-width joiner after each @ keeps the notes from mentioning anyone.
  python3 -c 'import json,sys; print((json.load(open(sys.argv[1])).get("body") or "(none)")[:40000].replace("@", "@\u200d"))' \
    "$work/release.json"
  echo
  echo "</details>"
  echo
  cat "$work/report.md"
  # Hook entries run commands on every session, so list each one that changed.
  python3 - "$work/old-lock.json" .harness/lock.json <<'PY'
import json, sys
old, new = (json.load(open(p)).get("hooks", {}).get("claude", {}) for p in sys.argv[1:3])
lines = []
for event in sorted(set(old) | set(new)):
    for label, a, b in (("removed", old, new), ("added", new, old)):
        for entry in a.get(event, []):
            if entry not in b.get(event, []):
                matcher = f" (matcher `{entry['matcher']}`)" if entry.get("matcher") else ""
                cmds = "; ".join(f"`{h.get('command', '')}`" for h in entry.get("hooks", []))
                lines.append(f"- {label} `{event}`{matcher}: {cmds}")
if lines:
    print("\n## Hook changes\n\nThis update changes the harness hook entries in `.claude/settings.json`,"
          " which run on every session. Review each command:\n")
    print("\n".join(lines))
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

pr=$(gh pr list --head "$branch" --base "$base" --state open --json number --jq '.[0].number // empty')
if [ -n "$pr" ]; then
  gh pr edit "$pr" --title "$title" --body-file "$work/body.md"
  echo "harness-update: updated PR #$pr"
else
  gh pr create --head "$branch" --base "$base" --title "$title" --body-file "$work/body.md"
fi
