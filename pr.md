---
description: Open a draft PR, or update the existing one without destroying attached images/media. Works from any directory.
argument-hint: [repo name/path and/or context, e.g. "claude-push" or "target release-2"]
allowed-tools: Bash(git:*), Bash(gh:*), Bash(pwd), Bash(find:*)
---

The user ran `/pr $ARGUMENTS`. Extra context from them (may be empty): $ARGUMENTS

## Repo state

- Working dir: !`pwd`
- Repo here: !`git rev-parse --show-toplevel 2>/dev/null || echo "NOT-A-GIT-REPO"`
- Repos with branches worth a PR: !`find "$HOME" -maxdepth 3 \( -name Library -o -name .Trash -o -name node_modules -o -name .npm -o -name .cache -o -name Applications \) -prune -o -name .git -type d -print 2>/dev/null | while read -r g; do r="${g%/.git}"; b=$(git -C "$r" rev-parse --abbrev-ref HEAD 2>/dev/null) || continue; d=$(basename "$(git -C "$r" symbolic-ref -q refs/remotes/origin/HEAD 2>/dev/null || echo origin/main)"); n=$(git -C "$r" status --porcelain 2>/dev/null | wc -l | tr -d ' '); a=$(git -C "$r" log --oneline "origin/$d"..HEAD 2>/dev/null | wc -l | tr -d ' '); [ "$b" = "$d" ] && [ "$n" = 0 ] && continue; [ "$a" = 0 ] && [ "$n" = 0 ] && continue; echo "$r [$b] dirty=$n ahead-of-$d=$a"; done | head -12 || echo "-"`
- Branch here: !`git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "-"`
- Default branch here: !`basename "$(git symbolic-ref -q refs/remotes/origin/HEAD 2>/dev/null || echo origin/main)" 2>/dev/null || echo "-"`
- Uncommitted here: !`git status --short 2>/dev/null | head -40 || echo "-"`
- Unpushed here: !`git log --oneline @{u}..HEAD 2>/dev/null || echo "no upstream — branch not on GitHub yet"`
- Existing PR here: !`gh pr view --json number,url,title,isDraft,baseRefName,state 2>/dev/null || echo "none for this branch"`

## What to do

**0. Pick the target repo — this command is not tied to the current directory.**
Resolve `$ROOT` in this order, stopping at the first that applies:
1. `$ARGUMENTS` names a path or repo name matching one of the repos listed above → use it.
2. The current directory is a repo → use it.
3. Exactly one repo listed above → use it.
4. You've been editing files in one specific repo this session and it appears above → use it.
5. Otherwise → list the candidates, ask which one, and stop.

If nothing resolves, say so in one line and stop.

**Run every command as `git -C "$ROOT" …` and `gh -R <owner/repo> …`** (get the slug from `git -C "$ROOT" remote get-url origin`) so this works from anywhere. If `$ROOT` isn't the current directory, the "here" lines above describe the wrong repo — re-gather branch, base, commits, and existing-PR state for `$ROOT` first.

**1. Preconditions.**
- Uncommitted changes → stop. Print `⚠ N uncommitted files — run /push first` and list them. Do not commit anything yourself.
- On the default branch → stop and say the work needs a feature branch (`/push` will create one).
- Unpushed commits → push them first (`push -u origin HEAD` if no upstream, else `push`). Never force-push.
- No commits vs. the base branch → stop and say there's nothing to open a PR for.

**2. Write the summary.**
Read the actual diff (`git -C "$ROOT" diff origin/<base>...HEAD`) and the commit log. Write:
- **Title**: ≤ 70 chars, imperative, what this PR does. Match the repo's PR conventions if recent titles show one (`gh pr list --limit 10 --json title`).
- **Body**: a `## Summary` section (2–5 bullets, effect-first) and a `## Test plan` section (real commands or steps; tick boxes only for what actually ran). Follow your session's PR attribution/footer guidance.

Wrap the generated part in markers so future runs can update it safely:

```
<!-- claude:summary:start -->
…summary + test plan + attribution footer…
<!-- claude:summary:end -->
```

**3a. No existing PR → create it as a draft.**
Write the body to a temp file, then:
`gh pr create --draft --base <base> --title "<title>" --body-file <tmpfile>`
Base is the repo default branch unless the user's arguments say otherwise.

**3b. Existing PR → update it, and preserve everything the user added.**

This is the part that must not go wrong. The body may contain images, videos, and file attachments the user dragged into GitHub, and those references are unrecoverable if you drop them.

1. Fetch the current body to a temp file: `gh pr view --json body -q .body > <tmp_old>`.
2. Inventory every media/attachment reference in the old body — count them, keep the exact strings:
   - markdown images `![...](...)` and any link whose target ends in `.png .jpg .jpeg .gif .webp .svg .mp4 .mov .webm .pdf`
   - raw HTML `<img …>`, `<video …>`, `<source …>`, `<picture>` blocks (keep the full tag verbatim, attributes included)
   - `https://github.com/user-attachments/...`, `https://github.com/<owner>/<repo>/assets/...`, `https://user-images.githubusercontent.com/...`
3. Build the new body:
   - Old body has the `claude:summary` markers → replace **only** the text between them. Everything outside stays byte-identical.
   - No markers → keep the entire old body untouched and put the new marker block **above** it, separated by a blank line and a `---` rule.
   - Media that lived *inside* the marker region → carry those exact references into the new region (a `## Media` section at its end) rather than letting the rewrite eat them.
4. **Verify before writing.** Re-run the inventory on the new body. Every reference from step 2 must still be present, verbatim. If even one is missing, do not edit the PR — report what would have been lost and stop.
5. Update with `gh pr edit --body-file <tmpfile>` (and `--title` only if the current title is clearly stale). Never pass `--body`; never touch labels, reviewers, assignees, milestone, or base. Never convert an open PR back to draft, and never mark a draft ready.

**4. Report, tersely.** Number, created-or-updated, and the URL on its own line. Name the repo whenever it isn't the current directory:

```
~/claude-push (not cwd)
✓ draft PR #142 created
  https://github.com/owner/repo/pull/142
```

For an update, add one clause on what changed and confirm media survived, e.g. `updated summary; 3 attachments preserved`. No preamble.
