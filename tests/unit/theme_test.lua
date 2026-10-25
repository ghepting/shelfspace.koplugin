local T = dofile((debug.getinfo(1, "S").source:match("^@(.*)/[^/]+$") or ".") .. "/helper.lua")

-- Colours as plain strings, and the screen reporting colour, so Theme.get() can be read as data.
package.preload["ffi/blitbuffer"] = function()
    local b = { colorFromString = function(s) return s end }
    for _, name in ipairs({ "WHITE", "BLACK", "GRAY_4", "GRAY_5", "GRAY_7", "GRAY_9", "GRAY_B", "GRAY_D", "GRAY_E" }) do
        b["COLOR_" .. name] = "gray:" .. name
    end
    return b
end
local color = true
package.preload["device"] = function() return { screen = { isColorEnabled = function() return color end } } end
local Theme = require("shelfspace/theme")

print("theme")

-- The design tokens, read from assets/theme.json: { name = "seeking sage", hex = "#99B898" } ...
local function tokens()
    local here = debug.getinfo(1, "S").source:match("^@(.*)/[^/]+$") or "."
    local f = assert(io.open(here .. "/../../assets/theme.json"), "assets/theme.json is missing")
    local text = f:read("*a")
    f:close()
    local list = {}
    for name, hex in text:gmatch('"name"%s*:%s*"([^"]+)"%s*,%s*"hex"%s*:%s*"(#%x%x%x%x%x%x)"') do
        list[#list + 1] = { name = name, hex = hex:upper() }
    end
    return list
end

T.test("theme.json lists the seven tokens, each with a hex that matches its rgb", function()
    local here = debug.getinfo(1, "S").source:match("^@(.*)/[^/]+$") or "."
    local f = assert(io.open(here .. "/../../assets/theme.json"))
    local text = f:read("*a")
    f:close()
    T.eq(#tokens(), 7)
    for hex, r, g, b in text:gmatch('"hex"%s*:%s*"#(%x%x%x%x%x%x)"%s*,%s*"rgb"%s*:%s*%[%s*(%d+)%s*,%s*(%d+)%s*,%s*(%d+)%s*%]') do
        T.eq(string.format("%02X%02X%02X", tonumber(r), tonumber(g), tonumber(b)), hex:upper(), "rgb of #" .. hex)
    end
end)

T.test("every token in theme.json is a colour the plugin uses, and the plugin has no other brand colours", function()
    local used = {}
    for _, hex in pairs(Theme.TOKENS) do used[hex:upper()] = true end
    for _, token in ipairs(tokens()) do
        assert(used[token.hex], token.name .. " (" .. token.hex .. ") is in theme.json but not in Theme.TOKENS")
        used[token.hex] = nil
    end
    for hex in pairs(used) do error(hex .. " is in Theme.TOKENS but not in theme.json") end
end)

T.test("the chart and the header tiles use the colours that were asked for", function()
    local th = Theme.get()
    T.eq(th.free_space, Theme.TOKENS.sage)   -- free space: seeking sage
    T.eq(th.other, Theme.TOKENS.gray)        -- other files: other gray
    T.eq(th.koreader, Theme.TOKENS.coral)    -- KOReader data: complete coral
    T.eq(th.brand, Theme.TOKENS.slate)       -- the ShelfSpace tile: coup de grâce
    T.eq(th.books, Theme.TOKENS.melon)       -- books, and the Library tile: melonjolly
    T.eq(th.koreader_tile, Theme.OFFICIAL.koreader) -- the KOReader tile: KOReader's own teal
    T.eq(th.bg, Theme.TOKENS.beige)          -- the page
    T.eq(th.ink, Theme.TOKENS.slate)
end)

T.test("no two chart slices share a colour", function()
    local th, seen = Theme.get(), {}
    for _, key in ipairs({ "books", "koreader", "other", "free_space" }) do
        assert(not seen[th[key]], key .. " shares a colour with " .. tostring(seen[th[key]]))
        seen[th[key]] = key
    end
end)

T.test("a grayscale screen gets the same roles, all in grays", function()
    color = false
    local th = Theme.get()
    color = true
    for _, key in ipairs({ "bg", "ink", "muted", "line", "chip", "free", "accent", "danger", "brand", "koreader_tile", "books", "koreader",
                            "other", "free_space", "folder", "epub", "pdf", "comic" }) do
        assert(th[key] and tostring(th[key]):find("^gray:"), key .. " is not a gray")
    end
end)

T.test("files are coloured by type, and unknown ones fall back to the rule colour", function()
    local th = Theme.get()
    T.eq(Theme.kind(th, { name = "x", is_dir = true }), th.folder)
    T.eq(Theme.kind(th, { name = "a.EPUB" }), th.epub)
    T.eq(Theme.kind(th, { name = "a.pdf" }), th.pdf)
    T.eq(Theme.kind(th, { name = "a.cbz" }), th.comic)
    T.eq(Theme.kind(th, { name = "a.so" }), th.line)
end)

T.done()
