#!/usr/bin/env bash
# Symlink the plugin into a KOReader plugins dir (e.g. the desktop emulator).
set -euo pipefail
dest="${1:?usage: dev.sh <koreader>/plugins}"
ln -sfn "$(cd "$(dirname "$0")" && pwd)/shelfspace.koplugin" "$dest/shelfspace.koplugin"
echo "linked into $dest"
