# Plan: Public "fish-ai-git" — a Fisher-installable AI git workflow toolkit

## Context

Emilio has a set of personal fish functions in `~/.config/fish/functions/`. He wants to
publish a **focused, public GitHub repo** of his most-used ones, in good shape to share.
The empty working dir `/Users/emilio/projects/fish_functions` is where the repo will be built.

Decisions made during grilling:
- **Scope:** ship only the AI-assisted git workflow — `ac`, `ghpr`, `gitm`, `gitc`. The
  one-off aliases (`l`, `gits`), the fzf search (`f`), `portinfo`, and the `nomad-*`
  functions are **excluded**. The nomad functions especially must NOT ship — they contain
  real infra identifiers (a production SSH host, SSH user/key paths, and a live Infisical
  project UUID). Leaking those to a public repo is the main risk this plan avoids.
- **Testing:** real Fishtape unit tests with `claude`/`gh`/`git` mocked as PATH shims.
- **Install:** Fisher plugin (community standard; Emilio already uses `jorgebucaran/fisher`)
  plus a `justfile` for dev/test/lint tasks. Same install path for Emilio and the public.
- **AI config:** model via env var (`$AC_MODEL` / `$GHPR_MODEL`, default `haiku`); big
  inline prompt stays as the default.
- **gitm:** keep the `git branch -d $prev` cleanup (safe: `-d` refuses unmerged branches).
- **Name:** themed — proposed `fish-ai-git` (repo `emilio/fish-ai-git`).

The two functions with real public value are `ac` (AI Conventional-Commit message) and
`ghpr` (push + AI-generated GitHub PR). `gitm`/`gitc` round out the workflow.

## Source functions (current state)

- `~/.config/fish/functions/ac.fish` — stage all, AI commit msg via `claude -p --model haiku`,
  confirm loop. Already has good large-diff handling (lockfile excludes, byte cap, `string collect`).
- `~/.config/fish/functions/ghpr.fish` — push branch, AI PR title/body, `gh pr create`.
  Already detects base branch via `origin/HEAD` with main/master fallback.
- `~/.config/fish/functions/gitm.fish` — checkout main + pull + delete prev branch.
  Currently hardcodes `main`.
- `~/.config/fish/functions/gitc.fish` — `git checkout $argv`.

## Target repo layout (Fisher convention)

```
fish-ai-git/
  functions/
    ac.fish
    ghpr.fish
    gitm.fish
    gitc.fish
  conf.d/
    fish-ai-git.fish        # sets default $AC_MODEL/$GHPR_MODEL if unset (universal-safe)
  tests/
    ac.test.fish
    ghpr.test.fish
    gitm.test.fish
    helpers/
      mock_bin/             # shim scripts: git, claude, gh (put on PATH during tests)
      setup.fish            # sourced by each test: builds temp repo + PATH shims
  justfile
  .pre-commit-config.yaml
  .github/workflows/ci.yml
  .editorconfig
  .gitignore
  README.md
  LICENSE                   # MIT (confirm license choice at implementation)
  CHANGELOG.md              # optional; Keep a Changelog format
```

## Changes to the functions (minimal, deliberate)

1. **`ac.fish`** — copy verbatim, with one change: model via env var.
   Add near the top: `set -q AC_MODEL; or set -l AC_MODEL haiku` and change the call to
   `claude -p --model $AC_MODEL ...`. Everything else (excludes, byte cap, confirm loop) stays.

2. **`ghpr.fish`** — same env-var change with `$GHPR_MODEL` (default `haiku`). No other logic changes.

3. **`gitm.fish`** — generalize the hardcoded `main` to the repo's default branch so it works
   on `master` repos too. Reuse the base-branch detection pattern already in `ghpr.fish`
   (`git symbolic-ref refs/remotes/origin/HEAD` → strip prefix; fall back to main/master).
   Keep the `git branch -d $prev` cleanup and the `$prev != base` guard. Add a
   `--description`. Keep it short.

4. **`gitc.fish`** — add a `--description` and `--wraps 'git checkout'` (gives free
   completions). Otherwise unchanged.

