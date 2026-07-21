---
name: llm-wiki-base
description: >-
  Shared model for the llm-wiki skill family — a plain-Markdown knowledge base
  (KB) that an AI agent builds and maintains through the zk CLI over Bash. Owns
  the notebook location and one-time setup, the note model (slug filenames,
  wikilinks, a single reserved axis — Scope, a directory tree of concerns —
  with distill as the first-class process, archive as a location, and note kind
  left to free tags), the reach (pull-only query/traverse) command surface, and
  the gap-log habit.
  llm-wiki-capture / -retrieve / -distill / -overview delegate here to resolve
  the notebook and apply the model before reading or writing. Use this skill when
  another llm-wiki skill asks to resolve the notebook or apply the KB model. Not
  typically invoked on its own.
---

# llm-wiki — Shared Model

llm-wiki is a **plain-Markdown knowledge base an AI agent operates via the
[zk](https://github.com/zk-org/zk) CLI**. The agent is the primary reader and
writer; there is no GUI in the loop. The KB is an explicit, visible,
git-versionable asset — retention is exactly what is written to files.

The KB is a **vessel**, judged by three properties:

- **Doesn't scatter** — every note lives in its concern's scope directory and
  links to related notes.
- **Doesn't bloat** — notes are continuously distilled (consolidated, refreshed,
  split), not hoarded; retired material is archived out of reach; no
  hand-maintained index that duplicates what zk computes live.
- **Holds everything needed** — the container stays general; nothing needed is
  excluded (even disposable notes live here, and are distilled or pruned later).

**Scope boundary — reach, not surface.** llm-wiki provides the means to *reach*
the right note on demand (query + link traversal). It does **not** decide *when*
to recall or proactively *surface* notes — that is the memory layer's job.
llm-wiki is pulled; it never pushes.

## Notebook Location & Setup (MUST run before any read/write)

The notebook is a single zk notebook at:

```sh
wiki="${XDG_DATA_HOME:-$HOME/.local/share}/llm-wiki"
```

Every llm-wiki skill runs this setup first. It is idempotent — safe to re-run.
Before running it, set `llm_wiki_base_dir` to this (llm-wiki-base) skill's own
directory — setup installs the bundled `scripts/walk.sh` (the human `walk` verb)
into the notebook from there.

```sh
wiki="${XDG_DATA_HOME:-$HOME/.local/share}/llm-wiki"
if [ ! -d "$wiki/.zk" ]; then
  mkdir -p "$wiki"
  zk --no-input init "$wiki" >/dev/null
fi
# The config and template are skill-owned and fully generated, so (re)write them
# on EVERY setup — not just first init — so existing notebooks pick up changes
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
# mechanics (see "Verb surface" below): every skill routes its reads/maintenance
# through a verb, never a raw `zk list …`/`index` again. Invoke a verb as
# `zk -W "$wiki" <verb>` (the operation skills call them this way); note that a
# *no-value* global flag before the verb name breaks zk's alias resolution
# (`zk --no-input find …` fails), so each verb bakes `--no-input` inside
# instead. Verified on zk 0.15.5.
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
TOML
# Template: {{content}} is required so `zk new -i` can pipe a body in via stdin.
# Frontmatter carries the distill footprint (see "Note Model"): created/updated
# start at today, distilled empty (= never distilled), distill_count 0. tags
# starts empty — capture adds free topical tags, never a maturity state.
printf -- '---\ntitle: {{title}}\ncreated: {{format-date now "%%Y-%%m-%%d"}}\nupdated: {{format-date now "%%Y-%%m-%%d"}}\ndistilled:\ndistill_count: 0\ntags: []\n---\n\n{{content}}\n' \
  > "$wiki/.zk/templates/default.md"
# Install the human-only `walk` script into the notebook so `zk -W "$wiki" walk`
# is self-contained — the notebook carries its own copy, so a human can run it
# from any checkout. Source of truth: this skill's scripts/walk.sh; like the
# config and template it is (re)installed on EVERY setup. `$llm_wiki_base_dir`
# is THIS (llm-wiki-base) skill's own directory — set it before running setup
# (the agent resolves it to wherever this skill is loaded from, the same way
# inception-base references its scripts/inception.sh).
: "${llm_wiki_base_dir:?set llm_wiki_base_dir to the llm-wiki-base skill directory}"
install -m 0755 "$llm_wiki_base_dir/scripts/walk.sh" "$wiki/.zk/walk.sh"
```

