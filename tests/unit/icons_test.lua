local T = dofile((debug.getinfo(1, "S").source:match("^@(.*)/[^/]+$") or ".") .. "/helper.lua")
local Icons = require("shelfspace/icons")

print("icons")

T.test("the ShelfSpace and library icons are tiles in the asked-for colour with a white glyph", function()
    for _, name in ipairs({ "shelfspace", "library" }) do
        local svg = Icons.svg(name, "2f6f5e")
        assert(svg:find("^<%?xml"), name .. " is not an svg document")
        assert(svg:find('fill="#2f6f5e"', 1, true), name .. " tile has the wrong colour")
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

T.test("the full logo is the mark with the name under the shelf, and only the logo has the name", function()
    local logo = Icons.logo("2f6f5e")
    assert(logo:find('<path d="M', 1, true), "no wordmark outlines")
    assert(not logo:find("<text", 1, true), "the renderer ignores <text>; the name must be outlines")
    assert(not Icons.svg("shelfspace", "2f6f5e"):find("<text", 1, true), "the in-app icon should be the mark alone")
end)

T.test("the README logos are the mark and the name with no tile behind them, in one colour", function()
    for _, color in ipairs({ "2f6f5e", "ffffff" }) do
        local svg = Icons.plainLogo(color)
        assert(svg:find('fill="#' .. color .. '"', 1, true), "colour missing")
        assert(not svg:find('rx="22.5"', 1, true), "the tile is still there")
        assert(not svg:find('<rect width="195" height="195" fill="#', 1, true) or svg:find("<mask", 1, true), "an opaque canvas")
        assert(svg:find("<mask", 1, true), "the spine bands are not cut out of the books")
        assert(svg:find("stroke-dasharray", 1, true), "no empty slot")
        assert(svg:find('<path transform="translate(0 13)" d="M', 1, true), "no wordmark outlines")
    end
end)

T.test("the files in assets are the generated logos", function()
    local here = debug.getinfo(1, "S").source:match("^@(.*)/[^/]+$") or "."
    for file, expected in pairs({
        ["logo.svg"] = Icons.logo("2f6f5e"),
        ["logo-light.svg"] = Icons.plainLogo("2f6f5e"),
        ["logo-dark.svg"] = Icons.plainLogo("ffffff"),
    }) do
        local f = assert(io.open(here .. "/../../assets/" .. file), file .. " is missing; run tools/make-logos.lua")
        local text = f:read("*a")
        f:close()
        T.eq(text, expected, file)
    end
end)

T.test("the logo in assets is the ShelfSpace logo on the brand green", function()
    local here = debug.getinfo(1, "S").source:match("^@(.*)/[^/]+$") or "."
    local f = assert(io.open(here .. "/../../assets/logo.svg"))
    local file = f:read("*a")
    f:close()
    T.eq(file, Icons.logo("2f6f5e"))
end)

T.test("an icon can be painted over the page colour, so it has no transparent corners", function()
    local plain = Icons.svg("library", "2f6f5e")
    local solid = Icons.svg("library", "2f6f5e", nil, { bg = "fbf8f1" })
    assert(not plain:find("fbf8f1", 1, true), "background added when none was asked for")
    assert(solid:find('<rect width="195" height="195" fill="#fbf8f1"/>', 1, true), "no background rect")
    local logo = '<svg><defs><clipPath/></defs><path style="fill:#00a89c"/></svg>'
    local k = Icons.svg("koreader", "d9822b", logo, { bg = "fbf8f1" })
    assert(k:find('</defs><rect width="195" height="195" fill="#fbf8f1"/>', 1, true), "bg not behind KOReader's logo")
end)

T.test("the mark sits higher when it has a name under it, and the name is centred with it", function()
    assert(Icons.svg("shelfspace", "000000"):find("translate(4 -9)", 1, true), "icon not centred by weight")
    local logo = Icons.logo("000000")
    assert(logo:find("translate(0 -13)", 1, true), "logo mark not raised and centred under the name")
    assert(logo:find("Q", 1, true) and logo:find(' fill="#ffffff"/></svg>$'), "wordmark not last, in white")
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
