function gitc --wraps 'git checkout' --description "Shorthand for git checkout"
    # Intercept help only when it's the sole argument, so real checkout flags
    # (e.g. `gitc -b foo`) still pass straight through to git.
    if test (count $argv) -eq 1; and contains -- $argv[1] -h --help
        echo "gitc: shorthand for `git checkout`."
        echo "Run `git checkout -h` for checkout's own options."
        return 0
    end
    # Only the long form, and only alone: `-v` is git checkout's own verbose
    # flag, so intercepting it would shadow real checkout behaviour.
    if test (count $argv) -eq 1; and test "$argv[1]" = --version
        echo "gitc (fish-ai-git) v"(_fish_ai_git_version)
        return 0
    end
    git checkout $argv
end
