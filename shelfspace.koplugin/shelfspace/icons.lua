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
local GLYPHS = {
    -- A ring with a wedge missing: the chart on the Overview.
    storage = function()
        return string.format('<circle cx="%.1f" cy="%.1f" r="38" fill="none" stroke="%s" stroke-width="22" '
            .. 'stroke-dasharray="180 59" transform="rotate(-70 %.1f %.1f)"/>', CENTER_X, CENTER_Y, WHITE, CENTER_X, CENTER_Y)
    end,
    -- Four books on a shelf, each spine banded top and bottom.
    library = function(tile)
        local out = { string.format('<rect x="%.1f" y="136" width="96" height="9" rx="4.5" fill="%s"/>', CENTER_X - 48, WHITE) }
        local heights = { 58, 80, 52, 70 }
        for i, h in ipairs(heights) do
            local x, top = CENTER_X - 40 + (i - 1) * 21, 132 - h
            out[#out + 1] = string.format('<rect x="%.1f" y="%d" width="17" height="%d" rx="3.5" fill="%s"/>', x, top, h, WHITE)
            out[#out + 1] = string.format('<rect x="%.1f" y="%d" width="17" height="3.5" fill="#%s"/>', x, top + 9, tile)
            out[#out + 1] = string.format('<rect x="%.1f" y="%d" width="17" height="3.5" fill="#%s"/>', x, 132 - 14, tile)
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
