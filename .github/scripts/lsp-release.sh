#!/usr/bin/env bash
set -euo pipefail

die() {
  printf '%s\n' "$*" >&2
  exit 1
}

stable_version() {
  [[ "$1" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]]
}

installed_lsp_version() {
  local version
  version=$(sed -n -E 's/^[[:space:]]*version = "([^"]+)",$/\1/p' lua/copilot/lsp/release.lua)
  stable_version "$version" || die "Unable to read the installed LSP version"
  printf '%s\n' "$version"
}

latest_stable_tag() {
  local tag
  while IFS= read -r tag; do
    if [[ "$tag" == v* ]] && stable_version "${tag#v}"; then
      printf '%s\n' "$tag"
      return
    fi
  done < <(git tag --list 'v*' --sort=-version:refname)
  die "No stable plugin tag found"
}

next_patch() {
  local tag
  local version
  local major
  local minor
  local patch

  tag=$(latest_stable_tag)
  version=${tag#v}
  stable_version "$version" || die "Invalid stable plugin tag: $tag"
  IFS=. read -r major minor patch <<<"$version"
  printf '%s.%s.%s\n' "$major" "$minor" "$((patch + 1))"
}

manifest_version() {
  local version
  if ! version=$(jq -er '.["."] | select(type == "string")' .release-please-manifest.json); then
    die "Unable to read the release manifest version"
  fi
  stable_version "$version" || die "Invalid release manifest version: $version"
  printf '%s\n' "$version"
}

tag_release() {
  local requested_sha=$1
  local sha
  local version
  local tag
  local existing_sha
  local expected

  sha=$(git rev-parse --verify "$requested_sha^{commit}") || die "Invalid merge commit: $requested_sha"
  version=$(manifest_version)
  tag="v$version"

  if git show-ref --verify --quiet "refs/tags/$tag"; then
    existing_sha=$(git rev-parse "$tag^{commit}")
    [[ "$existing_sha" == "$sha" ]] || die "$tag already points to $existing_sha"
    git push origin "refs/tags/$tag"
    printf '%s already points to %s\n' "$tag" "$sha"
    return
  fi

  expected=$(next_patch)
  [[ "$version" == "$expected" ]] || die "Manifest version $version is stale; expected $expected"

  git tag "$tag" "$sha"
  git push origin "refs/tags/$tag"
}

command=${1:-}
case "$command" in
  needs-lsp-update)
    [[ $# -eq 2 ]] || die "Usage: $0 needs-lsp-update <resolved-lsp-version>"
    stable_version "$2" || die "Invalid resolved LSP version: $2"
    if [[ "$(installed_lsp_version)" == "$2" ]]; then
      printf 'false\n'
    else
      printf 'true\n'
    fi
    ;;
  next-patch)
    [[ $# -eq 1 ]] || die "Usage: $0 next-patch"
    next_patch
    ;;
  tag)
    [[ $# -eq 2 ]] || die "Usage: $0 tag <commit-sha>"
    tag_release "$2"
    ;;
  *)
    die "Usage: $0 {needs-lsp-update <version>|next-patch|tag <commit-sha>}"
    ;;
esac
