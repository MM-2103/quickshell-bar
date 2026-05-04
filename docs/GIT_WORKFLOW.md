# Git Workflow

Rules for working with git in this repo. Applies equally to humans and
AI agents — if anything, agents need it more, since the temptation to
"just commit on master because the working tree is clean" is real.

> Companion docs:
> - [`AGENTS.md`](AGENTS.md) — orientation for contributors and AI agents
> - [`STYLE.md`](STYLE.md) — visual + structural conventions
> - [`README.md`](../README.md) — install + user-facing overview

---

## The three rules

1. **Never commit or push directly to `master`.**
2. **Every feature, fix, or doc tweak goes on its own branch.**
3. **Rebase, don't merge,** when bringing branches up to date with master.

That's it. The rest of this file is the *how* — branch naming, recovery
from accidental master commits, and the rebase-merge mechanics.

---

## Starting any work

Before the first edit, always branch:

```bash
git fetch origin
git checkout master
git pull --rebase origin master         # make sure local master is current
git checkout -b <area>/<short-description>
```

Even for a one-line typo fix in a doc. Discipline is cheaper than
recovery.

### Branch naming

`<area>/<topic>` — area matches the commit-message areas already in
use throughout the repo (see [`STYLE.md`](STYLE.md#commit-message-style)
for the canonical list). Examples:

```
themes/preset-catalogue
settings/colorpicker-keyboard-nav
docs/git-workflow
compositor/sway-layout-osd
bar/bluetooth-tooltip
launcher/calc-precision
```

Lowercase, kebab-case in the topic, no trailing dots. Keep topics
short — the branch is ephemeral, the commit messages carry the detail.

---

## Committing

Commits inside a branch follow the same `<area>: <imperative summary>`
convention as the rest of the repo (see [`STYLE.md`](STYLE.md#commit-message-style)).
Small, atomic, smoke-tested. Multiple commits per branch is fine and
often desirable — a feature-sized change might land 5–10 commits on
one branch.

---

## Pushing and opening PRs

When the work on a branch is ready for review:

```bash
git push -u origin <branch-name>
gh pr create --title "<area>: <summary>" --body "..."
```

The PR title should match the lead commit's subject style. The body
should explain *why*, not what (the diff already shows the what). For
multi-commit branches, a short bullet list of the logical pieces is
helpful.

After merge, the branch can be deleted both locally and on origin:

```bash
git checkout master
git pull --rebase origin master
git branch -d <branch-name>
git push origin --delete <branch-name>
```

---

## Keeping a branch up to date with master

While your branch is open, master may move forward. **Rebase**, don't
merge:

```bash
git fetch origin
git rebase origin/master
```

If conflicts surface during the rebase:

```bash
# edit the conflicted files, then:
git add <file>
git rebase --continue

# or, if it's a mess and you want to back out:
git rebase --abort
```

After a rebase, your local branch's history has been rewritten — so
the next push needs `--force-with-lease`:

```bash
git push --force-with-lease
```

**`--force-with-lease`, never plain `--force`.** With-lease checks that
the remote tip hasn't moved since you last fetched; if someone else
pushed to your branch in the meantime, the push will be rejected so
you can investigate. Plain `--force` clobbers their work silently.

### Why rebase, not merge

Merge commits clutter `git log` with diamond-shaped history that's
hard to read. Linear history (one commit per logical change, in order)
makes `git log --oneline` a faithful changelog. The repo's existing
history is fully linear; preserve that.

---

## Recovery: "I committed to master by accident"

This was the prompt for this doc — exactly what happened on the themes
feature work. The recovery depends on whether the bad commits have
been pushed to origin yet.

### Case A: not yet pushed (only local master is "wrong")

```bash
# 1. Create the feature branch at the current (wrong) master tip
git branch <feature-branch>

# 2. Move local master back to where origin/master is
git reset --hard origin/master

# 3. Switch to the feature branch and continue normally
git checkout <feature-branch>
git push -u origin <feature-branch>
gh pr create ...
```

This is the painless case. Local-only mistakes are always recoverable.

### Case B: already pushed to origin/master

You have three options:

1. **Accept it.** The commits are on master, the work is good, the
   merge has effectively happened just without a PR. Move on; create
   a branch for the *next* piece of work and follow the rules from
   there.

2. **Force-push to rewrite origin/master** (requires explicit user
   sign-off — this is a destructive remote operation):
   ```bash
   git branch <feature-branch> origin/master
   git push origin <feature-branch>
   git reset --hard <known-good-master-sha>
   git push --force-with-lease origin master
   ```
   Anyone else who's pulled the affected commits will need to reset
   their local master too. **Don't do this without asking.**

3. **Revert the commits and re-do via PR.** Slowest but never
   destructive:
   ```bash
   git revert <bad-sha-1> <bad-sha-2> ...
   git push origin master
   git checkout -b <feature-branch> <bad-sha-N>     # the work pre-revert
   git push -u origin <feature-branch>
   gh pr create ...
   ```

For a personal repo where only the user pulls master, option 1 is
usually the right call — the cost of rewriting history outweighs the
cosmetic win.

---

## Things to never do

- **`git push --force` to master** (or any shared branch). Use
  `--force-with-lease` and only on YOUR feature branch.
- **`git push --force-with-lease` to master.** Even with-lease, master
  is a shared branch; the only acceptable rewrites to master are via
  merged PRs.
- **`git commit --no-verify`** (skipping pre-commit hooks) unless the
  user explicitly asks. Hooks are there for a reason.
- **`git commit --amend`** to a commit that has already been pushed.
  Amending changes the SHA, and the next push would need a force.
  If you must amend a published commit, ask the user first.
- **`git merge` master into your feature branch.** Rebase instead.
- **Long-lived feature branches.** A branch that's been open for
  weeks is a merge-conflict factory. Land it or close it.

---

## TL;DR for AI agents

If you're reading this as part of a multi-step build:

1. **First action of any work session:** `git checkout -b <area>/<topic>`.
2. **Before each commit:** smoke-test, atomic edit, `<area>:` prefix.
3. **End of session:** push the branch, open a PR. Don't ask "should
   I push directly to master?" — the answer is always no.
4. **If you slipped and committed to local master:** Case A above
   fixes it before anyone notices.
