#!/usr/bin/env bash
set -Eeuo pipefail

readonly targets=(darwin-arm64 darwin-x64 js linux-arm64 linux-x64 win32-arm64 win32-x64)

die() {
  printf 'update-lsp-metadata: %s\n' "$*" >&2
  exit 1
}

[[ $# -eq 2 ]] || die "Usage: $0 <release-json> <output-lua>"
release_json=$1
output_lua=$2
command -v jq >/dev/null 2>&1 || die 'jq is required'
[[ -r "$release_json" ]] || die "release metadata is not readable: $release_json"
output_parent=${output_lua%/*}
[[ "$output_parent" == "$output_lua" ]] && output_parent=.
[[ -d "$output_parent" ]] || die "output parent does not exist: $output_parent"

version=$(jq -er '.tag_name | select(type == "string" and test("^(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)\\z"))' "$release_json") \
  || die 'release has no stable version'
jq -e '.assets | type == "array"' "$release_json" >/dev/null || die 'release assets are not an array'

tmp_output=$(mktemp "$output_parent/.release.lua.XXXXXX")
cleanup() {
  rm -f -- "$tmp_output"
}
trap cleanup EXIT

printf '%s\n' '---@class copilot_release_asset' '---@field filename string' '---@field sha256 string' '---@field entrypoint string' '' 'return {' "  version = \"$version\"," '  assets = {' >"$tmp_output"

for target in "${targets[@]}"; do
  expected_filename="copilot-language-server-$target-$version.zip"
  asset=$(jq -e --arg filename "$expected_filename" \
    '.assets | map(select(type == "object" and .name == $filename)) | select(length == 1) | .[0]' "$release_json") \
    || die "missing or duplicate asset: $expected_filename"
  filename=$(jq -er '.name | select(type == "string")' <<<"$asset") \
    || die "malformed asset name: $expected_filename"
  digest=$(jq -er '.digest | select(type == "string" and test("^sha256:[0-9a-f]{64}\\z")) | ltrimstr("sha256:")' <<<"$asset") \
    || die "invalid digest: $expected_filename"
  if [[ "$target" == js ]]; then
    entrypoint=language-server.js
  elif [[ "$target" == win32-* ]]; then
    entrypoint=copilot-language-server.exe
  else
    entrypoint=copilot-language-server
  fi
  if [[ "$target" == js ]]; then
    key=js
  else
    key="[\"$target\"]"
  fi
  printf '    %s = {\n      filename = "%s",\n      sha256 = "%s",\n      entrypoint = "%s",\n    },\n' "$key" "$filename" "$digest" "$entrypoint" >>"$tmp_output"
done

printf '%s\n' '  },' '}' >>"$tmp_output"
mv -f -- "$tmp_output" "$output_lua"
trap - EXIT
