local Blitbuffer = require("ffi/blitbuffer")
local Screen = require("device").screen

-- ShelfSpace is black on white, like KOReader itself, with grays where something has to be told apart (the chart's
-- slices, a file's type, a rule, a disabled button). No colours of its own, with one exception: free space is green on
-- a colour screen, the one thing you open the chart to see, and a green that is dark (4.6 : 1 against white) so it
-- stands out from the grays. On a gray screen that green would come out about the same gray as the KOReader slice, so
-- there free space is the empty white ring inside the chart's outline instead.
local Theme = {}

Theme.FREE_GREEN = "#00873C"

function Theme.get()
    return {
        bg = Blitbuffer.COLOR_WHITE, ink = Blitbuffer.COLOR_BLACK, muted = Blitbuffer.COLOR_GRAY_5,
        -- rules and dividers are dark enough to see; fills (a disabled button, a chip's track) stay light, under black text
        line = Blitbuffer.COLOR_GRAY_9, chip = Blitbuffer.COLOR_GRAY_E, free = Blitbuffer.COLOR_GRAY_E, clear = Blitbuffer.COLOR_GRAY_E,
        accent = Blitbuffer.COLOR_BLACK, danger = Blitbuffer.COLOR_BLACK, white = Blitbuffer.COLOR_WHITE,
        -- what the chart and the header tiles stand for. The chart's slices run from black to a mid gray, and free space is
        -- the empty part of the ring (white, inside the chart's black outline) or green.
        brand = Blitbuffer.COLOR_BLACK, koreader_tile = Blitbuffer.COLOR_GRAY_7,
        books = Blitbuffer.COLOR_BLACK, koreader = Blitbuffer.COLOR_GRAY_5, other = Blitbuffer.COLOR_GRAY_9,
        free_space = Screen:isColorEnabled() and Blitbuffer.colorFromString(Theme.FREE_GREEN) or Blitbuffer.COLOR_WHITE,
        -- the tiles beside files in Browse: the file's type is also in its name, so shade only needs to help
        folder = Blitbuffer.COLOR_GRAY_9, epub = Blitbuffer.COLOR_BLACK, pdf = Blitbuffer.COLOR_GRAY_5,
        comic = Blitbuffer.COLOR_GRAY_B,
    }
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
