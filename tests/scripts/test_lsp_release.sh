#!/usr/bin/env bash
# bash -c snippets intentionally expand their positional arguments in the child.
# shellcheck disable=SC2016
set -Eeuo pipefail
shopt -s inherit_errexit
trap 'printf "Test failed at line %s (exit %s)\n" "$LINENO" "$?" >&2' ERR

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
  git init --initial-branch=master --bare "$dir-origin.git" >/dev/null
  git init --initial-branch=master "$dir" >/dev/null
  git -C "$dir" config user.name test
  git -C "$dir" config user.email test@example.com
  git -C "$dir" remote add origin "$dir-origin.git"
  mkdir -p "$dir/lua/copilot"
  mkdir -p "$dir/lua/copilot/lsp"
  printf 'return {\n  version = "1.527.1",\n  assets = {},\n}\n' >"$dir/lua/copilot/lsp/release.lua"
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

# No unchecked, working-tree-based tag publication interface may remain.
assert_fails_with 'legacy tag command removed' 'Usage:' bash -c 'cd "$1" && bash "$2" tag HEAD' _ "$repo" "$script"

untagged_repo=$(new_fixture untagged)
assert_fails "missing stable plugin tag" bash -c 'cd "$1" && bash "$2" next-patch' _ "$untagged_repo" "$script"

# Only gh is mocked: Git refs, pushes and rejected pushes use real repositories.
mkdir "$tmp/bin"
cat >"$tmp/bin/gh" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
[[ "$1" == api && "$2" == repos/test/project/* ]] || exit 90
case "$2" in
  */pulls*)
    [[ ${PR_ERROR:-0} == 0 ]] || exit 1
    printf '[%s]\n' "$PR_JSON"
    ;;
  */tags*)
    [[ ${TAG_ERROR:-0} == 0 ]] || exit 1
    if [[ ${TAG_HIDDEN:-0} == 1 ]]; then
      printf '[[]]\n'
    else
      git ls-remote --tags origin | jq -Rn --arg hide "${HIDE_TAG:-}" '[[inputs | capture("^(?<sha>[^\\t]+)\\trefs/tags/(?<name>.*)$") | select(.name != $hide) | {name, commit: {sha}}]]'
    fi
    ;;
  *) exit 91 ;;
esac
STUB
chmod +x "$tmp/bin/gh"
export PATH="$tmp/bin:$PATH" GH_TOKEN=test GITHUB_REPOSITORY=test/project

run_helper() { (cd "$repo" && bash "$script" "$@"); }
repo=$(new_fixture ordered)
git -C "$repo" tag v3.0.3
git -C "$repo" push origin HEAD:master --tags >/dev/null
base=$(git -C "$repo" rev-parse HEAD)
printf '{".":"3.0.4"}\n' >"$repo/.release-please-manifest.json"
printf 'return { version = "1.528.0" }\n' >"$repo/lua/copilot/lsp/release.lua"
git -C "$repo" add .
git -C "$repo" commit -m 'update metadata' >/dev/null
merge_sha=$(git -C "$repo" rev-parse HEAD)
export PR_JSON
PR_JSON=$(jq -n --arg sha "$merge_sha" '[{merged_at:"2026-09-07T00:00:00Z", merge_commit_sha:$sha, base:{ref:"master",repo:{full_name:"test/project"}}, head:{ref:"create-pull-request/update-copilot-lsp",repo:{full_name:"test/project"}}}]')
good_pr=$PR_JSON
run_helper check-pr "$base" "$merge_sha"
printf 'not JSON\n' >"$repo/.release-please-manifest.json"
run_helper check-pr "$base" "$merge_sha" # Must read refs, not worktree.
git -C "$repo" restore .release-please-manifest.json
assert_fails 'base is not an ancestor' run_helper check-pr "$merge_sha" "$base"
assert_fails 'invalid ref' run_helper check-pr nonexistent "$merge_sha"
TAG_HIDDEN=1 assert_fails 'base not published' run_helper check-pr "$base" "$merge_sha"
TAG_ERROR=1 assert_fails 'tag API failure' run_helper check-pr "$base" "$merge_sha"

