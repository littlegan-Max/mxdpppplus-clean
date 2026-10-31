#!/usr/bin/env bash
# mxdpppplus dedicated server launcher.
# Usage: ./run_server.sh [--port=7777]
set -e
cd "$(dirname "$0")"
PORT="${PORT:-7777}"
GODOT_BIN="${GODOT_BIN:-}"

for arg in "$@"; do
  case "$arg" in
    --port=*) PORT="${arg#--port=}" ;;
  esac
done

if [ -f "./mxdpppplus_server.x86_64" ]; then
  [ -x "./mxdpppplus_server.x86_64" ] || chmod +x "./mxdpppplus_server.x86_64"
  echo "[mxdpppplus] starting bundled server on UDP ${PORT}"
  MXD_PORT="$PORT" exec ./mxdpppplus_server.x86_64 --headless -- --server --port="$PORT"
fi

if [ -z "$GODOT_BIN" ]; then
  if [ -x "./Godot_v4.7.2-stable_linux.x86_64" ]; then
    GODOT_BIN="./Godot_v4.7.2-stable_linux.x86_64"
  elif command -v godot >/dev/null 2>&1; then
    GODOT_BIN="godot"
  elif command -v godot4 >/dev/null 2>&1; then
    GODOT_BIN="godot4"
  else
    echo "找不到 Godot 4.7.2。请把 Godot 放本目录，或设置 GODOT_BIN=/path/to/godot"
    exit 1
  fi
fi

echo "[mxdpppplus] starting server on UDP ${PORT}"
exec "$GODOT_BIN" --headless --path "$(pwd)" -- --server --port="$PORT"
