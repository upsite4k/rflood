#!/usr/bin/env bash
set -euo pipefail

KODI_HOST="${KODI_HOST:?KODI_HOST not set}"
KODI_PORT="${KODI_PORT:?KODI_PORT not set}"
KODI_USER="${KODI_USER:?KODI_USER not set}"
KODI_PASSWORD="${KODI_PASSWORD:?KODI_PASSWORD not set}"

/usr/bin/curl --data-binary '{ "jsonrpc": "2.0", "method": "VideoLibrary.Scan", "id": "mybash"}' -H 'content-type: application/json;' http://$KODI_USER:$KODI_PASSWORD@$KODI_HOST:$KODI_PORT/jsonrpc
/usr/bin/curl --data-binary '{ "jsonrpc": "2.0", "method": "VideoLibrary.Clean", "id": "mybash"}' -H 'content-type: application/json;' http://$KODI_USER:$KODI_PASSWORD@$KODI_HOST:$KODI_PORT/jsonrpc

