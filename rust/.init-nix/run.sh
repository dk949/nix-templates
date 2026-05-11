#!/usr/bin/env bash
# Scaffolds a Rust project using `cargo init`. Output is merged into the
# scaffold root, preserving our flake.nix/.envrc/.gitignore. cargo runs
# inside `nix develop` so the toolchain matches what nix build will use,
# and we pre-generate Cargo.lock so the flake's `cargoLock.lockFile` ref
# resolves on first `nix build` (no deps -> no network needed).
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

# Run cargo inside the flake's dev shell so it picks up the pinned cargo
# (instead of whatever the host has installed). `cargo generate-lockfile`
# also runs there so the produced lock matches the build's cargo version.
# shellcheck disable=SC2016  # $1..$4 are positional args to the inner bash
nix --extra-experimental-features 'nix-command flakes' develop --command bash -c '
    set -e
    cargo init \
        --name "$1" \
        --vcs none \
        --edition "$2" \
        "--$3" \
        "$4" >/dev/null
    cd "$4"
    cargo generate-lockfile --offline >/dev/null 2>&1 \
        || cargo generate-lockfile >/dev/null 2>&1
' _ "$cargo_name" "$INIT_NIX_RUST_EDITION" "$INIT_NIX_RUST_KIND" "$tmp_dir"

merge_scaffold_from "$tmp_dir" cargo

sub_in_file flake.nix INIT_NIX_PROJECT_NAME
