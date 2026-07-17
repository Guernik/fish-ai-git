# fish-ai-git — task runner.
# Run `just` with no arguments to list recipes.

# Where test dependencies (fisher + fishtape) are installed, isolated from your
# real fish config so tests never touch ~/.config/fish.
test_deps := justfile_directory() / ".test-deps"

default:
    @just --list

# Install the plugin into your fish config via Fisher (from this local clone).
install:
    fish -c "fisher install {{justfile_directory()}}"

# Symlink functions + conf.d into ~/.config/fish for live development, so a
# `git pull` in this repo is reflected immediately without reinstalling.
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

# Remove the dev symlinks created by install-dev (only removes links pointing
# back into this repo; leaves real files alone).
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

# Lint: syntax-check and formatting-check every fish file.
lint:
    #!/usr/bin/env fish
    set -l failed 0
    for f in functions/*.fish conf.d/*.fish tests/*.fish tests/helpers/*.fish
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
    fish_indent -w functions/*.fish conf.d/*.fish tests/*.fish tests/helpers/*.fish

# Install fishtape into an isolated location (if missing), then run the suite.
test: _ensure-fishtape
    #!/usr/bin/env fish
    set -gx XDG_DATA_HOME {{test_deps}}/data
    set -gx XDG_CONFIG_HOME {{test_deps}}/config
    # Run in a fresh fish so fishtape's per-run state starts clean; a plain
    # `fishtape tests/*.test.fish` from inside a just recipe mis-counts the
    # TAP summary, so invoke it via `fish -c` with the expanded glob.
    fish -c 'fishtape tests/*.test.fish'

# Install fisher + fishtape into the isolated test-deps dir if not already there.
_ensure-fishtape:
    #!/usr/bin/env fish
    set -gx XDG_DATA_HOME {{test_deps}}/data
    set -gx XDG_CONFIG_HOME {{test_deps}}/config
    mkdir -p $XDG_CONFIG_HOME/fish
    if functions -q fishtape
        exit 0
    end
    echo "Installing fishtape into {{test_deps}} …"
    curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source
    fisher install jorgebucaran/fishtape

# Remove the isolated test dependencies.
clean:
    rm -rf {{test_deps}}
