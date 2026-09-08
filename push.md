---
description: Commit the working tree with generated messages and push the branch (never to main). Works from any directory.
argument-hint: [repo name/path and/or context, e.g. "claude-push" or "fix auth retry"]
allowed-tools: Bash(git:*), Bash(gh:*), Bash(pwd), Bash(find:*)
---

The user ran `/push $ARGUMENTS`. Extra context from them (may be empty): $ARGUMENTS

## Repo state

- Working dir: !`pwd`
- Repo here: !`git rev-parse --show-toplevel 2>/dev/null || echo "NOT-A-GIT-REPO"`
- Other repos with pending work: !`find "$HOME" -maxdepth 3 \( -name Library -o -name .Trash -o -name node_modules -o -name .npm -o -name .cache -o -name Applications \) -prune -o -name .git -type d -print 2>/dev/null | while read -r g; do r="${g%/.git}"; b=$(git -C "$r" rev-parse --abbrev-ref HEAD 2>/dev/null) || continue; n=$(git -C "$r" status --porcelain 2>/dev/null | wc -l | tr -d ' '); u=$(git -C "$r" log --oneline @{u}..HEAD 2>/dev/null | wc -l | tr -d ' '); [ "$n" = 0 ] && [ "$u" = 0 ] && continue; echo "$r [$b] dirty=$n unpushed=$u"; done | head -12 || echo "-"`
- Branch here: !`git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "-"`
- Default branch here: !`basename "$(git symbolic-ref -q refs/remotes/origin/HEAD 2>/dev/null || echo origin/main)" 2>/dev/null || echo "-"`
- Status here: !`git status --short 2>/dev/null | head -60 || echo "-"`
- Diff stat here: !`git diff HEAD --stat 2>/dev/null | tail -30 || echo "-"`
- Recent commits here (match this style): !`git log --oneline -8 2>/dev/null || echo "-"`

## What to do

**0. Pick the target repo — this command is not tied to the current directory.**
Resolve `$ROOT` in this order, and stop at the first that applies:
1. `$ARGUMENTS` names a path or repo name matching one of the repos listed above → use it.
2. The current directory is a repo (`Repo here` is a path) → use it.
3. Exactly one repo in "Other repos with pending work" → use it.
4. You've been editing files in one specific repo this session and it appears above → use it.
5. Otherwise → list the candidates, ask which one, and stop.

If `Repo here` is `NOT-A-GIT-REPO` and no candidate has pending work, say so in one line and stop.

**Run every git command as `git -C "$ROOT" …`** so this works from anywhere. If `$ROOT` isn't the current directory, the "here" lines above describe the wrong repo — re-gather branch, status, diff, and log for `$ROOT` before doing anything.

**1. Branch guard — never commit to the default branch.**
If the target branch equals the default branch (or is `main`/`master`), read the diff, invent a short descriptive branch name from it (`fix/…`, `feat/…`, `chore/…`, kebab-case, no ticket numbers you don't have), and `git -C "$ROOT" checkout -b <name>` before committing. Do this silently — no confirmation prompt — and report it in your final output. If the user's arguments read like a branch name, use those instead. If a push is rejected because the branch is protected, report it — never `--force`.

**2. Inspect everything that changed.**
`git -C "$ROOT" status --porcelain` plus `git -C "$ROOT" diff HEAD`. Understand *what the changes do*, not just which files moved.

**3. Skip anything that looks secret or junk.**
Do not stage `.env*`, `*.pem`, `*.key`, `id_rsa*`, credential/token files, or obvious build output and huge binaries that aren't already tracked. If you skip something, say so in the final output. If a secret-looking file is *already tracked and modified*, stage it but flag it clearly.

**4. Commit — split by theme.**
Stage and commit everything else. If the changes are clearly unrelated, split them into 2–3 logical commits (`git -C "$ROOT" add -- <paths>` then commit); if they're one coherent change, one commit. Never more than 3 — this is a quick-push button, not a history-rewriting exercise.

Message style: match that repo's existing log (conventional-commit prefixes only if it already uses them). Subject ≤ 72 chars, imperative mood, describes the *effect* of the change, not the file list. Add a short body with bullets only when the change isn't self-evident from the subject. Follow your session's commit attribution/trailer guidance.

If a pre-commit hook modifies files, re-stage and retry the commit once. Never use `--no-verify`. If a hook fails outright, stop and report its output.

**5. Push.**
- No upstream → `git -C "$ROOT" push -u origin HEAD`
- Otherwise → `git -C "$ROOT" push`
- Rejected as non-fast-forward → do **not** force. Report it and suggest `git pull --rebase`.

**6. Report, tersely.** One line per commit (`hash subject`), then the branch and its GitHub URL. Name the repo whenever it isn't the current directory:

```
~/claude-push (not cwd)
a1b2c3d fix: retry token refresh on 401
→ pushed fix/token-refresh-race → https://github.com/owner/repo/tree/fix/token-refresh-race
```

No preamble, no summary paragraph. If there was nothing to commit but unpushed commits exist, just push them and say so.
