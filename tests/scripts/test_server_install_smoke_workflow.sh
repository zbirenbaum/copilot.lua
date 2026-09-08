#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
workflow="$root/.github/workflows/server-install-smoke.yml"

for runtime_file in \
  'tests/scripts/windows_installer.lua' \
  'tests/scripts/windows_installer.ps1'; do
  if [[ ! -f "$root/$runtime_file" ]]; then
    printf 'Missing Windows installer runtime harness: %s\n' "$runtime_file" >&2
    exit 1
  fi
done

for contract in \
  'Windows installer ACL regression (${{ matrix.account }},' \
  'account: [standard, elevated]' \
  'if: matrix.account == '\''standard'\''' \
  'if: matrix.account == '\''elevated'\''' \
  '-Account standard' \
  '-Account elevated' \
  'tests/scripts/windows_installer.lua' \
  'tests/scripts/windows_installer.ps1' \
  'Start-Process -FilePath $pwsh -Credential $credential -LoadUserProfile -WorkingDirectory $sandbox' \
  'tests/scripts/windows_installer.*'; do
  grep -Fq -- "$contract" "$workflow" || {
    printf 'Missing Windows runtime-harness contract: %s\n' "$contract" >&2
    exit 1
  }
done

expected='          if ($install.Name -cnotmatch '\''^[0-9a-f]{64}$'\'') { throw "unexpected install digest: $($install.Name)" }'
grep -Fqx -- "$expected" "$workflow" || {
  printf 'Missing exact Windows install-digest contract\n' >&2
  exit 1
}

for contract in \
  'assert(not exited, "server exited during smoke interval")'; do
  grep -Fq -- "$contract" "$workflow" || {
    printf 'Missing early-exit smoke contract: %s\n' "$contract" >&2
    exit 1
  }
done

if grep -Fq -- '          if ($install.Name -notmatch '\''^[0-9a-f]{64}$'\'')' "$workflow"; then
  printf 'Windows install-digest contract must be case-sensitive\n' >&2
  exit 1
fi

for malformed in \
  '^[0-9A-Fa-f]{64}$' \
  '^[0-9a-f]{63}$' \
  '^[0-9a-f]{65}$'; do
  if grep -Fq -- "$malformed" "$workflow"; then
    printf 'Malformed Windows install-digest contract found: %s\n' "$malformed" >&2
    exit 1
  fi
done

if [[ -n $(git -C "$root" ls-files -- 'task-3-review.md') ]]; then
  printf 'Accidentally tracked root review artifact found\n' >&2
  exit 1
fi

printf 'Server install smoke workflow tests passed\n'
