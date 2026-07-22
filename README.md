# llm-wiki

> Super tiny LLM wiki — no engine, just zk.

[Karpathy's LLM Wiki](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f)
— a wiki an LLM keeps for itself — has inspired plenty of implementations,
and many of them ship an engine: a desktop app, a backend, a web UI for the
human and an MCP server for the agent. This one is five skill files and a
[zk](https://github.com/zk-org/zk) notebook:

- **No engine.** The KB is a plain-Markdown zk notebook — notes are files,
  retention is exactly what is written to them, and everything is
  git-versionable. The skills add only judgment (when and why to write,
  rework, or reach); every mechanic is a zk verb.
- **One verb set, no drift.** Because the agent drives the same mature CLI a
  human uses, there is no split between a human GUI and an agent API — both
  entrances share the identical zk verbs, so there is no second
  implementation to fall out of sync.
- **Distill, not just lint.** Health checks (broken links, orphans) are table
  stakes; the hard problem is the knowledge *lifecycle*. Here capture is a
  dumb, friction-free drop, and a first-class **distill** process —
  consolidate / refresh / split, each leaving a footprint in frontmatter —
  keeps the KB high-signal, with retired notes archived out of reach instead
  of deleted.

## Quick start

**Requirements:** [zk](https://github.com/zk-org/zk) (`brew install zk`) —
required for everything. [fzf](https://github.com/junegunn/fzf) — only for the
interactive `walk` command; everything else works without it.

Install the skills with the
[`vercel-labs/skills`](https://github.com/vercel-labs/skills) CLI (works for
Claude Code, Codex, Cursor, and 70+ agents — `-a` takes the agent id):

```bash
skills add choplin/llm-wiki --skill '*' -a claude-code -g -y
```

Then just talk to your agent:

> "capture this into the wiki" — writes the finding as a linked, tagged note
> "what does the wiki know about X?" — reaches the right notes, cheaply
> "distill the wiki" — consolidates duplicates, refreshes stale notes

The notebook is created on first use at
`${XDG_DATA_HOME:-$HOME/.local/share}/llm-wiki/`. Browse it yourself any time
— same notebook, same verbs:

```bash
wiki="${XDG_DATA_HOME:-$HOME/.local/share}/llm-wiki"
zk -W "$wiki" find "raft"      # human-readable search: title · tags · snippet
zk -W "$wiki" walk "raft"      # interactive fzf link walker
```

## How it works

**Notes are scoped, not filed.** Every note lives in the directory of the
*concern* it belongs to — a repo (`<repo-name>/`), a bounded effort nested
under it, or `global/` for cross-cutting knowledge. The directory tree is the
whole structure: no registry, no index files, no status fields. Notes relate
through `[[wikilinks]]` and free topic tags on top of that.

**No maturity states.** There is no fleeting→permanent ladder to manage.
Instead each note carries a distill footprint in frontmatter
(`created` / `updated` / `distilled` / `distill_count`), and the distill
process works the notes that need it — merging duplicates, revisiting the
stalest, splitting the oversized.

**Retirement is a location.** Notes that no longer earn attention move to a
root `_archived/` directory. They stay linkable (nothing breaks), but every
query excludes them by default; set `LLM_WIKI_INCLUDE_ARCHIVED=1` to look at
history.

**Pull, never push.** llm-wiki answers "get me what the KB knows about X" —
it does not decide when to recall or proactively surface notes. That keeps it
a dependable substrate for whatever memory layer sits above it.

The full model and the reasoning behind it: [docs/note-model.md](docs/note-model.md).

## Skills (the agent entrance)

| Skill | Description |
|-------|-------------|
| `llm-wiki-init` | Provision or update the notebook config — the deliberate deploy step; idempotently (re)writes config, template, and the human verbs via `scripts/setup.sh` |
| `llm-wiki-capture` | Write a finding into the KB as a note (no classification, no maturity state), tagged and linked |
| `llm-wiki-retrieve` | Reach the right note(s) on demand — cheap scan → expand → traverse (pull-only) |
| `llm-wiki-distill` | Run the distill primitives (consolidate / refresh / split), archive retired notes, drive close-concern when a bounded concern ends |
| `llm-wiki-overview` | Overview a theme from the graph; keep any optional curated hub + front-door note |
| `llm-wiki-base` | Shared model the other skills delegate to: notebook setup, note model, the verb command surface, gap-log |

## Human CLI reference

Run these against the notebook with `zk -W "$wiki" <verb> [args]`, where
`wiki="${XDG_DATA_HOME:-$HOME/.local/share}/llm-wiki"`. These are the same verbs
the skills use; `find` prints human-readable lines and `walk` is interactive.

| Verb | What it does |
|------|--------------|
| `find <query>` | Human-readable list of matching notes (title · tags · snippet). |
| `show <query>` | Full body (title, tags, text) of the matches. |
| `links <path>` | Inbound then outbound links of a note. The argument is a **path**, not a title; add `--recursive --max-distance N` to traverse the graph. |
| `tags` | The keyword index. |
| `walk <query>` | Interactive [fzf](https://github.com/junegunn/fzf) link walker — start from a note and browse its links by hand (**human-only**; agents traverse non-interactively with `links`). |
| `browse [filters…]` | Interactive [fzf](https://github.com/junegunn/fzf) note picker — narrow by title and `#tag` at once, enter prints the path, ctrl-o edits. No args scopes to the current repo's concern; args forward to `scan` (**human-only**; agents use `scan`). |

The remaining verbs are agent-facing: `scan` and `graph` return raw JSON (`find`
is the thin human presenter over `scan`), and `new` / `archive` / `reindex`
handle writes and maintenance. Retired notes live under a root `_archived/`
directory that every verb excludes by default — set
`LLM_WIKI_INCLUDE_ARCHIVED=1` to include them. See `llm-wiki-base` for the full
verb surface.

## Repository structure

```
skills/                  # portable, agent-agnostic Agent Skills
  llm-wiki-<name>/       #   flat, prefix-namespaced (no group layer — single group repo)
    SKILL.md
docs/                    # design / decision records
```

Skill names carry the `llm-wiki-` prefix because installs are flat by name
(no namespace mechanism in the Agent Skills standard or the skills CLI).
To install from a local checkout instead of the published repo:

```bash
skills add ./skills --skill '*' -a claude-code -g -y   # symlinks this working tree
```
