# nix-templates

[![Release templates](https://github.com/dk949/nix-templates/actions/workflows/release.yml/badge.svg)](https://github.com/dk949/nix-templates/actions/workflows/release.yml)

Nix flake templates per language. Each template is a minimal `devShell` ready to drop into a project. Templates may also ship a setup hook that scaffolds language-specific config (e.g. `Cargo.toml`, `CMakeLists.txt`) on first use.

## Templates

| Language | Tools in the dev shell |
|----------|------------------------|
| `cpp`    | gcc, cmake, ninja, gdb, clang-tools (clangd, clang-format, clang-tidy) |
| `go`     | go, gopls, delve, gotools |
| `node`   | nodejs, pnpm, typescript, typescript-language-server |
| `python` | python3, uv, ruff, pyright |
| `rust`   | rustc, cargo, clippy, rustfmt, rust-analyzer |
| `zig`    | zig, zls |

Each template ships with:

- `flake.nix`: the dev shell definition.
- `.envrc`: `use flake`, for direnv plus nix-direnv integration.
- `.gitignore`: nix outputs and editor noise.
- Optionally `.init-nix/run.sh`: setup hook (see below).

## Usage

The recommended path is the `init-nix` shell function (source `init-nix.sh` from your shell rc, then call it). It fetches the templates tarball on first use, scaffolds into a target dir, runs the setup hook if present, and `git init`s the result.

```sh
. /path/to/init-nix.sh    # in your bashrc/zshrc
init-nix                  # list templates
init-nix rust ./my-proj   # scaffold rust into ./my-proj
init-nix --help           # full usage
```

Or grab the tarball directly:

```sh
curl -L https://github.com/dk949/nix-templates/releases/download/latest/templates.tar.gz \
  | tar -xz                # all templates
curl -L https://github.com/dk949/nix-templates/releases/download/latest/templates.tar.gz \
  | tar -xz python         # just one
```

The download URL is stable across releases.

## Setup hooks (`.init-nix/run.sh`)

A template may include a `.init-nix/` directory containing a `run.sh` (and optionally helper data). `init-nix` runs it after copying the template into a tmp dir; on success the dir contents are moved into the target and `.init-nix/` is removed. On failure the tmp dir is preserved for inspection and the target is untouched.

### Env vars

Pre-set any of these to skip the corresponding prompt; unset values are prompted on a TTY. Shared:

- `INIT_NIX_PROJECT_NAME` (defaults to target dir basename)
- `INIT_NIX_AUTHOR` (defaults to `git config user.name <email>`)
- `INIT_NIX_DESC` (optional, may be empty)
- `INIT_NIX_LICENSE` (one of: MIT, Apache-2.0, BSD-3-Clause, GPL-3.0, none)

Lang-scoped vars use `INIT_NIX_<LANG>_*` (e.g. `INIT_NIX_CPP_STANDARD`, `INIT_NIX_RUST_EDITION`). Each template's `run.sh` documents the ones it consumes.

Auto-injected by `init-nix`:

- `INIT_NIX_TEMPLATE`: template name
- `INIT_NIX_TARGET`: absolute path of the eventual project root

### Placeholders in template files

Use `{{INIT_NIX_VAR}}` (the full env-var name) in any template file. Helpers below substitute them.

### Helper API

`run.sh` should inline the shared helpers via `#@include` directives (the build expands them so the dist tarball is self-contained):

```sh
#!/usr/bin/env bash
set -euo pipefail
#@include common/lib.sh
#@include common/prompts.sh

ask_shared_vars                              # prompts the shared vars above
ask_choice INIT_NIX_CPP_STANDARD "C++ std" 23 17 20 23 26
sub_in_files 'flake.nix CMakeLists.txt' \
    INIT_NIX_PROJECT_NAME INIT_NIX_CPP_STANDARD
rename_token __PROJECT_NAME__ "$INIT_NIX_PROJECT_NAME"
```

`common/lib.sh` provides:

- `ask_var VAR PROMPT [DEFAULT]`: env > prompt (TTY) > default. Omit DEFAULT for a required var; pass `""` to allow empty.
- `ask_choice VAR PROMPT DEFAULT C1 C2 ...`: constrained choice, validates env values.
- `sub_in_file FILE VAR ...`: replace `{{VAR}}` with `${!VAR}` in FILE.
- `sub_in_files GLOB VAR ...`: same, over a glob (cwd-relative).
- `rename_token FROM TO [ROOT]`: rename matching file/dir basenames depth-first.
- `default_project_name`, `default_author`: defaults used by the shared prompts.

`common/prompts.sh` provides `ask_shared_vars` which prompts the four shared vars in order.

### Authoring + testing

```sh
make scaffold-dev TEMPLATE=cpp TARGET=/tmp/foo
```

Builds dist for the named template (running the inliner), then scaffolds it via `init-nix.sh` pointed at `./dist` instead of the published tarball. Use this to iterate on a template's `run.sh`.

## How releases work

Pushing to `trunk` triggers `.github/workflows/release.yml`:

1. `make dist` assembles per-language template directories from `common/` plus the language source. `.init-nix/run.sh` files have their `#@include` directives expanded against `common/`.
2. The result is packaged as `templates.tar.gz`.
3. The rolling `latest` tag is rebuilt to point at the new asset.

## Adding a template

1. Create a directory at the repo root, e.g. `myhaskell/`.
2. Add `flake.nix` with a `devShells.default` output.
3. Optionally add a language-specific `.envrc` or `.gitignore`. Both are concatenated with the matching files in `common/` at build time.
4. Optionally add `.init-nix/run.sh` for post-scaffold setup (see above).
5. Push to `trunk`. CI does the rest.
