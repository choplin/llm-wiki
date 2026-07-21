---
name: llm-wiki-overview
description: >-
  Give a bird's-eye view of what the llm-wiki knowledge base knows about a theme,
  built from the zk link graph and tag index — and optionally persist that view as
  a curated hub note (a plain `_*.md` structure file kept out of reach) plus a
  single front-door note. Structure notes are an optional consumer-layer
  convenience, not a reserved axis of the model. Use to answer "what do I know about
  X?" or to refresh the KB's navigable structure. Triggers on "what does the
  KB know about X", "give me an overview of the wiki", "build a map of
  content", "update the hub note". Should NOT trigger for finding one specific
  note (use
  llm-wiki-retrieve) or promoting/merging notes (use llm-wiki-distill).
allowed-tools: Read, Write, Edit, Glob, Bash
user-invocable: true
---

# llm-wiki: Overview & Structure

Answer "what does the KB know about X?" from the link graph and tags, and — when
useful — persist that view as a curated hub so the KB stays navigable.

The KB's **structural truth is the directory tree + zk's computed index** (the
Scope axis; see llm-wiki-base). A hub is an **optional human-facing convenience**
layered on top — *not* part of the reserved model, and *not* a note type. There is
no `moc` tag: a hub is just a structure file named `_*.md`, which the `_`-prefix
convention keeps out of reach.

Apply **llm-wiki-base** first (Setup resolves `$wiki`).

## Produce an overview of a theme

```sh
zk -W "$wiki" scan --tag <theme>                                # notes on the theme (JSON)
zk -W "$wiki" scan --tag <theme> --recursive --max-distance 2   # how they connect
zk -W "$wiki" graph                                             # whole-notebook shape (JSON)
```

Synthesize the result into a short map: the key notes, how they relate, and gaps
(sparse areas). This is a **read** — do not create files unless asked to persist it.

## Persist a curated hub (optional)

When an overview is worth keeping, persist it as a **curated hub** — a plain
structure note named `_<theme>.md` so the `_`-prefix convention keeps it out of
reach (see llm-wiki-base; no marker tag, it is not a regular note):

1. Create/edit `_<theme>.md` in the relevant concern's scope directory (or
   `global/`), e.g. `global/_consensus.md`.
2. In its body, organize the theme's notes into a sensible structure/sequence with
   `[[slug]]` links (`[[dir/slug]]` across scopes) — curate, don't dump exhaustively.
3. The hub is read **directly** (Glob/Read), not via zk reach: being `_`-prefixed,
   the hub itself — and the links inside it — stay out of the zk graph by design (so
   it never adds backlink noise). Re-index only registers the *target* notes:
   `zk -W "$wiki" reindex`.

## Maintain the single home / front-door note

Keep **one** top-level front-door note, `global/_home.md` (also `_`-prefixed), that
links to the major hubs — a map of maps. Update it only when a new hub is added.

- Do **not** build per-keyword index notes by hand: the live keyword index is
  `zk -W "$wiki" tags` (see llm-wiki-retrieve). A hand-maintained keyword index would
  duplicate it and go stale — that is bloat.

## Success Criteria

- [ ] An overview is synthesized from the graph/tags, not a raw file dump.
- [ ] Any persisted hub is a `_`-prefixed structure note (out of reach, no marker
      tag), curated (not exhaustive), linking its theme's notes with `[[slug]]`.
- [ ] At most one home/front-door note (`global/_home.md`); it maps to the hubs.
- [ ] No hand-maintained per-keyword index (that role is `zk tag list`).
