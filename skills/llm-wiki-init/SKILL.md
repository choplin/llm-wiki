---
name: llm-wiki-init
description: >-
  Provision or update the llm-wiki knowledge base — the deliberate deploy step
  for the KB's config. Runs the bundled llm-wiki-base `scripts/setup.sh`, which
  idempotently (re)writes the zk notebook's config.toml (the verb aliases), the
  note template, and the human-only walk.sh into
  `${XDG_DATA_HOME:-$HOME/.local/share}/llm-wiki`. Use for a first-time install,
  or to force-refresh the notebook config after pulling new llm-wiki skill
  versions (e.g. new/changed verbs). Triggers on "set up llm-wiki",
  "initialize the wiki", "update the llm-wiki config", "redeploy the wiki verbs",
  "llm-wikiをセットアップ / 初期化 / 設定を更新". Should NOT trigger for reading,
  writing, or maintaining notes (use llm-wiki-capture / -retrieve / -distill /
  -overview) — those already run setup themselves; this skill is the standalone
  front door when no note operation is involved.
allowed-tools: Read, Bash
user-invocable: true
---

# llm-wiki: Initialize / Update

Deploy (or redeploy) the llm-wiki notebook config. This is a thin front door
over **llm-wiki-base**'s `scripts/setup.sh` — the single source of truth for the
deployable config (config.toml verb aliases, note template, bundled walk.sh).
The operation skills already run setup on every use; this skill exists for the
**standalone** case: a first install, or forcing a config refresh after the
skills were updated, without touching any note.

## Steps

1. **Locate llm-wiki-base.** Resolve the llm-wiki-base skill directory (wherever
   this skill family is loaded from) and set `llm_wiki_base_dir` to it. Its
   `scripts/setup.sh` sits beside its `SKILL.md`.

2. **Run setup (idempotent).** Execute the script:
   ```sh
   bash "$llm_wiki_base_dir/scripts/setup.sh"
   ```
   It self-locates its bundled `walk.sh`, needs no other input, fully rewrites
   the config / template / walk.sh (a rewrite, not a diff — safe to re-run any
   number of times), and prints the notebook path. `zk init` runs only if the
   notebook does not yet exist.
   - If it writes to `~/.local/share` and hits a sandbox denial
     (`Operation not permitted`), re-run with the sandbox disabled — the write
     target is outside the workspace by design.
   - If `zk` is not on PATH, stop and tell the user to install it
     (`brew install zk`); it is the irreplaceable dependency for this family.

3. **Confirm.** Report the notebook path from setup's output and that the verbs
   are (re)deployed. Optionally list the installed verbs (`scan` / `find` /
   `show` / `links` / `tags` / `graph` / `new` / `archive` / `reindex` / `walk`
   / `browse`) so the user sees what is now available.

Setup does **not** create or reindex notes — it only provisions config. For note
operations, use the capture / retrieve / distill / overview skills (which apply
this same setup themselves before reading or writing).
