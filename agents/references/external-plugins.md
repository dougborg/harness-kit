# External Plugins Reference — Official Anthropic Marketplaces

Single source of truth for recommending Anthropic's official plugins during `/harness bootstrap` and `/harness audit`. Referenced by `skills/harness/SKILL.md` (Bootstrap and Audit modes) and `agents/harness-builder.md` — do not duplicate this catalog elsewhere.

## The Two Marketplaces

| Marketplace | Repo | Contents |
| --- | --- | --- |
| `claude-code-plugins` | `anthropics/claude-code` | ~13 Anthropic-authored plugins bundled with Claude Code (dev workflows, output styles) |
| `claude-plugins-official` | `anthropics/claude-plugins-official` | Large directory (270+ plugins) — the Anthropic dev-workflow set above plus third-party integrations (AWS, Sentry, Stripe, LSPs, ...) |

Add a marketplace before installing from it:

```bash
/plugin marketplace add anthropics/claude-plugins-official
/plugin install <name>@claude-plugins-official
```

The Anthropic dev-workflow plugins appear in both marketplaces; prefer `@claude-plugins-official` since it is the superset directory. Both marketplaces evolve — treat the catalog below as a curated snapshot (verified 2026-07-23) and check the live `marketplace.json` when in doubt:

```bash
gh api repos/anthropics/claude-plugins-official/contents/.claude-plugin/marketplace.json --jq '.content' | base64 -d
```

## Catalog: Stack-Conditional Recommendations

Recommend when the stack trigger matches. One-line rationale comes from the "What it does" column.

### Language servers (recommend whenever the language is detected)

| Plugin | Stack trigger | What it does |
| --- | --- | --- |
| `pyright-lsp` | Python | Type-aware code intelligence via Pyright |
| `typescript-lsp` | TypeScript/JavaScript | TS/JS language server integration |
| `rust-analyzer-lsp` | Rust | rust-analyzer code intelligence |
| `gopls-lsp` | Go | gopls code intelligence and refactoring |
| `jdtls-lsp` | Java | Eclipse JDT.LS integration |
| `kotlin-lsp` | Kotlin | Kotlin language server |
| `ruby-lsp` | Ruby | Ruby LSP integration |
| `php-lsp` | PHP | Intelephense integration |
| `swift-lsp` | Swift | SourceKit-LSP integration |
| `csharp-lsp` | C# | C# language server |
| `clangd-lsp` | C/C++ | clangd code intelligence |
| `lua-lsp` | Lua | Lua language server |

LSP plugins have **no harness-kit overlap** — always safe to recommend alongside harness-kit.

### Domain-specific development

| Plugin | Stack trigger | What it does | harness-kit overlap |
| --- | --- | --- | --- |
| `mcp-server-dev` | Project builds an MCP server | MCP server design skills: deployment models, tool design, auth | None — complements everything |
| `agent-sdk-dev` | Project uses the Claude Agent SDK | Agent SDK development kit | None |
| `plugin-dev` | Project develops Claude Code plugins | 7 expert skills for hooks, MCP, commands, agents | Complements `/skill-writer` (harness-kit covers skill structure; plugin-dev covers plugin packaging) |
| `frontend-design` | Frontend present | Production-grade UI generation avoiding generic AI aesthetics | Complements `/ui-review` (design generation vs accessibility audit) |
| `code-modernization` | Legacy codebase (COBOL, legacy Java/C++, monoliths) | Structured assess/transform/harden modernization workflow | None — pairs with project-local modernizer agents |
| `security-guidance` | Any project handling untrusted input or secrets | Pattern-based security warnings on edits + agentic commit reviewer | Complements code-reviewer's security dimension (hook-time vs review-time) |
| `context7` | Heavy third-party API/framework use | Up-to-date version-specific docs pulled into context | None |
| `playwright` / `chrome-devtools-mcp` | Web app with E2E testing needs | Browser automation MCP servers | None |

### Workflow plugins with harness-kit overlap (pick one, or document composition)

| Plugin | What it does | Overlapping harness-kit skill | Guidance |
| --- | --- | --- | --- |
| `code-review` | Multi-agent PR review with confidence-based false-positive filtering | `code-reviewer` agent + skill | Pick one active reviewer. harness-kit: 6-dimension structured review, project conventions. Anthropic: parallel agents + confidence scoring. Running both doubles review noise. |
| `pr-review-toolkit` | Specialized review agents (comments, tests, error handling, type design) | `/review-pr`, `/pr-comments` | Pick one. harness-kit's `/review-pr` handles the full feedback-response loop; the toolkit adds per-dimension specialists. |
| `commit-commands` | Commit, push, and PR creation commands | `/commit`, `/open-pr` | Pick one, or compose: harness-kit `/commit` adds project quality gates; `commit-commands` is a lighter generic flow. |
| `code-simplifier` | Simplifies recently modified code while preserving behavior | `/simplify`-style cleanup in `/open-pr` self-review | Compose freely — same goal, invoked at different times. |
| `feature-dev` | Feature workflow: exploration, architecture, quality review agents | `/feature-spec` | Compose: `/feature-spec` writes the spec; `feature-dev` drives implementation. Or pick one end-to-end flow. |
| `claude-code-setup` | Analyzes codebase, recommends hooks/skills/MCP servers/subagents | `/harness bootstrap` | Pick one — both scaffold the project harness. harness-kit adds provenance tracking (`.harness-lock.json`), update/retro/hoist loops. |
| `claude-md-management` | Audit CLAUDE.md quality, capture session learnings | `/harness retro` + bootstrap's CLAUDE.md generation | Compose: retro captures harness gaps; claude-md-management focuses on CLAUDE.md hygiene. |
| `skill-creator` | Create, improve, and eval skills | `/skill-writer` | Pick one. harness-kit teaches the scannable-contract structure; skill-creator adds eval/benchmark tooling. |
| `hookify` | Generate custom hooks from conversation patterns or instructions | Automation-First Hooks guidance in `/harness` | Compose: harness-kit defines the formatter/validator/guidance ordering; hookify authors the individual hooks. |
| `session-report` | HTML report of session token/cache/subagent usage | `/standup` (loosely) | Compose — different outputs (usage analytics vs daily summary). |
| `ralph-loop` | Iterative self-referential task loops | None direct | Optional productivity tool; named `ralph-wiggum` in `claude-code-plugins`. |
| `learning-output-style` / `explanatory-output-style` | Output-style preferences (educational insights / contribution prompts) | None | Pure user preference — mention, never preselect. |

## Composition Principles

- **Avoid double-installs** — never leave two active tools covering the same job (e.g. harness-kit `code-reviewer` AND Anthropic `code-review`). Recommend one and record the choice.
- **Overlap is not always conflict** — some pairs compose (quality-gate commit + AI messages; spec writing + feature workflow). When recommending both, state the division of labor in one line.
- **Record decisions in CLAUDE.md** — bootstrap should add an "External plugins" section listing what was installed or deliberately skipped, with rationale, so audit can check it later.
- **Plugins are installed, not copied** — external plugins are managed by `/plugin install`, live outside `.claude/`, and are NOT tracked in `.harness-lock.json`. Only harness-kit files copied into `.claude/` get lock-file entries.
