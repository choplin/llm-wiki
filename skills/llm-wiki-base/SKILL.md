---
name: llm-wiki-base
description: >-
  Shared model for the llm-wiki skill family — a plain-Markdown knowledge base
  (KB) that an AI agent builds and maintains through the zk CLI over Bash. Owns
  the notebook location, the note model (slug filenames, wikilinks, a single
  reserved axis — Scope, a directory tree of concerns — with distill as the
  first-class process, archive as a location, and note kind left to free tags),
  the reach (pull-only query/traverse) command surface, and the gap-log habit.
  The deployable artifacts themselves (config.toml verb aliases, note template,
  walk.sh) and the setup script that installs them live in llm-wiki-init.
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

**This skill holds the model; llm-wiki-init holds the payload.** The deployable
artifacts — the zk `config.toml` (the verb `[alias]` block), the note template,
and the human-only `walk.sh` — are files under **llm-wiki-init**
(`assets/`, `scripts/`), and its `scripts/setup.sh` installs them into the
notebook. Every llm-wiki skill runs that setup first. It is **idempotent** (it
overwrites every artifact on each run, never diffs), so re-running is always
safe and is exactly how an existing notebook picks up new aliases after a
`git pull`.

```sh
# Resolve the llm-wiki-init skill's directory (the agent resolves it to wherever
# that skill is loaded from), then run setup. setup.sh self-locates its own
# assets, needs no other input, and prints the notebook path.
bash "$llm_wiki_init_dir/scripts/setup.sh"
wiki="${XDG_DATA_HOME:-$HOME/.local/share}/llm-wiki"   # for the verb calls below
```

The verbs it installs — `scan` / `find` / `show` / `links` / `tags` / `graph` /
`new` / `archive` / `reindex` / `walk` / `browse` / `help` — are documented in
**Verb surface** below (what each does, when to reach for it); their
implementation lives in `llm-wiki-init/assets/config.toml`.

Every operation below runs through a **verb**. Call one as
`zk -W "$wiki" <verb> [args]` — the `-W "$wiki"` targets this notebook and,
unlike a no-value global flag, does not break alias resolution. The verbs bake
in `--no-input` and (for `new`) `-p`, so those flags never appear at a call site
again.

> Setting up or updating llm-wiki as a deliberate act (first install, or a
> forced config refresh after pulling new skill versions) is the
> **llm-wiki-init** skill itself — invoke it directly instead of hand-running
> the script.

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
the base hardcodes the *abstraction*, not repo/project/branch.

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

### Enumerating the live structure

The structural truth is only **the directory tree + zk's computed index**:

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

# Human-only. Interactive fzf verbs — agents never use these (they read via
# `scan`/`links`); fzf is REQUIRED (no fzf → they error out, they do not degrade):
zk -W "$wiki" walk "<query>"                    # start from a note, walk links in fzf
zk -W "$wiki" browse                            # fzf-pick a note of the current concern (git-resolved from the caller's dir)
zk -W "$wiki" browse <scope>/                   # fzf-pick over an explicit scope (args forward to scan)

# Human discovery:
zk -W "$wiki" help                              # human verb reference + complete alias-list pointer
```

- `links` takes a **path**, not a title. Resolve a title to a path with
  `zk -W "$wiki" scan -m "<title>"` and read `.path` from its JSON.
- `walk` and `browse` are the only interactive verbs and the sole verbs that
  need a dependency beyond zk (fzf).
- `walk` is a thin wrapper over the bundled
  `llm-wiki-init/scripts/walk.sh`, installed into the notebook at `.zk/walk.sh` by
  setup. Keys:
  enter moves to the highlighted note keeping the current direction, ctrl-d flips
  the direction — advancing along this note's outbound links (labelled "in", →in)
  vs its backlinks (labelled "out", ←out), shown in the prompt — ctrl-o opens
  `$EDITOR`, esc quits; each list row appends the link-context snippet (the
  paragraph where the link occurs, dimmed) after the title, and the preview
  pane shows the highlighted target's body.
  Agents keep using `links` — walk is for a human browsing the KB by hand.
- `browse` is the human note picker: rows show title + `#tags` (+ dimmed
  snippet), so fzf's query narrows by title and tag alike (type `#raft` to bite
  on the tag). Enter prints the selected note's notebook-relative path, ctrl-o
  opens it in `$EDITOR`, the preview pane shows the body, esc quits. With no
  args it scopes to the **current concern**, falling back to the whole notebook
  when there is no repo or no matching scope directory; any args replace that
  default and forward to `scan`, so `browse global/` or
  `browse <scope>/ --tag raft` compose as usual. Agents keep using `scan` —
  browse is fzf-interactive.
  **Caveat worth knowing when writing any alias:** zk chdir's into the notebook
  before executing an alias, so inside one `$PWD` is the notebook, not the
  caller's directory — `browse` resolves the concern by running git against
  `$OLDPWD` (which zk's own `cd` sets to the caller's dir; it is not inherited
  from the caller's shell). Verified on zk 0.15.5.
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
