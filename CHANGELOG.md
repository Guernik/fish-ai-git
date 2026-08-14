# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.2.0] - 2026-08-14

### Added

- Version reporting. Every command answers `--version` (`ac`, `ghpr` and `gitm`
  also accept `-v`; `gitc` takes only the long form, since `-v` belongs to
  `git checkout`), and `ac`/`ghpr` prefix their progress line with it:
  `ac v1.2.0: Generating commit message…`.
- A root `VERSION` file as the single source of truth, mirrored into
  `conf.d/fish-ai-git.fish` because Fisher installs only `functions/` and
  `conf.d/` — a root file never reaches an installed plugin.
- Release recipes that need no separate release commit or PR: `just bump X.Y.Z`
  writes both files without committing (so the bump rides along in the PR you
  are already opening), and `just push-version` signs and pushes the matching
  tag once that PR is merged. Both refuse to run in unsafe states — an existing
  tag, non-semver input, a dirty tree, or a `main` with unpushed commits.
- `just version` and `just version-check`; the latter fails CI if `VERSION` and
  `conf.d/` ever drift apart.

### Fixed

- `ac` no longer commits the model's chatter. Preamble lines ("Now I'll create
  the commit message:") and Markdown code fences wrapped around the message are
  stripped, so only the real commit message is committed.
- `ghpr` no longer leaves a stray closing ``` at the end of the PR body when the
  model wraps its whole answer in a code fence. Its previous sanitizer removed
  only the opening fence.

### Changed

- `ac` and `ghpr` now share one sanitizer, `_fish_ai_git_clean_output`, so both
  treat model output identically instead of drifting apart.

## [1.0.1] - 2026-08-11

### Changed

- `ac` now instructs the model to keep entries in the `Changes:` section brief
  and direct, rather than restating a diff line by line.

## [1.0.0] - 2026-07-22

Initial release.

### Added

- `ac` — stage all changes and commit with an AI-generated Conventional Commit
  message.
- `ghpr` — push the current branch and open a GitHub PR with an AI-generated
  title and body.
- `gitm` — switch to the default branch, pull, and delete the merged branch you
  left.
- `gitc` — `git checkout` shorthand.
- `$AC_MODEL` / `$GHPR_MODEL` to override the Claude model, seeded as universal
  variables via Fisher event handlers.
- `--help` on every function.
- Noisy-file filtering (lockfiles, minified assets, `dist/`, `build/`,
  snapshots) and a ~100 KB cap on the diff sent to the model — the filtering
  affects only what the model sees; every staged file is still committed.
- Fishtape test suite with mocked `claude`/`gh` CLIs.
- `justfile`, pre-commit config, and GitHub Actions CI (lint + test).

### Fixed

- `ghpr` sanitizes a model preamble before parsing the PR title, so a line like
  "Here's the PR:" is no longer captured as the title.

### Security

- `SECURITY.md` documenting the trust model, private reporting, signed-release
  verification, and branch-protection expectations.
- Signed, pinned releases: a `release.yml` workflow cuts a GitHub Release from
  signed `v*` tags so users can `fisher install …@vX.Y.Z` and verify with
  `git tag -v`.
- `just audit` — a high-signal scan of the shipped files for dangerous shell
  patterns, run on every PR in CI and reported as a sticky PR comment. (Scoped
  to contributor mistakes, not a defense against a malicious maintainer.)
- `.github/CODEOWNERS` requiring owner review of shipped code and CI/release
  workflows.
- CI actions pinned to commit SHAs; workflow permissions set to least
  privilege.

[Unreleased]: https://github.com/Guernik/fish-ai-git/compare/v1.2.0...HEAD
[1.2.0]: https://github.com/Guernik/fish-ai-git/compare/v1.0.1...v1.2.0
[1.0.1]: https://github.com/Guernik/fish-ai-git/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/Guernik/fish-ai-git/releases/tag/v1.0.0
