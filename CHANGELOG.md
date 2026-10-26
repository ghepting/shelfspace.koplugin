# Changelog

## [0.4.0](https://github.com/ghepting/shelfspace.koplugin/compare/v0.3.0...v0.4.0) (2026-10-26)

### Features

* About ShelfSpace: an info icon at the top left opens a card with the version, the release date and the commit it was built from, the KOReader version and the device, the library and its free space, and the license
* QR codes on that card for the repository and for reporting a problem, with your device and versions already filled in
* Check for updates: asks GitHub for the latest release when you tap it, and says whether you are up to date or what is new

## [0.3.0](https://github.com/ghepting/shelfspace.koplugin/compare/v0.2.0...v0.3.0) (2026-10-26)

### Features

* Close book: a book that was open before you came to ShelfSpace can be closed from its card, which brings you back where you were with the book unlocked, so you can delete it
* Press and hold any row for its card. A folder's card shows how many files it holds and how big it is, and offers Open, Delete and, for the folder holding the open book, Close book

### Bug Fixes

* A folder holding the book you are reading says "Holds the book you are reading" instead of "You are reading this book"

## [0.2.0](https://github.com/ghepting/shelfspace.koplugin/compare/v0.1.1...v0.2.0) (2026-10-26)

Browse is now a table, with new ways to find what to delete.

### Features

* Browse is a table: a checkbox on every row (the one in the header ticks them all) and columns for name, % read and size. What you tick shows in a bar that floats over the bottom of the list, so the table never moves under your finger, with one Delete
* A % Read column: 0% to 99%, or Read for a finished book
* Show only the books KOReader has marked as finished, or only the ones you never opened
* Sort by size, name, date modified or when you last opened a book, with one button that flips the direction; its icon shows what is being sorted
* Search is a tag beside the file-type tags: tap the magnifier to search, tap the tag to clear it
* When a search or filter finds nothing, a message says why and a button undoes it
* The KOReader tab says ALL CLEAR when nothing is left to clear, and its tags show only what you can clear

### Bug Fixes

* Going Up returns to the page you were on, and the Show filter stays on when you change folder
* The list fills the page at any screen height
* A single picture (SVG, PNG and so on) is no longer listed as a book, with a reading progress or as unread

## [0.1.1](https://github.com/ghepting/shelfspace.koplugin/compare/v0.1.0...v0.1.1) (2026-10-25)


### Bug Fixes

* draw the ShelfSpace tile natively so the Kobo shows no vertical line ([#27](https://github.com/ghepting/shelfspace.koplugin/issues/27)) ([3062db9](https://github.com/ghepting/shelfspace.koplugin/commit/3062db950a4f3c461b4d1290352f3e37e0e1b9d0))

## 0.1.0 (2026-10-25)

First release. ShelfSpace shows where your device's storage went and lets you free it up. It has been run in the KOReader desktop emulator and on a Kobo Libra Colour; other devices are untested.

### Features

* Overview: free space as a donut chart and where the rest went (books, KOReader data, other files), with a header showing the share of each
* Browse: your library largest first with a share bar per row, sort by size, name or date (ascending or descending), search by name across a folder and everything under it, and quick filters for the book types in your library
* Tap a file to see what it is (type, size, location, last change, reading progress), then open it or see its book info
* Delete a file or folder with its own button, or select several and delete them together; every delete asks first, and only books KOReader can open (and folders holding only those) can be deleted
* KOReader data: clear its cache, update downloads, logs, screenshots and orphaned reading progress, one at a time or several together
* Colour for Kaleido screens from a fixed palette, and a grayscale version of the same layout for other screens
* The last scan is kept, so reopening ShelfSpace only re-reads folders that changed

### Bug Fixes

* Buttons keep their rounded corners when tapped, and disabled ones recede as a whole
* Only the Delete button deletes: tapping a row opens it
* One dialog at a time, so confirmations cannot stack up
