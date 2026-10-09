#!/usr/bin/env bash
# Materialize the submodules under vendor/ that the links in skills/ point into, and trim each
# working tree to the linked skill directories.
#
#   bin/sync-submodules.sh          # default
#   bin/sync-submodules.sh --full   # complete working trees for every submodule
#
# Submodules are partial clones (--filter=blob:none, no checkout), so only the blobs behind the
# linked skills are downloaded: github/awesome-copilot costs a few MB instead of roughly 100MB.
# The links in skills/ are the source of truth, so a skill is materialized only if something links
# to it. Git keeps the partial-clone and sparse-checkout state in .git/modules/, outside this
# repository, so run this once after cloning.

set -euo pipefail

usage() {
  cat >&2 <<'USAGE'
Usage: bin/sync-submodules.sh [--sparse|--full]

  --sparse  materialize and trim the submodules that skills/ links point into (default)
  --full    materialize every submodule with complete working trees
USAGE
}

mode=sparse
case "${1:-}" in
  ""|--sparse) ;;
  --full) mode=full ;;
  *) usage; exit 2 ;;
esac

cd "$(git rev-parse --show-toplevel)"

declare -A paths urls branches wanted

while read -r key value; do
  name=${key#submodule.}
  case $key in
    *.path)   paths[${name%.path}]=$value ;;
    *.url)    urls[${name%.url}]=$value ;;
    *.branch) branches[${name%.branch}]=$value ;;
  esac
done < <(git config -f .gitmodules --get-regexp '^submodule\.' || true)

if (( ${#paths[@]} == 0 )); then
  echo "no submodules configured"
  exit 0
fi

while read -r link; do
  target=$(readlink "$link")
  case $target in
    ../*) rel=${target#../} ;;
    *)    echo "warning: $link does not start with ../, skipping" >&2; continue ;;
  esac
  for sub in "${!paths[@]}"; do
    case $rel in
      "${paths[$sub]}/"*)
        dir=${rel#"${paths[$sub]}"/}
        wanted["${paths[$sub]}"]+="$dir"$'\n'
        ;;
    esac
  done
done < <(find skills -maxdepth 1 -type l 2>/dev/null | sort)

materialize() {
  local path=$1 url=$2 branch=$3
  [[ -e $path/.git ]] && return 0
  local args=(--quiet --filter=blob:none --no-checkout)
  [[ -n $branch ]] && args+=(--branch "$branch")
  git clone "${args[@]}" "$url" "$path"
  git submodule absorbgitdirs "$path" >/dev/null 2>&1
}

for sub in $(printf '%s\n' "${!paths[@]}" | sort); do
  path=${paths[$sub]}
  sha=$(git ls-files -s -- "$path" | awk '{print $2}')

  if [[ $mode == full ]]; then
    materialize "$path" "${urls[$sub]}" "${branches[$sub]:-}"
    git -C "$path" sparse-checkout disable
    if [[ -n $sha ]]; then
      git -C "$path" -c advice.detachedHead=false checkout -q "$sha"
    else
      git -C "$path" checkout -q
    fi
    echo "full checkout:   $path"
    continue
  fi

  mapfile -t dirs < <(printf '%s' "${wanted[$path]:-}" | sort -u | sed '/^$/d')

  if (( ${#dirs[@]} == 0 )); then
    echo "skipped:         $path (no entry in skills/ links into it)"
    continue
  fi

  patterns=()
  for dir in "${dirs[@]}"; do
    patterns+=("/$dir/")
  done

  materialize "$path" "${urls[$sub]}" "${branches[$sub]:-}"
  git -C "$path" sparse-checkout set --no-cone "${patterns[@]}"
  if [[ -n $sha ]]; then
    git -C "$path" -c advice.detachedHead=false checkout -q "$sha"
  else
    git -C "$path" checkout -q
  fi
  echo "sparse checkout: $path -> ${patterns[*]}"
done
