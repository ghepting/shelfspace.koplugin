<p align="center">
  <img src="assets/logo.svg" width="112" alt="Shelf Space logo: books on a shelf with one empty slot">
</p>

<h1 align="center">Shelf Space</h1>

A [KOReader](https://github.com/koreader/koreader) plugin to see where your
device storage went and free it up. It uses only KOReader's own APIs, so it is
meant to work on every device KOReader supports; so far it has been run in the
desktop emulator and on a Kobo Libra Colour.

## Screenshots

| Overview | Browse by size | Quick filters |
| --- | --- | --- |
| <img src="assets/overview.png" width="260"> | <img src="assets/browse.png" width="260"> | <img src="assets/filter.png" width="260"> |

| Search and sort | Select several | File details |
| --- | --- | --- |
| <img src="assets/search.png" width="260"> | <img src="assets/select.png" width="260"> | <img src="assets/details.png" width="260"> |

| Delete | KOReader data | Clear |
| --- | --- | --- |
| <img src="assets/delete.png" width="260"> | <img src="assets/koreader.png" width="260"> | <img src="assets/clear.png" width="260"> |

Taken in the KOReader desktop emulator at Kobo Libra Colour proportions, so the
totals are a Mac's. Colour shows on Kaleido screens such as the Libra Colour;
other screens get a grayscale version of the same layout.

## What it does

Open **Tools › Shelf Space**. Three tabs:

- **Overview**: free space as a donut chart, and where the rest went (books,
  KOReader data, everything else). Tap a slice or a row to jump to Books or
  KOReader data; the info icon on Other files explains what that space is and
  why it is left alone.
- **Browse**: your library, largest first, with a share bar per row. The file
  type chips at the top are quick filters: tap one to show only that type
  (tap it again to clear). Sort by size, name or date, or search by name across
  the folder you are in and everything under it. Tap a folder to open it, or tap
  a file to see what it is (type, size, where it is, when it changed, your
  reading progress), with Open and Book info buttons. Every row has its own
  **Delete** button, or tap **Select** to tick several rows and delete them in
  one go. You always get a confirmation first, including how many books lose
  their reading progress. Only books KOReader can open, and folders holding
  nothing else, can be deleted here. Anything else (system folders, other
  files) is shown with the reason it is locked, and so are KOReader itself and
  the book you are reading.
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

## Tests

The logic that decides what can be deleted, how a selection collapses, how rows
are searched and sorted and how the chart is cut runs under plain `luajit`:

    tests/run.sh

## License

MIT