5. **`conf.d/fish-ai-git.fish`** — set `AC_MODEL`/`GHPR_MODEL` defaults only if unset, so
   users get a documented single place; functions still self-default so they work if copied alone.

All functions already emit dependency-missing errors (`command -q claude/gh`) and guard
non-git dirs — keep those; they're good public hygiene.

## Testing (Fishtape + PATH-shim mocks)

`tests/helpers/setup.fish` (sourced by each test):
- `mktemp -d` a throwaway git repo, `git init`, set user.name/email, make an initial commit.
- Prepend `tests/helpers/mock_bin` to `PATH` so `claude`/`gh` are replaced by shims that
  echo canned output and record their stdin/args to a temp file for assertions. `git` is
  mostly real (against the temp repo); only mock it where a test needs to force a branch/remote state.

Key cases to cover (exercise real logic, not the LLM):
- **ac**: bails with "Nothing to commit" when the diff is empty; excludes lockfiles from the
  diff sent to the mock `claude` (assert the recorded stdin omits `*.lock` content); commits
  with the message the mock `claude` returns on `y`; leaves changes staged on abort.
- **ghpr**: bails on detached HEAD; bails when on the base branch; base-branch detection picks
  up `origin/HEAD`; passes title/body through to mock `gh pr create`.
- **gitm**: switches to detected default branch; deletes prev only when it differs; no-op
  delete when already on base.

Each test file is a Fishtape `.test.fish`; run all via `fishtape tests/*.test.fish`.

## Tooling / CI

- **justfile** recipes:
  - `install` → `fisher install .` (from a local clone) or document `fisher install emilio/fish-ai-git`.
  - `install-dev` → symlink `functions/*.fish` + `conf.d/*.fish` into `~/.config/fish/` for live
    editing (so `git pull` reflects immediately). Provide matching `uninstall-dev`.
  - `test` → install fishtape if missing, run `fishtape tests/*.test.fish`.
  - `lint` → `fish -n` (syntax) on every `.fish` + `fish_indent --check` (formatting).
  - `fmt` → `fish_indent -w` in place.
- **.pre-commit-config.yaml** — local hooks calling `just lint` and `just test` (or the raw
  `fish -n` / `fish_indent --check` commands). Keep hooks fast; put full test run in CI.
- **.github/workflows/ci.yml** — on push/PR: install fish (apt on ubuntu-latest or the
  `fish-shell` action), install fisher + fishtape, run `just lint` then `just test`.
- **.editorconfig** — 4-space indent for `.fish` (matches `ac`/`ghpr` style).
- **README.md** — what it is, the 4 functions with examples, requirements (`claude` CLI, `gh`,
  fish ≥ 3.6), Fisher install, `$AC_MODEL`/`$GHPR_MODEL` config, dev/test via just.
- **LICENSE** — MIT (confirm at implementation).

## Verification

1. `just lint` → all `.fish` pass `fish -n` and `fish_indent --check`.
2. `just test` → `fishtape tests/*.test.fish` green (mocked claude/gh; real temp git repos).
3. Local install smoke test: `fisher install .` in a scratch fish session, then confirm
   `functions -q ac ghpr gitm gitc` and `type ac` resolves to the installed copy.
4. `install-dev` smoke test: run it, edit a function in the repo, confirm the change is live
   in a new shell (symlink works), then `uninstall-dev` cleans up.
5. Manual sanity of `ac` against a real throwaway repo (a one-line change) to confirm the
   env-var model swap and confirm loop still behave. `ghpr` can be dry-checked by pointing at
   a scratch repo/remote or reviewing the generated title/body before the `gh pr create` step.

## Explicitly out of scope / excluded

- `nomad-up.fish`, `nomad-down.fish`, `nomad-logs-*.fish`, `nomad-running-alloc.fish`, `nns.fish`
  — contain real production infra identifiers; do NOT publish.
- `f.fish`, `l.fish`, `gits.fish`, `portinfo.fish`, `tunnel-list.fish` — personal aliases /
  broad utilities that dilute the focused toolkit. Could become a separate dotfiles repo later.
- Tab completions beyond `gitc`'s free `--wraps` — not needed (ac/ghpr/gitm take no args).
