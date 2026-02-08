#!/bin/bash
# Preview the codebase at any git commit - serves locally without touching your working directory

set -e
REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
PREVIEW_DIR=""

# Find an available port (8765, 8766, 8767...)
find_port() {
  for port in 8765 8766 8767 8768 8769 8770; do
    if ! lsof -i :$port -sTCP:LISTEN -t &>/dev/null; then
      echo $port
      return
    fi
  done
  echo "8765"  # fallback, will show clearer error if still busy
}

cleanup() {
  echo ""
  echo "Cleaning up..."
  cd "$REPO_ROOT"
  if [ -d "$PREVIEW_DIR" ]; then
    git worktree remove "$PREVIEW_DIR" --force 2>/dev/null || rm -rf "$PREVIEW_DIR"
    echo "Removed preview worktree."
  fi
  exit 0
}

trap cleanup SIGINT SIGTERM EXIT

show_usage() {
  echo "Usage: ./preview-commit.sh <commit-hash>"
  echo "   or: ./preview-commit.sh          (interactive - pick from recent commits)"
  echo ""
  echo "Examples:"
  echo "  ./preview-commit.sh d6d8f76"
  echo "  ./preview-commit.sh 7ce26d6"
  echo ""
  echo "Recent commits:"
  git -C "$REPO_ROOT" log --oneline -12
  exit 1
}

# Get commit hash from arg or interactive prompt
if [ -n "$1" ]; then
  COMMIT="$1"
else
  echo "Recent commits (paste a hash or press Enter for latest):"
  echo ""
  git -C "$REPO_ROOT" log --oneline -15
  echo ""
  read -r -p "Commit hash: " COMMIT
  if [ -z "$COMMIT" ]; then
    COMMIT=$(git -C "$REPO_ROOT" rev-parse HEAD)
    echo "Using latest: $COMMIT"
  fi
fi

# Validate commit exists
if ! git -C "$REPO_ROOT" cat-file -e "$COMMIT^{commit}" 2>/dev/null; then
  echo "Error: Invalid commit '$COMMIT'"
  show_usage
fi

SHORT_HASH=$(echo "$COMMIT" | cut -c1-7)
PREVIEW_DIR="$REPO_ROOT/.preview-$SHORT_HASH"

# Remove existing worktree if present (e.g. from previous interrupted run)
if [ -d "$PREVIEW_DIR" ]; then
  git -C "$REPO_ROOT" worktree remove "$PREVIEW_DIR" --force 2>/dev/null || rm -rf "$PREVIEW_DIR"
fi

# Create worktree with commit's code
echo "Checking out commit $SHORT_HASH..."
git -C "$REPO_ROOT" worktree add "$PREVIEW_DIR" "$COMMIT"

PORT=$(find_port)

echo ""
echo "═══════════════════════════════════════════════════════"
echo "  Serving commit $SHORT_HASH at http://localhost:$PORT"
echo "  Press Ctrl+C to stop and return to current state"
echo "═══════════════════════════════════════════════════════"
echo ""

# Open browser if possible (macOS)
if command -v open &>/dev/null; then
  (sleep 1 && open "http://localhost:$PORT") &
fi

# Serve from the preview directory
cd "$PREVIEW_DIR"
python3 -m http.server "$PORT"
