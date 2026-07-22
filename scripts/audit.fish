#!/usr/bin/env fish
#
# audit.fish — high-signal supply-chain scan of the SHIPPED files
# (functions/*.fish and conf.d/*.fish — the code that actually runs on a
# user's machine after `fisher install`/`fisher update`).
#
# WHAT THIS DEFENDS AGAINST (and what it does NOT):
#
#   ✓ Outside contributors and honest mistakes that introduce an obviously
#     dangerous shell pattern (piping the network into a shell, evaling
#     untrusted input, sourcing a downloaded file, decode-and-run obfuscation).
#
#   ✗ A malicious or compromised MAINTAINER. Anyone who can merge can also edit
#     or delete this very script in the same change. This scan is NOT — and
#     cannot be — a defense against a rogue owner. That protection comes from
#     signed, pinned release tags and branch protection (see SECURITY.md), not
#     from a script the owner controls.
#
# The pattern set is deliberately TIGHT (near-unambiguous dangers only) to keep
# false positives near zero. Matching is done with fish's built-in `string
# match -r` (PCRE2) so there is no dependency on `grep -P`, which is absent on
# the BSD grep shipped with macOS. Output is greppable "file:line: <reason>"
# plus a final summary line the CI captures for the PR comment. Exit status is
# 0 when clean, 1 when any finding is present.

set -l root (path resolve (dirname (status filename))/..)
set -l targets $root/functions/*.fish $root/conf.d/*.fish

# Each rule pairs a PCRE pattern with a human reason. Kept intentionally narrow:
#   1. Piping remote content straight into a shell:  curl … | sh / wget … | bash|fish
#   2. eval of a variable/interpolated value (not eval of a constant literal)
#   3. source / `.` of a URL, a temp path, or a command-substitution result
#   4. base64 decode piped into a shell (decode-and-run obfuscation)
set -l patterns \
    '(?:curl|wget|fetch)\b[^|]*\|\s*(?:sudo\s+)?(?:sh|bash|fish|zsh|dash|ksh)\b' \
    'eval\b[^\r\n]*\$' \
    '(?:^|\s)(?:source|\.)\s+[^\r\n]*(?:https?://|/tmp/|/dev/fd/|\$\()' \
    'base64\s+(?:--decode|-[A-Za-z]*d[A-Za-z]*)\b[^\r\n]*\|\s*(?:sh|bash|fish|zsh)\b'

set -l reasons \
    'pipes network output into a shell (curl|wget … | sh)' \
    'eval on a variable/interpolated value' \
    'sources a remote or downloaded path' \
    'base64 decode piped into a shell (obfuscation)'

set -l findings 0

for file in $targets
    test -f $file; or continue
    set -l relpath (string replace -- $root/ '' $file)
    set -l lineno 0
    # Read line by line so we can report exact line numbers without grep -P.
    while read -l line
        set lineno (math $lineno + 1)
        for i in (seq (count $patterns))
            if string match -qr -- $patterns[$i] $line
                echo "$relpath:$lineno: $reasons[$i]"
                set findings (math $findings + 1)
            end
        end
    end <$file
end

echo
if test $findings -eq 0
    echo "AUDIT: clean — no high-signal dangerous patterns found in shipped files."
    exit 0
else
    echo "AUDIT: $findings finding(s) — review the lines above."
    exit 1
end
