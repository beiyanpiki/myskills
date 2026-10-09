# myskills

Agent skills I use, pulled from their upstream repositories as git submodules.

## Layout

```
vendor/<name>/    # git submodule -> upstream repository
skills/<skill>/   # symlink -> the skill directory inside a submodule
```

Each submodule points at an upstream repository and is named after it. A repository can hold one or
more skills at any depth; a skill is any directory containing a `SKILL.md` with `name` and
`description` front matter.

`skills/` is the directory to point a skill loader at. Every entry is a symlink to the directory
holding a `SKILL.md`, so `skills/<skill-name>/SKILL.md` resolves no matter where the skill sits
upstream. Submodules stay under `vendor/` and their working trees are trimmed to the skill
directories.

## Sources

| Submodule | Upstream | Skill link | SKILL.md |
| --- | --- | --- | --- |
| `vendor/gh-stack` | [github/gh-stack](https://github.com/github/gh-stack) | `skills/gh-stack` | `skills/gh-stack/SKILL.md` |

## Setup

```
git clone --recurse-submodules git@github.com:<you>/myskills.git myskills
bin/sync-submodules.sh
```

For a clone that already exists:

```
git submodule update --init --recursive
bin/sync-submodules.sh
```

The symlinks are committed and a full submodule checkout contains their targets, so
`git clone --recurse-submodules` already leaves `skills/gh-stack/SKILL.md` readable.
`bin/sync-submodules.sh` then trims each submodule to the directories holding a `SKILL.md`: a
submodule references a whole repository, so `vendor/gh-stack` would otherwise keep `cmd/`,
`internal/`, `docs/` and the other Go sources around. The pinned commit and the fetched objects are
untouched, and `bin/sync-submodules.sh --full` restores the complete working tree.

Git keeps sparse-checkout patterns in `.git/modules/`, outside this repository, so a fresh clone
runs the script once. Plain `git submodule update --init` afterwards leaves the trimmed working tree
alone.

Cloning without `--recurse-submodules` leaves the `skills/` links dangling until the submodules are
initialized.

## Updating submodules

Submodule revisions are pinned by this repository, so `git submodule update --init` restores the
exact commits recorded here. To move every submodule to the tip of the branch it tracks:

```
git submodule update --remote --merge
git add vendor
git commit -m "chore: bump skill submodules"
```

## Adding a repository

```
bin/add-skill-repo.sh https://github.com/github/gh-stack
```

It adds the submodule under `vendor/`, then runs `bin/sync-submodules.sh` to trim the checkout and
create the link. The same thing by hand:

```
git submodule add -b main https://github.com/github/gh-stack vendor/gh-stack
bin/sync-submodules.sh
```

Commit `.gitmodules`, the new `vendor/` submodule and the `skills/` link, then add the row to the
Sources table above.
