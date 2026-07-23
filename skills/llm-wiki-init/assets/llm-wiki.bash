# llm-wiki completion for bash.
#
# Source this file after setup. It adds configured zk aliases at the first
# argument while retaining native command candidates and delegating to an
# existing function-based zk completion when one is registered.

_llm_wiki_zk_candidates()
{
    {
        command zk --help 2>/dev/null |
            command awk '/^  [[:alpha:]][[:alnum:]_-]*[[:space:]][[:space:]]/ { print $1 }'
        command zk config --list aliases --quiet --no-pager 2>/dev/null
    } | command awk 'NF && !seen[$1]++ { print $1 }'
}

# Give bash-completion a chance to lazy-load an installed zk completion before
# capturing it. Re-sourcing this file keeps the original delegate.
if ! complete -p zk >/dev/null 2>&1 &&
        declare -F _completion_loader >/dev/null 2>&1; then
    _completion_loader zk >/dev/null 2>&1 || true
fi

if [ -z "${_LLM_WIKI_ZK_PREVIOUS_COMPLETION+x}" ]; then
    _LLM_WIKI_ZK_PREVIOUS_COMPLETION=
    _llm_wiki_zk_completion_spec=$(complete -p zk 2>/dev/null || true)
    if [[ $_llm_wiki_zk_completion_spec =~ (^|[[:space:]])-F[[:space:]]+([^[:space:]]+) ]]; then
        _LLM_WIKI_ZK_PREVIOUS_COMPLETION=${BASH_REMATCH[2]}
    fi
    unset _llm_wiki_zk_completion_spec
fi

_llm_wiki_zk_completion()
{
    local current=${COMP_WORDS[COMP_CWORD]}
    local candidate existing duplicate

    COMPREPLY=()
    if [ -n "$_LLM_WIKI_ZK_PREVIOUS_COMPLETION" ] &&
            [ "$_LLM_WIKI_ZK_PREVIOUS_COMPLETION" != _llm_wiki_zk_completion ] &&
            declare -F "$_LLM_WIKI_ZK_PREVIOUS_COMPLETION" >/dev/null 2>&1; then
        "$_LLM_WIKI_ZK_PREVIOUS_COMPLETION" "$@" || true
    fi

    # Aliases and native commands are top-level candidates. At later positions,
    # leave completion to the previous function or bash's default fallback.
    if [ "${COMP_CWORD:-0}" -eq 1 ]; then
        while IFS= read -r candidate; do
            case $candidate in
                "$current"*) ;;
                *) continue ;;
            esac
            duplicate=
            for existing in "${COMPREPLY[@]}"; do
                if [ "$existing" = "$candidate" ]; then
                    duplicate=1
                    break
                fi
            done
            [ -n "$duplicate" ] || COMPREPLY[${#COMPREPLY[@]}]=$candidate
        done < <(_llm_wiki_zk_candidates)
    fi
}

complete -o bashdefault -o default -F _llm_wiki_zk_completion zk
