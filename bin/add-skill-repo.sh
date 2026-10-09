#!/usr/bin/env bash
# Add an upstream repository that ships agent skills, and expose the skills you want through
# skills/ links.
#
#   bin/add-skill-repo.sh <git-url> [name] [--skill <skill>]...
#
#   <git-url>  clone URL of the upstream repository
#   [name]     directory name under vendor/, defaults to the repository name
#   --skill    skill directory to expose, repeatable; the default is every skill in the repository
#
# Examples:
#   bin/add-skill-repo.sh https://github.com/github/gh-stack
#   bin/add-skill-repo.sh https://github.com/github/awesome-copilot \
#     --skill git-commit --skill github-issues --skill markdown-to-html
#
# The submodule is a partial clone under vendor/ and tracks the upstream default branch, so
# `git submodule update --remote` picks up new commits. bin/sync-submodules.sh runs at the end to
# download and trim the working tree to the linked skills.

set -euo pipefail

usage() {
  cat >&2 <<'USAGE'
Usage: bin/add-skill-repo.sh <git-url> [name] [--skill <skill>]...

  <git-url>  clone URL of the upstream repository
  [name]     directory name under vendor/, defaults to the repository name
  --skill    skill directory to expose, repeatable; default is every skill in the repository
USAGE
}

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

skills=()
positional=()

while (( $# )); do
  case $1 in
    --skill)   shift; [[ $# ]] || { usage; exit 2; }; skills+=("$1") ;;
    --skill=*) skills+=("${1#--skill=}") ;;
    -h|--help) usage; exit 0 ;;
    -*)        usage; exit 2 ;;
    *)         positional+=("$1") ;;
  esac
  shift
done

if (( ${#positional[@]} < 1 || ${#positional[@]} > 2 )); then
  usage
  exit 2
fi

url=${positional[0]}
name=${positional[1]:-$(basename "${url%.git}")}
path="vendor/$name"

cd "$(git rev-parse --show-toplevel)"

if [[ -e $path ]]; then
  echo "error: $path already exists" >&2
  exit 1
fi

branch=$(git ls-remote --symref "$url" HEAD | awk '/^ref:/ {sub("refs/heads/", "", $2); print $2; exit}')

mkdir -p vendor

clone_args=(--quiet --filter=blob:none --no-checkout)
[[ -n $branch ]] && clone_args+=(--branch "$branch")
git clone "${clone_args[@]}" "$url" "$path"

# The clone above is registered as a submodule; git prints "Adding existing repo" for it, which is
# expected, so only surface output when the registration fails.
if [[ -n $branch ]]; then
  add_args=(-b "$branch")
else
  add_args=()
fi

if ! add_output=$(git submodule add --quiet "${add_args[@]}" "$url" "$path" 2>&1); then
  printf '%s\n' "$add_output" >&2
  exit 1
fi
git submodule absorbgitdirs "$path" >/dev/null 2>&1

# Read the skill directories from the object database, which a partial clone already has.
mapfile -t available < <(
  git -C "$path" ls-tree -r --name-only HEAD | sed -n 's|\(^.*\)/SKILL\.md$|\1|p' | sort -u
)

if (( ${#available[@]} == 0 )); then
  echo "error: no SKILL.md found in $url" >&2
  exit 1
fi

selected=()

if (( ${#skills[@]} )); then
  for want in "${skills[@]}"; do
    match=
    for dir in "${available[@]}"; do
      [[ ${dir##*/} == "$want" ]] && match=$dir
    done
    if [[ -z $match ]]; then
      echo "error: no skill '$want' in $url" >&2
      printf 'available: %s\n' "${available[@]##*/}" >&2
      exit 1
    fi
    selected+=("$match")
  done
else
  selected=("${available[@]}")
fi

mkdir -p skills

for dir in "${selected[@]}"; do
  link="skills/${dir##*/}"
  if [[ -e $link || -L $link ]]; then
    echo "error: $link already exists" >&2
    exit 1
  fi
  ln -s "../$path/$dir" "$link"
  echo "linked:          $link -> ../$path/$dir"
done

"$script_dir/sync-submodules.sh"
