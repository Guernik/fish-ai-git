source (path resolve (dirname (status filename)))/helpers/setup.fish

# --- Switches back to the default branch from a feature branch ---------------
set -l repo (setup_repo)
use_mocks
command git checkout --quiet -b feature
echo work >f.txt
command git add f.txt
command git commit --quiet -m work
# Merge the branch so `git branch -d` will accept deleting it.
command git checkout --quiet main
command git merge --quiet feature
command git checkout --quiet feature
gitm >/dev/null 2>&1
set -l current (command git rev-parse --abbrev-ref HEAD)
@test "gitm switches to the default branch" "$current" = main
@test "gitm deletes the merged branch it left" (command git rev-parse --verify --quiet refs/heads/feature >/dev/null; echo $status) -eq 1
teardown $repo

# --- Does not delete anything when already on the default branch -------------
set repo (setup_repo)
use_mocks
# We start on main; running gitm should stay on main and not try to self-delete.
gitm >/dev/null 2>&1
set current (command git rev-parse --abbrev-ref HEAD)
@test "gitm stays on the default branch when already there" "$current" = main
@test "gitm keeps the default branch intact" (command git rev-parse --verify --quiet refs/heads/main >/dev/null; echo $status) -eq 0
teardown $repo

# --- Refuses to drop unmerged work (git branch -d safety) --------------------
set repo (setup_repo)
use_mocks
command git checkout --quiet -b unmerged
echo work >u.txt
command git add u.txt
command git commit --quiet -m "unmerged work"
gitm >/dev/null 2>&1
@test "gitm still switches to default even with unmerged prev" (command git rev-parse --abbrev-ref HEAD) = main
@test "gitm does not delete an unmerged branch" (command git rev-parse --verify --quiet refs/heads/unmerged >/dev/null; echo $status) -eq 0
teardown $repo
