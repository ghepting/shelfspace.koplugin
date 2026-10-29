local T = dofile((debug.getinfo(1, "S").source:match("^@(.*)/[^/]+$") or ".") .. "/helper.lua")

-- Colours as plain strings, and the screen reporting colour or not, so Theme.get() can be read as data.
package.preload["ffi/blitbuffer"] = function()
    local b = { colorFromString = function(s) return "rgb:" .. s end }
    for _, name in ipairs({ "WHITE", "BLACK", "GRAY_4", "GRAY_5", "GRAY_7", "GRAY_9", "GRAY_B", "GRAY_D", "GRAY_E" }) do
        b["COLOR_" .. name] = name == "WHITE" and "white" or name == "BLACK" and "black" or "gray:" .. name
    end
    return b
end
local color = true
package.preload["device"] = function() return { screen = { isColorEnabled = function() return color end } } end
local Theme = require("shelfspace/theme")

local function get(on_colour_screen)
    color = on_colour_screen
    local th = Theme.get()
    color = true
    return th
end

-- Every colour in the theme, one by one: the nested tables (a colour for each kind of file) are flattened and flags skipped.
local function each(th, fn)
    for key, value in pairs(th) do
        if type(value) == "table" then
            for k2, v2 in pairs(value) do fn(key .. "." .. k2, v2) end
        elseif type(value) ~= "boolean" then
            fn(key, value)
        end
    end
end

print("theme")

T.test("the page is white and the text black", function()
    local th = get(true)
    T.eq(th.bg, "white")
    T.eq(th.ink, "black")
end)

T.test("on a gray screen every colour is black, white or a gray: ShelfSpace has none of its own", function()
    each(get(false), function(key, value)
        assert(value == "white" or value == "black" or tostring(value):find("^gray:"), key .. " is not black, white or a gray")
    end)
end)

local function luminance(hex)
    local c = {}
    for i = 2, 6, 2 do
        local v = tonumber(hex:sub(i, i + 1), 16) / 255
        table.insert(c, v <= 0.03928 and v / 12.92 or ((v + 0.055) / 1.055) ^ 2.4)
    end
    return 0.2126 * c[1] + 0.7152 * c[2] + 0.0722 * c[3]
end
local function contrast_with_white(hex) return 1.05 / (luminance(hex) + 0.05) end
local function lightness(hex)
    local y = luminance(hex)
    return y > 0.008856 and 116 * y ^ (1 / 3) - 16 or 903.3 * y
end

T.test("on a colour screen the colours come from the palette, and everything else stays black, white or gray", function()
    local th, in_palette = get(true), {}
    for _, hex in pairs(Theme.PALETTE) do in_palette["rgb:" .. hex] = true end
    each(th, function(key, value)
        assert(value == "white" or value == "black" or tostring(value):find("^gray:") or in_palette[value], key .. " is not from the palette")
    end)
    for _, key in ipairs({ "ink", "bg", "muted", "line", "chip", "free", "white" }) do
        assert(th[key] == "white" or th[key] == "black" or tostring(th[key]):find("^gray:"), key .. " is not black, white or a gray")
    end
end)

T.test("a colour that carries text or sits under white text has at least 4.5:1 against white", function()
    for _, name in ipairs({ "indigo", "teal", "red", "magenta", "orange", "purple", "slate" }) do
        assert(contrast_with_white(Theme.PALETTE[name]) >= 4.5, name .. " is under 4.5:1")
    end
end)

T.test("a colour only used as a chart fill has at least 3:1 against white, or is beside a black outline", function()
    assert(contrast_with_white(Theme.PALETTE.green) >= 3, "green is under 3:1")
end)

T.test("the chart's colours are at least 10 points of lightness apart, so they stay apart without hue", function()
    local names, shades = { "indigo", "teal", "green", "gray" }, {}
    for _, name in ipairs(names) do table.insert(shades, lightness(Theme.PALETTE[name])) end
    table.sort(shades)
    for i = 2, #shades do assert(shades[i] - shades[i - 1] >= 10, "two chart colours are within 10 points of lightness") end
end)

T.test("every pale fill keeps black text above 15:1", function()
    for name, hex in pairs(Theme.PALETTE) do
        if name:find("^tint_") or name == "clear" then
            assert((luminance(hex) + 0.05) / 0.05 > 15, name .. " is too dark for black text")
        end
    end
end)

T.test("on a colour screen a row is tinted and the header is a band; on a gray screen neither is", function()
    local colour, gray = get(true), get(false)
    assert(colour.tinted and not gray.tinted)
    T.eq(colour.band, "rgb:" .. Theme.PALETTE.indigo)
    T.eq(gray.band, "white")
    T.eq(gray.on_band, "black")
end)

T.test("a file's tint and the letters on its tile follow its kind", function()
    local th = get(true)
    T.eq(Theme.tint(th, { name = "a.epub" }), th.tint_kind.epub)
    T.eq(Theme.tint(th, { name = "a.pdf" }), th.tint_kind.pdf)
    T.eq(Theme.tint(th, { name = "x", is_dir = true }), th.tint_kind.dir)
    T.eq(Theme.on(th, { name = "a.cbz" }), th.on_kind.comic)
    T.eq(Theme.kindName({ name = "a.so" }), "other")
    T.eq(Theme.kindName({ name = "README" }), "other")
end)

T.test("a folder is neither the books' indigo nor KOReader's teal", function()
    local th = get(true)
    assert(th.folder ~= th.books and th.folder ~= th.koreader)
end)

T.test("on a gray screen the letters on a tile are readable on its shade", function()
    local th = get(false)
    T.eq(th.on_kind.dir, "black") -- light gray tile
    T.eq(th.on_kind.epub, "white") -- black tile
end)

T.test("no two chart slices share a shade", function()
    local th, seen = get(true), {}
    for _, key in ipairs({ "books", "koreader", "other", "free_space" }) do
        assert(not seen[th[key]], key .. " shares a shade with " .. tostring(seen[th[key]]))
        seen[th[key]] = key
    end
end)

T.test("on a gray screen a delete button is as dark as the text, so it reads", function()
    local th = get(false)
    T.eq(th.danger, th.ink)
end)

T.test("files are shaded by type, and unknown ones fall back to the rule shade", function()
    local th = get(true)
    T.eq(Theme.kind(th, { name = "x", is_dir = true }), th.folder)
    T.eq(Theme.kind(th, { name = "a.EPUB" }), th.epub)
    T.eq(Theme.kind(th, { name = "a.pdf" }), th.pdf)
    T.eq(Theme.kind(th, { name = "a.cbz" }), th.comic)
    T.eq(Theme.kind(th, { name = "a.so" }), th.line)
end)

T.done()
