#!/usr/bin/env bash
# Workflow contract strings deliberately preserve shell and Actions expressions.
# shellcheck disable=SC2016
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
workflow="$root/.github/workflows/update-copilot-nodejs.yaml"

tracked_payloads=$(git -C "$root" ls-files copilot)
if [[ -n $tracked_payloads ]]; then
  printf 'Tracked Copilot server payloads are forbidden:\n%s\n' "$tracked_payloads" >&2
  exit 1
fi

assert_contains() {
  local text=$1
  grep -Fq -- "$text" "$workflow" || {
    printf 'Missing workflow contract: %s\n' "$text" >&2
    exit 1
  }
}

assert_not_contains() {
  local text=$1
  local file=${2:-$workflow}
  if grep -Fq -- "$text" "$file"; then
    printf 'Unexpected workflow contract: %s\n' "$text" >&2
    return 1
  fi
  return 0
}

assert_not_contains_exact() {
  local text=$1
  if grep -Fxq -- "$text" "$workflow"; then
    printf 'Unexpected exact workflow contract: %s\n' "$text" >&2
    return 1
  fi
  return 0
}

assert_at_least() {
  local expected=$1
  local text=$2
  local actual
  actual=$(grep -Fc -- "$text" "$workflow" || true)
  (( actual >= expected )) || {
    printf 'Workflow contract appears too few times: %s (expected at least %s, got %s)\n' "$text" "$expected" "$actual" >&2
    exit 1
  }
}

assert_exactly() {
  local expected=$1
  local text=$2
  local actual
  actual=$(grep -Fc -- "$text" "$workflow" || true)
  (( actual == expected )) || {
    printf 'Workflow contract appears an unexpected number of times: %s (expected %s, got %s)\n' "$text" "$expected" "$actual" >&2
    exit 1
  }
}

assert_contains '    concurrency:'
assert_contains '      group: copilot-lsp-update'
assert_contains '      cancel-in-progress: false'
assert_exactly 1 '    concurrency:'
assert_not_contains_exact 'concurrency:'
assert_not_contains 'pull_request:'
assert_not_contains 'tag_copilot_lsp_update:'
assert_contains 'fetch-depth: 0'
assert_contains 'id: release'
assert_contains 'git show-ref --verify --quiet "refs/tags/v$manifest_version"'
assert_contains "if: steps.release.outputs.ready == 'true'"
assert_contains 'needs-lsp-update'
assert_contains 'next-patch'
assert_contains '.release-please-manifest.json'
assert_contains 'update-lsp-metadata.sh'
assert_contains 'lua/copilot/lsp/release.lua'
assert_not_contains 'lsp-release.sh tag'
assert_contains 'name: Set up Neovim and dependencies'
assert_contains 'make deps'
assert_contains 'name: Validate generated update'
assert_contains 'make lint'
assert_contains 'make test'
assert_contains 'test_lsp_release.sh'
assert_contains 'test_update_lsp_metadata.sh'
assert_contains 'bash .github/scripts/lsp-release.sh needs-lsp-update'
assert_contains 'actionlint'
assert_contains 'name: Validate generated update'
assert_contains 'name: Refresh tags before version bump'
assert_at_least 2 'git fetch --tags --force'
assert_contains 'ruby tests/scripts/test_release_workflow.rb'
assert_contains 'gh api --paginate'
assert_contains 'GH_TOKEN: ${{ github.token }}'
assert_contains 'copilot-selected-release.json'
assert_contains '\\z'
assert_not_contains 'wget'
assert_not_contains 'unzip'
assert_not_contains 'util.lua'
assert_not_contains 'curl'
assert_not_contains 'Invoke-WebRequest'

for forbidden in wget unzip util.lua; do
  mutation_name=${forbidden//\//-}
  mutated="$root/.workflow-mutation-$mutation_name"
  cp -- "$workflow" "$mutated"
  printf '      run: %s -v archive.zip\n' "$forbidden" >>"$mutated"
  if assert_not_contains "$forbidden" "$mutated"; then
    rm -f -- "$mutated"
    printf 'Mutation was not rejected: %s\n' "$forbidden" >&2
    exit 1
  fi
  rm -f -- "$mutated"
done

printf 'LSP update workflow tests passed\n'
