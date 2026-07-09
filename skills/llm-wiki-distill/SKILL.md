---
name: llm-wiki-distill
description: >-
  Distill the llm-wiki knowledge base — promote raw `fleeting` notes into
  durable, self-contained notes (`permanent` reusable idea / `project`
  project-specific record), consolidate duplicates, and weave links — so the KB
  stays high-signal and does not bloat. Use at a wrap-up, or when fleeting notes
  have piled up, or when several notes cover the same thing. Triggers on
  "llm-wiki を蒸留して", "fleeting を整理して", "KB のノートを統合して", "wiki を
  片付けて", "distill the wiki", "consolidate the KB", "promote these notes".
  Should NOT trigger for the initial quick capture (use llm-wiki-capture) or for
  building structure/overview notes (use llm-wiki-overview).
allowed-tools: Read, Write, Edit, Glob, Bash
user-invocable: true
---

# llm-wiki: Distill

Turn raw captures into durable knowledge and keep the vessel from bloating.
`fleeting` is the only raw layer; distilling promotes it and consolidates
overlap.

Apply **llm-wiki-base** first (Setup resolves `$wiki`).

## Find what to distill

```sh
zk -W "$wiki" list --tag fleeting -f json --quiet |
  jq -c '.[] | {title, path, tags: .metadata.tags, snippet: (.body[0:100])}'
zk -W "$wiki" list --orphan  -f '{{title}}' --quiet   # unlinked → likely undigested
zk -W "$wiki" list --tagless -f '{{title}}' --quiet   # untyped → needs a type
```

## Promote a note

Rewrite the note so it stands on its own, then change its type tag from
`fleeting` to the right durable type (edit the frontmatter):

| Promote to | When | Bar to meet |
|------------|------|-------------|
| `permanent` | A reusable, atomic idea worth recalling across projects | Self-contained and atomic — one idea, readable months later without the session. |
| `project` | A project-specific decision/state/PRD/handoff | States the decision AND *why* (alternatives rejected), or the current state + next action. |
| `moc` | It is really a structure/hub over many notes | Hand off to **llm-wiki-overview** instead. |

Weave it into the graph: add `[[slug]]` links to related notes (`[[dir/slug]]`
across scopes). A promoted note that links nowhere is a smell.

## Consolidate (anti-bloat)

When several notes cover the same thing, merge them into one durable note:

1. Pick (or write) the keeper.
2. Fold the others' content into it; add source links where they came from
   research.
3. Repoint inbound links to the keeper, then delete the redundant notes.
4. Re-index: `zk -W "$wiki" index >/dev/null`.

**Known gap:** zk has no merge/consolidate command and no rename-safe link
refactoring — this is manual, agent-judged editing. Every time it is painful
(repointing links by hand, title-rename breaking links), append a line to
`_gaps.md` (see llm-wiki-base). That log is the evidence for whether custom
tooling is ever justified.

## Success Criteria

- [ ] Promoted notes are self-contained and carry a durable type
      (`permanent`/`project`), no longer `fleeting`.
- [ ] `permanent` notes are atomic and reusable; `project` notes state decision
      + rationale or state + next action.
- [ ] Duplicates were consolidated into one keeper with inbound links repointed;
      redundant notes deleted.
- [ ] Promoted notes are linked into the graph (no orphans left behind).
- [ ] Consolidation/rename friction was logged to `_gaps.md`.
