# Shared model-output sanitizer for `ac` and `ghpr`.
#
# Models occasionally ignore the "raw output only" instruction and answer with
# a preamble ("Now I'll create the commit message:", "Here's the PR:"), a '---'
# rule, and/or the real content wrapped in a Markdown code fence. This strips
# that wrapper so callers parse only what the model was asked to produce.
#
# Plain text in, plain text out — no JSON, no external tools:
#   - When a fence is present, its contents ARE the output; everything outside
#     it (preamble before, stray closing fence after) is dropped.
#   - Otherwise only *leading* blank lines, horizontal rules, and a preamble
#     sentence (a line ending in ':') are skipped. The body is never altered,
#     so inline backticks, apostrophes and quotes survive byte-for-byte.
#
# A Conventional Commit header ("feat(ac): add thing") contains a colon but
# does not END with one, so it is never mistaken for a preamble line.
function _fish_ai_git_clean_output --argument-names raw
    set -l lines (printf '%s\n' $raw | string split \n)

    # --- Fenced: return the first fenced block, ignoring anything around it.
    set -l fenced
    set -l in_fence 0
    for line in $lines
        if string match -qr '^\s*(`{3,}|~{3,})' -- "$line"
            if test $in_fence -eq 0
                set in_fence 1
                continue
            end
            break
        end
        test $in_fence -eq 1; and set -a fenced $line
    end

    if test $in_fence -eq 1
        string join -- \n $fenced | string trim | string collect
        return 0
    end

    # --- Unfenced: skip leading noise only, then pass everything through.
    set -l cleaned
    set -l started 0
    for line in $lines
        if test $started -eq 0
            set -l t (string trim -- "$line")
            if test -z "$t"
                continue
            else if string match -qr '^(-{3,}|\*{3,}|_{3,})$' -- "$t"
                continue
            else if string match -qr ':\s*$' -- "$t"
                continue
            end
            set started 1
        end
        set -a cleaned $line
    end

    string join -- \n $cleaned | string trim | string collect
end
