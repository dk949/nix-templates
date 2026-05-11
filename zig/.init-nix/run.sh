#!/usr/bin/env bash
# Scaffolds a Zig project using `zig init`. Output is merged into the
# scaffold root, preserving our flake.nix/.envrc/.gitignore.
#
# `zig init` has no name flag - it derives the project name from cwd's
# basename (written into build.zig.zon's .name field). To get the right
# name without renaming files afterwards, we mkdir a tmp subdir named
# after the project, run `zig init` inside it, then merge.
#
# Env vars:
#   INIT_NIX_PROJECT_NAME   project name (prompted; default = target basename)
set -euo pipefail
#@include common/lib.sh

# Zig identifiers (and the .name field) are [a-zA-Z_][a-zA-Z0-9_]*.
# Lowercase + map '-' to '_' to keep names valid by default.
_zig_id() {
    printf '%s' "$1" | tr '[:upper:]-' '[:lower:]_'
}

ask_var INIT_NIX_PROJECT_NAME "Project name" "$(default_project_name)"

zig_name="$(_zig_id "$INIT_NIX_PROJECT_NAME")"

tmp_parent="$(mktemp -d -p . zig-init.XXXXXX)"
trap 'rm -rf "$tmp_parent"' EXIT
mkdir -p "$tmp_parent/$zig_name"

(
    cd "$tmp_parent/$zig_name"
    zig init >/dev/null
)

merge_scaffold_from "$tmp_parent/$zig_name" zig
