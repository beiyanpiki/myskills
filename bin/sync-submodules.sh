#!/usr/bin/env bash
# Check out the submodules and keep only the folders holding skills in their working trees.
#
#   bin/sync-submodules.sh          # init/update submodules, trim each one to its skill folders
#   bin/sync-submodules.sh --full   # restore the complete working tree of every submodule
#
# A submodule references a whole repository, so a skill that lives in a subdirectory brings the
# rest of that project along. Sparse-checkout limits each submodule's working tree to the
# directories containing a SKILL.md. The pinned commit and the fetched objects are unchanged;
# only the files checked out shrink.
#
# Git keeps sparse-checkout patterns in .git/modules/, which is not part of this repository, so a
# fresh clone has to run this script once.

set -euo pipefail

usage() {
  cat >&2 <<'USAGE'
Usage: bin/sync-submodules.sh [--sparse|--full]

  --sparse  only check out the folders that contain a SKILL.md (default)
  --full    check out every submodule in full
USAGE
}

case "${1:-}" in
  ""|--sparse) mode=sparse ;;
  --full) mode=full ;;
  *) usage; exit 2 ;;
esac

cd "$(git rev-parse --show-toplevel)"

git submodule update --init --recursive

while read -r path; do
  [[ -d $path ]] || continue

  if [[ $mode == full ]]; then
    git -C "$path" sparse-checkout disable
    echo "full checkout:   $path"
    continue
  fi

  if git -C "$path" ls-files | grep -qx 'SKILL.md'; then
    echo "skipped:         $path (SKILL.md sits at the repository root)"
    continue
  fi

  mapfile -t dirs < <(git -C "$path" ls-files |
    sed -n 's|\(^.*\)/SKILL\.md$|\1|p' | sort -u)

  if (( ${#dirs[@]} == 0 )); then
    echo "skipped:         $path (no SKILL.md)"
    continue
  fi

  patterns=()
  for dir in "${dirs[@]}"; do
    patterns+=("/$dir/")
  done

  git -C "$path" sparse-checkout set --no-cone "${patterns[@]}"
  echo "sparse checkout: $path -> ${patterns[*]}"
done < <(git config -f .gitmodules --get-regexp '^submodule\..*\.path$' | cut -d' ' -f2)
