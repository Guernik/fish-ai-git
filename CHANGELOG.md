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
