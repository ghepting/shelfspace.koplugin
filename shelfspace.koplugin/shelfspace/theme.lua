local Blitbuffer = require("ffi/blitbuffer")
local Formats = require("shelfspace/formats")
local Screen = require("device").screen

-- Text and outlines are black on white, like KOReader itself, with grays where something has to be told apart. On a
-- colour screen (Kaleido) ShelfSpace adds a few dark, saturated colours for the accent, the chart and the file types,
-- because a colour e-ink screen washes pastels out. Colour never carries meaning alone: the chart's slices have a black
-- outline and a label, a file's type is in its name, and a button says what it does. The chart's colours are spaced
-- apart in lightness, so it still reads for someone who cannot tell them apart. A gray screen gets the grays below.
local Theme = {}

-- Contrast against white: indigo 8.4, teal 5.3, magenta 5.9, red 5.0, burnt orange 4.7, purple 7.1 (all fine under white text);
-- green 3.1 and gray 1.9 are only ever a fill beside a black outline and a label, never text. Gray is for what ShelfSpace
-- cannot touch (Other files), so it is the one chart colour with no hue.
Theme.PALETTE = {
    indigo = "#3B2FD1", teal = "#00796B", green = "#34A853", gray = "#BBBBBB", red = "#D32F2F",
    magenta = "#C2185B", orange = "#B35C00", purple = "#6A2C91", slate = "#6B6B6B", cyan = "#00698F", olive = "#6F6100", clear = "#FFDAD6",
    -- Pale fills behind a row, under black text (16:1 or better). A colour e-ink screen washes them nearly to white, so a
    -- row never depends on its tint: the label and the size say everything.
    tint_indigo = "#E0DEFF", tint_teal = "#D3F2EC", tint_gray = "#E6E6E6", tint_green = "#DDF5DF", tint_magenta = "#FBD9E8",
    tint_orange = "#FFE3CC", tint_purple = "#F0E1FA", tint_slate = "#EDEDED", tint_cyan = "#D6EEF7", tint_olive = "#F2EBC8",
}

function Theme.get()
    local th = {
        bg = Blitbuffer.COLOR_WHITE, ink = Blitbuffer.COLOR_BLACK, muted = Blitbuffer.COLOR_GRAY_5,
        -- rules and dividers are dark enough to see; fills (a disabled button, a chip's track) stay light, under black text
        line = Blitbuffer.COLOR_GRAY_9, chip = Blitbuffer.COLOR_GRAY_E, free = Blitbuffer.COLOR_GRAY_E, clear = Blitbuffer.COLOR_GRAY_E,
        accent = Blitbuffer.COLOR_BLACK, danger = Blitbuffer.COLOR_BLACK, white = Blitbuffer.COLOR_WHITE,
        -- what the chart and the header tiles stand for. The chart's slices run from black to a mid gray, and free space is
        -- the empty part of the ring (white, inside the chart's black outline).
        brand = Blitbuffer.COLOR_BLACK, koreader_tile = Blitbuffer.COLOR_BLACK, duplicates = Blitbuffer.COLOR_BLACK,
        books = Blitbuffer.COLOR_BLACK, koreader = Blitbuffer.COLOR_GRAY_5, other = Blitbuffer.COLOR_GRAY_9,
        free_space = Blitbuffer.COLOR_WHITE,
        -- the tiles beside files in the Library: the file's type is also in its name, so shade only needs to help
        folder = Blitbuffer.COLOR_GRAY_9, book = Blitbuffer.COLOR_BLACK, document = Blitbuffer.COLOR_GRAY_7, fixed = Blitbuffer.COLOR_GRAY_5,
        comic = Blitbuffer.COLOR_GRAY_B, image = Blitbuffer.COLOR_GRAY_D,
        -- what a legend row sits on; white on a gray screen, where a rule between rows does the separating
        tint_books = Blitbuffer.COLOR_WHITE, tint_koreader = Blitbuffer.COLOR_WHITE, tint_other = Blitbuffer.COLOR_WHITE,
        tint_free = Blitbuffer.COLOR_WHITE, tint_duplicates = Blitbuffer.COLOR_WHITE,
        -- the page's title band: white with a rule on a gray screen, indigo on a colour one; and whether rows are tinted
        band = Blitbuffer.COLOR_WHITE, on_band = Blitbuffer.COLOR_BLACK, tinted = false,
        -- the row of each kind of file: its fill, and the colour of the letters on its tile
        tint_kind = { dir = Blitbuffer.COLOR_WHITE, book = Blitbuffer.COLOR_WHITE, document = Blitbuffer.COLOR_WHITE, fixed = Blitbuffer.COLOR_WHITE,
            comic = Blitbuffer.COLOR_WHITE, image = Blitbuffer.COLOR_WHITE, other = Blitbuffer.COLOR_WHITE },
        on_kind = { dir = Blitbuffer.COLOR_BLACK, book = Blitbuffer.COLOR_WHITE, document = Blitbuffer.COLOR_WHITE, fixed = Blitbuffer.COLOR_WHITE,
            comic = Blitbuffer.COLOR_BLACK, image = Blitbuffer.COLOR_BLACK, other = Blitbuffer.COLOR_BLACK },
    }
    if not Screen:isColorEnabled() then return th end
    local function hex(name) return Blitbuffer.colorFromString(Theme.PALETTE[name]) end
    th.accent, th.brand, th.books = hex("indigo"), hex("indigo"), hex("indigo")
    th.koreader_tile, th.koreader, th.folder = hex("teal"), hex("teal"), hex("teal")
    th.other, th.free_space, th.danger, th.clear = hex("gray"), hex("green"), hex("red"), hex("clear")
    th.duplicates = hex("magenta")
    th.tint_books, th.tint_koreader, th.tint_other = hex("tint_indigo"), hex("tint_teal"), hex("tint_gray")
    th.tint_free, th.tint_duplicates = hex("tint_green"), hex("tint_magenta")
    th.book, th.document, th.fixed, th.comic, th.image = hex("indigo"), hex("cyan"), hex("orange"), hex("purple"), hex("olive")
    th.folder = hex("slate") -- teal means KOReader's data and indigo means books, so a folder is neither
    th.band, th.on_band, th.tinted = hex("indigo"), th.white, true
    th.tint_kind = {
        dir = hex("tint_slate"), book = hex("tint_indigo"), document = hex("tint_cyan"), fixed = hex("tint_orange"),
        comic = hex("tint_purple"), image = hex("tint_olive"), other = hex("tint_gray"),
    }
    th.on_kind = { dir = th.white, book = th.white, document = th.white, fixed = th.white, comic = th.white, image = th.white, other = th.ink }
    return th
end

-- "dir" for a folder, else what Formats says the file is: "book", "document", "fixed", "comic", "image" or "other". What a row's
-- tile and tint are drawn for.
function Theme.kindName(entry)
    if entry.is_dir then return "dir" end
    return Formats.kind(entry.name)
end

local KIND_COLOR = { dir = "folder", book = "book", document = "document", fixed = "fixed", comic = "comic", image = "image", other = "line" }

function Theme.kind(th, entry) return th[KIND_COLOR[Theme.kindName(entry)]] end
function Theme.tint(th, entry) return th.tint_kind[Theme.kindName(entry)] end
function Theme.on(th, entry) return th.on_kind[Theme.kindName(entry)] end

return Theme
