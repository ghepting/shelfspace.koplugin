#!/usr/bin/env bash
# Takes every ShelfSpace screenshot in the KOReader desktop emulator, checks the app along the way, and (with --readme) puts the
# README's screenshots in assets/ after washing them with tools/kaleido-wash.sh, so they look the way a Kaleido colour e-ink
# screen shows them. Every screenshot in this repository goes through that wash.
#
#   tools/screenshots/run.sh /path/to/KOReader.app            takes them all, into a temporary folder, and prints it
#   tools/screenshots/run.sh /path/to/KOReader.app --readme   and replaces the screenshots in assets/ with the washed ones
#
# The emulator is a macOS KOReader nightly (KOReader.app) or any `koreader` binary. It runs with its own data folder, never yours.
# The walkthrough deletes files, but only in the sample library it builds for itself.
set -euo pipefail
repo="$(cd "$(dirname "$0")/../.." && pwd)"
app="${1:?usage: run.sh <KOReader.app or koreader binary> [--readme]}"
bin="$app"; [ -d "$app" ] && bin="$app/Contents/MacOS/koreader"
[ -x "$bin" ] || { echo "run.sh: cannot run $bin" >&2; exit 1; }

work="$(mktemp -d "${TMPDIR:-/tmp}/shelfspace-shots.XXXXXX")"
mkdir -p "$work/home/plugins" "$work/shots"
"$repo/tools/screenshots/make-library.sh" "$work"
ln -s "$repo/shelfspace.koplugin" "$work/home/plugins/shelfspace.koplugin"
cp -R "$repo/tools/screenshots/shotdriver.koplugin" "$work/home/plugins/"
cat > "$work/home/settings.reader.lua" <<S
return {
    ["home_dir"] = "$work/Books",
    ["lastdir"] = "$work/Books",
    ["start_with"] = "filemanager",
    ["color_rendering"] = true,
    ["quickstart_shown_version"] = 99999999999,
}
S

# 632 x 840 points is 1264 x 1680 pixels on a Retina screen: the Kobo Libra Colour's proportions and the size of the screenshots.
echo "running ShelfSpace in $bin (about four minutes)..."
KO_HOME="$work/home" SHOT_OUT="$work/shots" SHOT_LIBRARY="$work/Books" \
    EMULATE_READER_W=632 EMULATE_READER_H=840 EMULATE_READER_DPI=300 "$bin" > "$work/run.log" 2>&1 || true

grep -E "TEST (PASS|FAIL)|TESTS [0-9]+ passed" "$work/run.log" | sed -E 's/^[0-9\/:-]+ //' | grep -E "FAIL|TESTS" || true
if grep -q "TEST FAIL" "$work/run.log" || ! grep -q "shotdriver: done" "$work/run.log"; then
    echo "run.sh: the walkthrough did not pass; see $work/run.log" >&2
    exit 1
fi

# Wash the colour screenshots. The gray screen is already what a gray screen shows, so it is left alone.
for f in "$work"/shots/*.png; do
    case "$(basename "$f")" in gray-*) ;; *) "$repo/tools/kaleido-wash.sh" "$f" > /dev/null ;; esac
done
echo "screenshots (washed): $work/shots"

if [ "${2:-}" = "--readme" ]; then
    # what the README shows: the screenshot, and the name it has in assets/
    while read -r shot name; do
        cp "$work/shots/$shot.png" "$repo/assets/$name.png"
    done <<M
library library
library-books books
library-filter-dialog filter
library-search search
library-select select
details details
delete delete
koreader-data koreader
clear-several clear-several
formats-readme formats
gray-library gray
menu menu
duplicates duplicates-list
duplicates-compare duplicates-compare
duplicates-confirm duplicates-confirm
duplicates-kept duplicates-kept
changelog changelog
about about
M
    echo "assets/ updated"
fi
