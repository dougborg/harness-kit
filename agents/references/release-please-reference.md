# Release Please Reference

Setting up automated semver releases with [Release Please](https://github.com/googleapis/release-please) — and the gotchas that aren't documented anywhere obvious.

## When to Use

Add Release Please when:

- Your repo uses [Conventional Commits](https://www.conventionalcommits.org/) (or you're committing to that style going forward)
- You want version bumps and `CHANGELOG.md` to be automatic, not hand-maintained
- You're publishing tagged releases (GitHub Releases, npm, marketplace, etc.)

Don't bother for: short-lived prototypes, repos with one author and no consumers, or repos where you genuinely never publish versioned releases.

## Minimal Setup (no `package.json`)

For repos without a standard package manager (Claude Code plugins, dotfiles, scripts), use `release-type: simple`. It tracks version in `.release-please-manifest.json` and updates other files via `extra-files`.

```json
// release-please-config.json
{
  "$schema": "https://raw.githubusercontent.com/googleapis/release-please/main/schemas/config.json",
  "packages": {
    ".": {
      "release-type": "simple",
      "package-name": "your-project",
      "include-component-in-tag": false,
      "changelog-path": "CHANGELOG.md",
      "extra-files": [
        { "type": "json", "path": "manifest.json", "jsonpath": "$.version" }
      ]
    }
  }
}
```

```json
// .release-please-manifest.json
{ ".": "0.1.0" }
```

```yaml
# .github/workflows/release-please.yml
name: Release Please
on:
  push:
    branches: [main]
permissions:
  contents: write
  pull-requests: write
jobs:
  release-please:
    runs-on: ubuntu-latest
    steps:
      - uses: googleapis/release-please-action@v5
        with:
          config-file: release-please-config.json
          manifest-file: .release-please-manifest.json
```

## ⚠ Three Gotchas Every Project Hits

### 1. GitHub Actions can't create PRs by default

**Symptom:** First Release Please run fails with `release-please failed: GitHub Actions is not permitted to create or approve pull requests`.

**Cause:** A repo-level setting is off by default for security.

**Fix (one-time, per repo):**

```bash
gh api repos/<owner>/<repo>/actions/permissions/workflow -X PUT \
  -f default_workflow_permissions=write \
  -F can_approve_pull_request_reviews=true
```

Or via UI: *Settings → Actions → General → Workflow permissions → enable "Allow GitHub Actions to create and approve pull requests"*.

### 2. Release PRs don't trigger CI on first open

**Symptom:** Release Please opens a release PR. Your branch protection requires CI checks. The release PR shows "no checks reported" forever.

**Cause:** GitHub doesn't trigger workflow runs for PRs created by `GITHUB_TOKEN` (security feature to prevent infinite workflow recursion).

**Workarounds, in order of effort:**

- **Manual close+reopen** (simplest): `gh pr close N && gh pr reopen N`. The reopen counts as a human action and triggers CI. Acceptable for solo projects where releases are infrequent.
- **Personal Access Token** (cleanest): pass a PAT to the action via `token: ${{ secrets.RELEASE_PLEASE_PAT }}`. PRs created by the PAT trigger CI normally. Costs: secret rotation, PAT scope management.
- **GitHub App** (best for orgs): create a bot app, install on the repo, use its token. Avoids personal credentials.

### 3. Auto-generated CHANGELOG conflicts with strict markdownlint

**Symptom:** First few release PRs fail markdown lint, one rule at a time:

- Release 1: MD012 (multiple consecutive blank lines) — between version sections
- Release 2: MD024 (no-duplicate-heading) — repeated `### Features` / `### Bug Fixes` across versions

**Cause:** Release Please writes a deterministic CHANGELOG format that's correct but stricter than default markdownlint allows.

**Fix:** Set both rules in `.markdownlint.json` *before* enabling Release Please, so the first release doesn't fail:

```json
{
  "MD012": false,
  "MD024": { "siblings_only": true }
}
```

`siblings_only: true` keeps MD024 catching real duplicate-heading bugs in hand-written docs but allows duplicates under different parent headings (each version section is a different parent — exactly the CHANGELOG case).

`.markdownlintignore` does **not** work with `markdownlint-cli2-action` when globs are passed via the action's `globs:` input — the rules above apply globally.

## Verifying Your Setup

After setup, the first push to main should:

1. Trigger the `Release Please` workflow
2. Open a PR titled `chore(main): release X.Y.Z`
3. The PR bumps your version files and creates/updates `CHANGELOG.md`

If step 1 happens but step 2 doesn't: check workflow logs for "not permitted to create" → gotcha #1.
If step 2 happens but the PR has no CI: gotcha #2 — close+reopen.
If CI fails on markdownlint: gotcha #3 — apply the rules above and merge a separate PR for the lint config first.

## Triggering Manually

```bash
# Re-run the release-please workflow against current main
gh workflow run release-please.yml
```

## Related

- [Release Please docs](https://github.com/googleapis/release-please)
- `agents/references/hooks-reference.md` — same authority + gotcha pattern, different domain
- `/harness-builder` — recommends adding Release Please when conventional commits + GitHub are detected
