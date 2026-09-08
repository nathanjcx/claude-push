#!/usr/bin/env bash
# Installs claude-push: adds the /push and /pr commands to ~/.claude/commands.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CMD_DIR="$HOME/.claude/commands"

command -v gh >/dev/null || { echo "the GitHub CLI is required (brew install gh), then run: gh auth login"; exit 1; }
gh auth status >/dev/null 2>&1 || { echo "gh is installed but not logged in — run: gh auth login"; exit 1; }
mkdir -p "$CMD_DIR"

# symlink so repo edits apply immediately
for c in push pr; do
  ln -sfn "$DIR/$c.md" "$CMD_DIR/$c.md"
  echo "installed /$c -> $CMD_DIR/$c.md"
done

echo "done. restart Claude Code (or start a new session) to pick up the commands."
