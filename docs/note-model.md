---
title: "llm-wiki Note Model — Scope + Lifecycle"
date: 2026-07-21
type: decision
status: accepted
tags:
  - llm-wiki
  - knowledge-base
  - note-model
---

# llm-wiki Note Model — Scope + Lifecycle

Decision record for the note model the `llm-wiki` skill family embodies. The
model itself is stated operationally across the skills (`llm-wiki-base` owns it;
`-capture` / `-retrieve` / `-distill` / `-overview` apply it). This document is
the durable **why** — the reasoning that shaped it — so the rationale does not
live only in a tracker.

## The model in one line

> An llm-wiki note is fixed by **two reserved axes — Scope and Lifecycle — and
> nothing else**. Everything else (a note's "kind", its topics) is a **free
> layer** the operation decides, not part of the reserved model.

The test for what earns a reserved axis: **it must be both settable clearly when a
note is written, and used when a note is searched for.** Only two things pass:

1. **Scope** — which concern the note belongs to (where it lives).
2. **internal Lifecycle** — its curation state inside the KB.

Everything else fails the test and is left free: wikilinks (a relation, not an
attribute), and domain/topic tags (loose, many-to-many). The base declares "these
two axes are reserved, the rest is free" and holds **no `kind` vocabulary**.

Tools for relating notes, strongest first: **Scope** (a structured single home) >
explicit **wikilink** (directed, specific) > **domain tag** (free, loose
association).

## Axis 1 — Scope: the tree of concerns

A note lives under the **concern** it belongs to. Concerns form a single-parent
forest:

- **permanent concern** — open-ended, stands alone. Dev: a repo. Non-dev: a life
  domain (`investment`, `kakeibo`). The roots of the forest.
- **bounded concern** — time-boxed, eventually closes. Dev: a project or branch.
  Its parent ∈ {a permanent concern, another bounded concern, none}.
- **`global`** — belongs to no concern (root-less, cross-cutting).

Dev (repo / project / branch) is just **one instantiation** of this abstraction;
the model hardcodes the *abstraction*, not repo/project/branch. This is not a new
invention — the same split is already latent wherever work is tracked as a
permanent "area" axis and a bounded "project" axis. The model just names it.

### The directory tree *is* the truth

Scope is represented as a **directory tree**, and that tree is the single source
of truth — there is deliberately **no stored structural metadata**:

- Enumerating the directories **is** the live list of active concerns. No root
  note, no registry, no index file to maintain.
- **`status` is not stored:** a directory that exists = the concern is open; a
  directory that is gone = closed.
- **`kind` (permanent vs bounded) is not stored:** *position* says it — a root
  directory is a domain, a nested directory is an endeavour.

The only thing given up is `kind` **enforcement** (nothing gates mis-closing a
permanent concern). Closing is a deliberate, external act, so convention suffices
— cheaper than carrying metadata that would have to be kept honest.

## Axis 2 — internal Lifecycle

A note's maturity **inside the KB**, expressed as a single lifecycle tag and
driven **only by KB operations**:

`fleeting` (raw capture) → `active` (distilled, stands on its own) →
`superseded` (replaced by another note) / `retired` (no longer accurate).

**Boundary — no external completion tracking.** llm-wiki does *not* observe "the
project/branch finished." It holds only the locator (Scope); an external actor
that knows a concern is done drives closure. This is "reach, not surface / pulled,
never push" applied to lifecycle: **durable-vs-bounded is a Scope fact (which
concern), not a maturity tag.**

### distill-up-on-close

The one path from a time-boxed concern to an open-ended one. When a bounded
concern closes, its directory must not be left as a dead label:

1. **Lift keepers up** into the parent concern (a permanent concern, the parent
   bounded concern, or `global` if none).
2. **Prune the rest.**
3. **Empty the directory** — its absence *is* the closed status.

This is the general form of Zettelkasten's "tidy project notes at project end;
survivors become permanent," and it is the reason ephemeral branch/project
identities never leave dead labels behind.

## How the old five prefixes are absorbed

The model supersedes an earlier `project-notes` convention that used five content
prefixes. None becomes a reserved `kind` tag — they map onto **Scope + Lifecycle
alone**:

| Old prefix | Now |
|---|---|
| `Concept` | A note in a **permanent** concern (a repo, or `global`). No kind tag. |
| `Decision` / `Proposal` / `Handoff` | A note in whatever concern it arose in (usually **bounded**); promoted up on close. No kind tag. |
| `PRD` | A note in its project (bounded) / repo scope. `prd` is a free tag if you want to group PRDs. |

Want to slice by "all decisions" or "all PRDs"? That is a **free domain tag**,
added by an operation when useful — never a reserved axis.

## What was deliberately left out (and why)

Each of these was considered as a reserved axis and rejected:

- **Expiry / a due date** — not knowable when a note is written, completion is
  external, and it is orthogonal to Scope. Expiry shows up only indirectly, as a
  bounded concern being closed (→ retire).
- **`permanent` / `project` as maturity tags** — absorbed into Scope (a durable
  concern vs a bounded concern is *which directory*, not a tag). Keeping them as
  tags would duplicate the Scope fact.
- **structure / `moc` markers** — no use case as a reserved type. A curated hub is
  an *optional* consumer-layer convenience, kept as a plain `_*.md` structure file
  (see reach exclusion below), not a note type.
- **a `kind` vocabulary** (decision / proposal / handoff / prd / concept) — fails
  the "settable + searched" test as a reserved axis; available as a free topical
  tag when a caller actually wants it.
- **domain as a Scope axis** — a free tag is enough for loose association; making
  it a scope would add a capture-time decision for zero retrieval gain.

## Reach exclusion: the `_*.md` convention

Plumbing files (the gap log, curated hubs, a front-door note) must not pollute
reach. They use a **`_`-prefixed filename convention**: the notebook config sets
`ignore = ["**/_*.md"]`, which drops every `_*.md` at any depth (root *and* nested
scope directories) from the index and from reach. No marker tag is needed. (A bare
`_*.md` glob would only match the notebook root — nested hubs like
`global/_consensus.md` need `**/_*.md`. Verified on zk 0.15.5.)

## Self-contained without any tracker

llm-wiki must stand on its own. The structural truth is only **the directory tree
+ zk's computed index** — no external tracker is required:

```sh
ls -d "$wiki"/*/                       # the live scope list (enumerated concerns)
zk -W "$wiki" tag list -f json --quiet # the live keyword + lifecycle index
```

## How the skills embody the model

| Skill | Role under this model |
|---|---|
| `llm-wiki-base` | Owns the model, notebook setup, the reach command surface, the gap log. |
| `llm-wiki-capture` | Drops a `fleeting` note into the current concern — **no classification** (dev scope from git; a non-dev concern is proposed by the agent and confirmed with the user). |
| `llm-wiki-retrieve` | Pull-only reach: cheap scan → expand → traverse. Filters by lifecycle/topic. |
| `llm-wiki-distill` | Promotes `fleeting` → `active`, runs distill-up-on-close, consolidates duplicates. |
| `llm-wiki-overview` | Synthesizes a bird's-eye view from the graph/tags; optionally persists a curated `_*.md` hub. |
