# shellcheck shell=bash
# init-nix template helper lib. Sourced (or inlined) by per-template run.sh.
# Requires bash 4+ for indirect expansion via ${!var}.

# ---- defaults --------------------------------------------------------------

# default_project_name: basename of the eventual project root.
# init-nix.sh exports INIT_NIX_TARGET (the final dest, before scaffold runs in tmp);
# fall back to cwd basename when running outside init-nix.
default_project_name() {
    basename -- "${INIT_NIX_TARGET:-$PWD}"
}

# default_author: "Name <email>" from git config, else "$USER", else empty.
default_author() {
    local name email
    name="$(git config --get user.name 2>/dev/null || true)"
    email="$(git config --get user.email 2>/dev/null || true)"
    if [[ -n "$name" && -n "$email" ]]; then
        printf '%s <%s>' "$name" "$email"
    elif [[ -n "$name" ]]; then
        printf '%s' "$name"
    elif [[ -n "${USER:-}" ]]; then
        printf '%s' "$USER"
    else
        printf ''
    fi
}

# ---- prompting -------------------------------------------------------------

# _is_tty: stdin attached to a terminal.
_is_tty() {
    [[ -t 0 ]]
}

# ask_var VAR PROMPT [DEFAULT]
#   If env VAR set + non-empty: keep it.
#   Else if TTY: prompt, accept default on empty input.
#   Else: use default.
#   Empty result is an error iff no DEFAULT arg was passed (3rd arg absent = required).
#   An explicit empty default ("") means the value may be left blank.
ask_var() {
    local var="$1" prompt="$2" reply
    local default="" has_default=0
    if [[ $# -ge 3 ]]; then
        default="$3"
        has_default=1
    fi
    if [[ -n "${!var:-}" ]]; then
        return 0
    fi
    if _is_tty; then
        if [[ -n "$default" ]]; then
            read -r -p "$prompt [$default]: " reply
        else
            read -r -p "$prompt: " reply
        fi
        reply="${reply:-$default}"
    else
        reply="$default"
    fi
    if [[ -z "$reply" && "$has_default" -eq 0 ]]; then
        printf 'init-nix: %s required (set %s or run interactively)\n' "$prompt" "$var" >&2
        return 1
    fi
    printf -v "$var" '%s' "$reply"
    export "${var?}"
}

# ask_choice VAR PROMPT DEFAULT CHOICE1 CHOICE2 ...
#   Restricted choice. Env value validated against choices; rejects + reprompts on TTY.
ask_choice() {
    local var="$1" prompt="$2" default="$3"
    shift 3
    local choices=("$@") choice reply joined
    joined="$(IFS='|'; printf '%s' "${choices[*]}")"

    _in_choices() {
        local needle="$1" c
        for c in "${choices[@]}"; do [[ "$c" == "$needle" ]] && return 0; done
        return 1
    }

    if [[ -n "${!var:-}" ]]; then
        if _in_choices "${!var}"; then return 0; fi
        printf 'init-nix: %s=%s not in {%s}\n' "$var" "${!var}" "$joined" >&2
        if ! _is_tty; then return 1; fi
        unset "$var"
    fi

    while :; do
        if _is_tty; then
            read -r -p "$prompt [$joined] ($default): " reply
            reply="${reply:-$default}"
        else
            reply="$default"
        fi
        if _in_choices "$reply"; then
            choice="$reply"
            break
        fi
        printf 'init-nix: %s not in {%s}\n' "$reply" "$joined" >&2
        if ! _is_tty; then return 1; fi
    done
    printf -v "$var" '%s' "$choice"
    export "${var?}"
}

# ---- substitution ----------------------------------------------------------

# sub_in_file FILE VAR1 [VAR2 ...]
#   Replace {{VAR}} in FILE w/ ${!VAR}. Uses a literal-safe sed pipeline.
sub_in_file() {
    local file="$1"
    shift
    [[ -f "$file" ]] || { printf 'init-nix: sub_in_file: no such file: %s\n' "$file" >&2; return 1; }
    local v val tmp
    tmp="$(mktemp)"
    cp -- "$file" "$tmp"
    for v in "$@"; do
        val="${!v:-}"
        # Escape sed replacement metacharacters: \ & and the chosen delimiter (|).
        # Newlines in val are not supported.
        val="${val//\\/\\\\}"
        val="${val//|/\\|}"
        val="${val//&/\\&}"
        sed -i "s|{{${v}}}|${val}|g" "$tmp"
    done
    mv -- "$tmp" "$file"
}

# sub_in_files GLOB VAR1 [VAR2 ...]
#   Apply sub_in_file to every regular file matched by GLOB (relative to cwd).
#   GLOB can include ** if globstar; caller should `shopt -s globstar` if needed.
sub_in_files() {
    local glob="$1"
    shift
    local f matched=0
    # shellcheck disable=SC2206  # intentional word-split on glob expansion
    local files=($glob)
    for f in "${files[@]}"; do
        [[ -f "$f" ]] || continue
        sub_in_file "$f" "$@"
        matched=1
    done
    if (( matched == 0 )); then
        printf 'init-nix: sub_in_files: no files matched %s\n' "$glob" >&2
    fi
}

# ---- renames ---------------------------------------------------------------

# rename_token FROM TO [ROOT]
#   Rename every path under ROOT (default .) whose basename contains FROM,
#   replacing FROM w/ TO. Depth-first so parents rename last.
rename_token() {
    local from="$1" to="$2" root="${3:-.}"
    [[ -n "$from" && -n "$to" ]] || { printf 'init-nix: rename_token: FROM and TO required\n' >&2; return 1; }
    local path base new dir
    # Depth-first: -depth ensures children renamed before parents.
    while IFS= read -r path; do
        base="$(basename -- "$path")"
        case "$base" in
            *"$from"*) ;;
            *) continue ;;
        esac
        dir="$(dirname -- "$path")"
        new="${base//$from/$to}"
        mv -- "$path" "$dir/$new"
    done < <(find "$root" -depth -name "*${from}*" -print)
}
