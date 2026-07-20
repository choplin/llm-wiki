# llm-wiki

A plain-Markdown **knowledge base an AI agent builds and maintains**, operated
through the [zk](https://github.com/zk-org/zk) CLI over Bash. The agent is the
primary reader/writer — no GUI in the loop. Retention is exactly what is written
to files: explicit, visible, git-versionable.

The KB is a **vessel**: it doesn't scatter (scoped, lifecycle-tagged, linked), it
doesn't bloat (distill + consolidate, no hand-maintained indexes), and it holds
everything needed. It provides the means to **reach** notes on demand — it does
not decide *when* to recall or proactively surface them (that is the memory
layer's job).

The idea traces to [Karpathy's LLM Wiki](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f)
— a wiki an LLM keeps for itself.

## Skills

| Skill | Description |
|-------|-------------|
| `llm-wiki-base` | Shared model: notebook setup, note model (slug filenames, wikilinks, two reserved axes — Scope tree of concerns + internal Lifecycle — with kind left to free tags), the reach command surface, gap-log (delegated, not invoked directly) |
| `llm-wiki-capture` | Write a finding into the KB as a `fleeting` note (no classification), tagged and linked |
| `llm-wiki-retrieve` | Reach the right note(s) on demand — cheap scan → expand → traverse (pull-only) |
| `llm-wiki-distill` | Promote `fleeting` → `active`, lift a closed concern's keepers up (distill-up-on-close), consolidate duplicates |
| `llm-wiki-overview` | Overview a theme from the graph; keep any optional curated hub + front-door note |

## Prerequisite

`zk` must be on PATH (`brew install zk`, or see the [zk repo](https://github.com/zk-org/zk)).
It is an essential, irreplaceable capability for this family.

## Notebook

A single zk notebook at `${XDG_DATA_HOME:-$HOME/.local/share}/llm-wiki/`
(not tied to Obsidian, though the folder opens in Obsidian if wanted). Notes are
partitioned by **Scope** — the directory tree of concerns (`<repo-name>/`, nested
bounded concerns, or `global/`) — and each carries one **Lifecycle** tag
(`fleeting` → `active` → `superseded`/`retired`). Kind is a free tag, not reserved.

## Note model (verified zk behavior)

- `filename = {{slug title}}` — "Raft leader election" → `raft-leader-election.md`.
- Links resolve by filename/path, **not** by title: use `[[raft-leader-election]]`
  or `[[global/cap-theorem]]`, never `[[Raft leader election]]`.
- No rename safety (title change breaks inbound links) — a known zk gap, logged
  in `_gaps.md`.

## Relationship to project-notes

llm-wiki is the zk-engine successor to the `project-notes` capture/distill
convention. project-notes coexists for now; it is a migration target once
llm-wiki proves out. `_gaps.md` records where zk + conventions fall short — the
evidence for whether any custom tooling is ever justified.
