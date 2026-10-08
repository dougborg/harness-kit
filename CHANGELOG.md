# Changelog

## [1.0.0](https://github.com/dougborg/harness-kit/compare/v0.8.0...v1.0.0) (2026-10-08)


### ⚠ BREAKING CHANGES

* **project-management:** /feature-spec is removed. Use /to-spec to write a spec issue and /to-tickets to split it into tickets.

### Features

* add handoff and the ask-harness router ([10c0122](https://github.com/dougborg/harness-kit/commit/10c0122f08e7202ec9249fa718aa76a623b7a21f)), closes [#111](https://github.com/dougborg/harness-kit/issues/111)
* add implement and implement-spec ([91a67c1](https://github.com/dougborg/harness-kit/commit/91a67c1e06efa9ce23408503469c5cdc728c331c)), closes [#111](https://github.com/dougborg/harness-kit/issues/111)
* **code-reviewer:** check what assertions measure, and nothing vs unknown ([73eb115](https://github.com/dougborg/harness-kit/commit/73eb115a7232227a52cd4d74de9a50f0ab329941)), closes [#94](https://github.com/dougborg/harness-kit/issues/94)
* **codex:** generate .codex/agents/*.toml from agents/*.md ([5a14372](https://github.com/dougborg/harness-kit/commit/5a14372b9d94d422eb89dd3fa5fef076e043fd8f)), closes [#114](https://github.com/dougborg/harness-kit/issues/114)
* **engineering:** add minimal-change and a complexity lens for review ([143a1e7](https://github.com/dougborg/harness-kit/commit/143a1e7c20c57afc6c9a2b1b6a7059810ce61a87)), closes [#111](https://github.com/dougborg/harness-kit/issues/111)
* **engineering:** add prototype, improve-codebase-architecture, and wizard ([f0e9327](https://github.com/dougborg/harness-kit/commit/f0e93278e1ab51a292ca640141287db7fca56f64))
* **engineering:** add tdd, codebase-design, and diagnosing-bugs ([465d7fe](https://github.com/dougborg/harness-kit/commit/465d7fef9c49f38cbc90eac0acb84c0a7482fa72)), closes [#111](https://github.com/dougborg/harness-kit/issues/111)
* **open-pr:** make our own agent review the gate; outside reviews optional ([9521e82](https://github.com/dougborg/harness-kit/commit/9521e825df99c460231c9e6c1fc68d6a6b51c55b)), closes [#116](https://github.com/dougborg/harness-kit/issues/116) [#111](https://github.com/dougborg/harness-kit/issues/111)
* **open-pr:** one output contract and one test seam for both poll scripts ([9c85a43](https://github.com/dougborg/harness-kit/commit/9c85a43baabb59a2af4253924fc3b9fa214c01b2)), closes [#156](https://github.com/dougborg/harness-kit/issues/156)
* **pr:** fold five PR-thread scripts into one pr-threads module ([f12da75](https://github.com/dougborg/harness-kit/commit/f12da759f64990ceefa36415b1b0313fcbbb7130))
* **project-management:** add triage and a shortcut ledger ([54e2bc4](https://github.com/dougborg/harness-kit/commit/54e2bc4becf85905f60eb205d0127fca98827432)), closes [#111](https://github.com/dougborg/harness-kit/issues/111)
* **project-management:** add wayfinder and research ([c0c3ab3](https://github.com/dougborg/harness-kit/commit/c0c3ab3a232bc59ab2a6f0e86f819be19b09e3e3)), closes [#111](https://github.com/dougborg/harness-kit/issues/111)
* **project-management:** replace feature-spec with to-spec and to-tickets ([08e7069](https://github.com/dougborg/harness-kit/commit/08e70692c8b406d7dd2b52936ee592d1966f64fd)), closes [#111](https://github.com/dougborg/harness-kit/issues/111)
* **retro,pr:** add environment categories to retro and a pr-body skill ([4d1ac2d](https://github.com/dougborg/harness-kit/commit/4d1ac2dd7c13dd0e35992cd220efca0a40ef0f3f)), closes [#111](https://github.com/dougborg/harness-kit/issues/111)
* **review:** add a separate spec pass, documented standards, and smells ([4b0c6e6](https://github.com/dougborg/harness-kit/commit/4b0c6e67f2a691f218b0184efc03742c322119d6)), closes [#111](https://github.com/dougborg/harness-kit/issues/111)
* **skills:** derive invocation from agents/openai.yaml and reclassify ([9328970](https://github.com/dougborg/harness-kit/commit/932897050ccac29386eba8347e4b9ed41446da76)), closes [#111](https://github.com/dougborg/harness-kit/issues/111)
* **skills:** port teach and an experimental loop-me ([f6307f7](https://github.com/dougborg/harness-kit/commit/f6307f766984b165df43eda785a94f4bd3efaeda))
* **skills:** restate progress in reports, and break debug spirals ([7576640](https://github.com/dougborg/harness-kit/commit/7576640ed4e8f61cfaddcc521bc9eb184b5e5e1f)), closes [#152](https://github.com/dougborg/harness-kit/issues/152)
* support Claude Code and Codex ([#104](https://github.com/dougborg/harness-kit/issues/104)) ([a51af7e](https://github.com/dougborg/harness-kit/commit/a51af7e1269f8210fbdfd98a5c441090ee25b7a7))
* **thinking:** add grilling, domain-modeling, and their entry points ([559e7ca](https://github.com/dougborg/harness-kit/commit/559e7ca2ab860eadb3411a2d6bf583150918c7b5)), closes [#111](https://github.com/dougborg/harness-kit/issues/111)
* **validate:** fail when a script calls a sibling that isn't beside it ([2f18ced](https://github.com/dougborg/harness-kit/commit/2f18ceda35346b555df98114669efe40fd87fcf2))
* **verifier:** check that new assertions can fail ([e60c53a](https://github.com/dougborg/harness-kit/commit/e60c53a7c95bfc2c56c45fbf4e85b7bcff33d199)), closes [#93](https://github.com/dougborg/harness-kit/issues/93)
* **writing:** add adhd-mode, a skill and a harness-kit:adhd output style ([7020692](https://github.com/dougborg/harness-kit/commit/70206924415c76b946ac3174f157483c51f5b01e))


### Bug Fixes

* **ci:** wire the preflight test, widen the sibling guard, keep annotations ([55cde31](https://github.com/dougborg/harness-kit/commit/55cde312e886bb90d6ef9fbce445fb76ed45bed0))
* **codex:** address agent review of the verifier sandbox and hook findings ([573e0a9](https://github.com/dougborg/harness-kit/commit/573e0a90168e2ba52743ada06801d7cf088baf95))
* **codex:** harden the agent generator and address agent review ([94363e2](https://github.com/dougborg/harness-kit/commit/94363e288255a1391a5c19c5b4a72387eaac35a7))
* **codex:** run the verifier under workspace-write, not read-only ([eec153d](https://github.com/dougborg/harness-kit/commit/eec153d7608346c3c7bd80ec5db21149ae54f576)), closes [#143](https://github.com/dougborg/harness-kit/issues/143)
* **engineering:** address agent review of the PR-lifecycle rewrite ([bd5cdda](https://github.com/dougborg/harness-kit/commit/bd5cdda18866f907d983c1b97c19afa00c6d7056))
* **engineering:** address review of the code-reviewer, commit, and ui-review rewrite ([95d3124](https://github.com/dougborg/harness-kit/commit/95d312487b77e3c80c6b33293b16c12637820f13))
* **engineering:** harden the wizard template and address agent review ([f1088da](https://github.com/dougborg/harness-kit/commit/f1088da62d7d6560aa38f6068b1f2733f3c2b33f))
* **engineering:** make the HITL loop runnable and finish the done criteria ([b9ae431](https://github.com/dougborg/harness-kit/commit/b9ae4312a3a06f0ca32f8d49acc7f52cc64f4db1))
* **engineering:** number complexity findings apart and pin the shortcut format ([7316c49](https://github.com/dougborg/harness-kit/commit/7316c4924509ca872642a3a699a42848218eee9e))
* **hooks:** address agent review of the hook output rewrite ([74568a1](https://github.com/dougborg/harness-kit/commit/74568a11b8252e6a9ccf63c08ac11ee995072ea6))
* **hooks:** quote plugin-root paths in hook commands ([65b5d8f](https://github.com/dougborg/harness-kit/commit/65b5d8f60129c4676e0e249664c34c12ce4680f6))
* **hooks:** show the retro nudge as a Stop-hook systemMessage ([e02dbc5](https://github.com/dougborg/harness-kit/commit/e02dbc5c57f676bc5d17ada7099dd818503c66fd)), closes [#137](https://github.com/dougborg/harness-kit/issues/137)
* **hooks:** show the retro nudge once per session, with a test ([626131e](https://github.com/dougborg/harness-kit/commit/626131e3a36f5e501591f504e68b7cca49d8ab51))
* **meta:** working hook example, harness-builder grants, and review fixes ([1344a7c](https://github.com/dougborg/harness-kit/commit/1344a7c940d6326ad0500f381b7c39e0ad6ab304))
* one markdownlint for local and CI, stale-head waits, accepted root CLAUDE.md warning ([0f21183](https://github.com/dougborg/harness-kit/commit/0f21183056ad6b234d4fc60795ad82250ea9c832)), closes [#112](https://github.com/dougborg/harness-kit/issues/112) [#131](https://github.com/dougborg/harness-kit/issues/131) [#138](https://github.com/dougborg/harness-kit/issues/138)
* **open-pr:** address agent review of the shared poll contract ([48d0cbd](https://github.com/dougborg/harness-kit/commit/48d0cbdeed1d8d93193ba44aa0e45be026eee9fa))
* **open-pr:** count actionable threads past the first 100 in poll-review ([cfa0933](https://github.com/dougborg/harness-kit/commit/cfa0933ce20ac38f62c259cbc83a226212796574)), closes [#155](https://github.com/dougborg/harness-kit/issues/155)
* **open-pr:** harden the review gate after agent review ([68057ee](https://github.com/dougborg/harness-kit/commit/68057ee486a158e1cf8523e34b8121d31a20a7e0))
* **open-pr:** keep poll-ci alive when origin can't be read; skip fork PRs ([1a2bcb2](https://github.com/dougborg/harness-kit/commit/1a2bcb24ab8235d2f7ee99a11531d9cf10198b1d))
* **open-pr:** keep poll-ci waiting while workflow runs are queued ([68dedb4](https://github.com/dougborg/harness-kit/commit/68dedb414198fc2fc723eb289a25ebb2b59b800a)), closes [#126](https://github.com/dougborg/harness-kit/issues/126)
* **open-pr:** let a newer run of a workflow supersede an orphaned one ([9657452](https://github.com/dougborg/harness-kit/commit/9657452e699b4e70be2d9133e283b512d9e586a1))
* **open-pr:** let finished CI keep its verdict when the PR conflicts ([b9c9201](https://github.com/dougborg/harness-kit/commit/b9c92010eb7049be7a0a2e700aa35ca55141a1f0))
* **open-pr:** make poll-ci's failure paths explicit ([8d52f91](https://github.com/dougborg/harness-kit/commit/8d52f919d976583c6f7a654d962ca6460bf7ec4e))
* **open-pr:** report a merge conflict from poll-ci instead of timing out ([9838c50](https://github.com/dougborg/harness-kit/commit/9838c50240292e578425a39fd67b5cb77496ca40)), closes [#147](https://github.com/dougborg/harness-kit/issues/147)
* **pr:** a failed GitHub call is an error, never an empty result ([ac7defe](https://github.com/dougborg/harness-kit/commit/ac7defee73ea7f426e149a8848703a31dbe023a5))
* **project-management:** close the gaps the review found in to-spec and to-tickets ([9f08263](https://github.com/dougborg/harness-kit/commit/9f082631147c38616a25869d777dbed40c9f1daf))
* **project-management:** give wayfinder's tickets owners and safe claims ([9a6c892](https://github.com/dougborg/harness-kit/commit/9a6c89288ed0e8256b0e448e872b60a9b7ac833e))
* **project-management:** preview every write, narrow tools, and fix groom's count ([2ba31e5](https://github.com/dougborg/harness-kit/commit/2ba31e5bf6e7a8f5ae15b352463fd2e0ddda8648))
* **project-management:** run the ledger scan from groom's fork, tighten triage ([df28923](https://github.com/dougborg/harness-kit/commit/df2892360664395357fa38cbaadb172e11a2d480))
* **rebase:** detect pushed teammate commits and stash only what we own ([ffd8795](https://github.com/dougborg/harness-kit/commit/ffd87951124eef9b10c2d2ffb0f753b02f304b00))
* **rebase:** make the shared-branch check run, and ask before forcing ([a0e3ef7](https://github.com/dougborg/harness-kit/commit/a0e3ef7180131a6903810255e61c27bd4d57a89d))
* **retro,pr:** route environment findings and scale the PR body ([0ac4646](https://github.com/dougborg/harness-kit/commit/0ac4646bdafb535ab4df2b832af9bccd663b5027))
* **review-pr:** resolve threads without a sibling script ([8f52f01](https://github.com/dougborg/harness-kit/commit/8f52f0121f42302f56ba0fd6467889239bd0e946))
* **review:** address agent review of the dedupe and assertion checks ([b9b52fa](https://github.com/dougborg/harness-kit/commit/b9b52fa39682ea644f42538431650268068eab79))
* **review:** make the two passes runnable end to end ([58d9239](https://github.com/dougborg/harness-kit/commit/58d9239805b2c2c290c55a180cd3f539c928d802))
* **skills:** address agent review of the teach, loop-me, and skill-writer ports ([574b9e7](https://github.com/dougborg/harness-kit/commit/574b9e769a34d3e9177930d0208d5d0583f0e96d))
* **skills:** address review of the teach and skill-writer ports ([5e7071d](https://github.com/dougborg/harness-kit/commit/5e7071dc3c93b8bf863992d09ba6c61a1722db36))
* **skills:** close the gaps the topic-area review found ([914becb](https://github.com/dougborg/harness-kit/commit/914becbb14ae953cb14b68867c2ebe159d2fb885))
* **skills:** search the backlog by topic before filing deferred work ([4a193af](https://github.com/dougborg/harness-kit/commit/4a193afb7e77e490f8aaf4b84159ab9f99319008)), closes [#91](https://github.com/dougborg/harness-kit/issues/91)
* **skills:** tighten invocation validation and descriptions after review ([d164ab4](https://github.com/dougborg/harness-kit/commit/d164ab45f493a08206ae1c8da6bbcfca081e90f9)), closes [#111](https://github.com/dougborg/harness-kit/issues/111)
* **test:** copy only files that exist into validate-codex's scratch repos ([48e2885](https://github.com/dougborg/harness-kit/commit/48e2885d48db88ca1ff2f9f3e8af912fdc948a7b))
* **test:** stub browser openers in the wizard template test ([16a502d](https://github.com/dougborg/harness-kit/commit/16a502d3959490b2f23cb4287cf0e9a1866acf5b))
* **thinking:** tighten grilling's asking rules and restore adaptation losses ([f840e38](https://github.com/dougborg/harness-kit/commit/f840e38d317d5d8749fad9c7ddc0530e2e5a1fe0))
* tighten implement-spec's steps, permissions, and claims ([71b80c9](https://github.com/dougborg/harness-kit/commit/71b80c946e1271b52f6efad09f3399eefa64536e))
* valid router frontmatter, a Codex handoff launch, and a two-way router check ([e621fe1](https://github.com/dougborg/harness-kit/commit/e621fe1539b8703a2e41da22fb0a9633bd75bf7c))
* **validate:** check only tracked shared files, by exact name, with a test ([c9ad9d5](https://github.com/dougborg/harness-kit/commit/c9ad9d55d625580ff49adf8173a7ab653181229b))
* **validate:** require the Claude manifest to list every generated skill ([54f6eef](https://github.com/dougborg/harness-kit/commit/54f6eef2bd7473a026e558484c6d5b11021952c7)), closes [#111](https://github.com/dougborg/harness-kit/issues/111)
* **validate:** stop requiring the checkout folder to be named harness-kit ([19f5c9f](https://github.com/dougborg/harness-kit/commit/19f5c9fd5fd5fd3fc6c4574fd0f821fd30b81e4d)), closes [#111](https://github.com/dougborg/harness-kit/issues/111)
* **wizard:** use a neutral example service instead of Stripe ([b4db08f](https://github.com/dougborg/harness-kit/commit/b4db08f9ee429715be2e845116528dd1d76ce858))
* **writing:** address agent review of adhd-mode and the style generator ([b64fc22](https://github.com/dougborg/harness-kit/commit/b64fc221f623c5f2bc0031f5c60b03aa710a370a))

## [0.8.0](https://github.com/dougborg/harness-kit/compare/v0.7.0...v0.8.0) (2026-08-22)


### Features

* add multi-agent standup workflow ([#95](https://github.com/dougborg/harness-kit/issues/95)) ([d1417a4](https://github.com/dougborg/harness-kit/commit/d1417a497aad5767434d0dfce5ed668fa0ccf36b))

## [0.7.0](https://github.com/dougborg/harness-kit/compare/v0.6.0...v0.7.0) (2026-07-25)


### Features

* budget-aware coordination (usage check, /budget skill, pre-dispatch hook) ([#64](https://github.com/dougborg/harness-kit/issues/64)) ([ed6907f](https://github.com/dougborg/harness-kit/commit/ed6907fc61cb0155050a1cddb534ef388e22d60b))
* **ci:** add test harness for validate-hooks-schema.sh ([#56](https://github.com/dougborg/harness-kit/issues/56)) ([eb081f5](https://github.com/dougborg/harness-kit/commit/eb081f5884a63bfaf918d6967bf0d9c73ebb3d45)), closes [#16](https://github.com/dougborg/harness-kit/issues/16)
* **commit:** auto-stage drifted uv.lock in Python+uv projects ([#52](https://github.com/dougborg/harness-kit/issues/52)) ([4c5696c](https://github.com/dougborg/harness-kit/commit/4c5696c784f08d89320568b8a2d0237c1b54a724)), closes [#29](https://github.com/dougborg/harness-kit/issues/29)
* **harness:** recommend official Anthropic plugins in bootstrap and audit ([#59](https://github.com/dougborg/harness-kit/issues/59)) ([6fc2361](https://github.com/dougborg/harness-kit/commit/6fc236104f03df7fd2c5743b322775ae2ce14577)), closes [#31](https://github.com/dougborg/harness-kit/issues/31)
* **skill:** add /groom backlog-grooming skill + project-manager agent ([#57](https://github.com/dougborg/harness-kit/issues/57)) ([727077b](https://github.com/dougborg/harness-kit/commit/727077b614aa201e3f2f3b32f749a7694352ec1c)), closes [#26](https://github.com/dougborg/harness-kit/issues/26)
* **skill:** add /session-retro for structured session retrospectives ([#55](https://github.com/dougborg/harness-kit/issues/55)) ([6cac969](https://github.com/dougborg/harness-kit/commit/6cac969c69920460c1b553de92150a0ecfaa18e9)), closes [#30](https://github.com/dougborg/harness-kit/issues/30)
* **skills:** adopt disable-model-invocation, context fork, when_to_use, effort ([#81](https://github.com/dougborg/harness-kit/issues/81)) ([0ef8f94](https://github.com/dougborg/harness-kit/commit/0ef8f947793d1672e8264b2813339fb1e6ea03a3)), closes [#67](https://github.com/dougborg/harness-kit/issues/67)


### Bug Fixes

* **budget:** distinguish usage quota from context window in hook warning ([#76](https://github.com/dougborg/harness-kit/issues/76)) ([f338dc0](https://github.com/dougborg/harness-kit/commit/f338dc0d657050755382bf3f69fb2dbfea3bb8c8)), closes [#73](https://github.com/dougborg/harness-kit/issues/73)
* **ci:** mint release-please token via GitHub App so required checks run ([#53](https://github.com/dougborg/harness-kit/issues/53)) ([f3d644d](https://github.com/dougborg/harness-kit/commit/f3d644d04aa4d7ee93a2a939d00894cc0e0c3a41)), closes [#23](https://github.com/dougborg/harness-kit/issues/23)
* **frontmatter:** agents use tools: not allowed-tools:, Task is not a tool ([#77](https://github.com/dougborg/harness-kit/issues/77)) ([4c58de9](https://github.com/dougborg/harness-kit/commit/4c58de946a9095d60e9853baafd936a49839693e)), closes [#65](https://github.com/dougborg/harness-kit/issues/65)
* **open-pr:** redesign poll-review.sh signal contract (closes [#39](https://github.com/dougborg/harness-kit/issues/39), [#28](https://github.com/dougborg/harness-kit/issues/28), [#24](https://github.com/dougborg/harness-kit/issues/24)) ([#58](https://github.com/dougborg/harness-kit/issues/58)) ([9dbc32b](https://github.com/dougborg/harness-kit/commit/9dbc32b5dddd64c424c98173d48709600845ddad))
* **open-pr:** survive Bash 120s timeout during CI polls and add wakeup resume pattern ([#50](https://github.com/dougborg/harness-kit/issues/50)) ([76e0bfe](https://github.com/dougborg/harness-kit/commit/76e0bfed9de9995a39f5e7931c0237f3e2a7693c)), closes [#38](https://github.com/dougborg/harness-kit/issues/38) [#35](https://github.com/dougborg/harness-kit/issues/35)
* **pr-workflow:** review-pr branch guard + worktree branch-name inference ([#51](https://github.com/dougborg/harness-kit/issues/51)) ([5202a7e](https://github.com/dougborg/harness-kit/commit/5202a7eba60370e46a52742a9750a0f9ec84237d)), closes [#32](https://github.com/dougborg/harness-kit/issues/32) [#34](https://github.com/dougborg/harness-kit/issues/34)
* **pr-workflow:** route open-pr/review-pr commits through /commit's uv.lock drift check ([#63](https://github.com/dougborg/harness-kit/issues/63)) ([8500dd9](https://github.com/dougborg/harness-kit/commit/8500dd9e3565fbd46802ef3f042f9a5b0e8f437e)), closes [#62](https://github.com/dougborg/harness-kit/issues/62)
* **shared:** pagination, TOML quoted keys, verifier allowlist polish ([#60](https://github.com/dougborg/harness-kit/issues/60)) ([f310503](https://github.com/dougborg/harness-kit/commit/f3105030027f5633408afd4731d32e6fca8de5dd)), closes [#20](https://github.com/dougborg/harness-kit/issues/20)

## [0.6.0](https://github.com/dougborg/harness-kit/compare/v0.5.1...v0.6.0) (2026-06-03)


### Features

* **issue:** split lifecycle skill into four focused per-operation skills ([#25](https://github.com/dougborg/harness-kit/issues/25)) ([7ce23fb](https://github.com/dougborg/harness-kit/commit/7ce23fb18d69decd092ba4e1d5cc660fa960b8ff))
* **review-pr:** infer subject when omitted + detect dangling fixup! commits (closes [#40](https://github.com/dougborg/harness-kit/issues/40)) ([#45](https://github.com/dougborg/harness-kit/issues/45)) ([5c633f1](https://github.com/dougborg/harness-kit/commit/5c633f172fdb31940c302f79a7856a367c40b588))


### Bug Fixes

* **review-pr:** harden fixup-and-push against stale-lease rejection when the remote branch moved ([#46](https://github.com/dougborg/harness-kit/issues/46)) ([ade0b98](https://github.com/dougborg/harness-kit/commit/ade0b982aebc2626105e27bb2e6a6237f56bd25e))
* **review-pr:** include line field + surface latest comment in unresolved threads (closes [#41](https://github.com/dougborg/harness-kit/issues/41)) ([#43](https://github.com/dougborg/harness-kit/issues/43)) ([e40dea8](https://github.com/dougborg/harness-kit/commit/e40dea8e0bbb41ed4e387e4508bcfb0753a7f5fc))

## [0.5.1](https://github.com/dougborg/harness-kit/compare/v0.5.0...v0.5.1) (2026-04-28)


### Bug Fixes

* **shared:** align python3 fallback schema with jq path; fix verifier doc order ([#21](https://github.com/dougborg/harness-kit/issues/21)) ([d92f869](https://github.com/dougborg/harness-kit/commit/d92f86940f01c0fffccc585612e9d1efa6de35b0))

## [0.5.0](https://github.com/dougborg/harness-kit/compare/v0.4.0...v0.5.0) (2026-04-28)


### Features

* **harness-issue:** file upstream Issues or PRs from any consumer project ([#18](https://github.com/dougborg/harness-kit/issues/18)) ([4e438ba](https://github.com/dougborg/harness-kit/commit/4e438ba4a9c21a05ea92912bc2be9f1e7ca4e75a))


### Bug Fixes

* code-fence rendering, fetch-pr-context bugs, discover-cmd precedence ([#19](https://github.com/dougborg/harness-kit/issues/19)) ([f999e4d](https://github.com/dougborg/harness-kit/commit/f999e4dbc2bbe9d94c7249ef9bb20fdadc11d28d))
* **hooks:** drop redundant hooks field from plugin manifest ([#15](https://github.com/dougborg/harness-kit/issues/15)) ([622a368](https://github.com/dougborg/harness-kit/commit/622a3682f582cb30311fb3220b8e4495bb8c57e9))

## [0.4.0](https://github.com/dougborg/harness-kit/compare/v0.3.0...v0.4.0) (2026-04-26)


### Features

* **harness:** bundle audit fixes and retro learnings into the harness ([#13](https://github.com/dougborg/harness-kit/issues/13)) ([59a0f59](https://github.com/dougborg/harness-kit/commit/59a0f59792ff1a4486d90427f424d47879e453ad))

## [0.3.0](https://github.com/dougborg/harness-kit/compare/v0.2.0...v0.3.0) (2026-04-26)


### Features

* **harness:** add plugin hooks reference doc and schema validator ([#8](https://github.com/dougborg/harness-kit/issues/8)) ([48a1458](https://github.com/dougborg/harness-kit/commit/48a1458d7ae50cf2eb518cea0d6ebd83e1d9301b))


### Bug Fixes

* **ci:** set MD024 siblings_only to allow CHANGELOG repeated headings ([#11](https://github.com/dougborg/harness-kit/issues/11)) ([ec40b5c](https://github.com/dougborg/harness-kit/commit/ec40b5cf91de06c256050b3613c0e15ca3f18405))
* **hooks:** wrap hooks.json content in top-level "hooks" key ([#6](https://github.com/dougborg/harness-kit/issues/6)) ([cf78ebb](https://github.com/dougborg/harness-kit/commit/cf78ebbfa8858a9950c6d5c4c59dacb87a630a92))

## [0.2.0](https://github.com/dougborg/harness-kit/compare/v0.1.0...v0.2.0) (2026-04-24)


### Features

* **harness:** add update/add modes, Type D patterns, plugin-based bootstrap ([df6be56](https://github.com/dougborg/harness-kit/commit/df6be5610f2888a0fcbc7ed34b586496a50b22f6))
* initial harness-kit plugin ([ef2cabc](https://github.com/dougborg/harness-kit/commit/ef2cabc3b58fa6efa71c585d879cdb9b1d3f32ee))


### Bug Fixes

* **ci:** disable MD012 (no-multiple-blanks) in markdownlint config ([#5](https://github.com/dougborg/harness-kit/issues/5)) ([0ad6b7e](https://github.com/dougborg/harness-kit/commit/0ad6b7ed3dd03830c44c0ee99d1b63c41946b259))
* **ci:** exclude CHANGELOG.md from markdown linting ([#4](https://github.com/dougborg/harness-kit/issues/4)) ([5138b34](https://github.com/dougborg/harness-kit/commit/5138b3452f8e1413c84cb601ca800f495f1734aa))
* **harness:** address audit findings — verifier tools, plugin manifest, model tiers ([bd12ac2](https://github.com/dougborg/harness-kit/commit/bd12ac240d1ce1d3a780823e610ad92ce2a56398))
* **harness:** address audit findings — verifier tools, plugin manifest, model tiers ([cc95222](https://github.com/dougborg/harness-kit/commit/cc95222d1f9d407a42e93f99281730f2fa239346))
* **harness:** address PR review comments ([6b85e37](https://github.com/dougborg/harness-kit/commit/6b85e3758ff6e5ce760b631aba5f1486c7383017))
