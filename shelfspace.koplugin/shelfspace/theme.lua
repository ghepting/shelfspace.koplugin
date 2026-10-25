local Blitbuffer = require("ffi/blitbuffer")
local Screen = require("device").screen

local function hex(s) return Blitbuffer.colorFromString(s) end

-- The colours are the design tokens in assets/theme.json (a test checks they match): the "Coup de Grace"
-- palette on COLOURlovers plus two neutrals. Kaleido screens get them; everything else gets plain grays
-- with the same roles.
local Theme = {}

Theme.TOKENS = {
    sage = "#99B898",   -- seeking sage
    skin = "#FECEA8",   -- comfortable skin
    coral = "#FF847C",  -- complete coral
    melon = "#E84A5F",  -- melonjolly
    slate = "#2A363B",  -- coup de grace
    gray = "#BBBFC9",   -- other gray
    beige = "#F4F2ED",  -- beige ink
}

-- Tints of the page for rules, chips, tracks and disabled buttons, and the muted text colour. These are
-- not in theme.json; they are chosen to sit between the beige and the slate.
Theme.NEUTRALS = { muted = "#66737A", line = "#DCD8CE", chip = "#E9E5DB", track = "#E3DFD4" }

function Theme.get()
    if Screen:isColorEnabled() then
        local t, n = Theme.TOKENS, Theme.NEUTRALS
        return {
            bg = hex(t.beige), ink = hex(t.slate), muted = hex(n.muted),
            line = hex(n.line), chip = hex(n.chip), free = hex(n.track), -- free: tracks and disabled buttons
            accent = hex(t.slate), danger = hex(t.melon), white = Blitbuffer.COLOR_WHITE,
            -- what the chart and the header tiles stand for
            brand = hex(t.melon),                                   -- the ShelfSpace tile
            books = hex(t.slate), koreader = hex(t.coral), other = hex(t.gray), free_space = hex(t.sage),
            -- the tiles beside files in Browse
            folder = hex(t.sage), epub = hex(t.melon), pdf = hex(t.coral), comic = hex(t.skin),
        }
    end
    return {
        bg = Blitbuffer.COLOR_WHITE, ink = Blitbuffer.COLOR_BLACK, muted = Blitbuffer.COLOR_GRAY_5,
        line = Blitbuffer.COLOR_GRAY_B, chip = Blitbuffer.COLOR_GRAY_E, free = Blitbuffer.COLOR_GRAY_E,
        accent = Blitbuffer.COLOR_BLACK, danger = Blitbuffer.COLOR_BLACK, white = Blitbuffer.COLOR_WHITE,
        brand = Blitbuffer.COLOR_BLACK,
        books = Blitbuffer.COLOR_GRAY_4, koreader = Blitbuffer.COLOR_GRAY_7, other = Blitbuffer.COLOR_GRAY_B,
        free_space = Blitbuffer.COLOR_GRAY_D,
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
