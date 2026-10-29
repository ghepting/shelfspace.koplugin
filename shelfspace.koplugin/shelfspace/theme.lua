local Blitbuffer = require("ffi/blitbuffer")
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
    magenta = "#C2185B", orange = "#B35C00", purple = "#6A2C91", clear = "#FFDAD6",
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
        -- the tiles beside files in Browse: the file's type is also in its name, so shade only needs to help
        folder = Blitbuffer.COLOR_GRAY_9, epub = Blitbuffer.COLOR_BLACK, pdf = Blitbuffer.COLOR_GRAY_5,
        comic = Blitbuffer.COLOR_GRAY_B,
    }
    if not Screen:isColorEnabled() then return th end
    local function hex(name) return Blitbuffer.colorFromString(Theme.PALETTE[name]) end
    th.accent, th.brand, th.books, th.epub = hex("indigo"), hex("indigo"), hex("indigo"), hex("indigo")
    th.koreader_tile, th.koreader, th.folder = hex("teal"), hex("teal"), hex("teal")
    th.other, th.free_space, th.danger, th.clear = hex("gray"), hex("green"), hex("red"), hex("clear")
    th.duplicates = hex("magenta")
    th.pdf, th.comic = hex("orange"), hex("purple")
    return th
end

function Theme.kind(th, entry)
    if entry.is_dir then return th.folder end
    local ext = (entry.name:match("%.([^.]+)$") or ""):lower()
    if ext == "epub" or ext == "kepub" or ext == "mobi" or ext == "azw3" or ext == "azw" or ext == "fb2" then
        return th.epub
    elseif ext == "pdf" or ext == "djvu" then
        return th.pdf
    elseif ext == "cbz" or ext == "cbr" then
        return th.comic
    end
    return th.line
end

return Theme
