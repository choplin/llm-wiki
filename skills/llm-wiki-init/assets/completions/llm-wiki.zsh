#compdef zk
#
# llm-wiki completion for zsh.
#
# Install this file on fpath as `_zk`.  compinit discovers the
# #compdef line and autoloads the matching function on demand.

_zk_candidates()
{
    {
        command zk --help 2>/dev/null |
            command awk '/^  [[:alpha:]][[:alnum:]_-]*[[:space:]][[:space:]]/ { print $1 }'
        command zk config --list aliases --quiet --no-pager 2>/dev/null
    } | command awk 'NF && !seen[$1]++ { print $1 }'
}

_zk()
{
    if (( CURRENT == 2 )); then
        local -a candidates
        candidates=("${(@f)$(_zk_candidates)}")
        _describe -t commands 'zk command or alias' candidates
    fi
}
