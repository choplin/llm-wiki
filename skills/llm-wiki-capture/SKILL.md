---
name: llm-wiki-capture
description: >-
  Capture a piece of knowledge into the llm-wiki knowledge base (a zk notebook)
  as a note, so it is not lost and can be reached later. Writes a `fleeting` note
  into the current concern's scope directory, tags it, and links it to related
  existing notes — with no classification (that is distill's job). Use when a valuable finding, decision, or fact
  surfaces during work and should be kept without deciding where to put it.
  Triggers on "llm-wiki に書いて", "この知見を wiki に残して", "KB にメモして",
  "capture this into the wiki", "save this finding to the KB", "note this in
  llm-wiki". Should NOT trigger for shaping/merging notes already captured (use
  llm-wiki-distill), team-shared repo docs (README/docs/), or transient state for
  resuming the same session shortly (keep it in session).
allowed-tools: Read, Write, Edit, Glob, Bash
user-invocable: true
---

# llm-wiki: Capture a Note

Write knowledge into the KB as a note. Fast, no heavy shaping — the goal is to
not lose it and to make it reachable.

Apply **llm-wiki-base** first: run its Setup (resolve `$wiki`, create the
notebook if missing) and resolve the current concern's scope directory `$scope`
(repo-name, or `global`). This skill handles only the capture half — it drops a
`fleeting` note into the current concern and does **not** classify it.

## Steps

1. **Setup + scope** — per llm-wiki-base. In a git repo the scope derives
   automatically (`<repo-name>/`). Outside one — non-dev or cross-cutting work —
   there is no automatic source: **propose** a concern from the session context and
   **confirm it with the user**, then ensure `mkdir -p "$wiki/$scope"`. Resolving the
   locator is not classification; the note is still a dumb `fleeting` drop.

2. **Avoid duplication (reach before writing).** Search for an existing note on
   the same thing before creating a new one:
   ```sh
   zk -W "$wiki" scan -m "<topic keywords>"
   ```
   - If a note already covers it, **append to / edit that note** (Edit tool) and
     link the two, rather than creating a near-duplicate.
   - **Collision safety:** `zk new` with a title whose slug already exists in the
     scope is a *silent no-op* — it keeps the existing file and returns its path,
     dropping the new body. So before creating, check
     `"$wiki/$scope/<slug>.md"`; if it exists and is a *different* note, choose a
     more specific title.

3. **Create the note** (always `fleeting` — capture does not classify), piping the body via stdin:
   ```sh
   printf '%s' "<body>" |
     zk -W "$wiki" new "$scope" --title "<Concise Title>"
   ```
   The `new` verb bakes in `-i` (reads the body from stdin into the template's
   `{{content}}`) and `-p` (prints the path, no editor opens).

4. **Tag it.** The template seeds `tags: [fleeting]` — the **lifecycle tag stays
   `fleeting`** (capture never promotes; that is distill's job). Add free
   topical/domain tags by editing the frontmatter (e.g.
   `tags: [fleeting, raft, consensus]`).

5. **Link it in.** Add `[[slug]]` links to related notes found in step 2 (use the
   slug = kebab-case of the target's title; `[[dir/slug]]` for cross-scope). This
   is what keeps the KB from scattering. Never link by natural title — that form
   does not resolve in zk.

6. **Re-index** so links and tags register:
   ```sh
   zk -W "$wiki" reindex
   ```

## Success Criteria

- [ ] Note is under `$wiki/$scope/`, filename is the slugged title.
- [ ] Carries the `fleeting` lifecycle tag plus at least one topical tag.
- [ ] Linked to related existing notes with `[[slug]]` (not `[[Natural Title]]`).
- [ ] No near-duplicate created — an existing note was extended instead when one
      already covered the topic.
- [ ] If zk + conventions were awkward here, a line was appended to `_gaps.md`
      (see llm-wiki-base).
