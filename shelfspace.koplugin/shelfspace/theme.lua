local Blitbuffer = require("ffi/blitbuffer")
local Screen = require("device").screen

local function hex(s) return Blitbuffer.colorFromString(s) end

-- The palette is "Coup de Grace" on COLOURlovers: sage #99B898, peach #FECEA8, coral #FF847C,
-- raspberry #E84A5F and slate #2A363B, on a beige page (#F4F2ED). Kaleido screens get it; everything
-- else gets plain grays with the same roles.
local Theme = {}

function Theme.get()
    if Screen:isColorEnabled() then
        return {
            bg = hex("#F4F2ED"), ink = hex("#2A363B"), muted = hex("#66737A"),
            line = hex("#DCD8CE"), chip = hex("#E9E5DB"), free = hex("#E3DFD4"), -- neutrals: rules, chips, tracks, disabled
            accent = hex("#2A363B"), danger = hex("#E84A5F"), white = Blitbuffer.COLOR_WHITE,
            books = hex("#99B898"), koreader = hex("#FF847C"), other = hex("#2A363B"), peach = hex("#FECEA8"),
            library = hex("#99B898"), epub = hex("#E84A5F"), comic = hex("#FECEA8"),
        }
    end
    return {
        bg = Blitbuffer.COLOR_WHITE, ink = Blitbuffer.COLOR_BLACK, muted = Blitbuffer.COLOR_GRAY_5,
        line = Blitbuffer.COLOR_GRAY_B, chip = Blitbuffer.COLOR_GRAY_E, free = Blitbuffer.COLOR_GRAY_E,
        accent = Blitbuffer.COLOR_BLACK, danger = Blitbuffer.COLOR_BLACK, white = Blitbuffer.COLOR_WHITE,
        books = Blitbuffer.COLOR_BLACK, koreader = Blitbuffer.COLOR_GRAY_7, other = Blitbuffer.COLOR_GRAY_B,
        peach = Blitbuffer.COLOR_GRAY_D, library = Blitbuffer.COLOR_GRAY_4, epub = Blitbuffer.COLOR_GRAY_5,
        comic = Blitbuffer.COLOR_GRAY_9,
    }
end

function Theme.kind(th, entry)
    if entry.is_dir then return th.books end
    local ext = (entry.name:match("%.([^.]+)$") or ""):lower()
    if ext == "epub" or ext == "kepub" or ext == "mobi" or ext == "azw3" or ext == "azw" or ext == "fb2" then
        return th.epub
    elseif ext == "pdf" or ext == "djvu" then
        return th.koreader
    elseif ext == "cbz" or ext == "cbr" then
        return th.comic
    end
    return th.line
end

return Theme
