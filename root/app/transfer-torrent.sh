#!/usr/bin/env bash
set -euo pipefail

exec 2>>/config/debug.log

TORRENT_PATH="${1:-}"
CATEGORY="${2:-}"

if [[ -z "$TORRENT_PATH" || -z "$CATEGORY" ]]; then
  echo "Usage: $0 <torrent_path> <series|movies|games>" >&2
  exit 1
fi

# --- ENV CONFIG (from docker-compose.yml) -----------------------
RSYNC_HOST="${RSYNC_HOST:?RSYNC_HOST not set}"
RSYNC_USER="${RSYNC_USER:-media}"
RSYNC_SSH_PORT="${RSYNC_SSH_PORT:-22}"
SSH_KEY="${SSH_KEY:-/config/ssh/id_ed25519}"

REMOTE_BASE_SERIES="${REMOTE_BASE_SERIES:-/srv/media/series}"
REMOTE_BASE_MOVIES="${REMOTE_BASE_MOVIES:-/srv/media/movies}"
REMOTE_BASE_GAMES="${REMOTE_BASE_GAMES:-/srv/media/games}"
# ----------------------------------------------------------------

case "$CATEGORY" in
  series) TARGET_BASE="$REMOTE_BASE_SERIES" ;;
  movies) TARGET_BASE="$REMOTE_BASE_MOVIES" ;;
  games)  TARGET_BASE="$REMOTE_BASE_GAMES" ;;
  *)
    echo "Unknown category: $CATEGORY" >&2
    exit 1
    ;;
esac


# Normalize name (remove /data/)
NAME="$(echo "$TORRENT_PATH" | sed 's#^/data/##')"
TARGET="${TARGET_BASE%/}/$NAME"

chmod -R 777 "$TORRENT_PATH"

echo "=== Transfer job started ===" >> /config/debug.log
echo "SRC: $TORRENT_PATH" >> /config/debug.log
echo "DST: $RSYNC_USER@$RSYNC_HOST:$TARGET" >> /config/debug.log


# -----------------------------
# 1) Perform RSYNC transfer
# -----------------------------
rsync \
  -avch --progress \
  -e "ssh -i $SSH_KEY -p $RSYNC_SSH_PORT -o StrictHostKeyChecking=accept-new" \
  "$TORRENT_PATH" \
  "$RSYNC_USER@$RSYNC_HOST:$TARGET_BASE/" >> /config/debug.log


# -----------------------------
# 2) UNRAR if needed (directory only)
# -----------------------------
if [[ -d "$TORRENT_PATH" ]]; then
  echo "Checking for .rar files in: $TORRENT_PATH" >> /config/debug.log

  # Find the base folder on remote server
  REMOTE_TARGET_DIR="$TARGET"

  # Build a list of rar archives (only main .rar or .part1.rar)
  RAR_LIST=$(find "$TORRENT_PATH" -maxdepth 3 -type f \
      \( -iname "*.rar" -o -iname "*.part1.rar" \))

  if [[ -n "$RAR_LIST" ]]; then
    echo "RAR files found:" >> /config/debug.log
    echo "$RAR_LIST" >> /config/debug.log

    # Loop through files
    while IFS= read -r RARFILE; do

      BASENAME="$(basename "$RARFILE")"
      RAR_SUBPATH="$(dirname "$RARFILE" | sed 's#^/data/##')"

      echo "Unrar scheduled for: $BASENAME" >> /config/debug.log

      ssh -i "$SSH_KEY" -p "$RSYNC_SSH_PORT" \
        -o StrictHostKeyChecking=accept-new \
        "$RSYNC_USER@$RSYNC_HOST" \
        "cd '$TARGET_BASE/$RAR_SUBPATH' && unrar x -o+ '$BASENAME'" \
          >> /config/debug.log 2>&1

    done <<< "$RAR_LIST"
  else
    echo "No rar files found." >> /config/debug.log
  fi
fi

echo "=== Transfer job complete ===" >> /config/debug.log
