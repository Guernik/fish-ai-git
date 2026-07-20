function ac --description "Stage all changes and commit with an AI-generated Conventional Commit message"
    argparse h/help -- $argv
    or return 1
    if set -q _flag_help
        echo "usage: ac [-h|--help]"
        echo
        echo "Stage all changes (git add -A) and commit with an AI-generated"
        echo "Conventional Commit message. Shows the message and prompts before"
        echo "committing: [Y] commit, [e] edit in \$EDITOR, [n] abort (changes"
        echo "stay staged)."
        echo
        echo "The model defaults to \$AC_MODEL (haiku). Noisy/generated files"
        echo "(lockfiles, minified assets, dist/, build/, snapshots) are hidden"
        echo "from the diff sent to the model, but every staged file is committed."
        return 0
    end

    if not command -q claude
        echo "claude CLI not found. Install it from https://claude.com/claude-code."
        return 1
    end

    if not git rev-parse --is-inside-work-tree >/dev/null 2>&1
        echo "Not a git repository."
        return 1
    end

    # Model used to generate the message. Override with `set -Ux AC_MODEL sonnet`.
    set -q AC_MODEL; or set -l AC_MODEL haiku

    git add -A

    # Checks ALL staged changes, so we still bail correctly even when the
    # noisy files excluded below are the only thing that changed.
    if git diff --cached --quiet
        echo "Nothing to commit."
        return 1
    end

    # --- Large-diff fix 1: hide noisy/generated files from the diff we send to
    # the LLM. These pathspecs ONLY filter what the model sees — every staged
    # file is still committed. Add your own (e.g. ':!*.svg', ':!data/*') as needed.
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

    # --- Large-diff fix 2: cap the diff size so a huge change can't blow up the
    # prompt. string collect keeps the truncated output as one string (so the
    # emptiness test and the pipe below behave correctly).
    set -l max_bytes 100000
    set -l diff (git diff --cached -- . $exclude | head -c $max_bytes | string collect)

    # Fallback: if the excludes stripped everything (e.g. only a lockfile
    # changed), send the file-level summary so the model still has context.
    if test -z "$diff"
        set diff (git diff --cached --stat | head -c $max_bytes | string collect)
    end

    echo "Generating commit message…"

    set -l msg (printf '%s\n' $diff | claude -p --model $AC_MODEL "Write a single git commit message for the following staged diff, strictly following the Conventional Commits 1.0.0 spec AND the project's required structure.

Required structure (in this exact order):
1. Header line: <type>[optional scope]: <description>
2. Blank line
3. Main description paragraph: 1–3 sentences explaining what changed and why, wrapped at ~72 chars.
4. Blank line
5. A 'Changes:' section listing the concrete changes as bullets starting with '- ', wrapped at ~72 chars (continuation lines may be unindented).

Example of the exact required shape:

ci: migrate secrets management from ansible-vault to infisical

Replace ansible-vault encrypted files with Infisical for centralized secrets
management. Secrets are now injected as environment variables via \`infisical run\`
wrapper in the justfile, eliminating the need for vault passwords in CI and
simplifying local development.

Changes:
- Remove vault file exclusions from linting configs (ansible-lint, pre-commit,
yamlfmt, yamllint)
- Add \`.infisical.json\` project configuration
- Replace all vault-encrypted files with env var lookups in vars files
- Update justfile to wrap playbook invocations with \`infisical run\`
- Add \`infisical-setup\` and \`infisical-secrets\` recipes for setup and debugging
- Remove orphaned zsh setup tasks (atuin, path, pipx, tokens)
- Fix setup-playbook.yml to safely default ansible_user_name

Rules:
- type is one of: feat, fix, docs, style, refactor, perf, test, build, ci, chore, revert.
- Use a scope in parentheses when it clarifies the affected area.
- Header description: imperative mood, lower case, no trailing period, max 72 chars.
- The main description paragraph and the 'Changes:' section are REQUIRED — always include both, even for small changes.
- Use '!' after the type/scope and/or a 'BREAKING CHANGE:' footer for breaking changes.
- Use real blank lines between sections (actual newline characters, not the two characters backslash-n).
- Output ONLY the raw commit message. No backticks around the whole message, no quotes, no preamble." | string trim | string collect)

    if test -z "$msg"
        echo "Failed to generate a commit message."
        return 1
    end

    echo
    echo "$msg"
    echo
    if not read -l -P "Commit? [Y/n/e(dit)] " answer
        echo "Aborted. Changes remain staged."
        return 1
    end

    switch $answer
        case '' Y y
            git commit -m "$msg"
        case E e
            git commit -e -m "$msg"
        case '*'
            echo "Aborted. Changes remain staged."
    end
end
