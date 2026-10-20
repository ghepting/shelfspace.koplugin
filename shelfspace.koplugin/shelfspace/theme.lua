local Blitbuffer = require("ffi/blitbuffer")
local Screen = require("device").screen

local function hex(s) return Blitbuffer.colorFromString(s) end

-- Muted colours for Kaleido screens, plain grays everywhere else.
local Theme = {}

function Theme.get()
    if Screen:isColorEnabled() then
        return {
            bg = hex("#FBF8F1"), ink = hex("#1B1B1B"), muted = hex("#5E5A52"),
            line = hex("#D9D2C3"), chip = hex("#EFE8D8"), free = hex("#E8E2D3"),
            books = hex("#2F6F5E"), koreader = hex("#D9822B"), other = hex("#6C8EBF"),
        }
    end
    return {
        bg = Blitbuffer.COLOR_WHITE, ink = Blitbuffer.COLOR_BLACK, muted = Blitbuffer.COLOR_GRAY_5,
        line = Blitbuffer.COLOR_GRAY_B, chip = Blitbuffer.COLOR_GRAY_E, free = Blitbuffer.COLOR_GRAY_E,
        books = Blitbuffer.COLOR_BLACK, koreader = Blitbuffer.COLOR_GRAY_7, other = Blitbuffer.COLOR_GRAY_B,
    }
end

return Theme
