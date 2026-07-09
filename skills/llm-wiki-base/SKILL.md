---
name: llm-wiki-base
description: >-
  Shared model for the llm-wiki skill family — a plain-Markdown knowledge base
  (KB) that an AI agent builds and maintains through the zk CLI over Bash. Owns
  the notebook location and one-time setup, the note model (slug filenames,
  wikilinks, type tags fleeting/permanent/project/moc, per-repo directory scope),
  the reach (pull-only query/traverse) command surface, and the gap-log habit.
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

- **Doesn't scatter** — every note carries a type tag and topical tags, lives in
  a scope directory, and links to related notes.
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

```sh
wiki="${XDG_DATA_HOME:-$HOME/.local/share}/llm-wiki"
if [ ! -d "$wiki/.zk" ]; then
  mkdir -p "$wiki"
  zk --no-input init "$wiki" >/dev/null
  # Config: slug filenames (so [[slug]] wikilinks resolve), wiki links, hashtags.
  cat > "$wiki/.zk/config.toml" <<'TOML'
[note]
filename = "{{slug title}}"
template = "default.md"
[format.markdown]
link-format = "wiki"
hashtags = true
[filter]
fleeting = "--tag fleeting"
TOML
  # Template: {{content}} is required so `zk new -i` can pipe a body in via stdin.
  printf -- '---\ntitle: {{title}}\ncreated: {{format-date now "%%Y-%%m-%%d"}}\ntags: [fleeting]\n---\n\n{{content}}\n' \
    > "$wiki/.zk/templates/default.md"
fi
```

All `zk` commands below assume `-W "$wiki"` (run as if started in the notebook)
or `cd "$wiki"` first. Always pass `--no-input`, and `-p` on `zk new` (the agent
has no interactive editor — `-p` prints the path instead of opening one).

## Note Model

### Scope = directory (per repo)

Each note lives in a **scope directory**, resolved at run time — no symlink, no
config `[group]` needed (a plain subdirectory partitions the notebook):

```sh
# repo-name is stable across worktrees (from the shared git dir, not the checkout path)
common_dir=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null) &&
  scope=$(basename "$(dirname "$common_dir")") || scope="global"
mkdir -p "$wiki/$scope"   # `zk new <dir>` does NOT create the directory itself
```

- Repo-specific notes → `<repo-name>/`. Cross-cutting, repo-independent
  knowledge → `global/`.

### Type tags

Maturity and kind are expressed as **tags** (zk filters tags natively), not
folders:

| Tag | Meaning |
|-----|---------|
| `fleeting` | Raw, disposable capture — the only entry point. Distilled or deleted later. |
| `permanent` | A distilled, self-contained, reusable atomic idea (may be cross-project). |
| `project` | Durable project-specific record (decision, state, PRD, handoff). Not claimed reusable. |
| `moc` | A Map of Content — a curated structure/hub note over a theme (see llm-wiki-overview). |

- A source-derived note ("literature") is **not** a type — it is a `permanent`
  or `project` note that carries a source link/reference.
- `transient` marks a disposable session-continuity note (absorbed here, tagged,
  excluded from reach by the caller, pruned after use).

### Filenames & links (verified zk behavior — do not deviate)

- `filename = {{slug title}}` → a note titled "Raft leader election" becomes
  `raft-leader-election.md`.
- **zk resolves wikilinks by filename/path, never by title.** Link with the
  **slug**: `[[raft-leader-election]]` (same scope) or the path
  `[[global/cap-theorem]]` (cross-scope). `[[Raft leader election]]` (natural
  title) is a **broken link** — never use that form.
- **No rename safety.** Changing a note's title changes its slug and breaks
  inbound `[[slug]]` links — this is a known zk gap (log it, see below).

## Reach — the pull-only command surface

Used by llm-wiki-retrieve; available to any skill. All read-only.

```sh
# Cheap scan: title + tags + path + snippet as JSON (never dump full bodies first)
zk -W "$wiki" list -m "<query>" -f json --quiet |
  jq -c '.[] | {title, tags: .metadata.tags, path, snippet: (.body[0:120])}'

zk -W "$wiki" list --tag <tag> -f '{{title}}' --quiet     # enter by type/topic
zk -W "$wiki" tag list -f json --quiet                     # the live keyword index
zk -W "$wiki" list --link-to  <path> -f '{{title}}' --quiet  # inbound (backlinks)  — arg is a PATH
zk -W "$wiki" list --linked-by <path> -f '{{title}}' --quiet # outbound
zk -W "$wiki" list --link-to <path> --recursive --max-distance 2  # traverse the graph
zk -W "$wiki" graph --format json                          # whole-notebook overview
```

- `--link-to` / `--linked-by` take a **path**, not a title. Resolve a title to a
  path first with `zk list -m "<title>" -f '{{path}}' --quiet`.

## Gap Log

This whole configuration is also a test: *is zk + conventions enough, or is
there a real gap that would justify custom tooling?* Whenever zk or these
conventions are awkward (rename churn, no merge/consolidate command, overview
gaps), append to the gap log — do not silently work around it:

```sh
printf -- '- %s — <what was awkward> — <what would have helped>\n' "$(date +%F)" \
  >> "$wiki/_gaps.md"
```

Keep `_gaps.md` and any home/index note out of reach noise by tagging structure
notes (`moc`) and leaving `_gaps.md` untagged.

## Delegation

Other llm-wiki skills apply this skill first (run Setup + resolve `$scope`),
then do their half:

- **llm-wiki-capture** — write a note (default `fleeting`), link it in.
- **llm-wiki-retrieve** — reach notes on demand via the command surface above.
- **llm-wiki-distill** — promote `fleeting` → `permanent`/`project`/`moc`,
  consolidate duplicates.
- **llm-wiki-overview** — maintain `moc` hubs and the single home/index note.

If `zk` is not on PATH, stop and tell the user to install it
(`brew install zk` / see the zk repo) — it is an essential, irreplaceable
capability for this family.
