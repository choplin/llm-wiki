#!/usr/bin/env bash
set -euo pipefail

readonly expected_version="v1.5.6"

if ! command -v skill-validator >/dev/null 2>&1; then
  printf 'error: skill-validator %s is required\n' "$expected_version" >&2
  exit 127
fi

actual_version="$(skill-validator --version)"
if [[ "$actual_version" != "skill-validator version $expected_version" ]]; then
  printf 'error: expected skill-validator %s, got %s\n' \
    "$expected_version" "$actual_version" >&2
  exit 1
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

args=(check --strict --allow-extra-frontmatter)
if [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
  args+=(--emit-annotations)
fi

exec skill-validator "${args[@]}" skills/
