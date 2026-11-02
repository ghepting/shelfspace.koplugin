#!/usr/bin/env bash
# Opens ShelfSpace at the screen sizes of common e-readers and checks that every tab fits, saving a screenshot of each.
#
#   tools/screenshots/sizes.sh /path/to/KOReader.app            every size below
#   tools/screenshots/sizes.sh /path/to/KOReader.app clara      one of them
#
# Each size runs headless (SDL_VIDEODRIVER=dummy) in its own data folder against the sample library. The shots land in
# <work>/<name>/; a tab that runs off the screen prints FAIL and the script exits 1.
set -euo pipefail
repo="$(cd "$(dirname "$0")/../.." && pwd)"
app="${1:?usage: sizes.sh <KOReader.app or koreader binary> [name]}"
bin="$app"; [ -d "$app" ] && bin="$app/Contents/MacOS/koreader"
[ -x "$bin" ] || { echo "sizes.sh: cannot run $bin" >&2; exit 1; }
only="${2:-}"

# name width height dpi: pixels and dots per inch of the device's screen
SIZES="
libra 1264 1680 300
clara 1072 1448 300
sage 1440 1920 300
elipsa 1404 1872 227
paperwhite 758 1024 212
basic6 600 800 167
landscape 1680 1264 300
landscape-basic6 800 600 167
landscape-elipsa 1872 1404 227
"

work="$(mktemp -d "${TMPDIR:-/tmp}/shelfspace-sizes.XXXXXX")"
work="$(cd "$work" && pwd -P)"
status=0
while read -r name w h dpi; do
    [ -n "$name" ] || continue
    [ -z "$only" ] || [ "$only" = "$name" ] || continue
    dir="$work/$name"
    mkdir -p "$dir/home/plugins" "$dir/shots"
    "$repo/tools/screenshots/make-library.sh" "$dir" > /dev/null
    ln -s "$repo/shelfspace.koplugin" "$dir/home/plugins/shelfspace.koplugin"
    cp -R "$repo/tools/screenshots/sizedriver.koplugin" "$dir/home/plugins/"
    cat > "$dir/home/settings.reader.lua" <<S
return {
    ["home_dir"] = "$dir/Books",
    ["lastdir"] = "$dir/Books",
    ["start_with"] = "filemanager",
    ["color_rendering"] = true,
    ["quickstart_shown_version"] = 99999999999,
}
S
    SDL_VIDEODRIVER=dummy KO_HOME="$dir/home" SHOT_OUT="$dir/shots" \
        EMULATE_READER_W="$w" EMULATE_READER_H="$h" EMULATE_READER_DPI="$dpi" "$bin" > "$dir/run.log" 2>&1 || true
    if ! grep -q "sizedriver: done" "$dir/run.log"; then
        echo "FAIL  $name ($w x $h at $dpi dpi): the check did not finish; see $dir/run.log"; status=1; continue
    fi
    if grep -q "SIZE FAIL" "$dir/run.log"; then
        echo "FAIL  $name ($w x $h at $dpi dpi)"; grep "SIZE FAIL" "$dir/run.log" | sed -E 's/^[0-9\/:-]+ [A-Z]+ +/      /'; status=1
    else
        echo "ok    $name ($w x $h at $dpi dpi)"
    fi
done <<< "$SIZES"
echo "screenshots: $work"
exit $status
