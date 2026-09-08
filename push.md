---
description: Commit the working tree with generated messages and push the branch (never to main).
argument-hint: [optional context, e.g. "fix auth retry" or "wip"]
allowed-tools: Bash(git:*), Bash(gh:*)
---

The user ran `/push $ARGUMENTS`. Extra context from them (may be empty): $ARGUMENTS

## Repo state

- Root: !`git rev-parse --show-toplevel 2>/dev/null || echo "NOT-A-GIT-REPO"`
- Origin: !`git remote get-url origin 2>/dev/null || echo "no origin remote"`
- Branch: !`git rev-parse --abbrev-ref HEAD 2>/dev/null`
- Default branch: !`basename "$(git symbolic-ref -q refs/remotes/origin/HEAD 2>/dev/null || echo origin/main)"`
- Upstream: !`git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null || echo "NONE (first push needs -u)"`
- Status: !`git status --short 2>/dev/null | head -60`
- Diff stat: !`git diff HEAD --stat 2>/dev/null | tail -30`
- Recent commits (match this style): !`git log --oneline -8 2>/dev/null`

## What to do

Work only from the repo containing the current directory. If Root is `NOT-A-GIT-REPO`, say so in one line and stop.

**1. Branch guard — never commit to the default branch.**
If the current branch equals the default branch (or is `main`/`master`), read the diff, invent a short descriptive branch name from it (`fix/…`, `feat/…`, `chore/…`, kebab-case, no ticket numbers you don't have), and `git checkout -b <name>` before committing. Do this silently — no confirmation prompt — and report it in your final output. If the user gave arguments that read like a branch name, use those instead. Also refuse to push if the branch is protected and the push is rejected — report, never `--force`.

**2. Inspect everything that changed.**
`git status --porcelain` plus `git diff HEAD` (and `git diff` for untracked file contents via `git add -N` if useful). Understand *what the changes do*, not just which files moved.

**3. Skip anything that looks secret or junk.**
Do not stage `.env*`, `*.pem`, `*.key`, `id_rsa*`, credential/token files, or obvious build output and huge binaries that aren't already tracked. If you skip something, say so in the final output. If a secret-looking file is *already tracked and modified*, stage it but flag it clearly.

**4. Commit — split by theme.**
Stage and commit everything else. If the changes are clearly unrelated, split them into 2–3 logical commits (`git add -- <paths>` then `git commit`); if they're one coherent change, one commit. Never more than 3 commits — this is a quick-push button, not a history-rewriting exercise.

Message style: match the repo's existing log (conventional-commit prefixes only if the repo already uses them). Subject ≤ 72 chars, imperative mood, describes the *effect* of the change, not the file list. Add a short body with bullets only when the change isn't self-evident from the subject. Follow your session's commit attribution/trailer guidance.

If a pre-commit hook modifies files, re-stage and retry the commit once. Never use `--no-verify`. If a hook fails outright, stop and report its output.

**5. Push.**
- No upstream → `git push -u origin HEAD`
- Otherwise → `git push`
- Rejected as non-fast-forward → do **not** force. Report it and suggest `git pull --rebase`.

**6. Report, tersely.** One line per commit (`hash subject`), then the branch and its GitHub URL. Example:

```
a1b2c3d fix: retry token refresh on 401
e4f5g6h chore: bump axios to 1.7.9
→ pushed fix/token-refresh-race → https://github.com/owner/repo/tree/fix/token-refresh-race
```

No preamble, no summary paragraph. If there was nothing to commit but unpushed commits exist, just push them and say so.
