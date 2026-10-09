#!/usr/bin/env bash
# Check out the submodules, trim them to the folders that hold skills, and refresh the skills/
# links.
#
#   bin/sync-submodules.sh          # default: trimmed submodules plus the skills/ links
#   bin/sync-submodules.sh --full   # restore the complete working tree of every submodule
#
# Submodules live under vendor/ and reference whole repositories, so a skill kept in a
# subdirectory would otherwise drag the rest of that project into the checkout. Sparse-checkout
# limits each submodule's working tree to the directories containing a SKILL.md, and each of those
# directories is exposed as skills/<skill-name>, which is the layout skill loaders expect.
#
# Git keeps sparse-checkout patterns in .git/modules/, outside this repository, so run this once
# after cloning. The skills/ links are committed, so they exist without it.

set -euo pipefail

usage() {
  cat >&2 <<'USAGE'
Usage: bin/sync-submodules.sh [--sparse|--full]

  --sparse  check out only the folders that contain a SKILL.md (default)
  --full    check out every submodule in full
USAGE
}

mode=sparse
case "${1:-}" in
  ""|--sparse) ;;
  --full) mode=full ;;
  *) usage; exit 2 ;;
esac

cd "$(git rev-parse --show-toplevel)"

mapfile -t submodules < <(
  git config -f .gitmodules --get-regexp '^submodule\..*\.path$' | cut -d' ' -f2
)

git submodule update --init --recursive

skill_dirs=()

for path in "${submodules[@]}"; do
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

  mapfile -t dirs < <(
    git -C "$path" ls-files | sed -n 's|\(^.*\)/SKILL\.md$|\1|p' | sort -u
  )

  if (( ${#dirs[@]} == 0 )); then
    echo "skipped:         $path (no SKILL.md)"
    continue
  fi

  patterns=()
  for dir in "${dirs[@]}"; do
    patterns+=("/$dir/")
    skill_dirs+=("$path/$dir")
  done

  git -C "$path" sparse-checkout set --no-cone "${patterns[@]}"
  echo "sparse checkout: $path -> ${patterns[*]}"
done

if [[ $mode == full ]]; then
  exit 0
fi

mkdir -p skills

for dir in "${skill_dirs[@]}"; do
  name=$(basename "$dir")
  link="skills/$name"
  target="../$dir"

  if [[ -L $link ]]; then
    if [[ $(readlink "$link") == "$target" ]]; then
      echo "link ok:         $link -> $target"
      continue
    fi
    echo "error: $link points at $(readlink "$link"), expected $target" >&2
    exit 1
  fi

  if [[ -e $link ]]; then
    echo "error: $link exists and is not a symlink" >&2
    exit 1
  fi

  ln -s "$target" "$link"
  echo "linked:          $link -> $target"
done
