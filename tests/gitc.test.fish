source (path resolve (dirname (status filename)))/helpers/setup.fish

# --- --help / -h (sole arg) prints the note ----------------------------------
set -l repo (setup_repo)
use_mocks
set -l out (gitc --help 2>&1)
@test "gitc --help exits 0" $status -eq 0
@test "gitc --help mentions git checkout" (string match -q '*git checkout*' -- "$out"; echo $status) -eq 0
set -l out2 (gitc -h 2>&1)
@test "gitc -h exits 0" $status -eq 0
@test "gitc -h mentions git checkout" (string match -q '*git checkout*' -- "$out2"; echo $status) -eq 0
teardown $repo

# --- passthrough intact: real checkout flags reach git -----------------------
set repo (setup_repo)
use_mocks
gitc -b feature-x >/dev/null 2>&1
@test "gitc -b creates and switches to the branch" (command git rev-parse --abbrev-ref HEAD) = feature-x
gitc main >/dev/null 2>&1
@test "gitc <branch> switches branches" (command git rev-parse --abbrev-ref HEAD) = main
teardown $repo

# --- --help only intercepts when it is the SOLE argument ---------------------
# `gitc -b --help` must NOT print the note; it should pass through to git
# (which will create a branch literally named "--help" or error — either way
# the note is not printed).
set repo (setup_repo)
use_mocks
set -l out (gitc -b --help 2>&1)
@test "gitc -b --help does not print the gitc note" (string match -q '*shorthand for*' -- "$out"; echo $status) -eq 1
teardown $repo
