#!/usr/bin/env bash
# Scaffolds a Go project by running `go mod init`. The only artifact is
# go.mod, which doesn't conflict with scaffold files, so we run directly
# in cwd (no tmp+merge dance needed).
#
# Env vars:
#   INIT_NIX_PROJECT_NAME   project name (prompted; default = target basename)
#   INIT_NIX_GO_MODULE      module path (prompted; default = project name)
set -euo pipefail
#@include common/lib.sh

ask_var INIT_NIX_PROJECT_NAME "Project name"    "$(default_project_name)"
ask_var INIT_NIX_GO_MODULE    "Go module path"  "$INIT_NIX_PROJECT_NAME"

go mod init "$INIT_NIX_GO_MODULE" >/dev/null
