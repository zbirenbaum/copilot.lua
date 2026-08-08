#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
workflow="$root/.github/workflows/update-copilot-nodejs.yaml"

assert_contains() {
  local text=$1
  grep -Fq -- "$text" "$workflow" || {
    printf 'Missing workflow contract: %s\n' "$text" >&2
    exit 1
  }
}

assert_not_contains_exact() {
  local text=$1
  if grep -Fxq -- "$text" "$workflow"; then
    printf 'Unexpected workflow contract: %s\n' "$text" >&2
    exit 1
  fi
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
assert_contains 'pull_request:'
assert_contains 'types: [closed]'
assert_contains "github.event.pull_request.merged == true"
assert_contains "github.event.pull_request.head.repo.full_name == github.repository"
assert_contains "github.event.pull_request.head.ref == 'create-pull-request/update-copilot-lsp'"
assert_contains 'fetch-depth: 0'
assert_contains 'id: release'
assert_contains 'git show-ref --verify --quiet "refs/tags/v$manifest_version"'
assert_contains "if: steps.release.outputs.ready == 'true'"
assert_contains 'needs-lsp-update'
assert_contains 'next-patch'
assert_contains '.release-please-manifest.json'
assert_contains 'github.event.pull_request.merge_commit_sha'
assert_contains 'lsp-release.sh tag'
assert_contains 'name: Refresh tags before version bump'
assert_contains 'name: Refresh tags before tagging'
assert_at_least 3 'git fetch --tags --force'
assert_exactly 1 'rm -rf copilot/js'
assert_exactly 1 'mkdir -p copilot/js'
assert_contains '            copilot/js'
assert_not_contains_exact '            copilot/js/*'

printf 'LSP update workflow tests passed\n'
