#!/usr/bin/env bash
# walk.sh — human-only interactive link walker for an llm-wiki (zk) notebook.
#
# The `walk` verb (see llm-wiki-base [alias]) execs this. It is the ONE human-CLI
# entry that agents never use — agents traverse links non-interactively via the
# `links` verb. fzf is a REQUIRED dependency: with no fzf, walk errors out (it does
# not degrade). base setup installs a copy into "$notebook/.zk/walk.sh" so the
# notebook is self-contained and a human can run `zk -W "$wiki" walk <query>`
# from any checkout.
#
# Usage:
#   walk.sh <query>            Resolve a start note from <query>, then walk in fzf.
# Internal (invoked by fzf key binds, not by hand):
#   walk.sh __list             Print the current note's links (per mode) as TSV.
#   walk.sh __preview <path>   Print a note body for the fzf preview pane.
#   walk.sh __descend <path>   Go to <path> (push current to history; keep direction).
#   walk.sh __pop              Go back to the previous note (history stack).
#   walk.sh __toggle           Flip the walk direction (fwd/advance ⇄ back/backlinks).
#   walk.sh __prompt           Print the fzf prompt for the current direction.
#   walk.sh __header           Print the fzf header (current note @ title + keys).
#
# Keys while walking: enter = move to the highlighted note (keeping the current
# direction) · ctrl-b = go back to the previous note · ctrl-d = flip the direction
# · ctrl-o = open in $EDITOR · esc = quit. The header shows the current note
# (@ title); the prompt labels the advance direction (following this note's
# outbound links) as "in" (→in) and the backlinks direction as "out" (←out); each
# list row appends the link-context snippet (the paragraph where the link occurs,
# dimmed) after the title; the preview pane shows the highlighted target's body.
set -euo pipefail

# zk exports ZK_NOTEBOOK_DIR to alias commands; self-invocations re-export it below.
wiki="${ZK_NOTEBOOK_DIR:-}"
[ -n "$wiki" ] || { printf 'walk: ZK_NOTEBOOK_DIR is not set — run via `zk -W "$wiki" walk <query>`\n' >&2; exit 1; }
self="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"

die() { printf 'walk: %s\n' "$1" >&2; exit 1; }

# --- internal subcommands (called from fzf binds) ---------------------------
case "${1:-}" in
  __list)
    cur="$(cat "$WALK_STATE/current")"; mode="$(cat "$WALK_STATE/mode")"
    # Map the walk direction to a zk link direction, then reuse the base `links`
    # verb (single source of truth). "fwd" = advance along this note's outbound
    # links (shown to the human as "in"); "back" = its backlinks (shown as "out").
    # Column 3 is the link-context snippet from the `links` verb — the paragraph
    # around the link in the source note — flattened to one line (this also strips
    # tabs, keeping the TSV intact) and dimmed so the title stays prominent.
    if [ "$mode" = "back" ]; then dir="in"; marker="← "; else dir="out"; marker="→ "; fi
    zk -W "$wiki" links "$cur" 2>/dev/null | jq -r --arg d "$dir" --arg m "$marker" '
      select(.dir == $d)
      | [.path, ($m + .title),
         (if (.snippet // "") == "" then ""
          else "\u001b[2m" + (.snippet | gsub("\\s+"; " ")) + "\u001b[0m" end)]
      | @tsv'
    exit 0 ;;
  __preview)
    p="${2:-}"
    if [ -n "$p" ] && [ -f "$wiki/$p" ]; then cat "$wiki/$p"; else echo "(no preview)"; fi
    exit 0 ;;
  __descend)
    p="${2:-}"
    if [ -n "$p" ]; then
      printf '%s\n' "$(cat "$WALK_STATE/current")" >> "$WALK_STATE/history"   # remember where we came from
      printf '%s' "$p" > "$WALK_STATE/current"                                # keep the direction
    fi
    exit 0 ;;
  __pop)
    h="$WALK_STATE/history"
    if [ -s "$h" ]; then
      prev="$(tail -n 1 "$h")"; n="$(wc -l < "$h")"
      if [ "$n" -gt 1 ]; then head -n "$((n - 1))" "$h" > "$h.tmp"; else : > "$h.tmp"; fi
      mv "$h.tmp" "$h"
      printf '%s' "$prev" > "$WALK_STATE/current"
    fi
    exit 0 ;;
  __toggle)
    if [ "$(cat "$WALK_STATE/mode")" = "fwd" ]; then printf 'back' > "$WALK_STATE/mode"; else printf 'fwd' > "$WALK_STATE/mode"; fi
    exit 0 ;;
  __prompt)
    # human labels: "fwd" (advance/outbound) → "in"; "back" (backlinks) → "out".
    if [ "$(cat "$WALK_STATE/mode")" = "back" ]; then printf 'walk ←out> '; else printf 'walk →in> '; fi
    exit 0 ;;
  __header)
    cur="$(cat "$WALK_STATE/current")"
    t="$(zk -W "$wiki" --no-input list --quiet --format '{{title}}' "$cur" 2>/dev/null | head -n 1)"
    [ -n "$t" ] || t="$cur"
    printf '@ %s\nenter: descend · ctrl-b: back · ctrl-d: flip · ctrl-o: edit · esc: quit' "$t"
    exit 0 ;;
