local T = dofile((debug.getinfo(1, "S").source:match("^@(.*)/[^/]+$") or ".") .. "/helper.lua")
local Icons = require("shelfspace/icons")

print("icons")

T.test("the ShelfSpace and library icons are tiles in the asked-for colour with a white glyph", function()
    for _, name in ipairs({ "shelfspace", "library" }) do
        local svg = Icons.svg(name, "2a363b")
        assert(svg:find("^<%?xml"), name .. " is not an svg document")
        assert(svg:find('fill="#2a363b"', 1, true), name .. " tile has the wrong colour")
        assert(svg:find("#ffffff", 1, true), name .. " has no white glyph")
    end
end)

T.test("the ShelfSpace mark is books on a shelf and one long empty slot", function()
    local svg = Icons.svg("shelfspace", "000000")
    T.eq(select(2, svg:gsub("stroke%-dasharray", "")), 1) -- the empty slot
    T.eq(select(2, svg:gsub("<rect", "")), 1 + 1 + 3 * 3 + 1) -- tile, shelf, three books with two bands each, the empty slot
end)

T.test("the library icon is a stack of three banded books", function()
    T.eq(select(2, Icons.svg("library", "000000"):gsub("<rect", "")), 1 + 3 * 3)
end)

T.test("the README logo is the mark and the name with no tile behind them, in one colour", function()
    local svg = Icons.plainLogo("e84a5f")
    assert(svg:find('fill="#e84a5f"', 1, true), "colour missing")
    assert(not svg:find('rx="22.5"', 1, true), "the tile is still there")
    assert(svg:find("<mask", 1, true), "the spine bands are not cut out of the books")
    assert(svg:find("stroke-dasharray", 1, true), "no empty slot")
    assert(svg:find('<path transform="translate(0 13)" d="M', 1, true), "no wordmark outlines")
    assert(not svg:find("<text", 1, true), "the renderer ignores <text>; the name must be outlines")
end)

T.test("assets/logo.svg is the generated logo, in melonjolly (run tools/make-logos.lua after changing icons.lua)", function()
    local here = debug.getinfo(1, "S").source:match("^@(.*)/[^/]+$") or "."
    local f = assert(io.open(here .. "/../../assets/logo.svg"), "assets/logo.svg is missing")
    local text = f:read("*a")
    f:close()
    T.eq(text, Icons.plainLogo("e84a5f"))
end)

T.test("the glyph colour is whichever of white and the ink reads better on the tile", function()
    local ink = "2a363b"
    T.eq(Icons.glyphFor("2a363b", ink), "ffffff")   -- slate: white
    T.eq(Icons.glyphFor("e84a5f", ink), "ffffff")   -- raspberry: white
    T.eq(Icons.glyphFor("99b898", ink), ink)        -- sage: the ink
    T.eq(Icons.glyphFor("ff847c", ink), ink)        -- coral: the ink
    T.eq(Icons.glyphFor("fecea8", ink), ink)        -- peach: the ink
    T.eq(Icons.glyphFor("000000", "000000"), "ffffff") -- gray screens: black tile, white
end)

T.test("the glyph colour is used for the mark and the name, and cut-outs show the tile", function()
    local svg = Icons.svg("shelfspace", "99b898", nil, { glyph = "2a363b", named = true })
    assert(svg:find('fill="#2a363b"', 1, true), "glyph colour missing")
    assert(not svg:find("#ffffff", 1, true), "white left on a light tile")
    assert(svg:find('fill="#99b898"', 1, true), "tile colour missing")
    local k = Icons.svg("koreader", "ff847c", '<path style="fill:#00a89c"/><path style="fill:#ffffff"/></defs>', { glyph = "2a363b" })
    assert(k:find("#2a363b", 1, true) and not k:find("#ffffff", 1, true), "KOReader's logo keeps white on a light tile")
end)

T.test("an icon can be painted over the page colour, so it has no transparent corners", function()
    local plain = Icons.svg("library", "2a363b")
    local solid = Icons.svg("library", "2a363b", nil, { bg = "fbf8f1" })
    assert(not plain:find("fbf8f1", 1, true), "background added when none was asked for")
    assert(solid:find('<rect width="195" height="195" fill="#fbf8f1"/>', 1, true), "no background rect")
    local logo = '<svg><defs><clipPath/></defs><path style="fill:#00a89c"/></svg>'
    local k = Icons.svg("koreader", "d9822b", logo, { bg = "fbf8f1" })
    assert(k:find('</defs><rect width="195" height="195" fill="#fbf8f1"/>', 1, true), "bg not behind KOReader's logo")
end)

T.test("the mark sits higher when it has a name under it, and the name is centred with it", function()
    assert(Icons.svg("shelfspace", "000000"):find("translate(4 -9)", 1, true), "icon not centred by weight")
    local named = Icons.svg("shelfspace", "000000", nil, { named = true })
    assert(named:find("translate(0 -13)", 1, true), "mark not raised over the name")
    assert(named:find('<path d="M', 1, true) and not named:find("<text", 1, true), "name is not outlines")
    assert(not Icons.svg("shelfspace", "000000"):find('<path d="M', 1, true), "the in-app icon should be the mark alone")
end)

T.test("KOReader's own logo is recoloured, white left alone", function()
    local logo = '<path style="fill:#00a89c"/><path style="fill:#ffffff"/><path style="fill:#00a89c"/>'
    local svg = Icons.svg("koreader", "d9822b", logo)
    T.eq(select(2, svg:gsub("#d9822b", "")), 2)
    T.eq(select(2, svg:gsub("#00a89c", "")), 0)
    T.eq(select(2, svg:gsub("#ffffff", "")), 1)
end)

T.test("without KOReader's logo there is no koreader icon, and an unknown name has none either", function()
    T.eq(Icons.svg("koreader", "000000", nil), nil)
    T.eq(Icons.svg("nonsense", "000000"), nil)
end)

T.done()
