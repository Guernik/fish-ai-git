# fish-ai-git configuration.
#
# These set the default Claude model used by `ac` and `ghpr`. The functions
# also self-default, so they work even if copied out of this plugin — this file
# just gives you one documented place to change them.
#
# Override persistently from your shell instead of editing this file:
#     set -Ux AC_MODEL sonnet
#     set -Ux GHPR_MODEL sonnet

set -q AC_MODEL; or set -gx AC_MODEL haiku
set -q GHPR_MODEL; or set -gx GHPR_MODEL haiku
