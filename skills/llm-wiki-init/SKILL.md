---
name: llm-wiki-init
description: >-
  Provision or update the llm-wiki knowledge base — the deliberate deploy step
  for the KB's config. Owns the deployable artifacts (assets/config.toml, the
  verb aliases; assets/default.md, the note template; scripts/walk.sh) and runs
  its own `scripts/setup.sh`, which idempotently installs them into the zk
  notebook at
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

Deploy (or redeploy) the llm-wiki notebook config. **This skill owns llm-wiki's
deployable payload** — each artifact is a plain file here, and each file is the
source of truth:

| File | Deployed to | What it is |
|------|-------------|------------|
| `assets/config.toml` | `.zk/config.toml` | the verb `[alias]` block — the KB mechanics |
| `assets/default.md` | `.zk/templates/default.md` | the note template (distill footprint frontmatter) |
| `scripts/walk.sh` | `.zk/walk.sh` | the human-only fzf link walker |

`scripts/setup.sh` installs them — a plain file copy, so no shell quoting rule
can corrupt an artifact in transit. **llm-wiki-base** holds the complementary
half: what the verbs *mean* and when to use them.

The operation skills already run this setup on every use; this skill exists for
the **standalone** case: a first install, or forcing a config refresh after the
skills were updated, without touching any note.

## Steps

1. **Locate this skill.** Resolve the llm-wiki-init skill directory (wherever it
   is loaded from) and set `llm_wiki_init_dir` to it; `scripts/setup.sh` sits
   beside this `SKILL.md`.

2. **Run setup (idempotent).** Execute the script:
   ```sh
   bash "$llm_wiki_init_dir/scripts/setup.sh"
   ```
   It self-locates its own `assets/`, needs no other input, overwrites the
   config / template / walk.sh (an overwrite, not a diff — safe to re-run any
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
