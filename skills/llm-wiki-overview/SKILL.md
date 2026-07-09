---
name: llm-wiki-overview
description: >-
  Give a bird's-eye view of what the llm-wiki knowledge base knows about a theme,
  and maintain the curated structure notes that keep it navigable — `moc` (Map of
  Content) hub notes per theme, and the single home/index front-door note. Builds
  the overview from the zk link graph and tag index. Use to answer "what do I
  know about X?" or to refresh the KB's structure. Triggers on "llm-wiki の X に
  ついての俯瞰", "KB の全体像を見せて", "MOC を作って/更新して", "wiki の目次を
  整えて", "what does the KB know about X", "build a map of content", "overview of
  the wiki". Should NOT trigger for finding one specific note (use
  llm-wiki-retrieve) or promoting/merging notes (use llm-wiki-distill).
allowed-tools: Read, Write, Edit, Glob, Bash
user-invocable: true
---

# llm-wiki: Overview & Structure

Answer "what does the KB know about X?" from the link graph, and keep the curated
structure notes (`moc` hubs + one home/index) current so the KB stays navigable.

Apply **llm-wiki-base** first (Setup resolves `$wiki`).

## Produce an overview of a theme

```sh
zk -W "$wiki" list --tag <theme> -f json --quiet |
  jq -c '.[] | {title, tags: .metadata.tags, path}'            # notes on the theme
zk -W "$wiki" list --tag <theme> --link-to "$hub" --recursive  # how they connect
zk -W "$wiki" graph --format json                              # whole-notebook shape
```

Synthesize the result into a short map: the key notes, how they relate, and gaps
(sparse areas). This is a read; do not create notes unless asked to persist it.

## Maintain `moc` (Map of Content) hubs

A `moc` note is a curated hub over a theme — a human/agent-authored structure
note, the part zk does not generate. To persist an overview as a durable hub:

1. Create/edit a note titled for the theme (e.g. "MOC - Consensus"), tag it
   `moc`, place it in the relevant scope (or `global/`).
2. In its body, organize the theme's notes into a sensible structure/sequence
   with `[[slug]]` links (not an exhaustive dump — curate).
3. Re-index: `zk -W "$wiki" index >/dev/null`.

## Maintain the single home / index note

Keep **one** top-level front-door note (e.g. `global/home.md`, tagged `moc`) that
links to the major `moc` hubs — a map of maps. Update it only when a new hub is
added.

- Do **not** build per-keyword index notes by hand: the live keyword index is
  `zk tag list` (see llm-wiki-retrieve). A hand-maintained keyword index would
  duplicate it and go stale — that is bloat.

## Success Criteria

- [ ] An overview is synthesized from the graph/tags, not a raw file dump.
- [ ] Any persisted hub is tagged `moc`, curated (not exhaustive), and links its
      theme's notes with `[[slug]]`.
- [ ] At most one home/index note exists; it maps to the `moc` hubs.
- [ ] No hand-maintained per-keyword index (that role is `zk tag list`).
