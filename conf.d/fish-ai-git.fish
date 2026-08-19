# fish-ai-git — Fisher event handlers.
#
# These set the default Claude model used by `ac` and `ghpr` as *universal*
# variables, once, when the plugin is installed or updated — rather than
# re-exporting them on every shell start. The functions also self-default, so
# they still work if copied out of this plugin.
#
# Override any time (this is preserved across updates and uninstalls):
#     set -Ux AC_MODEL sonnet
#     set -Ux GHPR_MODEL sonnet

set -g __fish_ai_git_default_model haiku

# Plugin version, shown by `--version` and in the progress line of `ac`/`ghpr`.
#
# The root VERSION file is the source of truth, but Fisher only installs
# functions/ and conf.d/ — a root file never reaches an installed plugin — so
# `just release X.Y.Z` writes the number into BOTH places. Keep them in sync via
# that recipe rather than editing this line by hand (`just version-check`
# verifies they match, and CI runs it).
set -g __fish_ai_git_version 1.2.0

function _fish_ai_git_install --on-event fish-ai-git_install
    # Seed defaults only if the user hasn't already set them.
    set -q AC_MODEL; or set -Ux AC_MODEL $__fish_ai_git_default_model
    set -q GHPR_MODEL; or set -Ux GHPR_MODEL $__fish_ai_git_default_model
end

function _fish_ai_git_update --on-event fish-ai-git_update
    # Backfill defaults for anyone who installed before they existed, without
    # touching a value the user chose.
    set -q AC_MODEL; or set -Ux AC_MODEL $__fish_ai_git_default_model
    set -q GHPR_MODEL; or set -Ux GHPR_MODEL $__fish_ai_git_default_model
end

function _fish_ai_git_uninstall --on-event fish-ai-git_uninstall
    # Only erase the vars if they still hold our default — leave a user's own
    # override in place.
    if set -q AC_MODEL; and test "$AC_MODEL" = "$__fish_ai_git_default_model"
        set -e AC_MODEL
    end
    if set -q GHPR_MODEL; and test "$GHPR_MODEL" = "$__fish_ai_git_default_model"
        set -e GHPR_MODEL
    end
    set -e __fish_ai_git_default_model
    functions -e _fish_ai_git_install _fish_ai_git_update _fish_ai_git_uninstall
end
