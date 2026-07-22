# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `ac` — stage all changes and commit with an AI-generated Conventional Commit
  message.
- `ghpr` — push the current branch and open a GitHub PR with an AI-generated
  title and body.
- `gitm` — switch to the default branch, pull, and delete the merged branch you
  left.
- `gitc` — `git checkout` shorthand.
- `$AC_MODEL` / `$GHPR_MODEL` to override the Claude model.
- Fishtape test suite with mocked `claude`/`gh` CLIs.
- `justfile`, pre-commit config, and GitHub Actions CI (lint + test).

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
