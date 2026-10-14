---
name: work-with-pr
description: "Deliver implementation work as a pull request in any repository: split a task into atomic PRs, build each in an isolated git worktree, run the repo's own checks plus an independent review of the branch diff, open the PR against the correct base, drive CI to green, then merge and clean up. Use whenever work is meant to land through review — 'create a PR', 'implement and PR', 'implement issue #N', 'land this as a PR', 'split this into atomic PRs', '提 PR', '提个 PR 再合并', 'work-with-pr' — including when the user only says 'implement X' but PR delivery is implied. Host-agnostic (GitHub, GitLab, plain git) and agnostic about which reviewer or review tool performs the gate. Not for local-only edits that are not meant to land as a PR."
metadata:
  version: "0.1.0"
---

# Work With PR — a repo-agnostic PR lifecycle

You are delivering a change that lands through review in someone else's hands. **The unit of delivery is the smallest PR that compiles, passes, and stands on its own** — not "one task, one PR." A single task routinely splits into several atomic PRs; the lifecycle below describes one of them, so apply it to each, and build the independent ones concurrently when your environment can run several agents.

Nothing here outranks the repository. Read the repo's own instructions and CI config first, and follow them where they differ.

<architecture>

```
Phase 0: Setup        → Read repo conventions, split into atomic PRs, branch + worktree per PR
                        (independent PRs in parallel; each its own agent/worktree)
Phase 1: Implement    → One slice per PR; the repo's checks as proof; atomic commits
Phase 2: Review gate  → An independent reviewer reads the branch diff (any agent, tool, or human)
Phase 3: PR creation  → Push, open the PR against the right base, fill the repo's PR template
Phase 4: Verify loop  → Unbounded: local checks + review gate + CI, until green on the pushed code
Phase 5: Merge        → Repo's merge method, wait for MERGED, clean up the worktree, report
```

A failing gate routes back to Phase 1; you keep cycling until every gate passes on the exact code being pushed.

</architecture>

---

## Phase 0: Setup

### 1. Read the repo's conventions before inventing a workflow

Look at `CONTRIBUTING.md`, `AGENTS.md`, `README`, `.github/` (workflows, PR template, CODEOWNERS), and the last ~30 merged commits. Establish concretely:

- **What "green" means:** the exact commands CI runs and how to run them locally (package manifest scripts, Makefile targets, task runner). Those commands are your local gate; do not substitute your own.
- **Commit message convention:** the history's shape (`feat(scope): …`, plain sentences, ticket prefixes).
- **Merge method the project uses:** merge commits, squash, or rebase.
- **Branch naming and the PR base branch:** usually the default branch; a stack's parent branch otherwise.

When a convention is missing, choose something reasonable and consistent, and say what you chose in the PR body.

### 2. Decide the split

Decompose the task into the smallest PRs that each compile, pass, and deliver one reviewable slice. A 200-line PR gets a real review; a 2000-line PR gets a rubber stamp. Sequence by dependency:

- **Independent slices** branch off the default branch and can be built at the same time.
- **Dependent slices** stack: each branches off its parent's branch, and the PR base is that parent.

Carry `$BASE_REF` (the git ref to branch from and diff against) and `$BASE_BRANCH` (the PR target) through every phase instead of assuming the default branch.

### 3. Create the branch and an isolated worktree

The user's checkout may hold uncommitted work, so treat it as read-only context and never implement there.

```bash
cd <main repo dir>
git fetch origin
BRANCH="feat/short-slug"          # match the repo's naming convention
BASE_REF="origin/main"; BASE_BRANCH="main"   # stacked: both = parent branch
git worktree add -b "$BRANCH" "../wt/$BRANCH" "$BASE_REF"
cd "../wt/$BRANCH"                # siblings of the repo, never inside it
# run the repo's dependency install / bootstrap here
```

If your environment can run several agents or sessions at once, give each PR its own, with a self-contained brief: the slice, branch name, worktree path, and a pointer to this skill. Otherwise build them sequentially — the isolation comes from the per-PR worktree.

