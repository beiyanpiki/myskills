#!/usr/bin/env bash
# Add an upstream repository that ships agent skills, as a git submodule under vendor/.
#
#   bin/add-skill-repo.sh <git-url> [name]
#
#   <git-url>  clone URL of the upstream repository
#   [name]     directory name under vendor/, defaults to the repository name
#
# The submodule tracks the upstream default branch, so `git submodule update --remote` picks up
# new commits. bin/sync-submodules.sh runs at the end to trim the checkout and refresh the
# skills/ links.

set -euo pipefail

usage() {
  cat >&2 <<'USAGE'
Usage: bin/add-skill-repo.sh <git-url> [name]

  <git-url>  clone URL of the upstream repository
  [name]     directory name under vendor/, defaults to the repository name
USAGE
}

if [[ $# -lt 1 || $# -gt 2 ]]; then
  usage
  exit 2
fi

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
url=$1
name=${2:-$(basename "${url%.git}")}
path="vendor/$name"

cd "$(git rev-parse --show-toplevel)"

if [[ -e $path ]]; then
  echo "error: $path already exists" >&2
  exit 1
fi

branch=$(git ls-remote --symref "$url" HEAD | awk '/^ref:/ {sub("refs/heads/", "", $2); print $2; exit}')
if [[ -n $branch ]]; then
  git submodule add -b "$branch" "$url" "$path"
else
  git submodule add "$url" "$path"
fi

"$script_dir/sync-submodules.sh"
