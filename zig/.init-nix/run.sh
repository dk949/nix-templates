#!/usr/bin/env bash
# Scaffolds a Zig project using `zig init`. Output is merged into the
# scaffold root, preserving our flake.nix/.envrc/.gitignore. zig runs
# inside `nix develop` so the toolchain matches what nix build will use.
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

# Run zig from the flake's dev shell so the scaffolded files target the
# same zig version nix build will use (build.zig.zon's .minimum_zig_version
# is set from the running zig).
# shellcheck disable=SC2016  # $1 is a positional arg to the inner bash
nix --extra-experimental-features 'nix-command flakes' develop --command bash -c '
    cd "$1"
    zig init >/dev/null
' _ "$tmp_parent/$zig_name"

merge_scaffold_from "$tmp_parent/$zig_name" zig

sub_in_file flake.nix INIT_NIX_PROJECT_NAME
