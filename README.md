# nix-templates

[![Release templates](https://github.com/dk949/nix-templates/actions/workflows/release.yml/badge.svg)](https://github.com/dk949/nix-templates/actions/workflows/release.yml)

Nix flake templates per language. Each template is a minimal `devShell` ready to
drop into a project. Templates may also ship a setup hook that scaffolds
language-specific config (e.g. `Cargo.toml`, `CMakeLists.txt`) on first use.

## Templates

| Language   | Tools in the dev shell                                                 | Setup hook                                                                        |
| ---------- | ---------------------------------------------------------------------- | --------------------------------------------------------------------------------- |
| `cpp`      | gcc, cmake, ninja, gdb, clang-tools (clangd, clang-format, clang-tidy) | scaffolds via [dk949/cpp-init](https://github.com/dk949/cpp-init) (CMake + vcpkg) |
| `go`       | go, gopls, delve, gotools                                              | runs `go mod init`, writes a hello-world `main.go`                                |
| `node`     | nodejs, pnpm, typescript, typescript-language-server                   | none yet                                                                          |
| `python`   | python3, uv, ruff, pyright                                             | none yet                                                                          |
| `rust`     | rustc, cargo, clippy, rustfmt, rust-analyzer                           | runs `cargo init` + `cargo generate-lockfile`                                     |
| `zig`      | zig, zls                                                               | runs `zig init`                                                                   |

Templates with a setup hook (`go`, `rust`, `zig`) also wire `packages.default`
in their `flake.nix`, so `nix build` produces the project artefact right after
scaffolding. The hook substitutes `INIT_NIX_PROJECT_NAME` into the flake's
`pname`. `cpp` ships `devShell` only - vcpkg fetches deps at build time, which
breaks pure nix builds; use the dev shell + cmake directly.

The `go`/`rust`/`zig` hooks invoke their scaffolding tool via `nix develop`, so
the version that writes `go.mod`/`Cargo.lock`/`build.zig.zon` is the one pinned
by the flake (not whatever the host happens to have). The user only needs `nix`
on the host; `go`/`cargo`/`zig` come from the dev shell.

### `cpp` env vars

- `INIT_NIX_PROJECT_NAME` (shared) - prompted; sanitized to `[a-z0-9_]` for
  cpp-init
- `INIT_NIX_DESC` (shared) - prompted; passed as `-d`
- `INIT_NIX_CPP_NAMESPACE` - prompted; default = sanitized project name
- `INIT_NIX_CPP_URL` - optional; if set, passed as `-u`
- `INIT_NIX_CPP_VCPKG` - default `1` (vcpkg enabled); set to `0` to pass
  `--no-vcpkg`

### `rust` env vars

- `INIT_NIX_PROJECT_NAME` (shared) - prompted; lowercased and passed as `--name`
- `INIT_NIX_RUST_KIND` - `bin` or `lib`; default `bin` (passed as
  `--bin`/`--lib`)
- `INIT_NIX_RUST_EDITION` - one of `2024`, `2021`, `2018`, `2015`; default
  `2024`

### `zig` env vars

- `INIT_NIX_PROJECT_NAME` (shared) - prompted; lowercased w/ `-` -> `_` for the
  cwd-derived project name (`zig init` has no name flag)

### `go` env vars

- `INIT_NIX_PROJECT_NAME` (shared) - prompted
- `INIT_NIX_GO_MODULE` - module path passed to `go mod init`; default = project
  name

Each template ships with:

- `flake.nix`: the dev shell definition.
- `.envrc`: `use flake`, for direnv plus nix-direnv integration.
- `.gitignore`: nix outputs and editor noise.
- Optionally `.init-nix/run.sh`: setup hook (see below).

## Getting started

Download `init-nix.sh` from the latest release and source it from your shell rc.
Templates auto-fetch on first call.

```sh
# one-time install
mkdir -p ~/.local/bin
curl -fsSL https://github.com/dk949/nix-templates/releases/download/latest/init-nix.sh \
    -o ~/.local/bin/init-nix.sh

# in ~/.bashrc or ~/.zshrc
. ~/.local/bin/init-nix.sh
```

The cache directory defaults to `${XDG_CACHE_HOME:-~/.cache}/nix-templates`.
Override by exporting `INIT_NIX_TEMPLATES_DIR=<path>` before sourcing (or in the
shell rc above).

Then in a new shell:

```sh
init-nix                  # list templates (auto-fetches on first run)
init-nix rust ./my-proj   # scaffold rust into ./my-proj
init-nix --help           # full usage
init-nix --clear-cache    # wipe cache; next call re-fetches
```

Both `init-nix.sh` and `templates.tar.gz` are pinned to the same commit. On
a fresh fetch, `init-nix` verifies that the baked-in SHA matches the tarball's
`VERSION` file; on mismatch it errors with a link to re-download `init-nix.sh`.
No auto-update; cached tarballs are not re-checked.

Or grab the tarball directly without the shell function:

```sh
curl -L https://github.com/dk949/nix-templates/releases/download/latest/templates.tar.gz \
  | tar -xz                # all templates
curl -L https://github.com/dk949/nix-templates/releases/download/latest/templates.tar.gz \
  | tar -xz python         # just one
```

The download URLs are stable across releases.

## Setup hooks (`.init-nix/run.sh`)

A template may include a `.init-nix/` directory containing a `run.sh` (and
optionally helper data). `init-nix` runs it after copying the template into
a tmp dir; on success the dir contents are moved into the target and
`.init-nix/` is removed. On failure the tmp dir is preserved for inspection and
the target is untouched.

### Env vars

Pre-set any of these to skip the corresponding prompt; unset values are prompted
on a TTY. Shared:

- `INIT_NIX_PROJECT_NAME` (defaults to target dir basename)
- `INIT_NIX_AUTHOR` (defaults to `git config user.name <email>`)
- `INIT_NIX_DESC` (optional, may be empty)
- `INIT_NIX_LICENSE` (one of: MIT, Apache-2.0, BSD-3-Clause, GPL-3.0, none)

Lang-scoped vars use `INIT_NIX_<LANG>_*` (e.g. `INIT_NIX_CPP_STANDARD`,
`INIT_NIX_RUST_EDITION`). Each template's `run.sh` documents the ones it
consumes.

Auto-injected by `init-nix`:

- `INIT_NIX_TEMPLATE`: template name
- `INIT_NIX_TARGET`: absolute path of the eventual project root

### Placeholders in template files

Use `{{INIT_NIX_VAR}}` (the full env-var name) in any template file. Helpers
below substitute them.

### Helper API

`run.sh` should inline the shared helpers via `#@include` directives (the build
expands them so the dist tarball is self-contained):

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

- `ask_var VAR PROMPT [DEFAULT]`: env > prompt (TTY) > default. Omit DEFAULT for
  a required var; pass `""` to allow empty.
- `ask_choice VAR PROMPT DEFAULT C1 C2 ...`: constrained choice, validates env
  values.
- `sub_in_file FILE VAR ...`: replace `{{VAR}}` with `${!VAR}` in FILE.
- `sub_in_files GLOB VAR ...`: same, over a glob (cwd-relative).
- `rename_token FROM TO [ROOT]`: rename matching file/dir basenames depth-first.
- `merge_scaffold_from SRC [LABEL]`: overlay SRC's contents onto cwd (drops
  `SRC/.git`, appends `SRC/.gitignore` to `./.gitignore` tagged with LABEL, then
  `cp -an`). Use after running an external scaffolder (cargo init, zig init,
  ...) into a tmp dir.
- `default_project_name`, `default_author`: defaults used by the shared prompts.

`common/prompts.sh` provides `ask_shared_vars` which prompts the four shared
vars in order.

### Authoring + testing

```sh
make scaffold-dev TEMPLATE=cpp TARGET=/tmp/foo
```

Builds dist for the named template (running the inliner), then scaffolds it via
`init-nix.sh` pointed at `./dist` instead of the published tarball. Use this to
iterate on a template's `run.sh`.

## How releases work

Pushing to `trunk` triggers `.github/workflows/release.yml`:

1. `make dist` assembles per-language template directories from `common/` plus
   the language source. `.init-nix/run.sh` files have their `#@include`
   directives expanded against `common/`.
2. The commit SHA is written to `dist/VERSION`.
3. The same SHA is baked into `init-nix.sh` (replacing the `__INIT_NIX_SHA__`
   placeholder).
4. `dist/` is packaged as `templates.tar.gz`.
5. The rolling `latest` release is rebuilt with both `templates.tar.gz` and the
   baked `init-nix.sh` as assets.

The SHA pairing lets `init-nix` detect when a user's `init-nix.sh` and the
templates tarball are out of step (see Getting started).

## Adding a template

1. Create a directory at the repo root, e.g. `myhaskell/`.
2. Add `flake.nix` with a `devShells.default` output.
3. Optionally add a language-specific `.envrc` or `.gitignore`. Both are
   concatenated with the matching files in `common/` at build time.
4. Optionally add `.init-nix/run.sh` for post-scaffold setup (see above).
5. Push to `trunk`. CI does the rest.


## TODO

- [ ] Core
    - [ ] c++ should be scaffolded from `nix develop`. Just for consistency, not
      super important.
    - [ ] Add `nix build` for c++. By default should disable vcpkg, dependencies
      can/should be handled through nix.
    - [ ] Python setup hook
    - [ ] Node setup hook
- [ ] Nice-to-have
    - [ ] Better logging during setup
    - [ ] Colour when in a tty
