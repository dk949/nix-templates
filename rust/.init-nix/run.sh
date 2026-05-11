#!/usr/bin/env bash
# Scaffolds a Rust project using `cargo init`. Output is merged into the
# scaffold root, preserving our flake.nix/.envrc/.gitignore.
#
# Env vars:
#   INIT_NIX_PROJECT_NAME   project name (prompted; default = target basename)
#   INIT_NIX_RUST_KIND      bin|lib (prompted; default = bin)
#   INIT_NIX_RUST_EDITION   2024|2021|2018|2015 (prompted; default = 2024)
set -euo pipefail
#@include common/lib.sh

# cargo accepts -, _ and alnum in package names but rejects bare uppercase
# without a warning suppression; lowercase the project name to be safe.
_rust_id() {
    printf '%s' "$1" | tr '[:upper:]' '[:lower:]'
}

ask_var    INIT_NIX_PROJECT_NAME "Project name"  "$(default_project_name)"
ask_choice INIT_NIX_RUST_KIND    "Crate kind"    bin bin lib
ask_choice INIT_NIX_RUST_EDITION "Rust edition"  2024 2024 2021 2018 2015

cargo_name="$(_rust_id "$INIT_NIX_PROJECT_NAME")"

# Scaffold into a sibling tmp dir; cargo writes Cargo.toml, src/*, .gitignore
# (target/) there. Then no-clobber merge back so our scaffold files win.
tmp_dir="$(mktemp -d -p . cargo-init.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT

cargo init \
    --name "$cargo_name" \
    --vcs none \
    --edition "$INIT_NIX_RUST_EDITION" \
    "--$INIT_NIX_RUST_KIND" \
    "$tmp_dir" >/dev/null

merge_scaffold_from "$tmp_dir" cargo
