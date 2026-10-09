# myskills

Agent skills I use, pulled from their upstream repositories as git submodules.

## Layout

```
vendor/<name>/    # git submodule -> upstream repository (partial clone)
skills/<skill>/   # symlink -> the skill directory inside a submodule
```

Each submodule points at an upstream repository and is named after it. A repository can hold one or
more skills at any depth; a skill is any directory containing a `SKILL.md` with `name` and
`description` front matter.

The links in `skills/` are what this repository exposes, and they also decide what is downloaded: a
skill loader pointed at `skills/` finds `<skill-name>/SKILL.md` no matter where the skill sits
upstream. Submodules are partial clones (`--filter=blob:none`) whose working trees are trimmed to
the linked skill directories, so taking three skills out of github/awesome-copilot costs about 5MB
instead of roughly 100MB.

## Sources

| Submodule | Upstream | Skills |
| --- | --- | --- |
| `vendor/gh-stack` | [github/gh-stack](https://github.com/github/gh-stack) | `gh-stack` |
| `vendor/pir` | [beiyanpiki/pir](https://github.com/beiyanpiki/pir) | `pir` |
| `vendor/awesome-copilot` | [github/awesome-copilot](https://github.com/github/awesome-copilot) | `git-commit`, `github-issues`, `markdown-to-html` |

## Setup

```
git clone git@github.com:<you>/myskills.git myskills
cd myskills
bin/sync-submodules.sh
```

`bin/sync-submodules.sh` clones the submodules without blobs and checks out only the skill
directories linked from `skills/`. Git keeps that state in `.git/modules/`, outside this repository,
so a fresh clone runs the script once. Until then the `skills/` links are dangling.

`git clone --recurse-submodules` also works, but it checks out every submodule in full, which is
about 100MB for `vendor/awesome-copilot` alone. `bin/sync-submodules.sh --full` does the same on
demand: every submodule gets a complete working tree, downloading the remaining blobs.

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
bin/add-skill-repo.sh https://github.com/github/awesome-copilot \
  --skill git-commit --skill github-issues --skill markdown-to-html
```

The first argument is the repository, an optional second argument names the directory under
`vendor/`, and `--skill` selects which skills to expose, repeatable; without it every skill in the
repository is exposed. The command clones the submodule, creates the links under `skills/` and trims
the working tree.

Commit `.gitmodules`, the new `vendor/` submodule and the new links, then add a row to the Sources
table above. To drop a skill, delete its link, run `bin/sync-submodules.sh` and commit.
