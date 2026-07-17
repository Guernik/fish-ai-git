source (path resolve (dirname (status filename)))/helpers/setup.fish

# --- Bails when there is nothing to commit -----------------------------------
set -l repo (setup_repo)
use_mocks
set -l out (ac 2>&1)
set -l code $status
@test "ac bails when there is nothing to commit" $code -eq 1
@test "ac reports nothing to commit" (string match -q '*Nothing to commit*' -- "$out"; echo $status) -eq 0
teardown $repo

# --- Commits the mock message on confirmation --------------------------------
set repo (setup_repo)
use_mocks
set -gx MOCK_CLAUDE_OUTPUT "feat: add widget

Body paragraph explaining the widget.

Changes:
- add widget"
echo change >widget.txt
echo y | ac >/dev/null 2>&1
set -l subject (command git log -1 --pretty=%s)
@test "ac commits with the model's message subject" "$subject" = "feat: add widget"
set -e MOCK_CLAUDE_OUTPUT
teardown $repo

# --- Excludes lockfiles from the diff sent to the model ----------------------
set repo (setup_repo)
use_mocks
set -l stdin_capture (command mktemp)
set -gx MOCK_CLAUDE_STDIN $stdin_capture
echo "real source change" >app.js
echo GARBAGE_LOCK_CONTENT_XYZ >package-lock.json
echo y | ac >/dev/null 2>&1
set -l sent (command cat $stdin_capture)
@test "ac sends the real source change to the model" (string match -q '*app.js*' -- "$sent"; echo $status) -eq 0
@test "ac excludes lockfile content from the model prompt" (string match -q '*GARBAGE_LOCK_CONTENT_XYZ*' -- "$sent"; echo $status) -eq 1
set -e MOCK_CLAUDE_STDIN
command rm -f $stdin_capture
teardown $repo

# --- Uses $AC_MODEL when set -------------------------------------------------
set repo (setup_repo)
use_mocks
set -l args_capture (command mktemp)
set -gx MOCK_CLAUDE_ARGS $args_capture
set -gx AC_MODEL sonnet
echo change >thing.txt
echo y | ac >/dev/null 2>&1
set -l args (command cat $args_capture)
@test "ac passes the overridden model to claude" (string match -q '*sonnet*' -- "$args"; echo $status) -eq 0
set -e AC_MODEL
set -e MOCK_CLAUDE_ARGS
command rm -f $args_capture
teardown $repo

# --- Leaves changes staged on abort ------------------------------------------
set repo (setup_repo)
use_mocks
echo change >abort.txt
echo n | ac >/dev/null 2>&1
set -l staged (command git diff --cached --name-only)
@test "ac leaves changes staged when the user aborts" (string match -q '*abort.txt*' -- "$staged"; echo $status) -eq 0
@test "ac creates no commit when the user aborts" (command git log -1 --pretty=%s) = "chore: initial commit"
teardown $repo
