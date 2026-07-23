# llm-wiki completion for zsh.
#
# Source this file after setup. It initializes zsh's completion system when
# needed, adds configured zk aliases at the first argument, and delegates to an
# existing zk completion function when one is registered.

_llm_wiki_zk_candidates()
{
    {
        command zk --help 2>/dev/null |
            command awk '/^  [[:alpha:]][[:alnum:]_-]*[[:space:]][[:space:]]/ { print $1 }'
        command zk config --list aliases --quiet --no-pager 2>/dev/null
    } | command awk 'NF && !seen[$1]++ { print $1 }'
}

if (( ! $+functions[compdef] )); then
    autoload -Uz compinit
    compinit
fi

# Re-sourcing this file keeps the original delegate instead of capturing this
# wrapper and recursing.
if (( ! ${+_LLM_WIKI_ZK_PREVIOUS_COMPLETION} )); then
    typeset -g _LLM_WIKI_ZK_PREVIOUS_COMPLETION=${_comps[zk]-}
fi

_llm_wiki_zk_completion()
{
    local previous=$_LLM_WIKI_ZK_PREVIOUS_COMPLETION
    local result=1

    if [[ -n $previous && $previous != _llm_wiki_zk_completion ]]; then
        if (( ! $+functions[$previous] )); then
            autoload -Uz "$previous" 2>/dev/null || true
        fi
        if (( $+functions[$previous] )); then
            "$previous" "$@" || true
            result=0
        fi
    fi

    if (( CURRENT == 2 )); then
        local -a candidates
        candidates=("${(@f)$(_llm_wiki_zk_candidates)}")
        _describe -t commands 'zk command or alias' candidates && result=0
    fi

    return result
}

compdef _llm_wiki_zk_completion zk
