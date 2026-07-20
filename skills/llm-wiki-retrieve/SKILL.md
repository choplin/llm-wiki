---
name: llm-wiki-retrieve
description: >-
  Reach the right note(s) in the llm-wiki knowledge base on demand, cheaply —
  the alternative to grepping the repo and reading whole files. Runs a cheap
  scan (title + tags + snippet + links as JSON) over the zk notebook, then
  expands only the notes that matter, and follows [[wikilinks]] to gather
  context. Use before researching a topic from scratch, to check what the KB
  already knows. Triggers on "llm-wiki で調べて", "KB に何かあるか見て", "wiki
  から関連ノートを引いて", "what does the wiki know about X", "retrieve from the
  KB", "search llm-wiki". This is pull-only reach — it does not decide when to
  recall or proactively surface notes (that is the memory layer's job). Should
  NOT trigger for writing notes (use llm-wiki-capture).
allowed-tools: Read, Glob, Bash
user-invocable: true
---

# llm-wiki: Retrieve (reach a note on demand)

Find and reach the right note(s) without a full-text grep + whole-file read.
Cheap first, expand only what matters.

Apply **llm-wiki-base** first (Setup resolves `$wiki`). This skill is **pull-only
reach**: it answers "given I need X, how do I get to it," not "when should I
recall" — no proactive surfacing.

## Two-stage reach

### Stage 1 — cheap scan (a map, not the contents)

Return only title + tags + path + snippet + links. Do **not** read full bodies
yet.

```sh
zk -W "$wiki" scan -m "<query>"
```

Narrowing options (apply only what the request implies — the KB stays maximally
findable by default; the caller narrows). `scan` forwards these to zk list:

```sh
zk -W "$wiki" scan <scope>/ -m "<query>"       # scope to one concern's directory
zk -W "$wiki" scan --tag active                # by lifecycle (durable layer) or topic (raft)
zk -W "$wiki" scan --tag "NOT retired"         # drop stale/retired notes (NOT must be uppercase)
```

### Stage 2 — expand + traverse (only the relevant ones)

For the notes that look relevant, read the body and follow links to gather
surrounding context:

```sh
zk -W "$wiki" show "<query>"                    # full body of the matches
# resolve a title to a path, then walk its links (inbound then outbound):
p=$(zk -W "$wiki" scan -m "<title>" | jq -r '.path' | head -1)
zk -W "$wiki" links "$p"                        # backlinks + outbound, JSON
zk -W "$wiki" links "$p" --recursive --max-distance 2   # traverse the graph
```

Then Read the specific note files that matter for the task.

## Entry points (index)

To enter by keyword rather than free-text, list the live keyword index and jump
in:

```sh
zk -W "$wiki" tags                       # keywords + note counts (JSON)
zk -W "$wiki" scan --tag <keyword>       # jump into a keyword
```

## Success Criteria

- [ ] Stage 1 returned a compact map (titles/tags/snippets), not full bodies.
- [ ] Full bodies were read only for notes judged relevant.
- [ ] Links were followed where surrounding context mattered.
- [ ] No proactive surfacing beyond what was asked (reach, not recall).
