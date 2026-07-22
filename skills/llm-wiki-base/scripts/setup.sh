#!/usr/bin/env bash
# setup.sh — provision (or refresh) the single llm-wiki zk notebook.
#
# This is the ONE source of truth for llm-wiki's deployable config: the zk
# config.toml (the verb [alias] block — the KB mechanics), the note template,
# and the bundled human-only walk.sh. SKILL.md describes what the verbs mean and
# when to use them; this script *installs* them. The llm-wiki skills run it (via
# `bash "<llm-wiki-base>/scripts/setup.sh"`) before any read/write, and a human
# runs it directly after a `git pull` to redeploy — the llm-wiki-init skill is
# the front door for that.
#
# IDEMPOTENT by construction: it does not diff or patch, it fully (re)writes the
# config, template, and walk.sh on every run, so any number of runs converges to
# the same state. `zk init` is the only conditional step (only when `.zk` is
# absent). Re-running is always safe and is how existing notebooks pick up new
# aliases. NOTE: config.toml and the template are skill-owned and fully
# generated — a hand edit to either is overwritten on the next run by design.
set -euo pipefail

# Self-locate: the bundled walk.sh lives next to this script, so setup needs no
# externally-supplied base dir (unlike the old inline block, which required
# $llm_wiki_base_dir). Resolves correctly however the script is invoked.
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

wiki="${XDG_DATA_HOME:-$HOME/.local/share}/llm-wiki"
if [ ! -d "$wiki/.zk" ]; then
  mkdir -p "$wiki"
  zk --no-input init "$wiki" >/dev/null
fi
mkdir -p "$wiki/.zk/templates"   # zk init makes this, but be robust if it's gone

