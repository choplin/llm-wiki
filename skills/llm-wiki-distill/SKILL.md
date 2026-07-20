---
name: llm-wiki-distill
description: >-
  Distill the llm-wiki knowledge base — promote raw `fleeting` notes into durable,
  self-contained `active` notes, lift a closed bounded concern's keepers up to its
  parent (distill-up-on-close), consolidate duplicates, and weave links — so the KB
  stays high-signal and does not bloat. Use at a wrap-up, when fleeting notes have
  piled up, when several notes cover the same thing, or when a project/branch ends. Triggers on
  "llm-wiki を蒸留して", "fleeting を整理して", "KB のノートを統合して", "wiki を
  片付けて", "distill the wiki", "consolidate the KB", "promote these notes".
  Should NOT trigger for the initial quick capture (use llm-wiki-capture) or for
  building structure/overview notes (use llm-wiki-overview).
allowed-tools: Read, Write, Edit, Glob, Bash
user-invocable: true
---

# llm-wiki: Distill

Turn raw captures into durable knowledge and keep the vessel from bloating.
`fleeting` is the only raw layer; distilling promotes it to `active`, consolidates
overlap, and — when a bounded concern ends — lifts its keepers up to the parent.

Apply **llm-wiki-base** first (Setup resolves `$wiki`). Lifecycle (`fleeting` →
`active` → `superseded`/`retired`) and the concern tree are defined there.

## Find what to distill

```sh
zk -W "$wiki" scan --tag fleeting   # raw captures to promote (JSON {title,tags,path,snippet})
zk -W "$wiki" scan --orphan         # unlinked → likely undigested
zk -W "$wiki" scan --tagless        # no lifecycle tag → needs one
```

## Promote a note (fleeting → active)

Rewrite the note so it stands on its own, then swap its **lifecycle tag** from
`fleeting` to `active` in the frontmatter. There is **no `permanent`/`project`
choice** — durable-vs-bounded is a *Scope* fact (which concern's directory the note
lives in), not a tag. The bar for `active`:

- **Self-contained** — one idea, or one decision + its *why* (alternatives
  rejected), or one state + next action; readable months later without the session.
- **Placed in the right concern** — a note that is really cross-cutting belongs in
  a permanent concern (repo or `global`), not the passing concern capture dropped it
  in; **move the file** if so. This placement is the classification capture deferred.

Weave it into the graph: add `[[slug]]` links to related notes (`[[dir/slug]]`
across scopes). A promoted note that links nowhere is a smell.

Later lifecycle: when a note is replaced by another, tag it `superseded` and link
to the replacement; when it is no longer accurate, tag it `retired` (kept for
history, out of reach by default). One lifecycle tag per note. A curated hub over
many notes is **not** a promotion target — it is an optional `_*.md` structure note
(see **llm-wiki-overview**).

## distill-up-on-close (when a bounded concern ends)

When a bounded concern (a project/branch directory) closes, do not leave its
directory as a dead label. This is the **only** path from a time-boxed concern to an
open-ended one:

1. **Lift keepers up** — for each note worth keeping, promote it (as above) and move
   the file into the **parent** concern: the permanent concern above it, the parent
   bounded concern, or `global/` if it has none.
2. **Prune the rest** — delete the disposable notes (spent `fleeting`, drafts,
   `superseded`).
3. **Empty the directory** — once keepers are lifted and the rest pruned, the
   directory is gone; its absence *is* the closed status.
4. **Repoint & re-index** — fix inbound `[[dir/slug]]` links that pointed into the
   closed directory to the notes' new home, then `zk -W "$wiki" reindex`.

## Consolidate (anti-bloat)

When several notes cover the same thing, merge them into one durable note:

1. Pick (or write) the keeper.
2. Fold the others' content into it; add source links where they came from
   research.
3. Repoint inbound links to the keeper, then delete the redundant notes.
4. Re-index: `zk -W "$wiki" reindex`.

**Known gap:** zk has no merge/consolidate command and no rename-safe link
refactoring — this is manual, agent-judged editing. Every time it is painful
(repointing links by hand, title-rename breaking links), append a line to
`_gaps.md` (see llm-wiki-base). That log is the evidence for whether custom
tooling is ever justified.

## Success Criteria

- [ ] Promoted notes are self-contained and tagged `active` (no longer
      `fleeting`), placed in the right concern (cross-cutting → permanent / `global`).
- [ ] When a bounded concern was closed, its keepers were lifted to the parent, the
      rest pruned, the directory emptied, and inbound links repointed.
- [ ] Duplicates were consolidated into one keeper with inbound links repointed;
      redundant notes deleted.
- [ ] Promoted notes are linked into the graph (no orphans left behind).
- [ ] Consolidation/rename friction was logged to `_gaps.md`.
