#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)
script="$root/.github/scripts/update-lsp-metadata.sh"
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

assert_contains() {
  local needle=$1
  local file=$2
  grep -Fq -- "$needle" "$file" || fail "Missing '$needle' in $file"
}

assert_fails() {
  local name=$1
  shift
  if "$@" >/dev/null 2>&1; then
    fail "$name: command unexpectedly succeeded"
  fi
}

make_release() {
  local version=$1
  local output=$2
  local digest='0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef'
  local assets='[]'
  local target
  for target in darwin-arm64 darwin-x64 js linux-arm64 linux-x64 win32-arm64 win32-x64; do
    assets=$(jq -c --arg name "copilot-language-server-$target-$version.zip" --arg digest "sha256:$digest" \
      '. + [{name: $name, digest: $digest}]' <<<"$assets")
  done
  jq -n --arg tag "$version" --argjson assets "$assets" '{tag_name: $tag, assets: $assets}' >"$output"
}

release="$tmp/release.json"
output="$tmp/release.lua"
make_release 1.527.5 "$release"
bash "$script" "$release" "$output"
assert_contains 'version = "1.527.5"' "$output"
assert_contains 'copilot-language-server-darwin-arm64-1.527.5.zip' "$output"
assert_contains 'sha256 = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"' "$output"
assert_contains 'entrypoint = "language-server.js"' "$output"
assert_contains 'entrypoint = "copilot-language-server.exe"' "$output"

for target in darwin-arm64 darwin-x64 js linux-arm64 linux-x64 win32-arm64 win32-x64; do
  jq --arg target "copilot-language-server-$target-1.527.5.zip" 'del(.assets[] | select(.name == $target))' "$release" >"$tmp/missing.json"
  assert_fails "missing $target" bash "$script" "$tmp/missing.json" "$tmp/missing.lua"
done

jq '.assets[0].digest = null' "$release" >"$tmp/null-digest.json"
assert_fails 'null digest' bash "$script" "$tmp/null-digest.json" "$tmp/null-digest.lua"
jq '.assets[0].digest = "sha1:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"' "$release" >"$tmp/sha1.json"
assert_fails 'non-sha256 digest' bash "$script" "$tmp/sha1.json" "$tmp/sha1.lua"
jq '.tag_name = "1.527.5-rc.1"' "$release" >"$tmp/prerelease.json"
assert_fails 'prerelease' bash "$script" "$tmp/prerelease.json" "$tmp/prerelease.lua"
jq '.tag_name = "v1.527"' "$release" >"$tmp/malformed.json"
assert_fails 'malformed version' bash "$script" "$tmp/malformed.json" "$tmp/malformed.lua"
jq --arg version $'1.527.5\n' '.tag_name = $version' "$release" >"$tmp/trailing-newline-version.json"
assert_fails 'trailing-newline version' bash "$script" "$tmp/trailing-newline-version.json" "$tmp/trailing-newline-version.lua"
jq --arg digest $'sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef\n' '.assets[0].digest = $digest' "$release" >"$tmp/trailing-newline-digest.json"
assert_fails 'trailing-newline digest' bash "$script" "$tmp/trailing-newline-digest.json" "$tmp/trailing-newline-digest.lua"
jq '.assets += [.assets[-1]]' "$release" >"$tmp/duplicate.json"
sentinel="$tmp/duplicate.lua"
printf 'sentinel\n' >"$sentinel"
assert_fails 'duplicate asset' bash "$script" "$tmp/duplicate.json" "$sentinel"
[[ $(<"$sentinel") == 'sentinel' ]] || fail 'duplicate asset changed existing output'
assert_fails 'missing output parent' bash "$script" "$release" "$tmp/missing-parent/release.lua"

printf 'LSP metadata generator tests passed\n'
