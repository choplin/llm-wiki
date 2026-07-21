---
name: llm-wiki-distill
description: >-
  Distill the llm-wiki knowledge base — run the distill primitives (consolidate
  duplicates and orphans into keepers, refresh stale notes, split oversized
  ones), archive notes that no longer earn reach, and drive close-concern when
  a bounded concern ends — so the KB stays high-signal and does not bloat.
  Use at a wrap-up, when captures have piled up, when several notes cover the
  same thing, when notes have gone stale, or when a project/branch ends.
  Triggers on "llm-wiki を蒸留して", "KB のノートを統合して", "wiki を
  片付けて", "古いノートを見直して", "distill the wiki", "consolidate the KB",
  "refresh stale notes", "close out this concern". Should NOT trigger for the
  initial quick capture (use llm-wiki-capture) or for building
  structure/overview notes (use llm-wiki-overview).
allowed-tools: Read, Write, Edit, Glob, Bash
user-invocable: true
---

# llm-wiki: Distill

Distill is the KB's **first-class process**: notes are born reasonably shaped
(the writer is an AI), so there is no maturity ladder to climb — what keeps the
KB high-signal is continuously *reworking* it. This skill owns the judgment
half: which primitive to run, on what, and when. The model (primitives'
semantics, the frontmatter footprint contract, archive, close-concern) is
defined in **llm-wiki-base** — apply it first (Setup resolves `$wiki`).

## Select what to distill (an operating judgment, not a flow)

Selection strategies are **inputs to the same primitives**, chosen at run time
from what the session needs — none of them is a separate workflow. `scan`
emits the distill footprint (`updated`/`distilled`/`distill_count`) for
exactly this:

```sh
zk -W "$wiki" scan --orphan                 # unlinked → consolidate candidates
zk -W "$wiki" scan --tag <topic>            # a topic's cohort
zk -W "$wiki" scan <scope>/                 # one concern's notes
zk -W "$wiki" scan | jq -s 'sort_by(.distilled // "0000")[:10][]'   # stalest first (never-distilled sort first)
zk -W "$wiki" scan | jq -c 'select(.distilled == null)'             # never distilled
```

Other selectors — size (an oversized body → `split`), time cohorts,
contradictions noticed while reading — are judged from the notes themselves.
Pick the notes, then apply a primitive.

## The primitives

Every primitive ends the same way: update the reworked note's footprint
(`updated` and `distilled` to today, `distill_count` +1 — see the contract in
llm-wiki-base), weave `[[slug]]` links, then `zk -W "$wiki" reindex`. A
reworked note that links nowhere is a smell. `refresh` that confirms a note
unchanged still updates `distilled`/`distill_count` (the revisit is the fact
being recorded) but not `updated` (no content edit).

### consolidate — merge what covers the same thing

1. Pick (or write) the keeper; make it self-contained — one idea, or one
   decision + its *why* (alternatives rejected), readable months later.
2. Fold the other notes' content in; keep source links where content came from
   research.
3. Repoint inbound links to the keeper (`zk -W "$wiki" links "<path>"` shows
   them), then **delete the source notes — always** (history lives in git).
4. Orphans (`scan --orphan`) are consolidate candidates too: absorb them into
   the note they belong with, or link them in if they stand alone.
5. While consolidating, fix placement: a note that is really cross-cutting
   belongs in a permanent concern (repo or `global/`) — move the file.

### refresh — revisit the stalest notes

1. Select by `distilled` oldest-first (never-distilled sorts first — see above).
2. Reread each note against what is known now: update it, tighten it, link it
   to notes that did not exist when it was written — or confirm it unchanged.
3. A note found inaccurate or replaced is not refreshed — archive it (below).

### split — break up an oversized note

1. Cut the note into self-contained pieces, one idea each, in the same scope.
2. Link the pieces to each other (`[[slug]]`) and repoint inbound links to the
   right piece.
3. **Delete the source note — always** (history lives in git).

## Archive (retire from reach)

A note that no longer earns reach — inaccurate, replaced by a successor, or a
close-concern keeper that is only worth keeping on request — is **moved, not
tagged or deleted**:

```sh
zk -W "$wiki" archive "<scope>/<slug>.md"    # → _archived/<scope>/<slug>.md, reindexed
```

Before archiving a *replaced* note, add a `[[slug]]` wikilink to its successor
in the note body — the link, not a tag, is what records the succession.
Archived notes stay in the index (inbound slug links keep resolving) and are
excluded from reach by default; `LLM_WIKI_INCLUDE_ARCHIVED=1` opts back in.

## close-concern (when a bounded concern ends)

Drive the composite defined in llm-wiki-base. For **every** note in the closing
concern's directory, make a **positive keep decision**:

1. **Distill up** — worth keeping live: rework it (consolidate/refresh as
   fits) into the **parent** concern (the permanent concern above, the parent
   bounded concern, or `global/` if none) and move the file there.
2. **Archive** — worth keeping only on request:
   `zk -W "$wiki" archive "<scope>/<slug>.md"` (the scope path is preserved
   under `_archived/`).

Anything not positively kept goes down with the directory: once keepers are
moved out, **remove the directory** — that removal is the deletion, and the
directory being gone is the closed status. Then fix inbound `[[dir/slug]]`
links that pointed into the closed directory (distilled-up notes have a new
home) and `zk -W "$wiki" reindex`.

**Known gap:** zk has no merge/consolidate command and no rename-safe link
refactoring — repointing links is manual, agent-judged editing. Every time it
is painful, append a line to `_gaps.md` (see llm-wiki-base). That log is the
evidence for whether custom tooling is ever justified.

## Success Criteria

- [ ] Reworked notes are self-contained, linked into the graph, and their
      footprint reflects the operation (`distilled` today, `distill_count`
      incremented; `updated` only if content changed).
- [ ] consolidate/split source notes were deleted, with inbound links repointed
      to the keeper/pieces first.
- [ ] Retired notes were archived by moving (successor wikilink added when
      replaced), never tagged or silently deleted.
- [ ] When a bounded concern was closed, every note got a positive keep
      decision (distill-up / archive), the directory was removed, and inbound
      links were repointed.
- [ ] Selection was an in-session judgment (orphans / staleness / cohort /
      size), not a separate maintained workflow.
- [ ] Consolidation/rename friction was logged to `_gaps.md`.
