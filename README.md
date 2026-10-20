# Shelf Space

A [KOReader](https://github.com/koreader/koreader) plugin to see where your
device storage went and free it up. Works wherever KOReader runs (Kobo, Kindle,
PocketBook, Android, desktop).

## Status

Early scaffold. Today it shows free, used and total space for the library
partition under **Tools › Shelf Space**.

## Planned

- Biggest folders and files
- KOReader's own usage (cache, sidecars, logs, update downloads)
- Delete with proper sidecar cleanup

## Install

Copy the `shelfspace.koplugin` folder into KOReader's `plugins` directory and
restart KOReader.

## Development

Run the KOReader desktop emulator (`./kodev run`), then link the plugin in:

    ./dev.sh /path/to/koreader/plugins

## License

MIT
