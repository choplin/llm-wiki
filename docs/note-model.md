---
title: "llm-wiki Note Model — Scope + Distill"
date: 2026-07-21
type: decision
status: accepted
tags:
  - llm-wiki
  - knowledge-base
  - note-model
---

# llm-wiki Note Model — Scope + Distill

Decision record for the note model the `llm-wiki` skill family embodies. The
model itself is stated operationally across the skills (`llm-wiki-base` owns it;
`-capture` / `-retrieve` / `-distill` / `-overview` apply it). This document is
the durable **why** — the reasoning that shaped it — so the rationale does not
live only in a tracker.

This revises the first version of the model, which reserved a second axis — an
internal **Lifecycle** (`fleeting` → `active` → `superseded`/`retired` tags).
Why it was dropped is recorded below.

## The model in one line

> An llm-wiki note is fixed by **one reserved axis — Scope — and nothing
> else**; what keeps the KB high-signal is **distill, a first-class process**
> that continuously reworks notes and leaves its footprint in frontmatter.
> Everything else (a note's "kind", its topics) is a **free layer** the
> operation decides, not part of the reserved model.

The test for what earns a reserved axis: **it must be both settable clearly when
a note is written, and used when a note is searched for.** Only Scope passes.
Everything else fails the test and is left free: wikilinks (a relation, not an
attribute), and domain/topic tags (loose, many-to-many). The base declares "this
axis is reserved, the rest is free" and holds **no `kind` vocabulary**.

Tools for relating notes, strongest first: **Scope** (a structured single home) >
explicit **wikilink** (directed, specific) > **domain tag** (free, loose
association).

## The reserved axis — Scope: the tree of concerns

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

"No stored structural metadata" is about *structural indexes* (registry, root
note, index file) and *concern status* — a note's own frontmatter **distill
footprint** (below) is not structural metadata and is allowed.

## Distill — the first-class process (why Lifecycle was dropped)

The first version reserved a Lifecycle axis: `fleeting` raw captures, promoted
by distilling into `active`, ending as `superseded`/`retired`. In practice the
writer is an **AI**, so notes are born reasonably shaped — the raw→clean
maturity ladder, the "fleeting is the only entry point," and "distill's target
is the fleeting layer" all failed to match how the KB is actually used.

The revision: **stop managing a state; center the process.** Distill is a set of
purpose-specific primitives, run when judged useful (no on-save trigger):

| Primitive | Purpose |
|---|---|
| `consolidate` | Merge notes covering the same thing; absorb orphans; resolve duplication. Source notes are always deleted (history lives in git). |
| `refresh` | Revisit notes `distilled` least recently; update or confirm them. |
| `split` | Break an oversized note into linked, self-contained notes. Source note is always deleted. |

*What to select* — by tag, time cohort, orphans, staleness, size, contradiction
— is an **operating judgment, not a flow**: the strategies are just different
inputs to the same primitives.

**The distill footprint.** Every note carries
`created` / `updated` / `distilled` / `distill_count` in frontmatter. The
contract: content edit → `updated` = today; a distill primitive reworking the
note → also `distilled` = today and `distill_count`+1; `created` is written
once. Verified zk behavior (0.15.5): custom frontmatter fields surface in
`.metadata` of `zk list -f json` (types preserved) but zk cannot natively
filter/sort on them, and `--created`/`--modified` read filesystem timestamps —
so footprint-based selection runs through `zk list -f json` + jq (baked into
the `scan` verb).

## Archive — retirement is a location, not a tag

The old `superseded`/`retired` states collapse into one mechanism: a note that
no longer earns reach is **moved to the root `_archived/` directory, preserving
its scope path** (`<scope>/note.md` → `_archived/<scope>/note.md`). A replaced
note's successor is expressed by a **wikilink** in the archived note — the link
carries what the tag used to.

Grounded in verified zk behavior (0.15.5):

- Moving a note (while staying indexed) does **not** break `[[slug]]` links —
  links only break when a note leaves the index. So archived notes stay
  reachable *as link targets* forever.
- `-x` (exclude) matches a **literal path prefix only** (no globs) — which is
  why archive collects under a single root `_archived/`: one prefix covers
  every scope. Per-scope archive directories would defeat the exclusion.
  `zk graph` accepts the same `-x`; `zk tag list` filters nothing, so the
  `tags` verb aggregates from `zk list` instead.
- `ignore` (config) removes files from the index entirely — not opt-in-able,
  and it would break inbound links. Rejected for archive; reach verbs bake
  `-x '_archived'` as the default and `LLM_WIKI_INCLUDE_ARCHIVED=1` opts back
  in.

**Boundary — no external completion tracking.** llm-wiki does *not* observe
"the project/branch finished." It holds only the locator (Scope); an external
actor that knows a concern is done drives closure. This is "reach, not surface
/ pulled, never push": **durable-vs-bounded is a Scope fact (which concern),
never a stored status.**

### close-concern

The composite for a bounded concern's end. Every note in the closing directory
gets a **positive keep decision** — distill up into the parent concern, or
archive to `_archived/<scope path>/`. Whatever is not positively kept goes down
with the directory: removing the emptied directory *is* the deletion, and its
absence *is* the closed status. This is the general form of Zettelkasten's
"tidy project notes at project end; survivors become permanent."

## How the old five prefixes are absorbed

The model supersedes an earlier `project-notes` convention that used five content
prefixes. None becomes a reserved `kind` tag — they map onto **Scope alone**:

| Old prefix | Now |
|---|---|
| `Concept` | A note in a **permanent** concern (a repo, or `global`). No kind tag. |
| `Decision` / `Proposal` / `Handoff` | A note in whatever concern it arose in (usually **bounded**); distilled up on close. No kind tag. |
| `PRD` | A note in its project (bounded) / repo scope. `prd` is a free tag if you want to group PRDs. |

Want to slice by "all decisions" or "all PRDs"? That is a **free domain tag**,
added by an operation when useful — never a reserved axis.

## What was deliberately left out (and why)

Each of these was considered as a reserved element and rejected:

- **a Lifecycle axis** — the first version's second reserved axis, dropped in
  this revision: an AI writer's notes are born shaped, so a maturity ladder
  managed as state never matched reality. Its jobs moved to the distill process
  (quality), the frontmatter footprint (history), and archive (retirement).
- **Expiry / a due date** — not knowable when a note is written, completion is
  external, and it is orthogonal to Scope. Expiry shows up only indirectly, as a
  bounded concern being closed (→ archive).
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
- **an on-save distill trigger** — when to distill is an operating judgment;
  wiring it to saves would turn a process into ceremony.

## Reach exclusion: two mechanisms, different guarantees

- **`_*.md` convention (plumbing — never reachable).** The gap log, curated
  hubs, a front-door note must not pollute reach at all: the notebook config
  sets `ignore = ["**/_*.md"]`, dropping every `_*.md` at any depth from the
  index and from reach. No marker tag is needed. (A bare `_*.md` glob would
  only match the notebook root — nested hubs like `global/_consensus.md` need
  `**/_*.md`. Verified on zk 0.15.5.)
- **`_archived/` (retired notes — excluded by default, reachable on request).**
  Stays in the index (links keep resolving); excluded from reach by the verbs'
  `-x '_archived'` default; opted in with `LLM_WIKI_INCLUDE_ARCHIVED=1`.

## Self-contained without any tracker

llm-wiki must stand on its own. The structural truth is only **the directory tree
+ zk's computed index** — no external tracker is required:

```sh
ls -d "$wiki"/*/          # the live scope list (enumerated concerns)
zk -W "$wiki" tags        # the live keyword index (JSONL)
```

## How the skills embody the model

| Skill | Role under this model |
|---|---|
| `llm-wiki-base` | Owns the model, notebook setup, the reach command surface, the gap log. |
| `llm-wiki-capture` | Drops a note into the current concern — **no classification, no maturity state** (dev scope from git; a non-dev concern is proposed by the agent and confirmed with the user). |
| `llm-wiki-retrieve` | Pull-only reach: cheap scan → expand → traverse. Archived notes excluded unless opted in. |
| `llm-wiki-distill` | Runs the primitives (consolidate / refresh / split), archives retired notes, drives close-concern. |
| `llm-wiki-overview` | Synthesizes a bird's-eye view from the graph/tags; optionally persists a curated `_*.md` hub. |
