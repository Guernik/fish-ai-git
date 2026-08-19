# fish-ai-git — task runner.
# Run `just` with no arguments to list recipes.

default:
    @just --list

# Install the plugin into your fish config via Fisher (from this local clone).
install:
    fish -c "fisher install {{justfile_directory()}}"

# Symlink functions + conf.d into ~/.config/fish for live development.
install-dev:
    #!/usr/bin/env fish
    set -l src {{justfile_directory()}}
    set -l dest ~/.config/fish
    mkdir -p $dest/functions $dest/conf.d
    for f in $src/functions/*.fish
        ln -sfv $f $dest/functions/(basename $f)
    end
    for f in $src/conf.d/*.fish
        ln -sfv $f $dest/conf.d/(basename $f)
    end
    echo "Linked. Open a new shell or run: exec fish"

# Remove the dev symlinks created by install-dev (leaves real files alone).
uninstall-dev:
    #!/usr/bin/env fish
    set -l src {{justfile_directory()}}
    set -l dest ~/.config/fish
    for f in $src/functions/*.fish $src/conf.d/*.fish
        set -l link $dest/(string replace $src/ '' $f)
        if test -L $link; and test (path resolve $link) = (path resolve $f)
            rm -v $link
        end
    end

# Print the current plugin version.
version:
    @cat {{justfile_directory()}}/VERSION

# Verify VERSION and conf.d agree (they must — Fisher never ships VERSION).
version-check:
    #!/usr/bin/env fish
    set -l root {{justfile_directory()}}
    set -l file_version (string trim <$root/VERSION)
    set -l conf_version (string match -rg '^set -g __fish_ai_git_version (.+)$' <$root/conf.d/fish-ai-git.fish | string trim)
    if test -z "$file_version"
        echo "VERSION is empty" >&2
        exit 1
    end
    if test "$file_version" != "$conf_version"
        echo "version mismatch: VERSION=$file_version but conf.d has '$conf_version'" >&2
        echo "Run `just bump $file_version` to sync them." >&2
        exit 1
    end
    echo "version ok: $file_version"

# Bump the version in VERSION + conf.d, WITHOUT committing or tagging.
# Run this on your feature branch and include the change in that PR, so a
# release needs no separate commit. Usage: just bump 1.2.0
bump version:
    #!/usr/bin/env fish
    set -l root {{justfile_directory()}}
    set -l new {{version}}

    # Refuse anything that isn't plain semver — the tag and Fisher pin depend
    # on this shape (v1.2.3), and a typo here is painful to undo after tagging.
    if not string match -qr '^[0-9]+\.[0-9]+\.[0-9]+$' -- $new
        echo "version must be X.Y.Z (got '$new')" >&2
        exit 1
    end

    # Never bump onto a version that has already shipped. Check local tags and,
    # when the remote is reachable, the remote's tags too — a tag someone else
    # already pushed would not exist locally.
    if command git -C $root rev-parse -q --verify "refs/tags/v$new" >/dev/null
        echo "tag v$new already exists locally" >&2
        exit 1
    end
    set -l remote_tag (command git -C $root ls-remote --tags origin "refs/tags/v$new" 2>/dev/null | string collect)
    if test -n "$remote_tag"
        echo "tag v$new already exists on origin" >&2
        exit 1
    end

    # Write both places: VERSION is the source of truth, conf.d is what Fisher
    # actually installs. Done in fish rather than `sed -i` so the recipe works
    # the same on macOS (BSD sed) and Linux (GNU sed).
    echo $new >$root/VERSION
    set -l conf $root/conf.d/fish-ai-git.fish
    set -l patched (string replace -r '^set -g __fish_ai_git_version .*' "set -g __fish_ai_git_version $new" <$conf | string collect)
    printf '%s\n' $patched >$conf

    just version-check
    echo
    echo "Bumped to v$new (not committed)."
    echo "Stage it with the rest of your PR:"
    echo "    git add VERSION conf.d/fish-ai-git.fish"

# Create and push the signed tag for the version in VERSION.
# Run this on main AFTER the PR carrying the bump has been merged.
push-version:
    #!/usr/bin/env fish
    set -l root {{justfile_directory()}}
    just version-check
    set -l new (string trim <$root/VERSION)

    # The tag must point at merged, pushed work — never at local-only commits.
    set -l branch (command git -C $root rev-parse --abbrev-ref HEAD)
    if test "$branch" != main
        echo "on branch '$branch' — run this from main after the PR is merged" >&2
        exit 1
    end
    set -l dirty (command git -C $root status --porcelain | string collect)
    if test -n "$dirty"
        echo "working tree is dirty — commit or stash first" >&2
        exit 1
    end
    if command git -C $root rev-parse -q --verify "refs/tags/v$new" >/dev/null
        echo "tag v$new already exists" >&2
        exit 1
    end

    command git -C $root fetch --quiet origin main
    set -l unpushed (command git -C $root log --oneline origin/main..HEAD | string collect)
    if test -n "$unpushed"
        echo "local main is ahead of origin/main — push it first:" >&2
        printf '%s\n' $unpushed >&2
        exit 1
    end

    just lint
    just test

    # Signed tag: the release workflow refuses to publish an unsigned one.
    command git -C $root tag -s "v$new" -m "v$new"
    command git -C $root push origin "v$new"
    echo
    echo "Pushed v$new — the release workflow will publish it."

# Lint: syntax-check and formatting-check every fish file.
lint:
    #!/usr/bin/env fish
    set -l failed 0
    for f in functions/*.fish conf.d/*.fish scripts/*.fish tests/*.fish tests/helpers/*.fish
        if not fish -n $f
            echo "syntax error: $f"
            set failed 1
        end
        if not fish_indent --check $f >/dev/null 2>&1
            echo "not formatted (run `just fmt`): $f"
            set failed 1
        end
    end
    if test $failed -ne 0
        exit 1
    end
    echo "lint ok"

# Auto-format every fish file in place.
fmt:
    fish_indent -w functions/*.fish conf.d/*.fish scripts/*.fish tests/*.fish tests/helpers/*.fish

# Run the fishtape test suite (needs: fisher install jorgebucaran/fishtape).
test:
    #!/usr/bin/env fish
    if not functions -q fishtape
        echo "fishtape is not installed. Install it with:" >&2
        echo "    fisher install jorgebucaran/fishtape" >&2
        echo "See https://github.com/jorgebucaran/fishtape" >&2
        exit 1
    end
    # Run in a fresh fish so fishtape's per-run state starts clean; a plain
    # `fishtape tests/*.test.fish` from inside a just recipe mis-counts the
    # TAP summary, so invoke it via `fish -c` with the expanded glob.
    fish -c 'fishtape tests/*.test.fish'

# Security audit: scan the shipped files for high-signal dangerous patterns.
# Defends against contributor mistakes, NOT a rogue maintainer (see SECURITY.md).
audit:
    fish {{justfile_directory()}}/scripts/audit.fish

# Install the pre-commit hooks (lint on commit, tests on push; needs pre-commit).
install-hooks:
    #!/usr/bin/env fish
    if not command -q pre-commit
        echo "pre-commit is not installed. See https://pre-commit.com/#install" >&2
        echo "    pip install pre-commit   # or: brew install pre-commit" >&2
        exit 1
    end
    pre-commit install
    pre-commit install --hook-type pre-push

# Remove local dev/test artifacts (nothing here is tracked by git).
clean:
    #!/usr/bin/env fish
    rm -rf {{justfile_directory()}}/.test-deps
    find {{justfile_directory()}} -name .DS_Store -type f -delete
    echo "cleaned"