# The config and template are skill-owned and fully generated, so (re)write them
# on EVERY run — not just first init — so existing notebooks pick up changes
# (e.g. new aliases) too. Both writes are idempotent.
# Config: slug filenames (so [[slug]] wikilinks resolve), wiki links, hashtags.
# `ignore` keeps plumbing files (named _*.md at ANY depth, e.g. _gaps.md or
# global/_consensus.md) out of the index and out of reach — the reserved
# reach-exclusion mechanism for files that should NEVER be reachable. `**/_*.md`
# matches root and nested alike (a bare `_*.md` would only match the notebook
# root). Archived notes are NOT ignored — they stay in the index (so slug links
# to them keep resolving) and are excluded from reach by the verbs' default
# `-x _archived` filter instead, which is opt-in-able; `ignore` would make them
# unreachable, period. `-x` matches a literal path prefix (no globs), which is
# why archive collects everything under the single root `_archived/` directory.
# The [alias] block bakes in the zk verbs — the single source of truth for KB
# mechanics (see SKILL.md "Verb surface"): every skill routes its reads/
# maintenance through a verb, never a raw `zk list …`/`index` again. Invoke a
# verb as `zk -W "$wiki" <verb>`; note that a *no-value* global flag before the
# verb name breaks zk's alias resolution (`zk --no-input find …` fails), so each
# verb bakes `--no-input` inside instead. Verified on zk 0.15.5.
cat > "$wiki/.zk/config.toml" <<'TOML'
[note]
filename = "{{slug title}}"
template = "default.md"
ignore = ["**/_*.md"]
[format.markdown]
link-format = "wiki"
hashtags = true
[alias]
# Verbs = the one place KB mechanics live. Read verbs emit JSON as the canonical
# machine surface (agents parse it); `find` is the thin human presenter over
# `scan`. Every verb forwards extra args to the underlying zk command, so
# filters compose: `scan --tag raft`, `scan <scope>/ --match x`,
# `scan --orphan`, `links <path> --recursive --max-distance 2`.
# Reach and aggregate verbs exclude the root `_archived/` directory by default;
# set LLM_WIKI_INCLUDE_ARCHIVED=1 to include archived notes in any verb's
# result. The exclusion is prepended with `set -- -x _archived "$@"` — NOT via
# an unquoted variable — because zk runs aliases through $SHELL and zsh does
# not word-split unquoted variables (a "$excl" holding "-x _archived" reaches
# zk as one useless argument; verified).
#   scan  [filters…]      — compact JSON map {title,tags,path,snippet,updated,
#                           distilled,distill_count}; the workhorse behind every
#                           "reach a note" read and the distill-selection scan
#   find  <query>         — human-readable presenter over `scan --match`
#   show  <query>         — full note (title, tags, body) for full-text matches
#   links <path> [flags]  — inbound then outbound links of <path> as JSON;
#                           snippet = the paragraph(s) around the link in the
#                           source note, i.e. why the two notes connect
#   tags                  — the keyword index (JSONL {name,count}; aggregated
#                           from `zk list` via jq because `zk tag list` cannot
#                           filter, so the `_archived` exclusion applies here too)
#   graph                 — the whole-notebook link graph (JSON)
#   new   <scope> [flags] — create a note: body from stdin (-i), print path (-p)
#   archive <path>…       — move notes to root `_archived/<scope path>/` and
#                           reindex; retirement is a location, not a tag
#   reindex               — refresh the index after writes/moves
#   walk  <query>         — HUMAN-ONLY interactive fzf link walker (needs fzf).
#                           Agents never use this; they traverse via `links`.
#                           Runs the bundled script installed at .zk/walk.sh.
#   browse [filters…]     — HUMAN-ONLY fzf note picker (needs fzf). Rows show
#                           title + #tags (+ dimmed snippet), so typing narrows
#                           by title and tag alike; enter prints the note path,
#                           ctrl-o opens $EDITOR, the preview pane shows the
#                           body. With NO args it defaults to the current
#                           concern, resolved via git from $PWD (the same
#                           dev-path resolution as Setup — aliases run in the
#                           caller's cwd) when that scope directory exists;
#                           any args forward to `scan` (e.g. `browse global/`,
#                           `browse <scope>/ --tag raft`), replacing the
#                           default.
scan  = '[ -z "$LLM_WIKI_INCLUDE_ARCHIVED" ] && set -- -x _archived "$@"; zk --no-input list --quiet "$@" -f json | jq -c ".[] | {title, tags: (.metadata.tags // []), path, snippet: (.body[0:120]), updated: .metadata.updated, distilled: .metadata.distilled, distill_count: .metadata.distill_count}"'
find  = 'zk scan --match "$*" | jq -r "[.title, (.tags | map(\"#\"+.) | join(\" \")), .snippet] | join(\"  \")"'
show  = 'q="$*"; set --; [ -z "$LLM_WIKI_INCLUDE_ARCHIVED" ] && set -- -x _archived; zk --no-input list --quiet "$@" --match "$q" --format full'
links = 'p="$1"; shift; [ -z "$LLM_WIKI_INCLUDE_ARCHIVED" ] && set -- -x _archived "$@"; { zk --no-input list --quiet --link-to "$p" "$@" -f json | jq -c ".[] | {dir:\"in\", title, path, snippet: ((.snippets // []) | join(\" … \"))}"; zk --no-input list --quiet --linked-by "$p" "$@" -f json | jq -c ".[] | {dir:\"out\", title, path, snippet: ((.snippets // []) | join(\" … \"))}"; }'
tags  = '[ -z "$LLM_WIKI_INCLUDE_ARCHIVED" ] && set -- -x _archived "$@"; zk --no-input list --quiet "$@" -f json | jq -c "[.[] | (.metadata.tags // [])[]] | group_by(.) | map({name: .[0], count: length}) | sort_by(-.count)[]"'
graph = '[ -z "$LLM_WIKI_INCLUDE_ARCHIVED" ] && set -- -x _archived "$@"; zk --no-input graph --format json --quiet "$@"'
new     = 'zk --no-input new "$@" -i -p'
archive = 'for p in "$@"; do d="_archived/$(dirname "$p")"; mkdir -p "$ZK_NOTEBOOK_DIR/$d"; mv "$ZK_NOTEBOOK_DIR/$p" "$ZK_NOTEBOOK_DIR/$d/"; done; zk --no-input index'
reindex = 'zk --no-input index'
walk    = 'bash "$ZK_NOTEBOOK_DIR/.zk/walk.sh" "$@"'
browse  = 'command -v fzf >/dev/null 2>&1 || { printf "browse requires fzf but it is not installed. Install it (e.g. \`brew install fzf\`) and retry.\n" >&2; exit 1; }; if [ $# -eq 0 ] && d=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null); then s=$(basename "$(dirname "$d")"); [ -d "$ZK_NOTEBOOK_DIR/$s" ] && set -- "$s/"; fi; zk scan "$@" | jq -r "[.path, .title, (.tags | map(\"#\"+.) | join(\" \")), \"\u001b[2m\" + ((.snippet // \"\") | gsub(\"\\\\s+\"; \" \")) + \"\u001b[0m\"] | @tsv" | fzf --ansi --delimiter="\t" --with-nth=2.. --prompt="browse> " --header="enter: print path · ctrl-o: edit · esc: quit" --preview="cat \"$ZK_NOTEBOOK_DIR\"/{1}" --bind="ctrl-o:execute(\${EDITOR:-vi} \"$ZK_NOTEBOOK_DIR\"/{1})" | cut -f1'
TOML

# Template: {{content}} is required so `zk new -i` can pipe a body in via stdin.
# Frontmatter carries the distill footprint (see SKILL.md "Note Model"):
# created/updated start at today, distilled empty (= never distilled),
# distill_count 0. tags starts empty — capture adds free topical tags, never a
# maturity state.
printf -- '---\ntitle: {{title}}\ncreated: {{format-date now "%%Y-%%m-%%d"}}\nupdated: {{format-date now "%%Y-%%m-%%d"}}\ndistilled:\ndistill_count: 0\ntags: []\n---\n\n{{content}}\n' \
  > "$wiki/.zk/templates/default.md"

# Install the human-only `walk` script into the notebook so `zk -W "$wiki" walk`
# is self-contained — the notebook carries its own copy, so a human can run it
# from any checkout. Source of truth: this script's sibling scripts/walk.sh;
# like the config and template it is (re)installed on EVERY run.
install -m 0755 "$script_dir/walk.sh" "$wiki/.zk/walk.sh"

printf 'llm-wiki notebook ready at %s\n' "$wiki"