Every operation below runs through a **verb** (see the `[alias]` block above and
the **Verb surface** section). Call one as `zk -W "$wiki" <verb> [args]` — the
`-W "$wiki"` targets this notebook and, unlike a no-value global flag, does not
break alias resolution. The verbs bake in `--no-input` and (for `new`) `-p`, so
those flags never appear at a call site again.

## Note Model

The base reserves **exactly one axis**; everything else is a free layer the
operation decides. There is **no lifecycle / maturity state**: what keeps the KB
high-signal is not a status tag but **distill — the first-class process** that
continuously reworks notes (see below), leaving its footprint in frontmatter.

> **Reserved:** **Scope** (which concern a note belongs to).
> **Free:** wikilinks, and domain/topic tags. The base holds **no `kind`
> vocabulary** — a note's "kind" (decision, PRD, concept, …) is at most a free
> topical tag a caller may add, never a reserved axis.

Tools for relating notes, strongest first: **Scope** (a structured single home) >
explicit **wikilink** (directed, specific) > **domain tag** (free, loose
many-to-many association).

### The reserved axis — Scope = the tree of concerns (a directory tree)

A note lives under the **concern** it belongs to. Concerns form a single-parent
forest, and **the directory tree *is* that forest — it is the source of truth**,
not a registry or a set of root notes.

- **permanent concern** — open-ended, stands alone. Dev: a repo. Non-dev: a life
  domain (`investment`, `kakeibo`). These are the roots of the forest.
- **bounded concern** — time-boxed, eventually closes. Dev: a project or branch.
  Its parent ∈ {a permanent concern, another bounded concern, none}, and it nests
  under that parent's directory.
- **`global`** — belongs to no concern (root-less, cross-cutting knowledge).

Dev (repo / project / branch) is just **one instantiation** of this abstraction;
the base hardcodes the *abstraction*, not repo/project/branch. (The Repo/Project
split already latent in the tracker is the same abstraction — a permanent-concern
axis and a bounded-concern axis — named here, not newly invented.)

**The tree carries the structure — no stored metadata:**

- Enumerating the directories **is** the live list of active concerns. There is
  **no maintained structural meta** (no root note, no registry, no index file).
- **`status` is not stored:** a directory that exists = the concern is open; a
  directory that is gone = closed.
- **`kind` (permanent vs bounded) is not stored:** *position* says it — a root
  directory is a domain, a nested directory is an endeavour. The only thing given
  up is `kind` *enforcement* (nothing gates mis-closing a permanent concern);
  closing is a deliberate external act, so convention suffices.

Resolve the current concern and drop into it (the dev path — via git):

```sh
# repo-name is stable across worktrees (from the shared git dir, not the checkout path)
common_dir=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null) &&
  scope=$(basename "$(dirname "$common_dir")") || scope="global"
mkdir -p "$wiki/$scope"   # `zk new <dir>` does NOT create the directory itself
```

- Repo-specific notes → `<repo-name>/`. A bounded concern under a repo (e.g. a
  branch) → `<repo-name>/<bounded>/`. Cross-cutting, concern-less → `global/`.
- **Capture is dumb:** it drops a note into *the current concern*, `mkdir -p` on
  demand, with **zero classification and no maturity state**. "This is actually
  a broader idea" is deferred to distill — never decided at capture time.
- Non-dev / cross-cutting work has no automatic source, so the **agent proposes** a
  concern name from the session's context and **confirms it with the user** before
  dropping the note, then `mkdir -p "$wiki/<concern>"`. This stays within "capture is
  dumb": it resolves a *locator* (which concern), never a *kind*. Auto when git makes
  it free; propose-and-confirm otherwise.

### Distill — the first-class process (not a state)

Why no lifecycle: the writer is an AI, so notes are born reasonably shaped — a
raw→clean maturity ladder (fleeting→active) does not match how the KB is used.
What keeps the KB high-signal is the *process* of reworking notes, so the base
defines **distill** as its first-class citizen: a set of purpose-specific
primitives, run when judged useful (no on-save trigger).

| Primitive | Purpose |
|-----------|---------|
| `consolidate` | Merge notes covering the same thing; absorb orphans; resolve duplication. Source notes are always deleted (history lives in git). |
| `refresh` | Revisit notes `distilled` least recently; update or confirm them. |
| `split` | Break an oversized note into linked, self-contained notes. Source note is always deleted. |

*When to run which, and on what* — by tag, time cohort, orphans, staleness,
size, contradiction — is an **operating judgment made at run time, not a flow**:
the strategies are just different inputs to the same primitives. The judgment
layer lives in **llm-wiki-distill**; the semantics above are the base model.

**The distill footprint (frontmatter).** Every note carries
`created` / `updated` / `distilled` / `distill_count`, seeded by the template.
The update contract:

