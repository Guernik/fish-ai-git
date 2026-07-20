function ghpr --description "Push the current branch and open a GitHub PR with an AI-generated title and body"
    argparse h/help -- $argv
    or return 1
    if set -q _flag_help
        echo "usage: ghpr [-h|--help]"
        echo
        echo "Push the current branch and open a GitHub PR with an AI-generated"
        echo "title and body. The base branch is detected automatically from the"
        echo "remote's default branch. Shows the title/body and prompts before"
        echo "pushing: [Y] push and create the PR, [w] push and open the browser"
        echo "pre-filled, [n] abort."
        echo
        echo "The model defaults to \$GHPR_MODEL (haiku). Noisy/generated files"
        echo "are hidden from the diff sent to the model; the PR still contains"
        echo "every commit."
        return 0
    end

    if not command -q gh
        echo "gh CLI not found. Install it from https://cli.github.com."
        return 1
    end

    if not command -q claude
        echo "claude CLI not found. Install it from https://claude.com/claude-code."
        return 1
    end

    if not git rev-parse --is-inside-work-tree >/dev/null 2>&1
        echo "Not a git repository."
        return 1
    end

    # Model used to generate the PR. Override with `set -Ux GHPR_MODEL sonnet`.
    set -q GHPR_MODEL; or set -l GHPR_MODEL haiku

    set -l branch (git rev-parse --abbrev-ref HEAD)
    if test "$branch" = HEAD
        echo "Detached HEAD — check out a branch first."
        return 1
    end

    # Determine the base branch: the repo's default branch on the remote.
    set -l base (git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | string replace -r '.*/' '')
    if test -z "$base"
        # Fall back to a common default if origin/HEAD isn't set.
        if git show-ref --verify --quiet refs/remotes/origin/main
            set base main
        else if git show-ref --verify --quiet refs/remotes/origin/master
            set base master
        else
            echo "Could not determine the base branch. Set origin/HEAD with 'git remote set-head origin --auto'."
            return 1
        end
    end

    if test "$branch" = "$base"
        echo "You're on the base branch ($base). Check out a feature branch first."
        return 1
    end

    # Range of commits unique to this branch, compared against the base.
    set -l range "origin/$base..$branch"

    if test -z (git log --oneline $range 2>/dev/null | string collect)
        echo "No commits on '$branch' beyond 'origin/$base'. Nothing to open a PR for."
        return 1
    end

    # --- Same large-diff handling as ac: hide noisy/generated files from the
    # diff we send to the LLM (the PR still contains every commit) and cap size.
    set -l exclude \
        ':!*.lock' \
        ':!*-lock.json' \
        ':!*-lock.yaml' \
        ':!pnpm-lock.yaml' \
        ':!Cargo.lock' \
        ':!poetry.lock' \
        ':!uv.lock' \
        ':!*.min.js' ':!*.min.css' ':!*.map' \
        ':!dist/*' ':!build/*' \
        ':!*.snap'

    set -l max_bytes 100000
    set -l commits (git log --pretty=format:'%s%n%b' $range | head -c $max_bytes | string collect)
    set -l diff (git diff $range -- . $exclude | head -c $max_bytes | string collect)

    if test -z "$diff"
        set diff (git diff $range --stat | head -c $max_bytes | string collect)
    end

    echo "Generating PR title and body…"

    set -l context "Branch: $branch
Base: $base

Commit messages on this branch:
$commits

Diff:
$diff"

    set -l pr (printf '%s\n' $context | claude -p --model $GHPR_MODEL "Write a GitHub pull request title and body for the branch described below.

Output format (exactly):
1. First line: the PR title — imperative mood, no trailing period, max 72 chars. Prefer a Conventional Commits style prefix (feat:, fix:, etc.) when it fits.
2. A blank line.
3. The PR body in GitHub-flavored Markdown, with these sections:
   ## Summary
   1–3 sentences on what changed and why.

   ## Changes
   - concrete bullets of the notable changes.

Rules:
- Base the content on the commit messages and diff, not speculation.
- Output ONLY the raw title and body. No code fences around the whole thing, no preamble, no quotes." | string collect)

    if test -z (string trim -- "$pr" | string collect)
        echo "Failed to generate PR content."
        return 1
    end

    # First line is the title; the rest (after the blank line) is the body.
    set -l title (printf '%s\n' $pr | head -n 1 | string trim)
    set -l body (printf '%s\n' $pr | tail -n +3 | string collect)

    echo
    echo "Title: $title"
    echo
    echo "$body"
    echo
    if not read -l -P "Push '$branch' and open PR against '$base'? [Y/n/w(eb)] " answer
        echo "Aborted."
        return 1
    end

    switch $answer
        case '' Y y
            git push -u origin $branch; or return 1
            gh pr create --base $base --head $branch --title "$title" --body "$body"
        case W w
            # Push, then open the browser pre-filled so you can tweak before submitting.
            git push -u origin $branch; or return 1
            gh pr create --base $base --head $branch --title "$title" --body "$body" --web
        case '*'
            echo "Aborted."
    end
end
