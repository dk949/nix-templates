#!/usr/bin/env bash
# Scaffolds a Go project: runs `go mod init` and writes a hello-world main.go
# so `nix build` has something to compile, then substitutes the project name
# into flake.nix's packages.default pname. `go mod init` runs inside
# `nix develop` so the toolchain matches the one nix build will use.
#
# Env vars:
#   INIT_NIX_PROJECT_NAME   project name (prompted; default = target basename)
#   INIT_NIX_GO_MODULE      module path (prompted; default = project name)
set -euo pipefail
#@include common/lib.sh

ask_var INIT_NIX_PROJECT_NAME "Project name"    "$(default_project_name)"
ask_var INIT_NIX_GO_MODULE    "Go module path"  "$INIT_NIX_PROJECT_NAME"

nix --extra-experimental-features 'nix-command flakes' develop \
    --command go mod init "$INIT_NIX_GO_MODULE" >/dev/null

cat > main.go <<'EOF'
package main

import "fmt"

func main() {
	fmt.Println("hello, world")
}
EOF

sub_in_file flake.nix INIT_NIX_PROJECT_NAME