---

## Phase 1: Implement

Deliver this PR's slice, prove it, and stop. Do not refactor surrounding code, add options nobody asked for, or fix unrelated bugs; that work belongs in its own PR, and scope creep makes a failing gate impossible to attribute.

**Proof comes from the repo.** Run the commands you found in Phase 0. Add tests where the repo's conventions expect them. For changes whose behavior is not fully covered by those tests — CLI output, rendering, network calls, migrations — exercise the real surface yourself and record the command and the observed result; that evidence goes into the PR's verification section. "It typechecks" is not evidence that behavior is correct. Docs-only PRs say so instead of inventing verification.

**Commits:** atomic, one logical change each, in the repo's message style, so a CI failure can be isolated and reverted without unwinding everything. Pair each commit with its tests.

---

## Phase 2: Review gate

An author re-reading their own diff in the same pass finds little. The gate is a fresh pass over the branch diff by someone who did not write it.

**Any of these can be the reviewer.** Choose what the environment offers, in roughly this order:

1. A review tool the repo or the user already uses — a review CLI, a CI review bot, a hosted reviewer. If a skill for it is installed, use that skill's invocation.
2. A fresh agent session or subagent that receives only the task statement, the repo conventions that matter, and the diff — never your conclusions, your plan, or your reasoning. Explicitly ask it to report findings, not to praise the work.
3. A human: a draft PR requesting review, or the user.

**What the reviewer reads:**

```bash
git diff "$BASE_REF...HEAD"        # committed branch diff
git diff --staged; git diff        # add while mid-work
```

**Triage every finding against the code before acting.** Neither blind-fix nor blind-dismiss: read the code and decide.

