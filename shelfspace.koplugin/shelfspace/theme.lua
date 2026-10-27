local Blitbuffer = require("ffi/blitbuffer")

-- ShelfSpace is black on white, like KOReader itself, with grays where something has to be told apart (the chart's
-- slices, a file's type, a rule, a disabled button). No colours of its own: they would mean the plugin looks
-- different from the rest of KOReader, and gray does the job on every screen, colour or not.
local Theme = {}

function Theme.get()
    return {
        bg = Blitbuffer.COLOR_WHITE, ink = Blitbuffer.COLOR_BLACK, muted = Blitbuffer.COLOR_GRAY_5,
        line = Blitbuffer.COLOR_GRAY_B, chip = Blitbuffer.COLOR_GRAY_E, free = Blitbuffer.COLOR_GRAY_E, clear = Blitbuffer.COLOR_GRAY_E,
        accent = Blitbuffer.COLOR_BLACK, danger = Blitbuffer.COLOR_BLACK, white = Blitbuffer.COLOR_WHITE,
        -- what the chart and the header tiles stand for
        brand = Blitbuffer.COLOR_BLACK, koreader_tile = Blitbuffer.COLOR_GRAY_7,
        books = Blitbuffer.COLOR_GRAY_4, koreader = Blitbuffer.COLOR_GRAY_7, other = Blitbuffer.COLOR_GRAY_B,
        free_space = Blitbuffer.COLOR_GRAY_D,
        -- the tiles beside files in Browse
        folder = Blitbuffer.COLOR_GRAY_9, epub = Blitbuffer.COLOR_GRAY_5, pdf = Blitbuffer.COLOR_GRAY_7,
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
