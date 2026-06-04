#compdef basedcode-ai basedcode-ai-backup basedcode-ai-calendar basedcode-ai-contacts basedcode-ai-cookbook basedcode-ai-docs basedcode-ai-gallery basedcode-ai-mail basedcode-ai-mcp basedcode-ai-memory basedcode-ai-notes basedcode-ai-personal basedcode-ai-preset basedcode-ai-research basedcode-ai-sessions basedcode-ai-signature basedcode-ai-skills basedcode-ai-tasks basedcode-ai-theme basedcode-ai-webhook
# Zsh tab-completion for the basedcode-ai umbrella + sub-CLIs.
#
# Drop in any directory on $fpath, e.g.:
#     fpath=(/path/to/basedcode-ai/scripts/_completion $fpath)
#     autoload -U compinit; compinit
#
# Then `basedcode-ai <tab>` completes subcommands; `basedcode-ai mail <tab>`
# completes mail subcommands; `basedcode-ai-mail <tab>` works the same.

_basedcode-ai_scripts_dir() {
    local self="${(%):-%x}"
    while [[ -L "$self" ]]; do self="$(readlink "$self")"; done
    cd "${self:h}/.." && pwd
}

typeset -gA _basedcode-ai_subs

_basedcode-ai_refresh() {
    _basedcode-ai_subs=()
    local dir="$(_basedcode-ai_scripts_dir)"
    local py="$dir/../venv/bin/python"
    [[ -x "$py" ]] || py="$(command -v python3)"
    local f sub help_out commands
    for f in "$dir"/basedcode-ai-*; do
        [[ -x "$f" ]] || continue
        case "$f" in
            *.bak|*.pyc|*.pre-*) continue ;;
        esac
        sub="${${f:t}#basedcode-ai-}"
        help_out=$("$py" "$f" --help 2>/dev/null) || continue
        commands=$(echo "$help_out" | grep -oE '\{[a-z0-9_,-]+\}' | head -1 \
            | tr -d '{}' | tr ',' ' ')
        _basedcode-ai_subs[$sub]="$commands"
    done
}

_basedcode-ai() {
    [[ ${#_basedcode-ai_subs} -eq 0 ]] && _basedcode-ai_refresh

    local cmd="${words[1]}"

    if [[ "$cmd" == "basedcode-ai" ]]; then
        if (( CURRENT == 2 )); then
            local -a subs=(${(k)_basedcode-ai_subs} help)
            _describe 'subcommand' subs
            return
        fi
        local sub="${words[2]}"
        if [[ "$sub" == "help" ]] && (( CURRENT == 3 )); then
            local -a subs=(${(k)_basedcode-ai_subs})
            _describe 'subcommand' subs
            return
        fi
        if (( CURRENT == 3 )); then
            local -a sc=(${(s/ /)_basedcode-ai_subs[$sub]})
            _describe 'command' sc
            return
        fi
        return
    fi

    # basedcode-ai-foo <tab>
    local sub="${cmd#basedcode-ai-}"
    if (( CURRENT == 2 )); then
        local -a sc=(${(s/ /)_basedcode-ai_subs[$sub]})
        _describe 'command' sc
        return
    fi
}

_basedcode-ai "$@"
