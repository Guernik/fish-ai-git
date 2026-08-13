source (path resolve (dirname (status filename)))/helpers/setup.fish

# --- Bails when on the base branch -------------------------------------------
set -l repo (setup_repo)
use_mocks
# setup_repo leaves us on main (the base), so ghpr should refuse.
set -l out (echo n | ghpr 2>&1)
set -l code $status
@test "ghpr bails when on the base branch" $code -eq 1
@test "ghpr explains it is on the base branch" (string match -q '*base branch*' -- "$out"; echo $status) -eq 0
teardown $repo

# --- Bails on detached HEAD --------------------------------------------------
set repo (setup_repo)
use_mocks
command git checkout --quiet (command git rev-parse HEAD)
set out (echo n | ghpr 2>&1)
@test "ghpr bails on detached HEAD" (string match -q '*Detached HEAD*' -- "$out"; echo $status) -eq 0
teardown $repo

# --- Bails when the feature branch has no new commits ------------------------
set repo (setup_repo)
use_mocks
command git checkout --quiet -b feature
set out (echo n | ghpr 2>&1)
@test "ghpr bails when there are no commits beyond base" (string match -q '*Nothing to open a PR*' -- "$out"; echo $status) -eq 0
teardown $repo

# --- Detects the base and passes title/body/base/head to gh pr create --------
set repo (setup_repo)
use_mocks
set -l gh_capture (command mktemp)
set -gx MOCK_GH_ARGS $gh_capture
set -gx MOCK_CLAUDE_OUTPUT "feat: add feature

## Summary
Adds a feature.

## Changes
- add the feature"
command git checkout --quiet -b feature
echo work >feature.txt
command git add feature.txt
command git commit --quiet -m "feat: add feature file"
echo y | ghpr >/dev/null 2>&1
set -l gh_args (command cat $gh_capture)
@test "ghpr calls gh pr create" (string match -q '*create*' -- "$gh_args"; echo $status) -eq 0
@test "ghpr passes the detected base branch to gh" (string match -q '*main*' -- "$gh_args"; echo $status) -eq 0
@test "ghpr passes the feature branch as head to gh" (string match -q '*feature*' -- "$gh_args"; echo $status) -eq 0
@test "ghpr passes the model's title to gh" (string match -q '*feat: add feature*' -- "$gh_args"; echo $status) -eq 0
set -e MOCK_GH_ARGS
set -e MOCK_CLAUDE_OUTPUT
command rm -f $gh_capture
teardown $repo

# --- Strips preamble/separator noise before the title ------------------------
set repo (setup_repo)
use_mocks
set -l gh_capture (command mktemp)
set -gx MOCK_GH_ARGS $gh_capture
# Reproduce the failing case: the model prepends a preamble sentence and a
# '---' rule before the real title. ghpr must still extract the real title.
set -gx MOCK_CLAUDE_OUTPUT "Based on the commit messages and extensive diff provided, here's the PR:

---

feat(ai): AI settings screen and enhanced review UX

## Summary
Adds a feature.

## Changes
- add the feature"
command git checkout --quiet -b feature-noise
echo work >feature-noise.txt
command git add feature-noise.txt
command git commit --quiet -m "feat: add feature file"
echo y | ghpr >/dev/null 2>&1
set -l gh_args (command cat $gh_capture)
@test "ghpr uses the real title, not the preamble" (string match -q '*feat(ai): AI settings screen and enhanced review UX*' -- "$gh_args"; echo $status) -eq 0
@test "ghpr drops the preamble line from the title" (string match -q '*Based on the commit messages*' -- "$gh_args"; echo $status) -eq 1
set -e MOCK_GH_ARGS
set -e MOCK_CLAUDE_OUTPUT
command rm -f $gh_capture
teardown $repo

# --- Unwraps a fenced PR without leaving a stray closing fence ---------------
# The old inline sanitizer only skipped *leading* fence lines, so a PR wrapped
# in ``` kept its closing fence at the end of the body and posted it to GitHub.
set repo (setup_repo)
use_mocks
set -l gh_capture (command mktemp)
set -gx MOCK_GH_ARGS $gh_capture
set -l fence '```'
set -gx MOCK_CLAUDE_OUTPUT "Here's the PR:

$fence
feat(ui): add settings screen

## Summary
Adds a settings screen.

## Changes
- add the screen
$fence"
command git checkout --quiet -b feature-fenced
echo work >feature-fenced.txt
command git add feature-fenced.txt
command git commit --quiet -m "feat: add fenced feature"
echo y | ghpr >/dev/null 2>&1
set -l gh_args (command cat $gh_capture)
@test "ghpr uses the fenced title" (string match -q '*feat(ui): add settings screen*' -- "$gh_args"; echo $status) -eq 0
@test "ghpr leaves no code fence in the PR body" (string match -q '*```*' -- "$gh_args"; echo $status) -eq 1
@test "ghpr drops the preamble before the fence" (string match -q "*Here's the PR*" -- "$gh_args"; echo $status) -eq 1
@test "ghpr keeps the PR body sections" (string match -q '*## Summary*' -- "$gh_args"; echo $status) -eq 0
set -e MOCK_GH_ARGS
set -e MOCK_CLAUDE_OUTPUT
command rm -f $gh_capture
teardown $repo

# --- Uses $GHPR_MODEL when set -----------------------------------------------
set repo (setup_repo)
use_mocks
set -l args_capture (command mktemp)
set -gx MOCK_CLAUDE_ARGS $args_capture
set -gx GHPR_MODEL sonnet
command git checkout --quiet -b feature2
echo work >feature2.txt
command git add feature2.txt
command git commit --quiet -m "feat: second feature"
echo n | ghpr >/dev/null 2>&1
set -l args (command cat $args_capture)
@test "ghpr passes the overridden model to claude" (string match -q '*sonnet*' -- "$args"; echo $status) -eq 0
set -e GHPR_MODEL
set -e MOCK_CLAUDE_ARGS
command rm -f $args_capture
teardown $repo

# --- --help prints usage (no repo/deps needed) -------------------------------
set repo (setup_repo)
use_mocks
set -l out (ghpr --help 2>&1)
@test "ghpr --help exits 0" $status -eq 0
@test "ghpr --help prints usage" (string match -q '*usage: ghpr*' -- "$out"; echo $status) -eq 0
set -l out2 (ghpr -h 2>&1)
@test "ghpr -h exits 0" $status -eq 0
@test "ghpr -h prints usage" (string match -q '*usage: ghpr*' -- "$out2"; echo $status) -eq 0
teardown $repo
