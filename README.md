# myskills

Agent skills I use, pulled from their upstream repositories as git submodules.

## Layout

```
skills/<name>/    # git submodule -> upstream repository
```

Each submodule points at an upstream repository and is named after it. A repository can hold one
or more skills at any depth; a skill is any directory containing a `SKILL.md` with `name` and
`description` front matter.

## Sources

| Submodule | Upstream | SKILL.md |
| --- | --- | --- |
| [`skills/gh-stack`](skills/gh-stack) | [github/gh-stack](https://github.com/github/gh-stack) | [`skills/gh-stack/skills/gh-stack/SKILL.md`](skills/gh-stack/skills/gh-stack/SKILL.md) |

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

`bin/sync-submodules.sh` limits each submodule's working tree to the folders holding a `SKILL.md`.
A submodule references a whole repository, so a skill that lives in a subdirectory otherwise drags
the rest of that project along; here `skills/gh-stack` keeps only `skills/gh-stack/` and drops
`cmd/`, `internal/`, `docs/` and the other Go sources. The pinned commit and the fetched objects
are untouched, and `bin/sync-submodules.sh --full` restores the complete working tree.

Git keeps the sparse-checkout patterns in `.git/modules/`, outside this repository, so a fresh
clone has to run the script once. Plain `git submodule update --init` afterwards does not expand
the working tree again.

## Updating submodules

Submodule revisions are pinned by this repository, so `git submodule update --init` restores the
exact commits recorded here. To move every submodule to the tip of the branch it tracks:

```
git submodule update --remote --merge
git add skills
git commit -m "chore: bump skill submodules"
```

## Adding a repository

```
bin/add-skill-repo.sh https://github.com/github/gh-stack
bin/sync-submodules.sh
```

The same thing by hand:

```
git submodule add -b main https://github.com/github/gh-stack skills/gh-stack
```

Then add the repository and the paths of the skills it provides to the Sources table above.
