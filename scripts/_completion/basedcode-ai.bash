#!/usr/bin/env bash
# Tab-completion for the `basedcode-ai` umbrella + every `basedcode-ai-*` CLI.
#
# Source from your shell rc:
#     source /path/to/basedcode-ai/scripts/_completion/basedcode-ai.bash
#
# Or wire it once per machine:
#     sudo install -m 644 basedcode-ai.bash /etc/bash_completion.d/basedcode-ai
#
# What it does:
#   - On the first word after `basedcode-ai`, complete with the list of
#     subcommands (`mail`, `calendar`, ...).
#   - On subsequent words, complete with the subcommand's first-token
#     subcommands (`list`, `show`, ...) which we cache by parsing the
#     tool's own --help output. Updates lazily; refresh by running
#     `_basedcode-ai_refresh_cache`.
#   - Same completion works for the individual `basedcode-ai-foo` scripts.

_basedcode-ai_scripts_dir() {
    # Resolve the scripts/ dir from the script that sources us. We assume
    # the user sourced the file directly out of scripts/_completion/.
    local self="${BASH_SOURCE[0]}"
    while [ -L "$self" ]; do self=$(readlink "$self"); done
    cd "$(dirname "$self")/.." && pwd
}

declare -A _BASEDCODE_AI_SUBS_CACHE=()

_basedcode-ai_refresh_cache() {
    local dir="$(_basedcode-ai_scripts_dir)"
    _BASEDCODE_AI_SUBS_CACHE=()
    # Prefer the project venv's Python so deps (bcrypt, sqlalchemy, ...)
    # resolve. Falls back to system `python3` for container installs.
    local py="$dir/../venv/bin/python"
    [ -x "$py" ] || py="$(command -v python3)"
    local f
    for f in "$dir"/basedcode-ai-*; do
        [ -x "$f" ] || continue
        case "$f" in *.bak|*.pyc|*.pre-*) continue ;; esac
        local name="$(basename "$f")"
        local sub="${name#basedcode-ai-}"
        local help_out
        help_out=$("$py" "$f" --help 2>/dev/null) || continue
        local commands
        commands=$(echo "$help_out" | grep -oE '\{[a-z0-9_,-]+\}' | head -1 \
            | tr -d '{}' | tr ',' ' ')
        _BASEDCODE_AI_SUBS_CACHE[$sub]="$commands"
    done
}

_basedcode-ai_complete() {
    [ ${#_BASEDCODE_AI_SUBS_CACHE[@]} -eq 0 ] && _basedcode-ai_refresh_cache

    local cur="${COMP_WORDS[COMP_CWORD]}"
    local cmd="${COMP_WORDS[0]}"

    # `basedcode-ai <tab>` → list every subcommand
    if [ "$cmd" = "basedcode-ai" ]; then
        if [ "$COMP_CWORD" -eq 1 ]; then
            local subs="${!_BASEDCODE_AI_SUBS_CACHE[@]} help"
            COMPREPLY=($(compgen -W "$subs" -- "$cur"))
            return 0
        fi
        # `basedcode-ai foo <tab>` — complete with foo's own subcommands
        local sub="${COMP_WORDS[1]}"
        # `basedcode-ai help <tab>` lists every subcommand
        if [ "$sub" = "help" ] && [ "$COMP_CWORD" -eq 2 ]; then
            COMPREPLY=($(compgen -W "${!_BASEDCODE_AI_SUBS_CACHE[*]}" -- "$cur"))
            return 0
        fi
        if [ "$COMP_CWORD" -eq 2 ]; then
            COMPREPLY=($(compgen -W "${_BASEDCODE_AI_SUBS_CACHE[$sub]}" -- "$cur"))
            return 0
        fi
        return 0
    fi

    # Direct `basedcode-ai-foo <tab>` (no umbrella)
    local sub="${cmd#basedcode-ai-}"
    if [ "$COMP_CWORD" -eq 1 ]; then
        COMPREPLY=($(compgen -W "${_BASEDCODE_AI_SUBS_CACHE[$sub]}" -- "$cur"))
        return 0
    fi
}

# Register the completion for every basedcode-ai-* script + the umbrella.
complete -F _basedcode-ai_complete basedcode-ai
for f in "$(_basedcode-ai_scripts_dir)"/basedcode-ai-*; do
    [ -x "$f" ] || continue
    case "$f" in *.bak|*.pyc|*.pre-*) continue ;; esac
    complete -F _basedcode-ai_complete "$(basename "$f")"
done
