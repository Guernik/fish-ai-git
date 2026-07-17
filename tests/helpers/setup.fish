# Shared test setup for fish-ai-git.
#
# Sourced by each *.test.fish. Provides helpers to build a throwaway git repo
# wired to a real local bare "remote" (so `git push` and origin/HEAD behave for
# real) and to put the mock `claude`/`gh` binaries on PATH.
#
# Usage in a test:
#     source (dirname (status filename))/helpers/setup.fish
#     set -l repo (setup_repo)      # cd's into a fresh work tree with origin
#     use_mocks                     # prepend mock_bin to PATH
#     ...
#     teardown $repo                # remove temp dirs, restore PATH

set -g __fag_helpers_dir (path resolve (dirname (status filename)))
set -g __fag_root (path resolve $__fag_helpers_dir/../..)
set -g __fag_mock_bin (path resolve $__fag_helpers_dir/mock_bin)

# Load the functions under test into this shell.
for f in $__fag_root/functions/*.fish
    source $f
end

# Track temp dirs and the saved PATH so teardown can clean up.
set -g __fag_tmpdirs
set -g __fag_saved_path

function setup_repo --description "Create a temp git repo wired to a local bare remote; cd into it; echo its path"
    set -l remote (command mktemp -d)
    set -l work (command mktemp -d)
    set -g __fag_tmpdirs $__fag_tmpdirs $remote $work

    # Bare remote that acts as `origin`.
    command git init --quiet --bare $remote

    command git init --quiet $work
    cd $work
    command git config user.email test@example.com
    command git config user.name "Test User"
    command git config commit.gpgsign false
    command git config init.defaultBranch main
    command git symbolic-ref HEAD refs/heads/main

    # Initial commit on main, pushed to origin so origin/HEAD resolves.
    echo "# test repo" >README.md
    command git add README.md
    command git commit --quiet -m "chore: initial commit"
    command git remote add origin $remote
    command git push --quiet -u origin main >/dev/null 2>&1
    command git remote set-head origin main >/dev/null 2>&1

    echo $work
end

function use_mocks --description "Prepend the mock_bin dir to PATH for the duration of a test"
    set -g __fag_saved_path $PATH
    set -gx PATH $__fag_mock_bin $PATH
end

function teardown --description "Remove temp dirs created during the test and restore PATH"
    cd /
    if set -q __fag_saved_path[1]
        set -gx PATH $__fag_saved_path
        set -e __fag_saved_path
    end
    for d in $__fag_tmpdirs
        test -d $d; and command rm -rf $d
    end
    set -g __fag_tmpdirs
end
