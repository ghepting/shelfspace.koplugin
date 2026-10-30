#!/bin/sh
# Builds the sample library the screenshots are taken of, and the KOReader data they show. Usage: make-library.sh <work dir>
# Makes <work dir>/Books (the library) and <work dir>/home (KOReader's data folder). It is rebuilt from scratch each time,
# because the walkthrough deletes files. The files are random bytes (or sparse), so only their names and sizes mean anything.
set -eu
W="$(cd "${1:?usage: make-library.sh <work dir>}" && pwd)"
B="$W/Books"
H="$W/home"
rm -rf "$B"
mkdir -p "$B/Sci-Fi" "$B/Fantasy" "$B/Manuals" "$B/Comics" "$B/Classics" "$B/Mixed" "$B/Formats" "$B/Shouting" "$H"

mk() { head -c $(( $2 * 1024 )) /dev/urandom > "$B/$1"; }
mks() { truncate -s $(( $2 * 1024 )) "$B/$1"; } # sparse: only its size matters, and it costs no disk

# The library as the README shows it.
mk "Sci-Fi/Dune.epub" 2400; mk "Sci-Fi/Hyperion.epub" 1900; mk "Sci-Fi/Neuromancer.epub" 1100; mk "Sci-Fi/The Three-Body Problem.epub" 3300
mk "Fantasy/The Name of the Wind.epub" 2800; mk "Fantasy/Mistborn.epub" 3600; mk "Fantasy/Earthsea.mobi" 900
mks "Manuals/Kobo Libra Colour Guide.pdf" 48000; mks "Manuals/Lua Reference.pdf" 21000; mks "Manuals/KOReader Manual.pdf" 15500
mks "Comics/Saga v1.cbz" 212000; mks "Comics/Saga v2.cbz" 198000; mks "Comics/Maus.cbz" 96000
mk "Classics/Moby Dick.epub" 1500; mk "Classics/Dracula.epub" 820; mk "Classics/Frankenstein.fb2" 600
# Three books that are on the shelf twice.
cp "$B/Sci-Fi/Dune.epub" "$B/Classics/Dune (copy).epub"; cp "$B/Fantasy/Mistborn.epub" "$B/Mistborn.epub"; cp "$B/Manuals/Lua Reference.pdf" "$B/Lua Reference.pdf"

# One of each kind under plain names, for the picture of the five colours.
mkm() { head -c $(( $2 * 1024 )) /dev/urandom > "$B/Mixed/$1"; }
mkm "Old Map.djvu" 9400; mkm "Field Guide.pdf" 7600; mkm "Nimona.cbz" 6100; mkm "Cover Photo.jpg" 4300
mkm "Piranesi.epub" 2900; mkm "Report Q3.docx" 1700; mkm "Trip Notes.md" 880; mkm "Solaris.fb2" 420

# One file of every format KOReader opens, in lower case and then in capitals, each under its own name so none is a duplicate of another.
FORMATS="epub kepub.epub mobi prc fb2 fb2.zip doc docx rtf txt text md markdown html htm chm pdb pdf djvu djv xps oxps cbz cbt zip jpg jpeg png bmp webp gif txt.zip html.zip md.zip epub3 fb3 odt docm tif svg"
n=0
for ext in $FORMATS; do
    n=$((n + 1)); kb=$(( 12 + (n * 37) % 290 ))
    head -c $((kb * 1024)) /dev/urandom > "$B/Formats/$ext sample.$ext"
    upper=$(printf '%s' "$ext" | tr '[:lower:]' '[:upper:]')
    head -c $(( (kb + 50) * 1024 )) /dev/urandom > "$B/Shouting/SHOUT $upper.$upper"
done
# Formats KOReader does not read natively: listed as locked files, never as books.
head -c 40960 /dev/urandom > "$B/Formats/azw3 sample.azw3"; head -c 30720 /dev/urandom > "$B/Formats/kfx sample.kfx"
# One book in three spellings and cases: a single set of duplicates.
head -c 81920 /dev/urandom > "$B/Formats/Emma.EPUB"; head -c 82944 /dev/urandom > "$B/Formats/emma.kepub.epub"; head -c 83968 /dev/urandom > "$B/Formats/EMMA.mobi"

# KOReader's own data: what its tab offers to clear (sparse files, so they cost no disk).
rm -rf "$H/cache" "$H/ota" "$H/screenshots" "$H/dictionaries" "$H/history" "$H/crash.log"
mkdir -p "$H/cache/cr3cache" "$H/ota" "$H/screenshots" "$H/dictionaries" "$H/history"
truncate -s 118m "$H/cache/cr3cache/Moby Dick.epub.cache"; truncate -s 64m "$H/cache/cr3cache/Dune.epub.cache"
truncate -s 86m "$H/ota/koreader-android-arm64-v2026.03.apk"
truncate -s 5m "$H/crash.log"
truncate -s 2m "$H/screenshots/KOReader_2026-10-02.png"; truncate -s 3m "$H/screenshots/KOReader_2026-10-11.png"
truncate -s 410m "$H/dictionaries/wiktionary-en.dict"; truncate -s 90m "$H/history/history.lua"
