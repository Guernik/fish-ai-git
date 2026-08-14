# Shared version accessor for the fish-ai-git functions.
#
# The version is set by conf.d/fish-ai-git.fish, which Fisher installs and fish
# sources on every shell start. If a function is copied out of the plugin
# without that file, fall back to reading the repo's VERSION file next to it,
# and finally to "unknown" — a missing version must never break the command.
function _fish_ai_git_version --description "Echo the fish-ai-git plugin version"
    if set -q __fish_ai_git_version; and test -n "$__fish_ai_git_version"
        echo $__fish_ai_git_version
        return 0
    end

    # Dev fallback: functions/ sits next to VERSION in a working clone.
    set -l root (path resolve (dirname (status filename))/..)
    if test -r $root/VERSION
        set -l v (string trim <$root/VERSION)
        if test -n "$v"
            echo $v
            return 0
        end
    end

    echo unknown
end
