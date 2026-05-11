#!/usr/bin/env bash
# Scaffolds a CMake + vcpkg C++ project by cloning github.com/dk949/cpp-init
# and running its setup.sh inside the clone, then merging the result into
# the scaffold root (preserving our flake.nix/.envrc/.gitignore).
#
# Env vars:
#   INIT_NIX_PROJECT_NAME   project name (prompted; default = target basename)
#   INIT_NIX_DESC           description (prompted; may be empty)
#   INIT_NIX_CPP_NAMESPACE  C++ namespace (prompted; default = lowercased project, '-' -> '_')
#   INIT_NIX_CPP_URL        project URL (optional, no prompt; passed to setup.sh if set)
#   INIT_NIX_CPP_VCPKG      1 (default) keeps vcpkg setup; 0 passes --no-vcpkg
set -euo pipefail
#@include common/lib.sh

# cpp-init's setup.sh requires identifiers to match [a-z0-9_]*; both the
# project name and namespace get this transformation before being passed in.
_cpp_id() {
    printf '%s' "$1" | tr '[:upper:]-' '[:lower:]_'
}

ask_var INIT_NIX_PROJECT_NAME  "Project name"  "$(default_project_name)"
ask_var INIT_NIX_DESC          "Description"   ""
ask_var INIT_NIX_CPP_NAMESPACE "C++ namespace" "$(_cpp_id "$INIT_NIX_PROJECT_NAME")"

cpp_name="$(_cpp_id "$INIT_NIX_PROJECT_NAME")"
cpp_ns="$(_cpp_id "$INIT_NIX_CPP_NAMESPACE")"

# Build optional flag arrays for setup.sh
desc_arg=()
[[ -n "${INIT_NIX_DESC:-}"     ]] && desc_arg=(-d "$INIT_NIX_DESC")
url_arg=()
[[ -n "${INIT_NIX_CPP_URL:-}"  ]] && url_arg=(-u "$INIT_NIX_CPP_URL")
vcpkg_arg=()
[[ "${INIT_NIX_CPP_VCPKG:-1}" == 0 ]] && vcpkg_arg=(--no-vcpkg)

# Clone cpp-init (HEAD) into a sibling tmp dir, run its setup.sh inside,
# then merge contents back without clobbering our scaffold files.
clone_dir="$(mktemp -d -p . cpp-init.XXXXXX)"
trap 'rm -rf "$clone_dir"' EXIT

git clone --depth=1 https://github.com/dk949/cpp-init "$clone_dir" >/dev/null

(
    cd "$clone_dir"
    ./setup.sh -y \
        -n "$cpp_name" \
        -s "$cpp_ns" \
        "${desc_arg[@]}" \
        "${url_arg[@]}" \
        "${vcpkg_arg[@]}"
)

merge_scaffold_from "$clone_dir" cpp-init
