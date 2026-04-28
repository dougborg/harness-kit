# Changelog

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
