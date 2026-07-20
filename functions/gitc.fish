function gitc --wraps 'git checkout' --description "Shorthand for git checkout"
    # Intercept help only when it's the sole argument, so real checkout flags
    # (e.g. `gitc -b foo`) still pass straight through to git.
    if test (count $argv) -eq 1; and contains -- $argv[1] -h --help
        echo "gitc: shorthand for `git checkout`."
        echo "Run `git checkout -h` for checkout's own options."
        return 0
    end
    git checkout $argv
end
