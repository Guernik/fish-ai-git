source (path resolve (dirname (status filename)))/helpers/setup.fish

# The version the functions report must match the VERSION file, and VERSION
# must match conf.d — Fisher installs conf.d but never the root VERSION file,
# so a drift between them ships the wrong number to users.
set -l root (path resolve (dirname (status filename)))/..
set -l file_version (string trim <$root/VERSION)
set -l conf_version (string match -rg '^set -g __fish_ai_git_version (.+)$' <$root/conf.d/fish-ai-git.fish | string trim)

@test "VERSION file is non-empty" (test -n "$file_version"; echo $status) -eq 0
@test "VERSION is plain semver" (string match -qr '^[0-9]+\.[0-9]+\.[0-9]+$' -- $file_version; echo $status) -eq 0
@test "conf.d version matches the VERSION file" "$conf_version" = "$file_version"

# --- _fish_ai_git_version resolution -----------------------------------------
set -g __fish_ai_git_version 9.9.9
@test "_fish_ai_git_version prefers the global set by conf.d" (_fish_ai_git_version) = 9.9.9
set -e __fish_ai_git_version
@test "_fish_ai_git_version falls back to the VERSION file" (_fish_ai_git_version) = "$file_version"

# --- --version on each command -----------------------------------------------
set -g __fish_ai_git_version $file_version

set -l repo (setup_repo)
use_mocks
set -l args_capture (command mktemp)
set -gx MOCK_CLAUDE_ARGS $args_capture
: >$args_capture

set -l out (ac --version 2>&1)
@test "ac --version exits 0" $status -eq 0
@test "ac --version prints the version" "$out" = "ac (fish-ai-git) v$file_version"
@test "ac --version does not invoke claude" (test -s $args_capture; echo $status) -eq 1
@test "ac --version creates no commit" (command git log -1 --pretty=%s) = "chore: initial commit"
@test "ac -v prints the version" (ac -v 2>&1) = "ac (fish-ai-git) v$file_version"

@test "ghpr --version prints the version" (ghpr --version 2>&1) = "ghpr (fish-ai-git) v$file_version"
@test "ghpr -v prints the version" (ghpr -v 2>&1) = "ghpr (fish-ai-git) v$file_version"
@test "gitm --version prints the version" (gitm --version 2>&1) = "gitm (fish-ai-git) v$file_version"
@test "gitm -v prints the version" (gitm -v 2>&1) = "gitm (fish-ai-git) v$file_version"
@test "gitc --version prints the version" (gitc --version 2>&1) = "gitc (fish-ai-git) v$file_version"

set -e MOCK_CLAUDE_ARGS
command rm -f $args_capture
teardown $repo

# --- gitc must not shadow git checkout's own -v ------------------------------
# `-v` is checkout's verbose flag, so gitc only intercepts the long --version.
set repo (setup_repo)
use_mocks
command git checkout --quiet -b other
command git checkout --quiet main
set -l out (gitc -v other 2>&1)
@test "gitc -v is passed through to git, not intercepted" (string match -q '*fish-ai-git*' -- "$out"; echo $status) -eq 1
teardown $repo

# --- the progress line carries the version -----------------------------------
set repo (setup_repo)
use_mocks
echo change >versioned.txt
set -l out (echo n | ac 2>&1 | head -n 1)
@test "ac prefixes its progress line with the version" "$out" = "ac v$file_version: Generating commit message…"
teardown $repo

set repo (setup_repo)
use_mocks
command git checkout --quiet -b feature-version
echo work >vwork.txt
command git add vwork.txt
command git commit --quiet -m "feat: version work"
set -l out (echo n | ghpr 2>&1 | head -n 1)
@test "ghpr prefixes its progress line with the version" "$out" = "ghpr v$file_version: Generating PR title and body…"
teardown $repo
