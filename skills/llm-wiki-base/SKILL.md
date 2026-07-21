---
name: llm-wiki-base
description: >-
  Shared model for the llm-wiki skill family — a plain-Markdown knowledge base
  (KB) that an AI agent builds and maintains through the zk CLI over Bash. Owns
  the notebook location and one-time setup, the note model (slug filenames,
  wikilinks, and two reserved axes — Scope, a directory tree of concerns, and an
  internal Lifecycle — with note kind left to free tags), the reach (pull-only
  query/traverse) command surface, and the gap-log habit.
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

- **Doesn't scatter** — every note carries a lifecycle tag, lives in its
  concern's scope directory, and links to related notes.
- **Doesn't bloat** — fleeting notes are distilled, not hoarded; duplicates are
  consolidated; no hand-maintained index that duplicates what zk computes live.
- **Holds everything needed** — the container stays general; nothing needed is
  excluded (even disposable notes live here, tagged, and are pruned later).

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
# reach-exclusion mechanism. `**/_*.md` matches root and nested alike (a bare
# `_*.md` would only match the notebook root). The [alias] block bakes in the
# zk verbs — the single source of truth for KB mechanics (see "Verb surface"
# below): every skill routes its reads/maintenance through a verb, never a raw
# `zk list …`/`tag list`/`index` again. Invoke a verb as `zk -W "$wiki" <verb>`
# (the operation skills call them this way); note that a *no-value* global flag
# before the verb name breaks zk's alias resolution (`zk --no-input find …`
# fails), so each verb bakes `--no-input` inside instead. Verified on zk 0.15.5.
cat > "$wiki/.zk/config.toml" <<'TOML'
[note]
filename = "{{slug title}}"
template = "default.md"
ignore = ["**/_*.md"]
[format.markdown]
link-format = "wiki"
hashtags = true
[filter]
fleeting = "--tag fleeting"
active = "--tag active"
[alias]
# Verbs = the one place KB mechanics live. Read verbs emit JSON as the canonical
# machine surface (agents parse it); `find` is the thin human presenter over
# `scan`. Every verb forwards extra args to the underlying zk command, so
# filters compose: `scan --tag active`, `scan <scope>/ --match x`,
# `scan --orphan`, `links <path> --recursive --max-distance 2`.
#   scan  [filters…]      — compact JSON map {title,tags,path,snippet}; the
#                           workhorse behind every "reach a note" read
#   find  <query>         — human-readable presenter over `scan --match`
#   show  <query>         — full note (title, tags, body) for full-text matches
#   links <path> [flags]  — inbound then outbound links of <path> as JSON;
#                           snippet = the paragraph(s) around the link in the
#                           source note, i.e. why the two notes connect
#   tags                  — the keyword index (JSON)
#   graph                 — the whole-notebook link graph (JSON)
#   new   <scope> [flags] — create a note: body from stdin (-i), print path (-p)
#   reindex               — refresh the index after writes/moves
#   walk  <query>         — HUMAN-ONLY interactive fzf link walker (needs fzf).
#                           Agents never use this; they traverse via `links`.
#                           Runs the bundled script installed at .zk/walk.sh.
scan  = 'zk --no-input list --quiet "$@" -f json | jq -c ".[] | {title, tags: .metadata.tags, path, snippet: (.body[0:120])}"'
find  = 'zk scan --match "$*" | jq -r "[.title, (.tags | map(\"#\"+.) | join(\" \")), .snippet] | join(\"  \")"'
show  = 'zk --no-input list --quiet --match "$*" --format full'
links = 'p="$1"; shift; { zk --no-input list --quiet --link-to "$p" "$@" -f json | jq -c ".[] | {dir:\"in\", title, path, snippet: ((.snippets // []) | join(\" … \"))}"; zk --no-input list --quiet --linked-by "$p" "$@" -f json | jq -c ".[] | {dir:\"out\", title, path, snippet: ((.snippets // []) | join(\" … \"))}"; }'
tags  = 'zk --no-input tag list -f json --quiet'
graph = 'zk --no-input graph --format json --quiet'
new     = 'zk --no-input new "$@" -i -p'
reindex = 'zk --no-input index'
walk    = 'bash "$ZK_NOTEBOOK_DIR/.zk/walk.sh" "$@"'
TOML
# Template: {{content}} is required so `zk new -i` can pipe a body in via stdin.
printf -- '---\ntitle: {{title}}\ncreated: {{format-date now "%%Y-%%m-%%d"}}\ntags: [fleeting]\n---\n\n{{content}}\n' \
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

The base reserves **exactly two axes**; everything else is a free layer the
operation decides.

> **Reserved:** **Scope** (which concern a note belongs to) and its internal
> **Lifecycle** (its curation state).
> **Free:** wikilinks, and domain/topic tags. The base holds **no `kind`
> vocabulary** — a note's "kind" (decision, PRD, concept, …) is at most a free
> topical tag a caller may add, never a reserved axis.

Tools for relating notes, strongest first: **Scope** (a structured single home) >
explicit **wikilink** (directed, specific) > **domain tag** (free, loose
many-to-many association).

### Axis 1 — Scope = the tree of concerns (a directory tree)

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
- **Capture is dumb:** it drops a `fleeting` note into *the current concern*,
  `mkdir -p` on demand, with **zero classification**. "This is actually a broader
  idea" is deferred to distill — never decided at capture time.
