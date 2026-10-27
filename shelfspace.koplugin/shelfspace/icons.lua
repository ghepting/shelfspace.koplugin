local DataStorage = require("datastorage")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local IconWidget = require("ui/widget/iconwidget")
local OverlapGroup = require("ui/widget/overlapgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local lfs = require("libs/libkoreader-lfs")

-- The three header icons: a portrait book-shaped tile with a white glyph, the shape of KOReader's own
-- logo. KOReader's logo is read from the install and recoloured; the other two are drawn here.
local Icons = {}

-- Same 195 x 195 canvas and cover outline as KOReader's logo (it starts 18.3 from the left and is 154.6
-- wide), so the three line up when drawn at one size.
local TILE_X, TILE_Y, TILE_W, TILE_H, TILE_R = 18.3, 0.6, 154.6, 193.8, 22.5
local TILE = string.format('<rect x="%s" y="%s" width="%s" height="%s" rx="%s" ry="%s" fill="#%%s"/>', TILE_X, TILE_Y, TILE_W, TILE_H, TILE_R, TILE_R)
local WHITE = "#ffffff"
local CENTER_X, CENTER_Y = 95.6, 97.5

-- Glyphs are white on the tile; `tile` is the tile colour, for details cut out of the glyph.
local function rect(x, y, w, h, rx, fill)
    return string.format('<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" rx="%.1f" fill="%s"/>', x, y, w, h, rx, fill)
end

