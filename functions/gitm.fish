function gitm --description "Switch to the default branch, pull, and delete the branch you left"
    if not git rev-parse --is-inside-work-tree >/dev/null 2>&1
        echo "Not a git repository."
        return 1
    end

    set -l prev (git rev-parse --abbrev-ref HEAD)

    # Determine the default branch: the repo's default branch on the remote,
    # falling back to a common name.
    set -l base (git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | string replace -r '.*/' '')
    if test -z "$base"
        if git show-ref --verify --quiet refs/heads/main
            set base main
        else if git show-ref --verify --quiet refs/heads/master
            set base master
        else
            echo "Could not determine the default branch. Set origin/HEAD with 'git remote set-head origin --auto'."
            return 1
        end
    end

    git checkout $base; and git pull origin $base

    # Clean up the branch we just left. `git branch -d` refuses to delete an
    # unmerged branch, so this can't drop unmerged work.
    if test "$prev" != "$base"
        git branch -d $prev
    end
end
