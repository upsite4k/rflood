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

NAME="$(echo "$TORRENT_PATH" | sed 's#^/data/##')"  
TARGET="${TARGET_BASE%/}/$NAME"
chmod -R 777 $TORRENT_PATH
echo "Transferring from: $TORRENT_PATH to: $RSYNC_USER@$RSYNC_HOST:$TARGET_BASE" >> /config/debug.log

rsync \
  -avh --progress \
  -e "ssh -i $SSH_KEY -p $RSYNC_SSH_PORT -o StrictHostKeyChecking=accept-new" \
  "$TORRENT_PATH" \
  "$RSYNC_USER@$RSYNC_HOST:$TARGET_BASE/" >> /config/debug.log

echo "Done." >> /config/debug.log