- Non-dev / cross-cutting work has no automatic source, so the **agent proposes** a
  concern name from the session's context and **confirms it with the user** before
  dropping the note, then `mkdir -p "$wiki/<concern>"`. This stays within "capture is
  dumb": it resolves a *locator* (which concern), never a *kind*. Auto when git makes
  it free; propose-and-confirm otherwise.

### Axis 2 — internal Lifecycle (curation state)

A note's maturity **inside the KB**, driven only by KB operations — expressed as a
single **lifecycle tag** (zk filters tags natively; `fleeting` already is one):

| Tag | Meaning |
|-----|---------|
| `fleeting` | Raw, disposable capture — the only entry point. Distilled or deleted later. |
| `active` | Distilled — shaped, stands on its own, the live durable layer. |
| `superseded` | Replaced by another note (link to the replacement). |
| `retired` | No longer accurate; kept for history, out of reach by default. |

- A source-derived note ("literature") is **not** a lifecycle state — it is an
  `active` note that carries a source link/reference.
- **Boundary — no external completion tracking.** llm-wiki does **not** observe
  "the project/branch finished". It holds only the locator (Scope); an external
  actor that knows a concern is done drives closure (see distill-up-on-close). This
  is "reach not surface / pulled, never push" applied to lifecycle: durable vs
  bounded is a *Scope* fact (which concern), not a maturity tag.

### distill-up-on-close (the sole time-boxed → open-ended promotion)

When a **bounded** concern closes, its directory must not be left as a dead label:

1. **Distill keepers up** — promote the notes worth keeping into the **parent**
   concern (a permanent concern, the parent bounded concern, or `global` if none).
2. **Prune the rest** — delete what was disposable.
3. **Empty the directory** — a closed concern's directory disappears (status = gone).

This is the one path from a time-boxed concern to an open-ended one — the general
form of Zettelkasten's "tidy project notes at project end; survivors become
permanent." The operation's **semantics** live here; its verb/command surface
belongs to the operation skills (see Delegation), not to the base.

### How the old five prefixes are absorbed (no kind tag)

The retired `project-notes` prefixes map onto **Scope + Lifecycle alone** — none
becomes a base `kind` tag:

| Old prefix | Now |
|-----|-----|
| `Concept` | A note in a **permanent** concern (a repo, or `global`). No kind tag. |
| `Decision` / `Proposal` / `Handoff` | A note in whatever concern it arose in (usually **bounded**); promoted up on close. No kind tag. |
| `PRD` | A note in its project (bounded) / repo scope. The inception-finalize PRD slot is settled separately; the frame is "PRD is one note in its scope, `prd` is a free tag if applied." |

Want to slice by "all decisions" or "all PRDs"? That is a **free domain tag**,
added by an operation when useful — never a reserved axis.

### Self-contained without Linear (or any tracker)

The structural truth is only **the directory tree + zk's computed index**. No
external tracker is needed for llm-wiki to stand on its own:

```sh
ls -d "$wiki"/*/          # the live scope list (enumerated concerns)
zk -W "$wiki" tags        # the live keyword + lifecycle index (JSON)
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
these mechanics — no skill inlines a raw `zk list …` / `tag list` / `index` again.
Call one as `zk -W "$wiki" <verb> [args]`; read verbs emit JSON so the agent can
parse them (`find` is the human-readable presenter over `scan`). Reads stay
**pull-only** — reaching a note, never surfacing one.

```sh
# Reach a note (read-only). `scan` is the workhorse; extra args forward to zk list:
zk -W "$wiki" scan -m "<query>"                # compact JSON {title,tags,path,snippet}
zk -W "$wiki" scan --tag <tag>                 # enter by lifecycle/topic tag
zk -W "$wiki" scan <scope>/ -m "<query>"       # narrow to one concern's directory
zk -W "$wiki" scan --orphan                    # unlinked notes (--tagless for no-tag)
zk -W "$wiki" show "<query>"                    # full body of the matches
zk -W "$wiki" links "<path>"                    # inbound then outbound links, JSON (arg is a PATH)
zk -W "$wiki" links "<path>" --recursive --max-distance 2   # traverse the graph
zk -W "$wiki" tags                              # the live keyword + lifecycle index (JSON)
zk -W "$wiki" graph                             # whole-notebook link graph (JSON)

# Write / maintenance. The prescribed flags (-i -p, >/dev/null) are baked in:
printf '%s' "<body>" | zk -W "$wiki" new "<scope>" --title "<Title>"   # create; prints path
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

- **llm-wiki-capture** — drop a `fleeting` note into the current concern, link it in.
- **llm-wiki-retrieve** — reach notes on demand via the command surface above.
- **llm-wiki-distill** — promote `fleeting` → `active`, run distill-up-on-close
  when a bounded concern ends, consolidate duplicates.
- **llm-wiki-overview** — synthesize a bird's-eye view from the graph/tags, and
  keep any curated hub / front-door note (an optional consumer-layer structure,
  named `_*.md` so it stays out of reach — not a reserved axis).

If `zk` is not on PATH, stop and tell the user to install it
(`brew install zk` / see the zk repo) — it is an essential, irreplaceable
capability for this family.
