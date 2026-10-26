# Changelog

## [0.2.0](https://github.com/ghepting/shelfspace.koplugin/compare/v0.1.1...v0.2.0) (2026-10-26)


### Features

* a % Read column instead of a progress bar ([#41](https://github.com/ghepting/shelfspace.koplugin/issues/41)) ([67d2ed0](https://github.com/ghepting/shelfspace.koplugin/commit/67d2ed0fee0fac575e599bec360b2185d6a66250))
* a floating bar for the ticked items, so the table never shifts ([#46](https://github.com/ghepting/shelfspace.koplugin/issues/46)) ([9b08c62](https://github.com/ghepting/shelfspace.koplugin/commit/9b08c621c7b5fd17b71a65781521f6eb4b064d0a))
* a search icon, with the search shown as a removable tag ([#42](https://github.com/ghepting/shelfspace.koplugin/issues/42)) ([1c94caa](https://github.com/ghepting/shelfspace.koplugin/commit/1c94caaa29257e3dc5699e6a0d3d569339dc6549))
* a sort icon for each category ([#40](https://github.com/ghepting/shelfspace.koplugin/issues/40)) ([dfaf0da](https://github.com/ghepting/shelfspace.koplugin/commit/dfaf0dad85aeb464ae61a745aaa180f57078d51a))
* checkbox column and header row in Browse, one Delete for the ticked items ([#37](https://github.com/ghepting/shelfspace.koplugin/issues/37)) ([4a95b11](https://github.com/ghepting/shelfspace.koplugin/commit/4a95b116d53c881d70cecb65c4692a86d2fb201d))
* draw Browse as a bordered table with column dividers ([#38](https://github.com/ghepting/shelfspace.koplugin/issues/38)) ([8df2c58](https://github.com/ghepting/shelfspace.koplugin/commit/8df2c58c7a854e916d77032fb3ecc623321fd0e0))
* make the search the first tag beside the file types ([#43](https://github.com/ghepting/shelfspace.koplugin/issues/43)) ([fd347b8](https://github.com/ghepting/shelfspace.koplugin/commit/fd347b83a313be997744c1860b914ca38abb8f51))
* say ALL CLEAR when nothing is left to clear, and KEPT instead of OTHER ([#45](https://github.com/ghepting/shelfspace.koplugin/issues/45)) ([bbc4223](https://github.com/ghepting/shelfspace.koplugin/commit/bbc422377066e9d5f67b29f12a7b7870f118b355))
* say why when a search or filter finds nothing, with a button to undo it ([#48](https://github.com/ghepting/shelfspace.koplugin/issues/48)) ([23fe45a](https://github.com/ghepting/shelfspace.koplugin/commit/23fe45af7d416a8eae1c67385aa2b402bd7efa5d))
* show only finished books in Browse ([#30](https://github.com/ghepting/shelfspace.koplugin/issues/30)) ([a92358a](https://github.com/ghepting/shelfspace.koplugin/commit/a92358a5126744ddbe008604888020d09195a626))
* show reading progress on book rows instead of a size bar ([#33](https://github.com/ghepting/shelfspace.koplugin/issues/33)) ([f6124eb](https://github.com/ghepting/shelfspace.koplugin/commit/f6124ebfbe16b034f3a4b3b40c5be349490e8d67))
* sort by last opened and show books you never read ([#35](https://github.com/ghepting/shelfspace.koplugin/issues/35)) ([3117125](https://github.com/ghepting/shelfspace.koplugin/commit/3117125ebd50663d21acd3fafe58c8a16d2c34dd))


### Bug Fixes

* fill the page with Browse rows at any screen height ([#39](https://github.com/ghepting/shelfspace.koplugin/issues/39)) ([31ba39e](https://github.com/ghepting/shelfspace.koplugin/commit/31ba39e7f2c06c0727603b900220f1e2bf59e665))
* keep the page tappable while the floating bar is showing ([#47](https://github.com/ghepting/shelfspace.koplugin/issues/47)) ([0558cb2](https://github.com/ghepting/shelfspace.koplugin/commit/0558cb2b759bd5c7a7835e9365b1a8ffbdb660fc))
* keep the Show filter when changing folder ([#32](https://github.com/ghepting/shelfspace.koplugin/issues/32)) ([e3ad970](https://github.com/ghepting/shelfspace.koplugin/commit/e3ad970bb2582104959474dbbb6f7a4939464e3d))
* put the search tag last, sized like the others ([#44](https://github.com/ghepting/shelfspace.koplugin/issues/44)) ([1fb07ff](https://github.com/ghepting/shelfspace.koplugin/commit/1fb07ffed133ac8ada21d6684ae00135627307d9))
* remember each folder's page so Up returns to where you were ([#34](https://github.com/ghepting/shelfspace.koplugin/issues/34)) ([2628e65](https://github.com/ghepting/shelfspace.koplugin/commit/2628e659a1257558d11e532002b0d122235e5b61))
* square checkbox cells, clearer KOReader tags, and no reading progress for pictures ([#49](https://github.com/ghepting/shelfspace.koplugin/issues/49)) ([4426f16](https://github.com/ghepting/shelfspace.koplugin/commit/4426f16c935caf91614271006d1120578814247c))

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
