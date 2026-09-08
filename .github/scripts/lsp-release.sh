#!/usr/bin/env bash
set -Eeuo pipefail
shopt -s inherit_errexit
trap 'printf "Release helper failed at line %s (exit %s)\n" "$LINENO" "$?" >&2' ERR

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
  local tag tags
  tags=$(git tag --list 'v*' --sort=-version:refname) || die "Unable to list tags"
  while IFS= read -r tag; do
    if [[ "$tag" == v* ]] && stable_version "${tag#v}"; then
      printf '%s\n' "$tag"
      return
    fi
  done <<<"$tags"
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

# Validation/publication require Bash 4.4+, Git, jq and gh. The caller supplies a full
# checkout with current tags, GH_TOKEN and GITHUB_REPOSITORY; no branch is pulled.
api_setup() {
  : "${GH_TOKEN:?GH_TOKEN is required}" "${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is required}"
  [[ "$GITHUB_REPOSITORY" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] || die "Invalid repository"
  command -v gh >/dev/null || die "gh is required"
}

ref_version() {
  local version
  version=$(git show "$1:.release-please-manifest.json" | jq -er '.["."] | select(type == "string")') || die "Unable to read manifest at $1"
  stable_version "$version" || die "Invalid manifest at $1"
  printf '%s\n' "$version"
}

# Require the same immutable commit in local Git, origin and GitHub's tag list.
published_boundary() {
  local tag=$1 ref=$2 sha remote tags
  sha=$(git rev-parse --verify "refs/tags/$tag^{commit}") || die "Missing boundary $tag"
  git merge-base --is-ancestor "$sha" "$ref" || die "$tag is not an ancestor of $ref"
  remote=$(git ls-remote --tags origin "refs/tags/$tag" "refs/tags/$tag^{}") || die "Unable to read remote tags"
  [[ "$remote" == *"$sha"$'\t'"refs/tags/$tag"* ]] || die "Remote boundary mismatch: $tag"
  tags=$(gh api "repos/$GITHUB_REPOSITORY/tags?per_page=100" --paginate --slurp) || die "Unable to list GitHub tags"
  jq -e --arg tag "$tag" --arg sha "$sha" '
    type == "array" and all(.[]; type == "array" and all(.[];
      (.name | type == "string") and (.commit.sha | type == "string"))) and
    ([.[][] | select(.name == $tag)] | length == 1 and .[0].commit.sha == $sha)
  ' <<<"$tags" >/dev/null || die "GitHub tag list does not verify $tag"
}

check_pr() {
  local base head version next major minor patch files
  base=$(git rev-parse --verify --end-of-options "$1^{commit}") || die "Invalid base ref"
  head=$(git rev-parse --verify --end-of-options "$2^{commit}") || die "Invalid head ref"
  git merge-base --is-ancestor "$base" "$head" || die "Base is not an ancestor of head"
  version=$(ref_version "$base") || die "Invalid base manifest"
  published_boundary "v$version" "$base"
  IFS=. read -r major minor patch <<<"$version"
  next="$major.$minor.$((patch + 1))"
  version=$(ref_version "$head") || die "Invalid head manifest"
  [[ "$version" == "$next" ]] || die "Manifest version $version is stale; expected $next"
  files=$(git diff --no-renames --name-only "$base" "$head" --) || die "Unable to compare refs"
  [[ "$files" == $'.release-please-manifest.json\nlua/copilot/lsp/release.lua' ]] || die "Expected exactly manifest and LSP metadata changes"
  git cat-file -e "$head:lua/copilot/lsp/release.lua" || die "Missing LSP metadata"
}

reconcile() {
  local head version tag remote sha parent prs existing
  head=$(git rev-parse --verify HEAD) || die "Invalid HEAD"
  version=$(ref_version "$head") || die "Invalid HEAD manifest"
  tag="v$version"
  remote=$(git ls-remote --tags origin "refs/tags/$tag") || die "Unable to read remote tags"
  if [[ -n "$remote" ]]; then
    published_boundary "$tag" "$head"
    return
  fi
  sha=$(git log --first-parent --format=%H -1 "$head" -- .release-please-manifest.json) || die "Unable to locate manifest change"
  [[ -n "$sha" ]] || die "No manifest change found"
  parent=$(git rev-parse --verify "$sha^1") || die "Manifest change has no parent"
  prs=$(gh api "repos/$GITHUB_REPOSITORY/commits/$sha/pulls?per_page=100" --paginate --slurp) || die "Unable to read merged PR provenance"
  jq -e --arg sha "$sha" --arg repo "$GITHUB_REPOSITORY" '
    type == "array" and all(.[]; type == "array") and
    ([.[][] | select(
      (.merged_at | type == "string" and length > 0) and
      .merge_commit_sha == $sha and .base.ref == "master" and
      .base.repo.full_name == $repo and .head.repo.full_name == $repo and
      .head.ref == "create-pull-request/update-copilot-lsp"
    )] | length == 1)
  ' <<<"$prs" >/dev/null || die "Unverified merged LSP PR for $sha"
  check_pr "$parent" "$sha"
  if git show-ref --verify --quiet "refs/tags/$tag"; then
    existing=$(git rev-parse --verify "refs/tags/$tag^{commit}") || die "Invalid existing tag"
    [[ "$existing" == "$sha" ]] || die "$tag already points to $existing"
  else
    git tag "$tag" "$sha"
  fi
  git push origin "refs/tags/$tag"
  published_boundary "$tag" "$head"
}

command=${1:-}
case "$command" in
  needs-lsp-update)
    [[ $# -eq 2 ]] || die "Usage: $0 needs-lsp-update <resolved-lsp-version>"
    stable_version "$2" || die "Invalid resolved LSP version: $2"
    installed=$(installed_lsp_version) || die "Unable to read installed LSP version"
    if [[ "$installed" == "$2" ]]; then
      printf 'false\n'
    else
      printf 'true\n'
    fi
    ;;
  next-patch)
    [[ $# -eq 1 ]] || die "Usage: $0 next-patch"
    next_patch
    ;;
  check-pr)
    [[ $# -eq 3 ]] || die "Usage: $0 check-pr <base-ref> <head-ref>"
    api_setup
    check_pr "$2" "$3"
    ;;
  reconcile)
    [[ $# -eq 1 ]] || die "Usage: $0 reconcile"
    api_setup
    reconcile
    ;;
  *)
    die "Usage: $0 {needs-lsp-update <version>|next-patch|check-pr <base-ref> <head-ref>|reconcile}"
    ;;
esac
