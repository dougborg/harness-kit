# Update and Add Modes

Both modes install content into the host destinations recorded in
`.harness-lock.json`. `update` syncs from upstream; `add` pulls skills from
another marketplace.

## Update Mode

Pull latest changes from upstream sources and smart-merge with local modifications. **Run after the harness-kit plugin is updated.**

1. **Read and migrate `.harness-lock.json`** — Missing `schemaVersion` means
   v1 Claude-only. Upgrade in memory while preserving every source, path, and
   modified flag; write only after the normal confirmation gate.

2. **Check for upstream updates:**
   - Compare plugin version (`${CLAUDE_PLUGIN_ROOT}` has the latest) vs lock file version
   - List files that differ in each recorded Claude or Codex destination.
     Projects install skills flat by name, but the plugin groups them by
     topic area. Map each installed skill to its upstream by name: Claude
     copies come from `${CLAUDE_PLUGIN_ROOT}/claude-skills/<skill>/`, Codex copies
     from `${CLAUDE_PLUGIN_ROOT}/skills/<area>/<skill>/` (find the area with
     `ls ${CLAUDE_PLUGIN_ROOT}/skills/*/<skill>`).

3. **For each upstream file:**
   - `modified: false` → **Overwrite** with latest from plugin. Silent.
   - `modified: true` → **Show diff** between upstream and local. Ask user:
     - Accept upstream (overwrite local changes)
     - Keep local (skip this file)
     - Merge manually (show both versions)
   - `source: "local"` → **Never touch**. These are project-specific.

4. **Check for new upstream files** — Files in the plugin that aren't in the lock file yet. Offer to install them. This includes new sibling reference files inside an already-installed skill directory (e.g. a skill that grew an `audit.md`) — a stale copy that's missing them will send Claude looking for content that isn't there.

5. **Check for removed upstream files** — Lock entries with `source` set to an upstream whose file no longer exists there. Offer to delete each unmodified one, and show modified ones for the user to keep as `source: "local"` or delete. Example: harness-kit #118 moved `agents/references/*.md` into the harness skill, so older installs carry stale `.claude/agents/references/` copies.

6. **Update `.harness-lock.json`** — New version, updated timestamps, modified flags, removed entries dropped.

7. **Show changelog** — Summary of what was updated, what was skipped, what's new.

If versions match and every tracked file is local, report that there is
nothing to sync from upstream and point session-learning improvements to
`harness retro` (issue #90).

## Add Mode

Add skills from another plugin marketplace into the project's `.claude/`.

```bash
/harness add vercel-labs/agent-skills
```

1. **Check if marketplace is already added:**

   ```bash
   claude plugin marketplace list
   ```

   If not, instruct user: `/plugin marketplace add vercel-labs/agent-skills`

2. **Browse available skills** from the marketplace.

3. **User selects** which skills to install into `.claude/`.

4. **Copy selected skills** from `claude-skills/` to `.claude/skills/` — whole directories, including reference files and scripts. The generated projection contains the host-specific paths and regular helper files needed by project-local skills; do not rewrite paths in the copied files.

5. **Update `.harness-lock.json`** with new source and file entries.

6. **Run verification command** to confirm nothing broke.