printf 'later unrelated change\n' >"$repo/unrelated"
git -C "$repo" add unrelated
git -C "$repo" commit -m unrelated >/dev/null
assert_fails 'extra file' run_helper check-pr "$base" HEAD
assert_fails 'current base has unpublished boundary' run_helper check-pr "$merge_sha" HEAD
git -C "$repo" push origin HEAD:master >/dev/null
for mutation in '[]' '.[0].merged_at = null' '.[0].merge_commit_sha = "wrong"' '.[0].head.repo.full_name = "fork/project"' '.[0].base.repo.full_name = "fork/project"' '.[0].base.ref = "other"' '.[0].head.ref = "other"'; do
  PR_JSON=$(jq "$mutation" <<<"$good_pr")
  assert_fails "unverified provenance: $mutation" run_helper reconcile
  assert_fails 'no tag on rejected provenance' git -C "$repo" show-ref --verify refs/tags/v3.0.4
done
PR_JSON='not JSON'
assert_fails 'malformed PR API' run_helper reconcile
PR_JSON=$good_pr
PR_ERROR=1 assert_fails 'PR API failure' run_helper reconcile

# A rejected push leaves a local tag; retry must also work without that local state.
printf '#!/bin/sh\nexit 1\n' >"$repo-origin.git/hooks/pre-receive"
chmod +x "$repo-origin.git/hooks/pre-receive"
assert_fails 'rejected push' run_helper reconcile
assert_fails 'remote remains untagged' git --git-dir="$repo-origin.git" show-ref --verify refs/tags/v3.0.4
rm "$repo-origin.git/hooks/pre-receive"
git clone "$repo-origin.git" "$tmp/retry" >/dev/null
repo="$tmp/retry"
HIDE_TAG=v3.0.4 assert_fails 'publication not visible' run_helper reconcile
assert_eq "$merge_sha" "$(git -C "$repo" rev-parse v3.0.4)" 'visibility fails after push'
run_helper reconcile
assert_eq "$merge_sha" "$(git -C "$repo" rev-parse v3.0.4)" 'tag merge rather than later HEAD'
run_helper reconcile

# A tag on a different history cannot establish a published boundary.
saved_repo=$repo
repo=$(new_fixture bad-ancestry)
initial=$(git -C "$repo" rev-parse HEAD)
git -C "$repo" checkout --orphan other >/dev/null 2>&1
git -C "$repo" commit -m other >/dev/null
git -C "$repo" tag v3.0.3
git -C "$repo" checkout --detach "$initial" >/dev/null 2>&1
git -C "$repo" push origin HEAD:refs/heads/master --tags >/dev/null
assert_fails 'invalid published tag ancestry' run_helper reconcile
repo=$saved_repo

# A current base boundary prevents accepting an allocation that skips a patch.
base=$(git -C "$repo" rev-parse HEAD)
git -C "$repo" config user.name test
git -C "$repo" config user.email test@example.com
printf '{".":"3.0.6"}\n' >"$repo/.release-please-manifest.json"
printf 'next metadata\n' >>"$repo/lua/copilot/lsp/release.lua"
git -C "$repo" add .
git -C "$repo" commit -m stale >/dev/null
assert_fails 'skipped patch' run_helper check-pr "$base" HEAD
stale_sha=$(git -C "$repo" rev-parse HEAD)
PR_JSON=$(jq --arg sha "$stale_sha" '.[0].merge_commit_sha = $sha' <<<"$good_pr")
assert_fails_with 'stale reconciliation' 'Manifest version 3.0.6 is stale; expected 3.0.5' run_helper reconcile
assert_fails 'stale tag not created locally' git -C "$repo" show-ref --verify refs/tags/v3.0.6
assert_fails 'stale tag not published' git --git-dir="$tmp/ordered-origin.git" show-ref --verify refs/tags/v3.0.6

printf 'LSP release helper tests passed\n'