local GLYPHS = {
    -- The ShelfSpace mark: a shelf used as a usage bar. Books stand on the left (what is used) and
    -- one long slot, drawn as a dashed outline, is left empty on the right (what is free). It is also
    -- the Overview's icon.
    shelfspace = function(tile, lift, shift, glyph)
        glyph = "#" .. (glyph or "ffffff")
        local out = { rect(CENTER_X - 54, 140, 108, 9, 4.5, glyph) }
        local base = 132
        for _, book in ipairs({ { 46.6, 76 }, { 67.6, 54 }, { 88.6, 84 } }) do -- x, top
            local x, top = book[1], book[2]
            out[#out + 1] = rect(x, top, 17, base - top, 3.5, glyph)
            out[#out + 1] = rect(x, top + 9, 17, 3.5, 0, "#" .. tile)
            out[#out + 1] = rect(x, base - 14, 17, 3.5, 0, "#" .. tile)
        end
        out[#out + 1] = string.format('<rect x="111.1" y="71.5" width="35" height="%d" rx="3.5" fill="none" stroke="%s" '
            .. 'stroke-width="3" stroke-dasharray="7 5"/>', base - 70 - 3, glyph)
        -- The default places the mark by weight, not by its bounding box: the shelf and books carry the ink
        -- low and to the left (the empty slot is only an outline), so it is raised 9 and moved right 4.
        -- With a name under it (the logo) it is raised 13 instead, and not shifted.
        return string.format('<g transform="translate(%d %d)">', shift or 4, -(lift or 9)) .. table.concat(out) .. "</g>"
    end,
    -- Three books lying in a stack, a band near each end of every spine: the Library.
    library = function(tile, _, _, glyph)
        glyph = "#" .. (glyph or "ffffff")
        local out = {}
        local stack = { { 55, 84, 116 }, { 61, 76, 92 }, { 51, 88, 68 } } -- x, width, y (bottom to top)
        for _, b in ipairs(stack) do
            out[#out + 1] = rect(CENTER_X - 46 + (b[1] - 51), b[3], b[2], 20, 4, glyph)
            out[#out + 1] = rect(CENTER_X - 46 + (b[1] - 51) + 11, b[3], 3.5, 20, 0, "#" .. tile)
            out[#out + 1] = rect(CENTER_X - 46 + (b[1] - 51) + b[2] - 15, b[3], 3.5, 20, 0, "#" .. tile)
        end
        return table.concat(out)
    end,
}

-- The name under the shelf, as outlines: KOReader's SVG renderer ignores <text>, and outlines look the same
-- everywhere. The letters are Noto Sans Bold (SIL Open Font License), the face KOReader ships, scaled to
-- 104 units wide with their baseline at y = 162; tools/make-wordmark.py regenerates this.
local WORDMARK = "M53.5 158.2Q53.5 160 52.1 161.1Q50.8 162.2 48.4 162.2Q46.2 162.2 44.5 161.4L44.5 158.6Q45.5 159.1 46.5 159.4Q47.6 159.8 48.6 159.8Q49.7 159.8 50.2 159.4Q50.6 158.9 50.6 158.3Q50.6 157.8 50.3 157.4Q49.9 157.1 49.3 156.7Q48.7 156.4 47.9 156.1Q47.4 155.8 46.9 155.5Q46.3 155.2 45.8 154.7Q45.3 154.2 45 153.6Q44.6 152.9 44.6 151.9Q44.6 150.1 45.9 149Q47.2 148 49.3 148Q50.4 148 51.4 148.3Q52.4 148.5 53.4 149L52.5 151.3Q51.5 150.9 50.8 150.7Q50 150.4 49.2 150.4Q48.4 150.4 47.9 150.8Q47.5 151.2 47.5 151.8Q47.5 152.6 48.2 153Q48.8 153.4 50.1 154Q51.2 154.5 51.9 155.1Q52.7 155.6 53.1 156.4Q53.5 157.1 53.5 158.2ZM58.6 150.3Q58.6 151.1 58.6 151.8Q58.5 152.5 58.5 152.8L58.6 152.8Q59.1 152 59.9 151.6Q60.7 151.3 61.7 151.3Q63.4 151.3 64.5 152.2Q65.5 153.1 65.5 155.1L65.5 162L62.6 162L62.6 155.8Q62.6 153.6 60.9 153.6Q59.6 153.6 59.1 154.5Q58.6 155.4 58.6 157L58.6 162L55.8 162L55.8 147.3L58.6 147.3L58.6 150.3ZM72.8 151.3Q75 151.3 76.2 152.5Q77.5 153.8 77.5 156.1L77.5 157.4L70.7 157.4Q70.8 158.7 71.4 159.4Q72.1 160 73.3 160Q74.4 160 75.2 159.8Q76 159.6 76.9 159.2L76.9 161.4Q76.1 161.8 75.3 162Q74.4 162.2 73.2 162.2Q71.6 162.2 70.4 161.6Q69.2 161 68.5 159.8Q67.8 158.6 67.8 156.8Q67.8 154.9 68.4 153.7Q69.1 152.5 70.2 151.9Q71.3 151.3 72.8 151.3ZM72.8 153.3Q72 153.3 71.4 153.8Q70.9 154.4 70.8 155.5L74.8 155.5Q74.8 154.6 74.3 153.9Q73.8 153.3 72.8 153.3ZM82.7 162L79.9 162L79.9 147.3L82.7 147.3L82.7 162ZM91.6 153.6L89.1 153.6L89.1 162L86.2 162L86.2 153.6L84.6 153.6L84.6 152.2L86.2 151.5L86.2 150.7Q86.2 149.3 86.7 148.6Q87.1 147.8 88 147.5Q88.8 147.2 89.9 147.2Q90.8 147.2 91.5 147.4Q92.2 147.5 92.6 147.7L91.9 149.8Q91.5 149.7 91.1 149.6Q90.8 149.5 90.2 149.5Q89.7 149.5 89.4 149.9Q89.1 150.2 89.1 150.8L89.1 151.5L91.6 151.5L91.6 153.6ZM101.6 158.2Q101.6 160 100.3 161.1Q98.9 162.2 96.5 162.2Q94.3 162.2 92.6 161.4L92.6 158.6Q93.6 159.1 94.6 159.4Q95.7 159.8 96.7 159.8Q97.8 159.8 98.3 159.4Q98.7 158.9 98.7 158.3Q98.7 157.8 98.4 157.4Q98 157.1 97.4 156.7Q96.8 156.4 96 156.1Q95.6 155.8 95 155.5Q94.4 155.2 93.9 154.7Q93.4 154.2 93.1 153.6Q92.8 152.9 92.8 151.9Q92.8 150.1 94 149Q95.3 148 97.4 148Q98.5 148 99.5 148.3Q100.5 148.5 101.5 149L100.6 151.3Q99.6 150.9 98.9 150.7Q98.1 150.4 97.3 150.4Q96.5 150.4 96.1 150.8Q95.6 151.2 95.6 151.8Q95.6 152.6 96.3 153Q96.9 153.4 98.2 154Q99.3 154.5 100 155.1Q100.8 155.6 101.2 156.4Q101.6 157.1 101.6 158.2ZM109.7 151.3Q111.5 151.3 112.6 152.6Q113.7 154 113.7 156.7Q113.7 159.4 112.6 160.8Q111.4 162.2 109.7 162.2Q108.5 162.2 107.8 161.8Q107.2 161.4 106.7 160.8L106.6 160.8Q106.7 161.7 106.7 162.4L106.7 166.6L103.9 166.6L103.9 151.5L106.2 151.5L106.6 152.8L106.7 152.8Q107.2 152.2 107.9 151.7Q108.6 151.3 109.7 151.3ZM108.8 153.6Q107.7 153.6 107.2 154.3Q106.8 154.9 106.7 156.4L106.7 156.7Q106.7 158.2 107.2 159Q107.7 159.9 108.9 159.9Q109.8 159.9 110.3 159Q110.8 158.2 110.8 156.7Q110.8 153.6 108.8 153.6ZM120.4 151.2Q122.5 151.2 123.7 152.2Q124.8 153.1 124.8 155L124.8 162L122.8 162L122.2 160.6L122.2 160.6Q121.5 161.4 120.7 161.8Q120 162.2 118.7 162.2Q117.3 162.2 116.3 161.4Q115.4 160.6 115.4 158.9Q115.4 157.2 116.6 156.4Q117.8 155.6 120.1 155.5L121.9 155.4L121.9 155Q121.9 154.1 121.5 153.8Q121.1 153.4 120.3 153.4Q119.5 153.4 118.8 153.6Q118.1 153.8 117.3 154.1L116.4 152.2Q117.2 151.7 118.3 151.5Q119.3 151.2 120.4 151.2ZM120.8 157.2Q119.4 157.2 118.9 157.7Q118.4 158.1 118.4 158.9Q118.4 159.5 118.7 159.8Q119.1 160.1 119.7 160.1Q120.7 160.1 121.3 159.5Q121.9 159 121.9 158L121.9 157.1L120.8 157.2ZM132.1 162.2Q129.7 162.2 128.4 160.9Q127.1 159.6 127.1 156.8Q127.1 154.9 127.8 153.6Q128.4 152.4 129.6 151.8Q130.8 151.3 132.3 151.3Q133.4 151.3 134.2 151.5Q135 151.7 135.6 152L134.7 154.2Q134.1 153.9 133.5 153.8Q132.9 153.6 132.3 153.6Q130.1 153.6 130.1 156.8Q130.1 158.3 130.6 159.1Q131.2 159.9 132.3 159.9Q133.2 159.9 133.9 159.6Q134.6 159.4 135.3 158.9L135.3 161.4Q134.6 161.8 133.9 162Q133.2 162.2 132.1 162.2ZM142 151.3Q144.2 151.3 145.5 152.5Q146.8 153.8 146.8 156.1L146.8 157.4L140 157.4Q140 158.7 140.7 159.4Q141.4 160 142.6 160Q143.6 160 144.5 159.8Q145.3 159.6 146.2 159.2L146.2 161.4Q145.4 161.8 144.5 162Q143.7 162.2 142.5 162.2Q140.9 162.2 139.7 161.6Q138.4 161 137.7 159.8Q137.1 158.6 137.1 156.8Q137.1 154.9 137.7 153.7Q138.3 152.5 139.4 151.9Q140.5 151.3 142 151.3ZM142.1 153.3Q141.2 153.3 140.7 153.8Q140.1 154.4 140 155.5L144.1 155.5Q144 154.6 143.6 153.9Q143.1 153.3 142.1 153.3Z"

local function wordmark(glyph)
    return '<path d="' .. WORDMARK .. '" fill="#' .. glyph .. '"/>'
end

-- The SVG text for icon `name` on a tile of colour `hex` ("2f6f5e"), or nil when it can't be made.
-- `koreader_logo` is KOReader's own logo as text, used for "koreader". `opts`: `glyph` (hex, default
-- white) is the colour of the drawing on the tile; `bg` (hex) fills the
-- whole canvas first so the icon has no transparency; `named` puts the ShelfSpace wordmark under
-- the mark (the mark is then raised to make room, and centred with it); `bare` leaves out the canvas
-- and the tile, for a glyph drawn over a tile that is not part of the SVG.
function Icons.svg(name, hex, koreader_logo, opts)
    opts = opts or {}
    local canvas = opts.bg and not opts.bare and string.format('<rect width="195" height="195" fill="#%s"/>', opts.bg) or ""
    if name == "koreader" then
        if not koreader_logo then return nil end
        local svg = koreader_logo:gsub("#00a89c", "#" .. hex)
        if opts.glyph and opts.glyph ~= "ffffff" then svg = svg:gsub("#ffffff", "#" .. opts.glyph) end
        return (svg:gsub("</defs>", "</defs>" .. canvas, 1))
    end
    local draw = GLYPHS[name]
    if not draw then return nil end
    local named = opts.named and name == "shelfspace"
    return '<?xml version="1.0" encoding="UTF-8"?><svg xmlns="http://www.w3.org/2000/svg" width="195" height="195" '
        .. 'viewBox="0 0 195 195">' .. canvas .. (opts.bare and "" or string.format(TILE, hex))
        .. draw(hex, named and 13 or nil, named and 0 or nil, opts.glyph or "ffffff")
        .. (named and wordmark(opts.glyph or "ffffff") or "") .. "</svg>"
end

-- The mark and the name in one colour on a transparent background, with no tile: the README's logo. The spines' bands are cut out with a mask so the page shows
-- through them. (The same coordinates as the tile version, which is raised 13 to centre it over the name.)
function Icons.plainLogo(hex)
    local fill = "#" .. hex
    local base = 132
    local solid, cuts = { rect(CENTER_X - 54, 140, 108, 9, 4.5, fill) }, {}
    for _, book in ipairs({ { 46.6, 76 }, { 67.6, 54 }, { 88.6, 84 } }) do -- x, top
        local x, top = book[1], book[2]
        solid[#solid + 1] = rect(x, top, 17, base - top, 3.5, fill)
        cuts[#cuts + 1] = rect(x, top + 9, 17, 3.5, 0, "#000000")
        cuts[#cuts + 1] = rect(x, base - 14, 17, 3.5, 0, "#000000")
    end
    local slot = string.format('<rect x="111.1" y="71.5" width="35" height="%d" rx="3.5" fill="none" stroke="%s" '
        .. 'stroke-width="3" stroke-dasharray="7 5"/>', base - 70 - 3, fill)
    return '<?xml version="1.0" encoding="UTF-8"?><svg xmlns="http://www.w3.org/2000/svg" width="120" height="137" '
        .. 'viewBox="35.6 48 120 137"><defs><mask id="spines" maskUnits="userSpaceOnUse" x="0" y="0" width="195" height="195">'
        .. '<rect width="195" height="195" fill="#ffffff"/>' .. table.concat(cuts) .. '</mask></defs>'
        .. '<g mask="url(#spines)">' .. table.concat(solid) .. "</g>" .. slot
        .. string.format('<path transform="translate(0 13)" d="%s" fill="%s"/>', WORDMARK, fill) .. "</svg>"
end

-- The sort button's icon: what is sorted, drawn the same way for all four, in one solid colour on `bg`
-- (opaque, so it has no transparency to blend). `kind` is a category from Search.SORTS:
--   size: three bars; date modified: a calendar; last opened: a clock, each with an arrow beside it that
--         points up for ascending (smallest, oldest) and down for descending (biggest, newest).
--   name: the letters A and Z, A on top for A to Z and Z on top for Z to A. The order is in the letters,
--         so there is no arrow.
function Icons.sortSvg(kind, descending, ink, bg)
    local stroke = string.format('fill="none" stroke="#%s" stroke-width="4" stroke-linecap="round" stroke-linejoin="round"', ink)
    local out = {}
    local function add(s) out[#out + 1] = s end
    local function arrow()
        local head = descending and "M33 30 L39 37 L45 30" or "M33 18 L39 11 L45 18"
        add(string.format('<path d="M39 11 V37" %s/>', stroke))
        add(string.format('<path d="%s" %s/>', head, stroke))
    end
    if kind == "name" then
        local top_a = not descending
        local a_y, z_y = top_a and 4 or 28, top_a and 28 or 4
        add(string.format('<path d="M12 %d L24 %d L36 %d M17 %d H31" %s/>', a_y + 18, a_y, a_y + 18, a_y + 12, stroke))
        add(string.format('<path d="M13 %d H35 L13 %d H35" %s/>', z_y, z_y + 18, stroke))
    elseif kind == "new" then
        add(string.format('<rect x="4" y="9" width="27" height="31" rx="6" %s/>', stroke))
        add(string.format('<path d="M4 20 H31 M12 4 V13 M23 4 V13" %s/>', stroke))
        arrow()
    elseif kind == "opened" then
        add(string.format('<circle cx="18" cy="24" r="15" %s/>', stroke))
        add(string.format('<path d="M18 14 V24 L25 29" %s/>', stroke))
        arrow()
    else
        local widths = descending and { 24, 18, 12 } or { 12, 18, 24 }
        for i, w in ipairs(widths) do
            add(string.format('<rect x="4" y="%d" width="%d" height="5" rx="2" fill="#%s"/>', 8 + (i - 1) * 12, w, ink))
        end
        arrow()
    end
    return '<?xml version="1.0" encoding="UTF-8"?><svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" '
        .. 'viewBox="0 0 48 48"><rect width="48" height="48" fill="#' .. bg .. '"/>' .. table.concat(out) .. "</svg>"
end

-- A magnifying glass, in one solid colour on `bg` (opaque, like the sort icons).
-- Line icons for the menu, drawn on a 24 x 24 grid in one stroke so they read as a set.
local ACTIONS = {
    about = '<circle cx="12" cy="12" r="9"/><path d="M12 11v6"/><circle cx="12" cy="7.6" r="0.9" fill="#%s"/>',
    update = '<path d="M19.5 12A7.5 7.5 0 1 1 17.3 6.7"/><path d="M18 3.5v4h-4"/>',
    changelog = '<path d="M7 3h7l5 5v12.2a.8.8 0 0 1-.8.8H7a.8.8 0 0 1-.8-.8V3.8A.8.8 0 0 1 7 3z"/><path d="M14 3v5h5"/><path d="M9 13h6M9 17h6"/>',
    exit = '<path d="M10 4H6.2a1.2 1.2 0 0 0-1.2 1.2v13.6A1.2 1.2 0 0 0 6.2 20H10"/><path d="M14 8l4 4-4 4M18 12H9"/>',
    kept = '<path d="M7 3.5h10v17l-5-3.7-5 3.7z"/>',
}

function Icons.actionSvg(name, ink, bg)
    local body = ACTIONS[name]
    if not body then return nil end
    local stroke = string.format('fill="none" stroke="#%s" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"', ink)
    return '<?xml version="1.0" encoding="UTF-8"?><svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" '
        .. 'viewBox="0 0 24 24"><rect width="24" height="24" fill="#' .. bg .. '"/><g ' .. stroke .. '>'
        .. body:gsub("%%s", ink) .. "</g></svg>"
end

function Icons.searchSvg(ink, bg)
    local stroke = string.format('fill="none" stroke="#%s" stroke-width="4" stroke-linecap="round" stroke-linejoin="round"', ink)
    return '<?xml version="1.0" encoding="UTF-8"?><svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" '
        .. 'viewBox="0 0 48 48"><rect width="48" height="48" fill="#' .. bg .. '"/>'
        .. string.format('<circle cx="21" cy="21" r="12" %s/><path d="M30 30 L41 41" %s/>', stroke, stroke) .. "</svg>"
end

local function readFile(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local text = f:read("*a")
    f:close()
    return text
end

-- Writes `svg` to `path` under another name first and renames it into place, so a reader (this plugin,
-- redrawing, or a second KOReader) never meets a half-written file.
local function store(path, svg)
    if readFile(path) == svg then return true end
    local cache = DataStorage:getDataDir() .. "/cache"
    lfs.mkdir(cache)
    lfs.mkdir(cache .. "/shelfspace")
    local tmp = string.format("%s.%d.tmp", path, os.time())
    local f = io.open(tmp, "w")
    if not f then return false end
    f:write(svg)
    f:close()
    if not os.rename(tmp, path) then
        os.remove(tmp)
        return false
    end
    return true
end

local function hexOf(color)
    local c = color:getColorRGB32()
    return string.format("%02x%02x%02x", c.r, c.g, c.b)
end

-- The sort direction icon, `size` pixels square, in the colour `ink` on `bg` (Blitbuffer colours).
-- The ShelfSpace mark alone, in the text colour and with no tile behind it, for the header. The gaps cut
-- out of the books are the page colour, so it reads as part of the page. The canvas is cropped to the mark
-- (it fills only the middle of the square the tile version is drawn on), so it can be shown large and sharp.
local MARK_X, MARK_Y, MARK_W, MARK_H = 44, 54, 112, 92
function Icons.markWidget(width, ink, bg)
    local ink_hex, bg_hex = hexOf(ink), hexOf(bg)
    local path = string.format("%s/cache/shelfspace/shelfspace-mark-%s-%s.svg", DataStorage:getDataDir(), ink_hex, bg_hex)
    local svg = Icons.svg("shelfspace", bg_hex, nil, { bare = true, glyph = ink_hex })
    if not svg then return nil end
    svg = svg:gsub('width="195" height="195" viewBox="0 0 195 195"',
        string.format('width="%d" height="%d" viewBox="%d %d %d %d"', MARK_W, MARK_H, MARK_X, MARK_Y, MARK_W, MARK_H), 1)
    if not store(path, svg) then return nil end
    return IconWidget:new{ file = path, width = width, height = math.floor(width * MARK_H / MARK_W), alpha = true }
end

function Icons.sortWidget(kind, descending, size, ink, bg)
    local ink_hex, bg_hex = hexOf(ink), hexOf(bg)
    local path = string.format("%s/cache/shelfspace/sort-%s-%s-%s-%s.svg", DataStorage:getDataDir(), kind,
        descending and "desc" or "asc", ink_hex, bg_hex)
    if not store(path, Icons.sortSvg(kind, descending, ink_hex, bg_hex)) then return nil end
    return IconWidget:new{ file = path, width = size, height = size }
end

-- The search icon, `size` pixels square, in the colour `ink` on `bg` (Blitbuffer colours).
function Icons.searchWidget(size, ink, bg)
    local ink_hex, bg_hex = hexOf(ink), hexOf(bg)
    local path = string.format("%s/cache/shelfspace/search-%s-%s.svg", DataStorage:getDataDir(), ink_hex, bg_hex)
    if not store(path, Icons.searchSvg(ink_hex, bg_hex)) then return nil end
    return IconWidget:new{ file = path, width = size, height = size }
end

function Icons.actionWidget(name, size, ink, bg)
    local ink_hex, bg_hex = hexOf(ink), hexOf(bg)
    local svg = Icons.actionSvg(name, ink_hex, bg_hex)
    if not svg then return nil end
    local path = string.format("%s/cache/shelfspace/action-%s-%s-%s.svg", DataStorage:getDataDir(), name, ink_hex, bg_hex)
    if not store(path, svg) then return nil end
    return IconWidget:new{ file = path, width = size, height = size }
end

-- An icon drawn `size` pixels square on a tile of colour `tile`; nil if it can't be produced. The SVG is
-- kept in KOReader's cache folder and rewritten whenever the drawing changes. The ShelfSpace tile is a
-- native rounded box with a transparent SVG on top, so the Kobo's SVG renderer never fills it; the other
-- two are painted over the page colour `bg`, so they have no transparency to blend.
function Icons.widget(name, size, tile, bg, named)
    local hex, bg_hex = hexOf(tile), hexOf(bg)
    local dir = DataStorage:getDataDir() .. "/cache/shelfspace"
    if name == "shelfspace" then
        local path = string.format("%s/shelfspace%s-glyph.svg", dir, named and "-named" or "")
        local svg = Icons.svg(name, hex, nil, { named = named, bare = true })
        if not svg or not store(path, svg) then return nil end
        local k = size / 195
        local box = FrameContainer:new{
            bordersize = 0, padding = 0, margin = 0, radius = math.floor(TILE_R * k), background = tile,
            overlap_offset = { math.floor(TILE_X * k), math.floor(TILE_Y * k) },
            HorizontalGroup:new{ HorizontalSpan:new{ width = math.floor(TILE_W * k) }, VerticalSpan:new{ width = math.floor(TILE_H * k) } },
        }
        return OverlapGroup:new{
            dimen = Geom:new{ w = size, h = size },
            box,
            IconWidget:new{ file = path, width = size, height = size, alpha = true },
        }
    end
    local path = string.format("%s/%s-%s-%s.svg", dir, name, hex, bg_hex)
    local svg = Icons.svg(name, hex, name == "koreader" and readFile("resources/koreader.svg") or nil, { bg = bg_hex })
    if not svg or not store(path, svg) then return nil end
    return IconWidget:new{ file = path, width = size, height = size }
end

return Icons
