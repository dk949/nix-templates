# shellcheck shell=bash
# init-nix: scaffold a project from a nix-templates template.
# Works in bash and zsh. Source this file from your shell rc.

# This is a generated file from https://github.com/dk949/nix-templates/releases/download/latest/init-nix.sh
init-nix() {
    # Rolling release URLs. Stable across releases.
    local init_nix_template_url="https://github.com/dk949/nix-templates/releases/download/latest/templates.tar.gz"
    local init_nix_initsh_url="https://github.com/dk949/nix-templates/releases/download/latest/init-nix.sh"

    # Commit SHA baked in at release time (CI rewrites the placeholder).
    # An unbaked source-tree copy keeps the literal placeholder; the version
    # check below treats that as a dev build and skips it.
    local init_nix_sha="__INIT_NIX_SHA__"

    # Default cache dir. Honors INIT_NIX_TEMPLATES_DIR if pre-set,
    # else XDG_CACHE_HOME/nix-templates, else ~/.cache/nix-templates.
    local INIT_NIX_TEMPLATES_DIR="${INIT_NIX_TEMPLATES_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/nix-templates}"

    # -h, --help: show usage and exit
    if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
        cat <<'EOF'
init-nix: scaffold a project from a template

Templates auto-fetch into $INIT_NIX_TEMPLATES_DIR on first use.
Default: ${XDG_CACHE_HOME:-~/.cache}/nix-templates

Usage:
  init-nix                      list available templates
  init-nix -h, --help           show this help
  init-nix -c, --clear-cache    remove the cached templates dir
  init-nix <template>           scaffold into current directory
  init-nix <template> <dir>     scaffold into <dir> (must be empty or missing)

Templates may ship a .init-nix/run.sh setup hook. It runs after copy
and is removed on success. Setup uses these env vars (pre-set to skip prompts):
  INIT_NIX_PROJECT_NAME, INIT_NIX_AUTHOR, INIT_NIX_DESC, INIT_NIX_LICENSE
plus lang-scoped INIT_NIX_<LANG>_* (e.g. INIT_NIX_CPP_STANDARD).
EOF
        return 0
    fi

    # --clear-cache: wipe the cache and exit
    if [[ "$1" == "--clear-cache" ]] || [[ "$1" == "-c" ]]; then
        if [[ -d "$INIT_NIX_TEMPLATES_DIR" ]]; then
            rm -rf "$INIT_NIX_TEMPLATES_DIR"
            echo "init-nix: cleared $INIT_NIX_TEMPLATES_DIR"
        else
            echo "init-nix: cache already empty ($INIT_NIX_TEMPLATES_DIR)"
        fi
        return 0
    fi

    # Auto-fetch if the cache is missing or empty
    local fetched=0
    if [[ ! -d "$INIT_NIX_TEMPLATES_DIR" ]] || [[ -z "$(\ls -A -- "$INIT_NIX_TEMPLATES_DIR" 2>/dev/null)" ]]; then
        echo "init-nix: fetching templates into $INIT_NIX_TEMPLATES_DIR"
        mkdir -p "$INIT_NIX_TEMPLATES_DIR"
        if ! curl -fsSL "$init_nix_template_url" | tar -xz -C "$INIT_NIX_TEMPLATES_DIR"; then
            echo "init-nix: fetch failed from $init_nix_template_url" >&2
            return 1
        fi
        fetched=1
    fi

    # Version check: only after a fresh fetch, and only if init-nix.sh has
    # a real baked SHA (the unbaked placeholder doesn't match the regex,
    # so dev source-tree copies silently skip the check).
    if [[ "$fetched" == 1 ]] && [[ "$init_nix_sha" =~ ^[0-9a-f]{40}$ ]]; then
        local version_file="$INIT_NIX_TEMPLATES_DIR/VERSION"
        if [[ ! -f "$version_file" ]]; then
            echo "init-nix: tarball missing VERSION file (malformed release?)" >&2
            return 1
        fi
        local tarball_sha
        tarball_sha="$(\head -n1 -- "$version_file" | \tr -d '[:space:]')"
        if [[ "$tarball_sha" != "$init_nix_sha" ]]; then
            echo "init-nix: version mismatch" >&2
            echo "  this init-nix.sh was built at: $init_nix_sha" >&2
            echo "  fetched templates built at:    $tarball_sha" >&2
            echo "  fetch the latest init-nix.sh and re-source it, then try again:" >&2
            echo "    curl -fsSL $init_nix_initsh_url -o <path/to/init-nix.sh>" >&2
            return 1
        fi
    fi

    local template="$1"
    local target="${2:-.}"

    if [[ -z "$template" ]]; then
        echo "Available templates in $INIT_NIX_TEMPLATES_DIR:"
        find "$INIT_NIX_TEMPLATES_DIR" -mindepth 1 -maxdepth 1 -type d \
            -printf '  %f\n' | sort
        echo
        echo "Usage: init-nix <template> [target-dir]"
        return 1
    fi

    local src="$INIT_NIX_TEMPLATES_DIR/$template"
    if [[ ! -d "$src" ]]; then
        echo "init-nix: template '$template' not found in $INIT_NIX_TEMPLATES_DIR" >&2
        return 1
    fi

    # Refuse to scaffold into a non-empty directory
    if [[ -d "$target" ]] && [[ -n "$(\ls -A -- "$target" 2>/dev/null)" ]]; then
        echo "init-nix: $target is not empty, refusing to scaffold" >&2
        return 1
    fi

    # Resolve absolute target path (target may not exist yet)
    local parent_dir parent_abs target_abs target_base
    target_base="$(basename -- "$target")"
    parent_dir="$(dirname -- "$target")"
    mkdir -p "$parent_dir"
    parent_abs="$(cd -- "$parent_dir" && pwd)"
    target_abs="$parent_abs/$target_base"

    # Scaffold into a tmp dir; only move into target on success
    local tmp
    tmp="$(mktemp -d -t init-nix.XXXXXXXX)" || {
        echo "init-nix: mktemp failed" >&2
        return 1
    }

    if ! cp -a "$src/." "$tmp/"; then
        echo "init-nix: copy from $src failed" >&2
        rm -rf "$tmp"
        return 1
    fi

    # Run setup hook if present. cwd = tmp dir (eventual project root).
    if [[ -f "$tmp/.init-nix/run.sh" ]]; then
        # Hold .envrc out of the tmp dir during the hook. direnv hooks in
        # the user's shell can fire on the tmp path and complain that the
        # .envrc is not authorized. Restored before mv-to-target whether
        # the hook succeeds or fails.
        local envrc_held=0
        if [[ -f "$tmp/.envrc" ]]; then
            mv "$tmp/.envrc" "$tmp/.envrc.holdback"
            envrc_held=1
        fi

        local rc=0
        (
            cd "$tmp" || exit 1
            INIT_NIX_TEMPLATE="$template" \
            INIT_NIX_TARGET="$target_abs" \
                bash .init-nix/run.sh
        ) || rc=$?

        if [[ "$envrc_held" == 1 ]]; then
            mv "$tmp/.envrc.holdback" "$tmp/.envrc"
        fi

        if [[ "$rc" != 0 ]]; then
            echo "init-nix: setup script failed (exit $rc)" >&2
            echo "init-nix: incomplete scaffold preserved at: $tmp" >&2
            echo "init-nix: target was not modified: $target_abs" >&2
            return 1
        fi
    fi

    # Strip setup machinery before moving into place
    rm -rf "$tmp/.init-nix"

    # Move tmp contents into target (handles both new and empty-existing target)
    mkdir -p "$target"
    if ! find "$tmp" -mindepth 1 -maxdepth 1 -exec mv -- {} "$target/" \;; then
        echo "init-nix: move from $tmp to $target_abs failed" >&2
        echo "init-nix: partial scaffold preserved at: $tmp" >&2
        return 1
    fi
    rmdir "$tmp" 2>/dev/null

    # Initialize git if not already a repo (so flake.lock can be tracked cleanly)
    if [[ ! -d "$target/.git" ]] && command -v git >/dev/null 2>&1; then
        git -C "$target" init -q
        git -C "$target" add -A
    fi

    # Allow direnv if available
    if command -v direnv >/dev/null 2>&1 && [[ -f "$target/.envrc" ]]; then
        direnv allow "$target/.envrc"
    fi

    echo "Scaffolded '$template' into $target_abs"
    echo "Next: cd $target && nix develop   (or just cd in if direnv is active)"
}
