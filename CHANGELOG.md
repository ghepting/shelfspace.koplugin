# Changelog

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
