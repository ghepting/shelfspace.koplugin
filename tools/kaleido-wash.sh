#!/usr/bin/env bash
# Washes colour screenshots the way a Kaleido e-ink screen shows them (about half the saturation, a touch darker and
# flatter), so the README shows what a Kobo Libra/Clara Colour really looks like and not the emulator's bright colours.
# Every README screenshot goes through this. Needs ImageMagick.
#
#   tools/kaleido-wash.sh shot.png [more.png ...]   washes the files in place
#   tools/kaleido-wash.sh                           washes every assets/*.png
#
# Running it twice washes twice; wash a fresh capture, not a screenshot that already went through it.
set -euo pipefail
here="$PWD"
root="$(cd "$(dirname "$0")/.." && pwd)"
command -v magick >/dev/null || { echo "kaleido-wash: ImageMagick (magick) is not installed" >&2; exit 1; }

# magick -modulate is brightness,saturation,hue in percent: 97% brightness, 55% saturation, hue untouched. The contrast
# step takes 5% off, since the colour layer also lowers the screen's contrast.
if [ "$#" -eq 0 ]; then set -- "$root"/assets/*.png; fi
for f in "$@"; do
    case "$f" in /*) ;; *) f="$here/$f" ;; esac
    magick "$f" -modulate 97,55,100 -brightness-contrast 0x-5 "$f"
    echo "washed $f"
done