- Editing a note's content → set `updated` to today.
- A distill primitive reworking the note → also set `distilled` to today and
  increment `distill_count`.
- `created` is written once at creation, never touched again.

zk cannot filter or sort on custom frontmatter fields (`--created`/`--modified`
read filesystem timestamps, not frontmatter) — they surface in `.metadata` of
`zk list -f json`, so footprint-based selection runs through `scan` + jq (the
`scan` verb emits `updated`/`distilled`/`distill_count` for exactly this).

### Archive — retirement is a location, not a tag

A note that no longer earns reach (inaccurate, replaced, or kept back from a
closed concern) is **moved to the root `_archived/` directory, preserving its
scope path**: `<scope>/note.md` → `_archived/<scope>/note.md` — the `archive`
verb does this. The old `superseded`/`retired` states collapse into this one
mechanism; a replaced note's successor is expressed by a **wikilink** in the
archived note, not by a tag.

- Archived notes **stay in the index** — slug wikilinks pointing at them keep
  resolving (links only break when a note leaves the index; `ignore` is not
  used for archive precisely because ignore cannot be opted back in).
- Reach and aggregate verbs exclude `_archived/` **by default** via the baked
  `-x '_archived'` filter; set `LLM_WIKI_INCLUDE_ARCHIVED=1` to include it.
  Root collection is load-bearing: `-x` matches a literal path prefix only (no
  globs), so one root directory is the only shape the exclusion can cover.
- **Boundary — no external completion tracking.** llm-wiki does **not** observe
  "the project/branch finished". It holds only the locator (Scope); an external
  actor that knows a concern is done drives closure (see close-concern). This
  is "reach not surface / pulled, never push": durable vs bounded is a *Scope*
  fact (which concern), never a stored status.

### close-concern (composite: when a bounded concern ends)

When a **bounded** concern closes, its directory must not be left as a dead
label. Every note in it gets a **positive keep decision** — one of:

1. **Distill up** — rework it (via the primitives) into the **parent** concern:
   the permanent concern above it, the parent bounded concern, or `global` if
   none.
2. **Archive** — keep it reachable-on-request at `_archived/<scope path>/`.

Whatever is not positively kept **disappears with the directory** — removing
the emptied directory *is* the deletion; there is no separate prune step, and
the directory being gone *is* the closed status. This is the general form of
Zettelkasten's "tidy project notes at project end; survivors become permanent."
The **semantics** live here; the drive procedure belongs to llm-wiki-distill
(see Delegation), not to the base.

### How the old five prefixes are absorbed (no kind tag)

The retired `project-notes` prefixes map onto **Scope alone** — none becomes a
base `kind` tag:

| Old prefix | Now |
|-----|-----|
| `Concept` | A note in a **permanent** concern (a repo, or `global`). No kind tag. |
| `Decision` / `Proposal` / `Handoff` | A note in whatever concern it arose in (usually **bounded**); distilled up on close. No kind tag. |
| `PRD` | A note in its project (bounded) / repo scope. The inception-finalize PRD slot is settled separately; the frame is "PRD is one note in its scope, `prd` is a free tag if applied." |

Want to slice by "all decisions" or "all PRDs"? That is a **free domain tag**,
added by an operation when useful — never a reserved axis.

### Self-contained without Linear (or any tracker)

The structural truth is only **the directory tree + zk's computed index**. No
external tracker is needed for llm-wiki to stand on its own:

```sh
ls -d "$wiki"/*/          # the live scope list (enumerated concerns)
zk -W "$wiki" tags        # the live keyword index (JSONL)
```

### Filenames & links (verified zk behavior — do not deviate)

- `filename = {{slug title}}` → a note titled "Raft leader election" becomes
  `raft-leader-election.md`.
- **zk resolves wikilinks by filename/path, never by title.** Link with the
  **slug**: `[[raft-leader-election]]` (same scope) or the path
  `[[global/cap-theorem]]` (cross-scope). `[[Raft leader election]]` (natural
  title) is a **broken link** — never use that form.
- **No rename safety.** Changing a note's title changes its slug and breaks
  inbound `[[slug]]` links — this is a known zk gap (log it, see below).

## Verb surface — the one command surface

Every KB read and every mechanical write/maintenance runs through a **verb** (the
`[alias]` block written at Setup). The verbs are the **single source of truth** for
these mechanics — no skill inlines a raw `zk list …` / `index` again.
Call one as `zk -W "$wiki" <verb> [args]`; read verbs emit JSON so the agent can
parse them (`find` is the human-readable presenter over `scan`). Reads stay
**pull-only** — reaching a note, never surfacing one. Reach and aggregate verbs
(`scan`/`find`/`show`/`links`/`tags`/`graph`) exclude the root `_archived/`
directory by default; prefix a call with `LLM_WIKI_INCLUDE_ARCHIVED=1` to
include archived notes.

