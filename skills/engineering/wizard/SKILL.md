---
name: wizard
description: >-
  Generates an interactive bash wizard that walks a human through steps only
  they can perform: it opens each page, says what to click and copy, captures
  the values, and writes them to .env or GitHub secrets. Use when provisioning
  infrastructure, setting up credentials or CI secrets, walking an unfamiliar
  third-party dashboard, or running a one-off migration or cutover. Not for
  steps the agent can perform itself.
---

# Wizard

A **wizard** is a bash script that walks a human, stage by stage, through a
manual procedure that's tedious to do by hand and tedious to re-explain to an
agent each time: configuring third-party services, a one-off migration, moving
the project from one state to another. It opens each URL, says exactly what to
click and copy, captures the values, writes them where they belong, confirms
at each stage, and shows how many stages are left.

The UX is already built in `<skill-dir>/wizard.template.sh`: stage progress,
confirmation gates, cross-platform URL opening (including WSL), hidden secret
entry, idempotent `.env` upserts, `gh secret` and `gh variable` writes, and a
closing summary. Your job is only to scope the procedure and write its
stages. The library above the `STAGES` marker is the same in every wizard;
leave it as is.

A wizard is ephemeral by default: written for one run to a scratch or
`scripts/` path, and deleted when the job is done. Commit it only when the
user wants a repeatable setup path in the repo.

## 1. Scope the procedure

List every manual step and every value captured along the way. Read the repo
before asking anything:

- For setup: `.env`, `.env.example`, `.env.*`, the README,
  `docker-compose*`, framework config, and `.github/workflows/*`. Every
  `secrets.*` or `vars.*` reference there is a value the wizard must produce.
- For a migration or cutover: the current state, the target state, and the
  irreversible actions between them.

Show the user the ordered stages and the values each produces, and confirm:
through `AskUserQuestion` on Claude Code, as a plain question on Codex. They
may add, drop, or reorder stages.

Done when every stage is named in order, and for each captured value you
know where the human gets it, where it's written (`.env`, a GitHub secret,
both, or nowhere, since some stages are pure actions), and whether it's
secret or public.

## 2. Map each stage's path

For each stage, write the exact path a human follows: which URL to open,
what to do there, where the value appears, and which variable it fills
("Dashboard → Developers → API keys → Reveal test key → copy"). Where you
don't know the current UI or command, check the provider's docs or ask the
user; never invent steps.

Done when every stage traces to instructions a stranger could follow.

## 3. Write the wizard

Copy `<skill-dir>/wizard.template.sh` to the target path. Replace the example
stage with one `stage` per step, in dependency order, using the library's
helpers: `stage`, `say` and `step`, `open_url`, `ask` and `ask_secret`,
`write_env`, `set_secret` and `set_var`, `pause` and `confirm`. Set
`TOTAL_STAGES` to the number of stages and change the `banner` title.

Hold the template's bar: open the URL before asking for its value, use
`ask_secret` for anything secret, `write_env` every value that persists,
`set_secret` only the values CI actually reads, and `confirm` before any
irreversible action. Each `stage` clears the screen, so keep a stage to one
task and nothing the human needs scrolls away.

Done when every stage from step 1 is in the script and `TOTAL_STAGES`
matches.

## 4. Verify and hand off

Run `bash -n <script>` and `shellcheck <script>`, then `chmod +x <script>`.
Don't run it yourself: it opens browsers and waits for a person. Trace it
instead: every value from step 1 is captured and lands where step 1 said, and
every `set_secret` name matches a `secrets.*` reference in CI exactly.

Tell the user to run it in their own terminal. Your shell has no terminal
for them to type into, and the wizard clears the screen as it goes. If it's
a repeatable setup path, commit it and link it from the README, so the next
person runs the script instead of asking an agent.

Done when the script passes both checks, the trace finds no gaps, and the
user has the command to run.
