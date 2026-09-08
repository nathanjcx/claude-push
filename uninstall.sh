#!/usr/bin/env bash
# Removes the /push and /pr commands. Leaves the repo in place.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
for c in push pr; do
  link="$HOME/.claude/commands/$c.md"
  # only remove our own symlink, never someone else's command of the same name
  if [ -L "$link" ] && [ "$(readlink "$link")" = "$DIR/$c.md" ]; then
    rm -f "$link"
    echo "removed /$c"
  elif [ -e "$link" ]; then
    echo "left $link alone (not installed by claude-push)"
  fi
done
echo "claude-push uninstalled"
