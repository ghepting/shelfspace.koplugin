# Shelf Space

A [KOReader](https://github.com/koreader/koreader) plugin to see where your
device storage went and free it up. It uses only KOReader's own APIs, so it is
meant to work on every device KOReader supports; so far it has only been run
in the desktop emulator.

## Screenshots

| Overview | Browse by size | Delete |
| --- | --- | --- |
| <img src="assets/overview.png" width="260"> | <img src="assets/browse.png" width="260"> | <img src="assets/delete.png" width="260"> |

| KOReader data | Clear | Grayscale screens |
| --- | --- | --- |
| <img src="assets/koreader.png" width="260"> | <img src="assets/clear.png" width="260"> | <img src="assets/overview-gray.png" width="260"> |

Taken in the KOReader desktop emulator, so the totals are a Mac's. Colour
shows on Kaleido screens such as the Kobo Libra Colour; other screens get the
grayscale version.

## What it does

Open **Tools › Shelf Space**. Three tabs:

- **Overview**: free space, and where the rest went (books, KOReader data,
  everything else).
- **Browse**: your library, largest first, with a share bar per row. Tap a
  folder to open it. Tap a file, or hold anything, to delete it; you always
  get a confirmation first, including how many books lose their reading
  progress. System folders (such as `.kobo`), KOReader itself and the book you
  are reading can't be deleted here.
- **KOReader**: what KOReader can rebuild or no longer needs (rendering cache,
  update downloads, crash logs, screenshots, reading progress of books that are
  gone), each with a Clear button.

## Planned

- Select several files at once
- A shelf view where spine width matches size
- A faster scan with a cached result

## Install

Copy the `shelfspace.koplugin` folder into KOReader's `plugins` directory and
restart KOReader.

## Development

Run the KOReader desktop emulator (`./kodev run`), then link the plugin in:

    ./dev.sh /path/to/koreader/plugins

## License

MIT
