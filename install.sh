#!/usr/bin/env bash
# Installs claude-push: adds the /push and /pr commands to ~/.claude/commands.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CMD_DIR="$HOME/.claude/commands"

mkdir -p "$CMD_DIR"

# symlink so repo edits apply immediately
for c in push pr; do
  ln -sfn "$DIR/$c.md" "$CMD_DIR/$c.md"
  echo "installed /$c -> $CMD_DIR/$c.md"
done

# the commands need the GitHub CLI, but a missing login shouldn't block installing them
if ! command -v gh >/dev/null; then
  echo
  echo "note: the GitHub CLI isn't installed — /pr needs it."
  echo "      brew install gh && gh auth login"
elif ! gh auth status >/dev/null 2>&1; then
  echo
  echo "note: gh is installed but not logged in — /pr needs it."
  echo "      gh auth login"
fi

echo
echo "done. restart Claude Code (or start a new session) to pick up the commands."