esac

# --- main -------------------------------------------------------------------
query="${1:-}"
[ -n "$query" ] || die "usage: walk <query>"
command -v fzf >/dev/null 2>&1 || die "walk requires fzf but it is not installed. Install it (e.g. \`brew install fzf\`) and retry."
command -v jq  >/dev/null 2>&1 || die "walk requires jq but it is not installed."

# Resolve the starting note from the query. `scan -m` is a full-text match, so a
# word like "raft" also matches notes that merely mention it. Prefer an exact
# title or slug match so a precise query jumps straight into the walk; only a
# genuinely ambiguous query opens the picker.
matches="$(zk -W "$wiki" scan -m "$query" 2>/dev/null || true)"
[ -n "$matches" ] || die "no note matches: $query"
slug="$(printf '%s' "$query" | tr 'A-Z ' 'a-z-')"
exact="$(printf '%s\n' "$matches" | jq -c --arg q "$query" --arg s "$slug" '
  select((.title | ascii_downcase) == ($q | ascii_downcase)
      or (.path | split("/") | last | rtrimstr(".md") | ascii_downcase) == $s)')"
if   [ "$(printf '%s\n' "$exact"   | grep -c .)" -eq 1 ]; then start="$(printf '%s' "$exact"   | jq -r '.path')"
elif [ "$(printf '%s\n' "$matches" | grep -c .)" -eq 1 ]; then start="$(printf '%s' "$matches" | jq -r '.path')"
else
  start="$(printf '%s\n' "$matches" | jq -r '[.path, .title] | @tsv' \
    | fzf --delimiter='\t' --with-nth=2.. --prompt='pick start> ' \
          --header="pick a start note matching: $query" \
          --preview="cat \"$wiki\"/{1}" | cut -f1)"
  [ -n "$start" ] || exit 0   # aborted the start selection
fi

# Per-session walk state (current note + link direction).
state="$(mktemp -d "${TMPDIR:-/tmp}/llm-wiki-walk.XXXXXX")"
trap 'rm -rf "$state"' EXIT
printf '%s' "$start" > "$state/current"
printf 'fwd'         > "$state/mode"
: > "$state/history"
export WALK_STATE="$state" ZK_NOTEBOOK_DIR="$wiki"

# Walk. The header shows the current note (@ title) and the prompt shows the
# direction (→in / ←out); both are set up front and updated on every move, so the
# launch screen matches the post-move screens. The list reloads from state after
# each descend / back / flip.
"$self" __list | fzf \
  --ansi --delimiter='\t' --with-nth=2.. \
  --prompt='walk →in> ' \
  --header="$("$self" __header)" \
  --preview="\"$self\" __preview {1}" \
  --bind="enter:execute-silent(\"$self\" __descend {1})+reload(\"$self\" __list)+transform-header(\"$self\" __header)" \
  --bind="ctrl-b:execute-silent(\"$self\" __pop)+reload(\"$self\" __list)+transform-header(\"$self\" __header)" \
  --bind="ctrl-d:execute-silent(\"$self\" __toggle)+reload(\"$self\" __list)+transform-prompt(\"$self\" __prompt)" \
  --bind="ctrl-o:execute(\${EDITOR:-vi} \"$wiki\"/{1})" \
  >/dev/null || true