- **Correctness, security, data-loss, or contract-breaking findings** → fix now, in this PR.
- **Smaller findings you agree with** (naming, clarity, dead code in your diff) → fix them now if they are inside the slice; otherwise record them.
- **Real issues outside the slice, or low-severity polish** → record them for a later sweep PR (or the repo's existing tracker) with the reason, and move on. Do not grow this PR.
- **False positives or intentional choices** → note the reason so the decision is auditable.

**Staleness rule:** any code change invalidates the gate. Re-run it before the next push; a review of an earlier revision does not cover the branch.

**If no independent reviewer is available or authorized** — say so plainly and record the gate as not run in the PR body. Never imply a review happened when it did not.

---

## Phase 3: PR creation

```bash
git push -u origin "$BRANCH"
gh pr create --base "$BASE_BRANCH" --title "$TITLE" --body-file pr-body.md
```

`gh` covers GitHub; use `glab` or the equivalent for GitLab, and if no host CLI is available or authorized, push the branch and hand the user the compare URL with the finished body. For `gh` command details the `gh-cli` skill covers the full surface.

**Title:** follow the repo's convention.

**Body:** if the repo has a PR template, fill it. Otherwise use this shape:

- **What & why** — what changed, why this approach, linked issues.
- **How it was verified** — the commands run, their outcomes, tests added, and the review gate result. State explicitly when the review gate did not run.
- **Scope and risk** — anything a reviewer could miss, and any convention this PR deliberately bends.
- **Deferred** — findings recorded for a later PR, when there are any.

Open a draft PR when the user wants early feedback or when the stack parent is still unmerged.

**Redaction:** PR bodies, comments, and pasted logs carry no tokens, auth headers, environment dumps, or secret-bearing output. Summarize instead of pasting.

**Formatting:** one paragraph is one source line, however long; Markdown reflows, and hard-wrapped prose makes bodies noisy to diff, edit, and quote. Lists get one line per item; code blocks and tables keep their structure. The same rule applies to prose you write to the user, in docs, and in commit messages.

---

## Phase 4: Verification loop

```
while true:
  1. Local checks   → the repo's own commands from Phase 0
  2. Review gate    → if any commit landed since the last gate run
  3. Push           → git push
  4. CI             → watch the PR's checks; on failure read the logs
  5. green          → break
```

**Watch CI in the background or at spaced intervals** — `gh pr checks --watch --fail-fast` as a background job, or `gh pr checks` every few minutes. Never sit in a tight foreground loop.

**On failure, get the logs before touching code:**

```bash
RUN_ID=$(gh run list --branch "$BRANCH" --status failure --json databaseId --jq '.[0].databaseId')
gh run view "$RUN_ID" --log-failed
```

Then fix only what the failing gate identified, re-run the local checks and the review gate (the code changed, so the previous gate is stale), push, and re-enter the loop. There is no iteration cap; the loop ends when every gate passes on exactly the code that is pushed.

**Infrastructure failures are not code failures.** A job queued with nothing running, an unrelated flaky job, or a network error gets reported; re-pushing blindly to "nudge" it wastes a round trip and hides the real state.

**Rebases and force-pushes:** rebase onto the updated base when the branch has drifted, resolve conflicts, re-verify (the code changed), then `git push --force-with-lease`. Never rewrite a branch other people are building on.

---

## Phase 5: Merge and cleanup

Merge when the user asked for the change to land ("land this", "merge it", "提个 PR 再合并"). Otherwise stop at a PR that is ready and report it — an unmerged, green PR is a complete deliverable.

```bash
gh pr merge "$PR_NUMBER" --merge --delete-branch     # use the method the repo's history shows
```

Use the repo's merge method: merge commits, `--squash`, or `--rebase`. Squashing a branch that deliberately carries atomic history, or merging where the project keeps a linear history, both fight the repository.

Do not fight a blocker: if a required human review or a protected-branch rule stops the merge, leave the PR ready and say so. Wait for the merge the same way you wait for CI — spaced checks of `gh pr view "$PR_NUMBER" --json state -q .state` — and never block in the foreground.

```bash
cd <main repo dir>
git worktree remove --force "$WORKTREE"   # --force: build artifacts and dependencies are gitignored
git worktree prune
```

Finally, report:

```
## PR Complete
- PR: #{N} — {title}
- Branch: {branch} → {base}
- Iterations: {N} passes through the verify loop
- Gates: CI {pass|fail-pending} | review {N findings fixed, M deferred, clean, or NOT RUN}
- Merged: {yes | no — ready for you to merge}
- Worktree: cleaned up
```

---

## Failure recovery

If you hit an unrecoverable error — merge conflict you cannot resolve, CI infrastructure down, missing auth or permissions:

1. Do not delete the worktree; it holds the only copy of the work in progress.
2. Report what happened, what you attempted, and the worktree path so the user can resume.
3. Leave the branch in a state the user can inspect: pushed if it was pushed, or committed locally if not.

---

## Anti-patterns

| Violation | Why it fails | Severity |
|-----------|--------------|----------|
| Implementing in the user's checkout | Can destroy uncommitted work; collides with any parallel PR | CRITICAL |
| Pushing code whose review gate ran on an earlier revision | The gate no longer covers the branch | CRITICAL |
| Pushing to the default or protected branch directly | Bypasses review entirely | CRITICAL |
| Skipping the review gate silently | The PR claims verification that never happened | HIGH |
| Scope creep inside the verify loop | New failures become indistinguishable from the original | HIGH |
| Bundling independent slices into one PR | One bad slice blocks every other one | HIGH |
| Blindly fixing or dismissing review findings | Unverified changes land, or real problems get dropped | MEDIUM |
| Assuming a merge method | Squash erases kept history; merge commits violate a squash-only repo | MEDIUM |
| Tight-looping on CI in the foreground | Burns turns and hides progress; watch in the background | MEDIUM |
| Growing the PR with deferred findings | Extra CI round trips for out-of-scope work | MEDIUM |
| Hard-wrapping PR prose at a fixed column | Noisy diffs, edits, and quotes; one paragraph = one line | LOW |
