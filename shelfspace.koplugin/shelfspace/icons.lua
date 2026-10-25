local DataStorage = require("datastorage")
local IconWidget = require("ui/widget/iconwidget")
local lfs = require("libs/libkoreader-lfs")

-- The three header icons: a portrait book-shaped tile with a white glyph, the shape of KOReader's own
-- logo. KOReader's logo is read from the install and recoloured; the other two are drawn here.
local Icons = {}

-- Same 195 x 195 canvas and cover outline as KOReader's logo (it starts 18.3 from the left and is 154.6
-- wide), so the three line up when drawn at one size.
local TILE = '<rect x="18.3" y="0.6" width="154.6" height="193.8" rx="22.5" ry="22.5" fill="#%s"/>'
local WHITE = "#ffffff"
local CENTER_X, CENTER_Y = 95.6, 97.5

-- Glyphs are white on the tile; `tile` is the tile colour, for details cut out of the glyph.
local function rect(x, y, w, h, rx, fill)
    return string.format('<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" rx="%.1f" fill="%s"/>', x, y, w, h, rx, fill)
end

local GLYPHS = {
    -- The Shelf Space mark: books standing on a shelf with one slot left empty, drawn as a dashed
    -- outline. It is also the Overview's icon.
    shelfspace = function(tile)
        local out = { rect(CENTER_X - 48, 136, 96, 9, 4.5, WHITE) }
        -- x, width, height; the third is the empty slot, wider than a book so it reads as room.
        local slots = { { 52.1, 17, 58 }, { 73.1, 17, 80 }, { 94.1, 24, 66 }, { 122.1, 17, 70 } }
        for i, slot in ipairs(slots) do
            local x, w, h = slot[1], slot[2], slot[3]
            local top = 132 - h
            if i == 3 then
                out[#out + 1] = string.format('<rect x="%.1f" y="%d" width="%d" height="%d" rx="3.5" fill="none" stroke="%s" '
                    .. 'stroke-width="3" stroke-dasharray="7 5"/>', x + 1.5, top + 1.5, w - 3, h - 3, WHITE)
            else
                out[#out + 1] = rect(x, top, w, h, 3.5, WHITE)
                out[#out + 1] = rect(x, top + 9, w, 3.5, 0, "#" .. tile)
                out[#out + 1] = rect(x, 132 - 14, w, 3.5, 0, "#" .. tile)
            end
        end
        return table.concat(out)
    end,
    -- Three books lying in a stack, a band near each end of every spine: the Library.
    library = function(tile)
        local out = {}
        local stack = { { 55, 84, 116 }, { 61, 76, 92 }, { 51, 88, 68 } } -- x, width, y (bottom to top)
        for _, b in ipairs(stack) do
            out[#out + 1] = rect(CENTER_X - 46 + (b[1] - 51), b[3], b[2], 20, 4, WHITE)
            out[#out + 1] = rect(CENTER_X - 46 + (b[1] - 51) + 11, b[3], 3.5, 20, 0, "#" .. tile)
            out[#out + 1] = rect(CENTER_X - 46 + (b[1] - 51) + b[2] - 15, b[3], 3.5, 20, 0, "#" .. tile)
        end
        return table.concat(out)
    end,
}

-- The SVG text for icon `name` on a tile of colour `hex` ("2f6f5e"), or nil when it can't be made.
-- `koreader_logo` is KOReader's own logo as text, used for "koreader".
function Icons.svg(name, hex, koreader_logo)
    if name == "koreader" then
        return koreader_logo and (koreader_logo:gsub("#00a89c", "#" .. hex)) or nil
    end
    local draw = GLYPHS[name]
    if not draw then return nil end
    local glyph = draw(hex)
    return '<?xml version="1.0" encoding="UTF-8"?><svg xmlns="http://www.w3.org/2000/svg" width="195" height="195" '
        .. 'viewBox="0 0 195 195">' .. string.format(TILE, hex) .. glyph .. "</svg>"
end

-- The mark on its own, cropped to the tile, for use as a standalone image (the README's logo).
function Icons.logo(hex)
    local svg = Icons.svg("shelfspace", hex)
    return (svg:gsub('width="195" height="195" viewBox="0 0 195 195"', 'width="154.6" height="193.8" viewBox="18.3 0.6 154.6 193.8"'))
end

local function readFile(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local text = f:read("*a")
    f:close()
    return text
end

-- An icon drawn `size` pixels square on a tile of colour `bg`, or nil if it can't be produced.
-- The SVG is written once per colour into KOReader's cache folder and reused.
function Icons.widget(name, size, bg)
    local c = bg:getColorRGB32()
    local hex = string.format("%02x%02x%02x", c.r, c.g, c.b)
    local cache = DataStorage:getDataDir() .. "/cache"
    local dir = cache .. "/shelfspace"
    local path = string.format("%s/%s-%s.svg", dir, name, hex)
    if lfs.attributes(path, "mode") ~= "file" then
        local svg = Icons.svg(name, hex, name == "koreader" and readFile("resources/koreader.svg") or nil)
        if not svg then return nil end
        lfs.mkdir(cache)
        lfs.mkdir(dir)
        local f = io.open(path, "w")
        if not f then return nil end
        f:write(svg)
        f:close()
    end
    return IconWidget:new{ file = path, width = size, height = size, alpha = true }
end

return Icons
