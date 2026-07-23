#compdef zk
#
# llm-wiki completion for zsh.
#
# Install this file on fpath as `_zk`.  compinit discovers the
# #compdef line and autoloads the matching function on demand.

_zk_alias_candidates()
{
    command zk config --list aliases --quiet --no-pager 2>/dev/null |
        while IFS= read -r alias; do
            case $alias in
                archive) description='Move notes to _archived and reindex' ;;
                browse)  description='Interactively pick a note with fzf' ;;
                find)    description='Search titles, tags, and snippets' ;;
                graph)   description='Produce the whole-notebook link graph as JSON' ;;
                help)    description='Show the llm-wiki verb reference' ;;
                links)   description='Show inbound and outbound links as JSON' ;;
                new)     description='Create a note from stdin and print its path' ;;
                reindex) description='Refresh the note index' ;;
                scan)    description='List notes as compact JSON' ;;
                show)    description='Print matching notes in full' ;;
                tags)    description='List the keyword index as JSONL' ;;
                walk)    description='Interactively walk links with fzf' ;;
                *)       description='Run a configured zk alias' ;;
            esac
            printf '%s:%s\n' "$alias" "$description"
        done
}

_zk_native_candidates()
{
    local -A aliases
    local alias name description

    for alias in ${(f)"$(command zk config --list aliases --quiet --no-pager 2>/dev/null)"}; do
        aliases[$alias]=1
    done

    command zk --help 2>/dev/null |
        command awk '
            /^  [[:alpha:]][[:alnum:]_-]*[[:space:]][[:space:]]/ {
                name = $1
                $1 = ""
                sub(/^[[:space:]]+/, "")
                sub(/[.]$/, "")
                print name ":" $0
            }
        ' |
        while IFS=: read -r name description; do
            [[ -n ${aliases[$name]} ]] || printf '%s:%s\n' "$name" "$description"
        done
}

_zk()
{
    if (( CURRENT == 2 )); then
        local -a verbs commands
        local result=1

        verbs=("${(@f)$(_zk_alias_candidates)}")
        commands=("${(@f)$(_zk_native_candidates)}")
        _describe -t llm-wiki-verbs 'llm-wiki verbs' verbs && result=0
        _describe -t zk-commands 'zk commands' commands && result=0
        return result
    fi
}
