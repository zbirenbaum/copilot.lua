#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
script="$root/.github/scripts/lsp-release.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

assert_eq() {
  local expected=$1
  local actual=$2
  local message=$3
  [[ "$actual" == "$expected" ]] || fail "$message: expected '$expected', got '$actual'"
}

assert_fails() {
  local message=$1
  shift
  if "$@" >/dev/null 2>&1; then
    fail "$message: command unexpectedly succeeded"
  fi
}

assert_fails_with() {
  local message=$1
  local expected=$2
  shift 2
  local output
  if output=$("$@" 2>&1); then
    fail "$message: command unexpectedly succeeded"
  fi
  [[ "$output" == *"$expected"* ]] || fail "$message: expected '$expected' in '$output'"
}

new_fixture() {
  local name=$1
  local dir="$tmp/$name"
  git init --bare "$dir-origin.git" >/dev/null
  git init "$dir" >/dev/null
  git -C "$dir" config user.name test
  git -C "$dir" config user.email test@example.com
  git -C "$dir" remote add origin "$dir-origin.git"
  mkdir -p "$dir/lua/copilot"
  printf 'return {\n  editorPluginInfo = {\n    version = "1.527.1",\n  },\n}\n' >"$dir/lua/copilot/util.lua"
  printf '{\n  ".": "3.0.3"\n}\n' >"$dir/.release-please-manifest.json"
  git -C "$dir" add .
  git -C "$dir" commit -m initial >/dev/null
  printf '%s\n' "$dir"
}

repo=$(new_fixture main)
assert_eq false "$(cd "$repo" && bash "$script" needs-lsp-update 1.527.1)" "installed LSP"
assert_eq true "$(cd "$repo" && bash "$script" needs-lsp-update 1.528.0)" "new LSP"

git -C "$repo" tag v2.9.9
git -C "$repo" tag v3.0.2
git -C "$repo" tag v4.00.0
git -C "$repo" tag v99.0.0-rc.1
git -C "$repo" tag not-semver
assert_eq 3.0.3 "$(cd "$repo" && bash "$script" next-patch)" "next stable patch"
assert_fails "leading-zero LSP version" bash -c 'cd "$1" && bash "$2" needs-lsp-update "$3"' _ "$repo" "$script" 01.527.1

git -C "$repo" push origin HEAD:master --tags >/dev/null
merge_sha=$(git -C "$repo" rev-parse HEAD)
(cd "$repo" && bash "$script" tag "$merge_sha")
remote_sha=$(git --git-dir="$repo-origin.git" rev-parse refs/tags/v3.0.3)
assert_eq "$merge_sha" "$remote_sha" "pushed tag target"
(cd "$repo" && bash "$script" tag "$merge_sha")
git --git-dir="$repo-origin.git" update-ref -d refs/tags/v3.0.3
(cd "$repo" && bash "$script" tag "$merge_sha")
remote_sha=$(git --git-dir="$repo-origin.git" rev-parse refs/tags/v3.0.3)
assert_eq "$merge_sha" "$remote_sha" "restored tag target"

printf 'conflict\n' >"$repo/conflict"
git -C "$repo" add conflict
git -C "$repo" commit -m conflict >/dev/null
conflicting_sha=$(git -C "$repo" rev-parse HEAD)
assert_fails "conflicting tag" bash -c 'cd "$1" && bash "$2" tag "$3"' _ "$repo" "$script" "$conflicting_sha"

stale_repo=$(new_fixture stale)
git -C "$stale_repo" tag v3.1.0
assert_fails "stale manifest" bash -c 'cd "$1" && bash "$2" tag "$3"' _ "$stale_repo" "$script" "$(git -C "$stale_repo" rev-parse HEAD)"

leading_zero_manifest_repo=$(new_fixture leading-zero-manifest)
git -C "$leading_zero_manifest_repo" tag v3.0.2
printf '{\n  ".": "3.00.3"\n}\n' >"$leading_zero_manifest_repo/.release-please-manifest.json"
assert_fails_with "leading-zero manifest" "Invalid release manifest version" bash -c 'cd "$1" && bash "$2" tag "$3"' _ "$leading_zero_manifest_repo" "$script" "$(git -C "$leading_zero_manifest_repo" rev-parse HEAD)"

malformed_repo=$(new_fixture malformed)
printf '{\n  ".": "invalid"\n}\n' >"$malformed_repo/.release-please-manifest.json"
assert_fails "malformed manifest" bash -c 'cd "$1" && bash "$2" tag "$3"' _ "$malformed_repo" "$script" "$(git -C "$malformed_repo" rev-parse HEAD)"

untagged_repo=$(new_fixture untagged)
assert_fails "missing stable plugin tag" bash -c 'cd "$1" && bash "$2" next-patch' _ "$untagged_repo" "$script"

printf 'LSP release helper tests passed\n'
