# llm-wiki

A plain-Markdown **knowledge base an AI agent builds and maintains**, operated
through the [zk](https://github.com/zk-org/zk) CLI over Bash. The agent is the
primary reader/writer; a human can also browse the same KB from the command line
(no GUI in the loop either way). Retention is exactly what is written to files:
explicit, visible, git-versionable.

The KB is a **vessel**: it doesn't scatter (scoped, lifecycle-tagged, linked), it
doesn't bloat (distill + consolidate, no hand-maintained indexes), and it holds
everything needed. It provides the means to **reach** notes on demand — it does
not decide *when* to recall or proactively surface them (that is the memory
layer's job).

The idea traces to [Karpathy's LLM Wiki](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f)
— a wiki an LLM keeps for itself.

## Two entrances, one verb set

llm-wiki has **two entrances that share the same zk verbs**. The verbs (an
`[alias]` block baked into the notebook's `config.toml` at setup) are the single
source of truth for KB mechanics, so both entrances drive identical operations —
there is no second implementation to drift:

- **Agent → the skills.** `capture` / `retrieve` / `distill` / `overview` (below)
  route every read and mechanical write through a verb and parse the JSON it
  emits. This is the primary path.
- **Human → the CLI.** A person browses the same notebook by hand with
  `zk -W "$wiki" <verb>`
  (`wiki="${XDG_DATA_HOME:-$HOME/.local/share}/llm-wiki"`). `find` is the
  human-readable presenter and `walk` is an interactive link browser (see
  [Human CLI reference](#human-cli-reference)).

## Skills (the agent entrance)

| Skill | Description |
|-------|-------------|
| `llm-wiki-base` | Shared model: notebook setup, note model (slug filenames, wikilinks, two reserved axes — Scope tree of concerns + internal Lifecycle — with kind left to free tags), the verb command surface, gap-log (delegated, not invoked directly) |
| `llm-wiki-capture` | Write a finding into the KB as a `fleeting` note (no classification), tagged and linked |
| `llm-wiki-retrieve` | Reach the right note(s) on demand — cheap scan → expand → traverse (pull-only) |
| `llm-wiki-distill` | Promote `fleeting` → `active`, lift a closed concern's keepers up (distill-up-on-close), consolidate duplicates |
| `llm-wiki-overview` | Overview a theme from the graph; keep any optional curated hub + front-door note |

## Human CLI reference

Run these against the notebook with `zk -W "$wiki" <verb> [args]`, where
`wiki="${XDG_DATA_HOME:-$HOME/.local/share}/llm-wiki"`. These are the same verbs
the skills use; `find` prints human-readable lines and `walk` is interactive.

| Verb | What it does |
|------|--------------|
| `find <query>` | Human-readable list of matching notes (title · tags · snippet). |
| `show <query>` | Full body (title, tags, text) of the matches. |
| `links <path>` | Inbound then outbound links of a note. The argument is a **path**, not a title; add `--recursive --max-distance N` to traverse the graph. |
| `tags` | The keyword + lifecycle index. |
| `walk <query>` | Interactive [fzf](https://github.com/junegunn/fzf) link walker — start from a note and browse its links by hand (**human-only**; agents traverse non-interactively with `links`). |

The remaining verbs are agent-facing: `scan` and `graph` return raw JSON (`find`
is the thin human presenter over `scan`), and `new` / `reindex` handle writes and
maintenance. See `llm-wiki-base` for the full verb surface.

## Dependencies

- **`zk` — required for all of llm-wiki** (`brew install zk`, or see the
  [zk repo](https://github.com/zk-org/zk)). It is an essential, irreplaceable
  capability for the whole family.
- **`fzf` — required only for the `walk` verb.** Everything else works without
  it: every agent skill and the read verbs `find` / `show` / `links` / `tags` are
  unaffected. With no fzf installed, only `walk` is unavailable — running it
  errors out with a `brew install fzf` hint rather than degrading to a
  non-interactive fallback.

## Notebook

A single zk notebook at `${XDG_DATA_HOME:-$HOME/.local/share}/llm-wiki/`
(not tied to Obsidian, though the folder opens in Obsidian if wanted). Notes are
partitioned by **Scope** — the directory tree of concerns (`<repo-name>/`, nested
bounded concerns, or `global/`) — and each carries one **Lifecycle** tag
(`fleeting` → `active` → `superseded`/`retired`). Kind is a free tag, not reserved.

## Note model

The reserved model is **two axes — Scope (a directory tree of concerns) and an
internal Lifecycle — with kind left to free tags**. See
[llm-wiki Note Model — Scope + Lifecycle](../../docs/llm-wiki-note-model.md) for
the full model and the reasoning behind it.

### Verified zk behavior

- `filename = {{slug title}}` — "Raft leader election" → `raft-leader-election.md`.
- Links resolve by filename/path, **not** by title: use `[[raft-leader-election]]`
  or `[[global/cap-theorem]]`, never `[[Raft leader election]]`.
- No rename safety (title change breaks inbound links) — a known zk gap, logged
  in `_gaps.md`.

## Relationship to project-notes

llm-wiki is the zk-engine successor to the `project-notes` capture/distill
convention and **replaces** it. project-notes (base/capture/distill) is slated
for removal once the migration completes — the `inception-finalize` hand-off is
repointed to llm-wiki first, then project-notes is deleted outright; there is no
long-term coexistence. `_gaps.md` records where zk + conventions fall short — the
evidence for whether any custom tooling is ever justified.
