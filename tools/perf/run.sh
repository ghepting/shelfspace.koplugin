#!/usr/bin/env bash
# Times ShelfSpace on a large made-up library in the KOReader desktop emulator, headless, with its own data folder and library.
#
#   tools/perf/run.sh /path/to/KOReader.app [books]     books defaults to 5000
#
# Prints one line per step. The times are a Mac's; an e-reader is many times slower, so read them for what grows with the library.
set -euo pipefail
repo="$(cd "$(dirname "$0")/../.." && pwd)"
app="${1:?usage: run.sh <KOReader.app or koreader binary> [books]}"
books="${2:-5000}"
bin="$app"; [ -d "$app" ] && bin="$app/Contents/MacOS/koreader"
[ -x "$bin" ] || { echo "run.sh: cannot run $bin" >&2; exit 1; }

work="$(mktemp -d "${TMPDIR:-/tmp}/shelfspace-perf.XXXXXX")"
work="$(cd "$work" && pwd -P)"
mkdir -p "$work/home/plugins"
python3 "$repo/tools/perf/make-library.py" "$work/Books" "$books"
ln -s "$repo/shelfspace.koplugin" "$work/home/plugins/shelfspace.koplugin"
cp -R "$repo/tools/perf/perfdriver.koplugin" "$work/home/plugins/"
cat > "$work/home/settings.reader.lua" <<S
return {
    ["home_dir"] = "$work/Books",
    ["lastdir"] = "$work/Books",
    ["start_with"] = "filemanager",
    ["quickstart_shown_version"] = 99999999999,
}
S
KO_HOME="$work/home" PERF_LIBRARY="$work/Books" SDL_VIDEODRIVER=dummy \
    EMULATE_READER_W=1264 EMULATE_READER_H=1680 EMULATE_READER_DPI=300 "$bin" > "$work/run.log" 2>&1 || true
grep -E "PERF |ShelfSpace: (scanned|built|[0-9]+ duplicate)" "$work/run.log" | sed -E 's/^[0-9\/:-]+ +//; s/^INFO +//' || true
grep -q "perfdriver: done" "$work/run.log" || { echo "run.sh: the run did not finish; see $work/run.log" >&2; exit 1; }
rm -rf "$work"
