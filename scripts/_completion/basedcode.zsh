#compdef basedcode basedcode-backup basedcode-calendar basedcode-contacts basedcode-cookbook basedcode-docs basedcode-gallery basedcode-mail basedcode-mcp basedcode-memory basedcode-notes basedcode-personal basedcode-preset basedcode-research basedcode-sessions basedcode-signature basedcode-skills basedcode-tasks basedcode-theme basedcode-webhook
# Zsh tab-completion for the basedcode umbrella + sub-CLIs.
#
# Drop in any directory on $fpath, e.g.:
#     fpath=(/path/to/basedcode-ui/scripts/_completion $fpath)
#     autoload -U compinit; compinit
#
# Then `basedcode <tab>` completes subcommands; `basedcode mail <tab>`
# completes mail subcommands; `basedcode-mail <tab>` works the same.

_basedcode_scripts_dir() {
    local self="${(%):-%x}"
    while [[ -L "$self" ]]; do self="$(readlink "$self")"; done
    cd "${self:h}/.." && pwd
}

typeset -gA _basedcode_subs

_basedcode_refresh() {
    _basedcode_subs=()
    local dir="$(_basedcode_scripts_dir)"
    local py="$dir/../venv/bin/python"
    [[ -x "$py" ]] || py="$(command -v python3)"
    local f sub help_out commands
    for f in "$dir"/basedcode-*; do
        [[ -x "$f" ]] || continue
        case "$f" in
            *.bak|*.pyc|*.pre-*) continue ;;
        esac
        sub="${${f:t}#basedcode-}"
        help_out=$("$py" "$f" --help 2>/dev/null) || continue
        commands=$(echo "$help_out" | grep -oE '\{[a-z0-9_,-]+\}' | head -1 \
            | tr -d '{}' | tr ',' ' ')
        _basedcode_subs[$sub]="$commands"
    done
}

_basedcode() {
    [[ ${#_basedcode_subs} -eq 0 ]] && _basedcode_refresh

    local cmd="${words[1]}"

    if [[ "$cmd" == "basedcode" ]]; then
        if (( CURRENT == 2 )); then
            local -a subs=(${(k)_basedcode_subs} help)
            _describe 'subcommand' subs
            return
        fi
        local sub="${words[2]}"
        if [[ "$sub" == "help" ]] && (( CURRENT == 3 )); then
            local -a subs=(${(k)_basedcode_subs})
            _describe 'subcommand' subs
            return
        fi
        if (( CURRENT == 3 )); then
            local -a sc=(${(s/ /)_basedcode_subs[$sub]})
            _describe 'command' sc
            return
        fi
        return
    fi

    # basedcode-foo <tab>
    local sub="${cmd#basedcode-}"
    if (( CURRENT == 2 )); then
        local -a sc=(${(s/ /)_basedcode_subs[$sub]})
        _describe 'command' sc
        return
    fi
}

_basedcode "$@"
