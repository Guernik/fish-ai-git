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

# --- Preserves the blank lines of a multi-line message -----------------------
set repo (setup_repo)
use_mocks
set -gx MOCK_CLAUDE_OUTPUT "feat: add widget

Body paragraph explaining the widget.

Changes:
- add widget"
echo change >multiline.txt
echo y | ac >/dev/null 2>&1
set -l full (command git log -1 --pretty=%B | string collect)
@test "ac keeps the body separated from the subject" (string match -q '*widget

Body paragraph*' -- "$full"; echo $status) -eq 0
@test "ac keeps the Changes section" (string match -q '*Changes:
- add widget*' -- "$full"; echo $status) -eq 0
set -e MOCK_CLAUDE_OUTPUT
teardown $repo

# --- Strips preamble and code-fence noise ------------------------------------
# Guards the reported failure: the model prepends a preamble sentence and wraps
# the real message in a ``` fence. Only the fenced text may reach the commit.
set repo (setup_repo)
use_mocks
set -l fence '```'
set -gx MOCK_CLAUDE_OUTPUT "Now I'll create the commit message following the required structure:

$fence
fix(rehype-lightbox): skip lightbox on images wrapped in links

Images inside links should not trigger the lightbox.

Changes:
- Refactor rehype-lightbox plugin
$fence"
echo change >fenced.txt
echo y | ac >/dev/null 2>&1
set -l subject (command git log -1 --pretty=%s)
set -l full (command git log -1 --pretty=%B | string collect)
@test "ac uses the fenced message, not the preamble" "$subject" = "fix(rehype-lightbox): skip lightbox on images wrapped in links"
@test "ac drops the preamble line" (string match -q '*Now I*create the commit message*' -- "$full"; echo $status) -eq 1
@test "ac drops the code fences" (string match -q '*```*' -- "$full"; echo $status) -eq 1
set -e MOCK_CLAUDE_OUTPUT
teardown $repo

# --- Leaves punctuation in the message untouched -----------------------------
# Real messages contain apostrophes, double quotes and inline backticks; the
# sanitizer must pass them through byte-for-byte (an earlier JSON-decoding
# approach silently ate apostrophes and left \" and \n literals behind).
set repo (setup_repo)
use_mocks
set -gx MOCK_CLAUDE_OUTPUT "feat(ac): keep Claude's \"message\" text intact

The `ac` function shouldn't mangle quotes.

Changes:
- Preserve apostrophes, \"double quotes\" and `backticks`"
echo change >punct.txt
echo y | ac >/dev/null 2>&1
set -l full (command git log -1 --pretty=%B | string collect)
@test "ac preserves apostrophes" (string match -q "*Claude's*" -- "$full"; echo $status) -eq 0
@test "ac preserves double quotes" (string match -q '*"message"*' -- "$full"; echo $status) -eq 0
@test "ac preserves inline backticks" (string match -q '*`backticks`*' -- "$full"; echo $status) -eq 0
@test "ac leaves no literal backslash-n" (string match -q '*\\n*' -- "$full"; echo $status) -eq 1
set -e MOCK_CLAUDE_OUTPUT
teardown $repo

# --- Fails cleanly when the model returns nothing usable ---------------------
# Whitespace-only output must not become an empty commit message. (The mock
# can't emit truly empty output — it treats that as "unset" — so use blanks,
# which reach the same guard after trimming.)
set repo (setup_repo)
use_mocks
set -gx MOCK_CLAUDE_OUTPUT "

"
echo change >empty.txt
set -l out (echo y | ac 2>&1)
set -l code $status
@test "ac fails when the model returns an empty message" $code -eq 1
@test "ac reports the generation failure" (string match -q '*Failed to generate*' -- "$out"; echo $status) -eq 0
@test "ac creates no commit from empty output" (command git log -1 --pretty=%s) = "chore: initial commit"
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

# --- --help prints usage without staging or calling the model ----------------
set repo (setup_repo)
use_mocks
set -l args_capture (command mktemp)
set -gx MOCK_CLAUDE_ARGS $args_capture
: >$args_capture
set -l out (ac --help 2>&1)
@test "ac --help exits 0" $status -eq 0
@test "ac --help prints usage" (string match -q '*usage: ac*' -- "$out"; echo $status) -eq 0
@test "ac --help does not invoke claude" (test -s $args_capture; echo $status) -eq 1
@test "ac --help creates no commit" (command git log -1 --pretty=%s) = "chore: initial commit"
set -l out2 (ac -h 2>&1)
@test "ac -h exits 0" $status -eq 0
@test "ac -h prints usage" (string match -q '*usage: ac*' -- "$out2"; echo $status) -eq 0
set -e MOCK_CLAUDE_ARGS
command rm -f $args_capture
teardown $repo
