#!/usr/bin/env bash
#
# Sync this repository's skills into the user's global Claude directory
# (~/.claude/skills) so they are available across all projects.
#
# Usage:
#   ./sync-skills.sh            # copy repo skills -> ~/.claude/skills
#   ./sync-skills.sh --dry-run  # show what would change, copy nothing

set -euo pipefail

DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

# Resolve the repo's skills dir relative to this script, so it works from anywhere.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$SCRIPT_DIR/.claude/skills"
DEST_DIR="$HOME/.claude/skills"

if [[ ! -d "$SRC_DIR" ]]; then
  echo "error: source skills dir not found: $SRC_DIR" >&2
  exit 1
fi

mkdir -p "$DEST_DIR"

changed=0
for skill_path in "$SRC_DIR"/*/; do
  skill="$(basename "$skill_path")"
  src="$SRC_DIR/$skill"
  dest="$DEST_DIR/$skill"

  if [[ -d "$dest" ]] && diff -qr "$src" "$dest" >/dev/null 2>&1; then
    echo "in sync: $skill"
    continue
  fi

  changed=$((changed + 1))
  if $DRY_RUN; then
    echo "would update: $skill"
  else
    mkdir -p "$dest"
    cp -R "$src/." "$dest/"
    echo "updated: $skill"
  fi
done

if $DRY_RUN; then
  echo "dry run complete — $changed skill(s) would change."
else
  echo "done — $changed skill(s) updated, synced to $DEST_DIR."
fi