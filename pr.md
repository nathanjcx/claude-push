---
description: Open a draft PR for the current branch, or update the existing one without destroying attached images/media.
argument-hint: [optional context, e.g. "target release-2 branch" or PR title]
allowed-tools: Bash(git:*), Bash(gh:*)
---

The user ran `/pr $ARGUMENTS`. Extra context from them (may be empty): $ARGUMENTS

## Repo state

- Root: !`git rev-parse --show-toplevel 2>/dev/null || echo "NOT-A-GIT-REPO"`
- Branch: !`git rev-parse --abbrev-ref HEAD 2>/dev/null`
- Default branch: !`basename "$(git symbolic-ref -q refs/remotes/origin/HEAD 2>/dev/null || echo origin/main)"`
- Uncommitted: !`git status --short 2>/dev/null | head -40`
- Unpushed commits: !`git log --oneline @{u}..HEAD 2>/dev/null || echo "no upstream — branch not on GitHub yet"`
- Commits on this branch: !`git log --oneline "origin/$(basename "$(git symbolic-ref -q refs/remotes/origin/HEAD 2>/dev/null || echo origin/main)")"..HEAD 2>/dev/null | head -30`
- Diff stat vs base: !`git diff --stat "origin/$(basename "$(git symbolic-ref -q refs/remotes/origin/HEAD 2>/dev/null || echo origin/main)")"...HEAD 2>/dev/null | tail -30`
- Existing PR: !`gh pr view --json number,url,title,isDraft,baseRefName,state 2>/dev/null || echo "none for this branch"`

## What to do

If Root is `NOT-A-GIT-REPO`, say so in one line and stop.

**1. Preconditions.**
- Uncommitted changes → stop. Print `⚠ N uncommitted files — run /push first` and list them. Do not commit anything yourself.
- On the default branch → stop and say the branch needs to be a feature branch (`/push` will create one).
- Unpushed commits → push them first (`git push -u origin HEAD` if no upstream, else `git push`). Never force-push.
- No commits at all vs. the base branch → stop and say there's nothing to open a PR for.

**2. Write the summary.**
Read the actual diff against the base (`git diff origin/<base>...HEAD`) and the commit log. Write:
- **Title**: ≤ 70 chars, imperative, what this PR does. Match repo PR conventions if the recent PR titles show one (`gh pr list --limit 10 --json title`).
- **Body**: a `## Summary` section (2–5 bullets, effect-first) and a `## Test plan` section (checklist of how to verify — real commands or steps, and mark boxes done only for what actually ran). Follow your session's PR attribution/footer guidance.

Wrap the generated part in markers so future runs can update it safely:

```
<!-- claude:summary:start -->
…title-agnostic summary + test plan + attribution footer…
<!-- claude:summary:end -->
```

**3a. No existing PR → create it as a draft.**
Write the body to a temp file and run:
`gh pr create --draft --base <base> --title "<title>" --body-file <tmpfile>`
Base is the repo default branch unless the user's arguments say otherwise.

**3b. Existing PR → update it, and preserve everything the user added.**

This is the part that must not go wrong. The PR body may contain images, videos, and file attachments the user dragged into GitHub, and those references are unrecoverable if you drop them.

1. Fetch the current body: `gh pr view --json body -q .body > /tmp/pr_old_body.md` (use a real temp path).
2. Inventory every media/attachment reference in the old body — count them and keep the exact strings. That means all of:
   - markdown images `![...](...)` and any link whose target ends in `.png .jpg .jpeg .gif .webp .svg .mp4 .mov .webm .pdf`
   - raw HTML `<img …>`, `<video …>`, `<source …>`, `<picture>` blocks (keep the full tag verbatim, attributes included)
   - `https://github.com/user-attachments/...`, `https://github.com/<owner>/<repo>/assets/...`, `https://user-images.githubusercontent.com/...`
3. Build the new body:
   - If the old body has the `claude:summary` markers → replace **only** the text between them. Everything outside the markers stays byte-identical.
   - If it has no markers → keep the entire old body untouched and put your newly-generated marker block **above** it, separated by a blank line and a `---` rule.
   - If media lived *inside* the marker region, carry those exact references into the new region (a `## Media` section at the end of it) rather than letting the rewrite eat them.
4. **Verify before writing.** Re-run the inventory on the new body. Every reference from step 2 must still be present, verbatim. If even one is missing, do not edit the PR — report what would have been lost and stop.
5. Update with `gh pr edit --body-file <tmpfile>` (and `--title` only if the current title is clearly stale). Never pass `--body`; never touch labels, reviewers, assignees, milestone, or base. Never convert an already-open PR back to draft, and never mark a draft ready.

**4. Report, tersely.** The PR number, whether it was created or updated, and the URL on its own line:

```
✓ draft PR #142 created
  https://github.com/owner/repo/pull/142
```

For an update, also state in one clause what you changed and confirm media was preserved, e.g. `updated summary; 3 attachments preserved`. No preamble.
