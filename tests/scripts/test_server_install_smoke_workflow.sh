#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
workflow="$root/.github/workflows/server-install-smoke.yml"

expected='          if ($generation.Name -cnotmatch '\''^[0-9a-f]{64}-[0-9]+-[0-9]+-[0-9]+$'\'') { throw "unexpected generation: $($generation.Name)" }'
grep -Fqx -- "$expected" "$workflow" || {
  printf 'Missing exact Windows generation-name contract\n' >&2
  exit 1
}

for contract in \
  'assert(not exited, "server exited during smoke interval")'; do
  grep -Fq -- "$contract" "$workflow" || {
    printf 'Missing early-exit smoke contract: %s\n' "$contract" >&2
    exit 1
  }
done

if grep -Fq -- '          if ($generation.Name -notmatch '\''^[0-9a-f]{64}-[0-9]+-[0-9]+-[0-9]+$'\'')' "$workflow"; then
  printf 'Windows generation-name contract must be case-sensitive\n' >&2
  exit 1
fi

for malformed in \
  '^[0-9a-f]{64}-[0-9]+-[0-9]+$' \
  '^[0-9A-Fa-f]{64}-[0-9]+-[0-9]+-[0-9]+$' \
  '^[0-9a-f]{63}-[0-9]+-[0-9]+-[0-9]+$'; do
  if grep -Fq -- "$malformed" "$workflow"; then
    printf 'Malformed Windows generation-name contract found: %s\n' "$malformed" >&2
    exit 1
  fi
done

if [[ -n $(git -C "$root" ls-files -- 'task-3-review.md') ]]; then
  printf 'Accidentally tracked root review artifact found\n' >&2
  exit 1
fi

printf 'Server install smoke workflow tests passed\n'
