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
    -- The Shelf Space mark: a shelf used as a usage bar. Books stand on the left (what is used) and
    -- one long slot, drawn as a dashed outline, is left empty on the right (what is free). It is also
    -- the Overview's icon.
    shelfspace = function(tile, lift)
        local out = { rect(CENTER_X - 54, 140, 108, 9, 4.5, WHITE) }
        local base = 132
        for _, book in ipairs({ { 46.6, 76 }, { 67.6, 54 }, { 88.6, 84 } }) do -- x, top
            local x, top = book[1], book[2]
            out[#out + 1] = rect(x, top, 17, base - top, 3.5, WHITE)
            out[#out + 1] = rect(x, top + 9, 17, 3.5, 0, "#" .. tile)
            out[#out + 1] = rect(x, base - 14, 17, 3.5, 0, "#" .. tile)
        end
        out[#out + 1] = string.format('<rect x="111.1" y="71.5" width="35" height="%d" rx="3.5" fill="none" stroke="%s" '
            .. 'stroke-width="3" stroke-dasharray="7 5"/>', base - 70 - 3, WHITE)
        -- Raised so the mark sits at the tile's centre (4), or higher with a name under it (13).
        return string.format('<g transform="translate(0 %d)">', -(lift or 4)) .. table.concat(out) .. "</g>"
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
-- `koreader_logo` is KOReader's own logo as text, used for "koreader". `opts`: `bg` (hex) fills the
-- whole canvas first so the icon has no transparency; `lift` raises the Shelf Space mark.
function Icons.svg(name, hex, koreader_logo, opts)
    opts = opts or {}
    local canvas = opts.bg and string.format('<rect width="195" height="195" fill="#%s"/>', opts.bg) or ""
    if name == "koreader" then
        if not koreader_logo then return nil end
        local svg = koreader_logo:gsub("#00a89c", "#" .. hex)
        return (svg:gsub("</defs>", "</defs>" .. canvas, 1))
    end
    local draw = GLYPHS[name]
    if not draw then return nil end
    return '<?xml version="1.0" encoding="UTF-8"?><svg xmlns="http://www.w3.org/2000/svg" width="195" height="195" '
        .. 'viewBox="0 0 195 195">' .. canvas .. string.format(TILE, hex) .. draw(hex, opts.lift) .. "</svg>"
end

-- The full logo for use as a standalone image (the README's): the mark cropped to its tile, with the
-- name under the shelf. The text is given a fixed width so it comes out the same in any font.
function Icons.logo(hex)
    local svg = Icons.svg("shelfspace", hex, nil, { lift = 13 })
    svg = svg:gsub('width="195" height="195" viewBox="0 0 195 195"', 'width="154.6" height="193.8" viewBox="18.3 0.6 154.6 193.8"')
    local wordmark = string.format('<text x="%.1f" y="162" text-anchor="middle" font-family="Helvetica Neue, Helvetica, Arial, sans-serif" '
        .. 'font-size="19" font-weight="700" fill="%s" textLength="104" lengthAdjust="spacingAndGlyphs">ShelfSpace</text>', CENTER_X, WHITE)
    return (svg:gsub("</svg>$", wordmark .. "</svg>"))
end

local function readFile(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local text = f:read("*a")
    f:close()
    return text
end

-- An icon drawn `size` pixels square on a tile of colour `tile`, painted over the page colour `bg` so
-- it has no transparency to blend; nil if it can't be produced. The SVG is kept in KOReader's cache
-- folder, one per pair of colours, and rewritten whenever the drawing changes.
function Icons.widget(name, size, tile, bg)
    local function hexOf(color)
        local c = color:getColorRGB32()
        return string.format("%02x%02x%02x", c.r, c.g, c.b)
    end
    local hex, bg_hex = hexOf(tile), hexOf(bg)
    local cache = DataStorage:getDataDir() .. "/cache"
    local dir = cache .. "/shelfspace"
    local path = string.format("%s/%s-%s-%s.svg", dir, name, hex, bg_hex)
    local svg = Icons.svg(name, hex, name == "koreader" and readFile("resources/koreader.svg") or nil, { bg = bg_hex })
    if not svg then return nil end
    if readFile(path) ~= svg then
        lfs.mkdir(cache)
        lfs.mkdir(dir)
        local f = io.open(path, "w")
        if not f then return nil end
        f:write(svg)
        f:close()
    end
    return IconWidget:new{ file = path, width = size, height = size }
end

return Icons
