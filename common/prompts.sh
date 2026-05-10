# shellcheck shell=bash
# Canonical prompts for shared vars. Source (or inline) from per-template run.sh,
# then add lang-scoped ask_var/ask_choice calls afterwards.
#
# Depends on common/lib.sh.

ask_shared_vars() {
    ask_var    INIT_NIX_PROJECT_NAME "Project name" "$(default_project_name)" || return 1
    ask_var    INIT_NIX_AUTHOR       "Author"       "$(default_author)"       || return 1
    ask_var    INIT_NIX_DESC         "Description"  ""                        || return 1
    ask_choice INIT_NIX_LICENSE      "License"      MIT MIT Apache-2.0 BSD-3-Clause GPL-3.0 none || return 1
}
