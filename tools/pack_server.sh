#!/usr/bin/env bash
# Build server/client source packages for handoff.
set -e
cd "$(dirname "$0")/.."
ROOT="$(pwd)"
DIST="$ROOT/dist"
mkdir -p "$DIST"

# Windows server bundle
rm -rf "$DIST/server-win64"
mkdir -p "$DIST/server-win64"
cp "$DIST/mxdpppplus_server.exe" "$DIST/server-win64/"
cp run_server.bat "$DIST/server-win64/"
( cd "$DIST/server-win64" && zip -q -r "$DIST/mxdpppplus-server-win64.zip" . )

# Linux server bundle
rm -rf "$DIST/server-linux"
mkdir -p "$DIST/server-linux"
cp "$DIST/mxdpppplus_server.x86_64" "$DIST/server-linux/"
chmod +x "$DIST/server-linux/mxdpppplus_server.x86_64"
cp run_server.sh "$DIST/server-linux/"
( cd "$DIST/server-linux" && zip -q -r "$DIST/mxdpppplus-server-linux.zip" . )

# Full source package (no git / uploads / dist)
rm -rf "$DIST/source"
mkdir -p "$DIST/source"
rsync -a --exclude .git --exclude .uploads --exclude dist --exclude .godot --exclude backup "$ROOT/" "$DIST/source/"
( cd "$DIST/source" && zip -q -r "$DIST/mxdpppplus-source.zip" . )

ls -lh "$DIST"/*.zip