```sh
# Reach a note (read-only). `scan` is the workhorse; extra args forward to zk list:
zk -W "$wiki" scan -m "<query>"                # compact JSON {title,tags,path,snippet,updated,distilled,distill_count}
zk -W "$wiki" scan --tag <tag>                 # enter by topic tag
zk -W "$wiki" scan <scope>/ -m "<query>"       # narrow to one concern's directory
zk -W "$wiki" scan --orphan                    # unlinked notes (--tagless for no-tag)
zk -W "$wiki" show "<query>"                    # full body of the matches
zk -W "$wiki" links "<path>"                    # inbound then outbound links, JSON (arg is a PATH)
zk -W "$wiki" links "<path>" --recursive --max-distance 2   # traverse the graph
zk -W "$wiki" tags                              # the live keyword index (JSONL {name,count})
zk -W "$wiki" graph                             # whole-notebook link graph (JSON)
LLM_WIKI_INCLUDE_ARCHIVED=1 zk -W "$wiki" scan -m "<query>"   # opt in to archived notes (any verb)

# Write / maintenance. The prescribed flags (-i -p, >/dev/null) are baked in:
printf '%s' "<body>" | zk -W "$wiki" new "<scope>" --title "<Title>"   # create; prints path
zk -W "$wiki" archive "<scope>/<slug>.md" …     # retire: move to _archived/<scope>/, reindex
zk -W "$wiki" reindex                           # after any write / move / delete

# Human-only. Interactive fzf link walker — agents never use this (they traverse
# with `links`); fzf is REQUIRED (no fzf → walk errors out, it does not degrade):
zk -W "$wiki" walk "<query>"                    # start from a note, walk links in fzf
```

- `links` takes a **path**, not a title. Resolve a title to a path with
  `zk -W "$wiki" scan -m "<title>"` and read `.path` from its JSON.
- `walk` is the **only human-CLI-facing verb** and the sole verb that needs a
  dependency beyond zk (fzf). It is a thin wrapper over the bundled
  `scripts/walk.sh`, installed into the notebook at `.zk/walk.sh` by Setup. Keys:
  enter moves to the highlighted note keeping the current direction, ctrl-d flips
  the direction — advancing along this note's outbound links (labelled "in", →in)
  vs its backlinks (labelled "out", ←out), shown in the prompt — ctrl-o opens
  `$EDITOR`, esc quits; each list row appends the link-context snippet (the
  paragraph where the link occurs, dimmed) after the title, and the preview
  pane shows the highlighted target's body.
  Agents keep using `links` — walk is for a human browsing the KB by hand.
- The verbs carry the *mechanics*; each operation skill adds only the *judgment*
  (when/why to capture, distill, consolidate, or surface a note).

## Gap Log

This whole configuration is also a test: *is zk + conventions enough, or is
there a real gap that would justify custom tooling?* Whenever zk or these
conventions are awkward (rename churn, no merge/consolidate command, overview
gaps), append to the gap log — do not silently work around it:

```sh
printf -- '- %s — <what was awkward> — <what would have helped>\n' "$(date +%F)" \
  >> "$wiki/_gaps.md"
```

`_gaps.md` and any other plumbing note (a home/index, a scratch hub) are kept out
of reach noise by the **`_`-prefixed filename convention** — the
`ignore = ["**/_*.md"]` set at Setup drops every `_*.md` (at any depth) from the
index and from reach. Name any structural or plumbing file `_<name>.md`; no marker
tag is needed.

## Delegation

Other llm-wiki skills apply this skill first (run Setup + resolve `$scope`),
then do their half:

- **llm-wiki-capture** — drop a note into the current concern (no maturity
  state), link it in.
- **llm-wiki-retrieve** — reach notes on demand via the command surface above.
- **llm-wiki-distill** — run the distill primitives (consolidate / refresh /
  split), archive retired notes, drive close-concern when a bounded concern
  ends.
- **llm-wiki-overview** — synthesize a bird's-eye view from the graph/tags, and
  keep any curated hub / front-door note (an optional consumer-layer structure,
  named `_*.md` so it stays out of reach — not a reserved axis).

If `zk` is not on PATH, stop and tell the user to install it
(`brew install zk` / see the zk repo) — it is an essential, irreplaceable
capability for this family.
