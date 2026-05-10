# nix-templates

[![Release templates](https://github.com/dk949/nix-templates/actions/workflows/release.yml/badge.svg)](https://github.com/dk949/nix-templates/actions/workflows/release.yml)

Nix flake templates per language. Each template is a minimal `devShell` ready to drop into a project.

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

## Usage

Grab the full set of templates:

```sh
curl -L https://github.com/dk949/nix-templates/releases/download/latest/templates.tar.gz \
  | tar -xz
```

Or extract just one:

```sh
curl -L https://github.com/dk949/nix-templates/releases/download/latest/templates.tar.gz \
  | tar -xz python
```

The download URL is stable across releases.

## How releases work

Pushing to `trunk` triggers `.github/workflows/release.yml`:

1. `make dist` assembles per-language template directories from `common/` plus the language source.
2. The result is packaged as `templates.tar.gz`.
3. The rolling `latest` tag is rebuilt to point at the new asset.

## Adding a template

1. Create a directory at the repo root, e.g. `myhaskell/`.
2. Add `flake.nix` with a `devShells.default` output.
3. Optionally add a language-specific `.envrc` or `.gitignore`. Both are concatenated with the matching files in `common/` at build time.
4. Push to `trunk`. CI does the rest.
