# claude-push 🚀

Two Claude Code slash commands that turn "commit, push, open a PR" into one keystroke each.

- **`/push`** — reads your diff, writes the commit message, commits, pushes.
- **`/pr`** — opens a draft PR (or updates the existing one) and hands you the link.

## Install

```sh
git clone https://github.com/nathanjcx/claude-push ~/claude-push
~/claude-push/install.sh
```

Restart Claude Code once after installing. Requires the [GitHub CLI](https://cli.github.com) (`brew install gh`, then `gh auth login`).

## `/push`

```
$ /push
↳ on main → created `fix/token-refresh-race`
a1b2c3d fix: retry token refresh on 401
→ pushed → https://github.com/you/repo/tree/fix/token-refresh-race
```

- **Never commits to `main`.** If you're on the default branch it auto-creates a descriptive branch from your diff first — no prompt, it just tells you what it named it.
- **Splits by theme.** Stages everything, but if the changes are clearly unrelated it makes 2–3 logical commits instead of one mush commit. Never more than 3.
- **Matches your repo's message style** by reading the existing log — conventional-commit prefixes only if you already use them.
- **Skips secrets.** Won't stage `.env*`, `*.pem`, `*.key`, `id_rsa*`, or credential files, and says so when it skips something.
- **Respects hooks.** Re-stages and retries once if a pre-commit hook rewrites files. Never `--no-verify`, never `--force`.

`/push some context here` passes you a hint for the branch name and message.

## `/pr`

```
$ /pr
✓ draft PR #142 created
  https://github.com/you/repo/pull/142
```

- Opens PRs **as drafts**, with a summary and test plan written from the real diff.
- Pushes unpushed commits for you; stops and says `⚠ N uncommitted files — run /push first` if the tree is dirty.
- **Re-running it on an existing PR will not eat your attachments.** This is the whole reason the command exists.

### How the media guard works

GitHub attachment URLs are unrecoverable once they're gone from a PR body, so `/pr` treats an existing body as append-only unless it can prove otherwise:

1. Dumps the current body and inventories every image, video, and attachment reference in it — markdown images, raw `<img>`/`<video>`/`<source>` tags, and `user-attachments` / `assets` / `githubusercontent` URLs.
2. Rewrites **only** the region between `<!-- claude:summary:start -->` and `<!-- claude:summary:end -->`. Everything outside those markers stays byte-identical.
3. A body with no markers keeps 100% of its content — the new summary goes above it, under a `---`.
4. Re-inventories the new body before writing. If even one reference from step 1 is missing, it **aborts and tells you** rather than editing the PR.

It also uses `--body-file` rather than `--body`, and never touches labels, reviewers, assignees, milestone, base branch, or draft/ready state on a PR that already exists.

## Customize

The commands are plain markdown — `push.md` and `pr.md` in this repo, symlinked into `~/.claude/commands/`, so edits apply on your next Claude Code session with no reinstall.

Want it to allow commits to `main`? Delete the "Branch guard" section of `push.md`. Want PRs opened ready-for-review instead of draft? Drop `--draft` from `pr.md`.

## Uninstall

```sh
~/claude-push/uninstall.sh
```

Only removes symlinks it created — a `/push` of your own is left alone.
