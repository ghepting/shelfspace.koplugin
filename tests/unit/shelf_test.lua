local T = require("helper")
local Shelf = require("shelfspace/shelf")

local function e(name, size) return { name = name, size = size } end

T.test("a spine is as wide as the file is big, between a minimum and a maximum", function()
    T.eq(Shelf.spineWidth(100, 100, 20, 200), 200)
    T.eq(Shelf.spineWidth(50, 100, 20, 200), 100)
    T.eq(Shelf.spineWidth(1, 100, 20, 200), 20, "tiny files stay tappable")
    T.eq(Shelf.spineWidth(0, 0, 20, 200), 20, "an empty folder")
end)

T.test("spines fill a shelf and the next one starts a new shelf", function()
    local shelves = Shelf.pack({ e("a", 100), e("b", 100), e("c", 100) }, 450, 20, 200, 10)
    T.eq(#shelves, 2)
    T.eq(#shelves[1], 2)
    T.eq(shelves[2][1].entry.name, "c")
end)

T.test("order is kept and every entry is placed once", function()
    local list = {}
    for i = 1, 30 do list[i] = e("f" .. i, i * 10) end
    local seen = {}
    for _, shelf in ipairs(Shelf.pack(list, 500, 30, 150, 8)) do
        local used = 0
        for _, s in ipairs(shelf) do seen[#seen + 1] = s.entry.name used = used + s.w end
        assert(used <= 500, "shelf overfull")
    end
    T.eq(#seen, 30)
    T.eq(seen[1], "f1")
    T.eq(seen[30], "f30")
end)

T.test("no entries means no shelves", function()
    T.eq(#Shelf.pack({}, 500, 20, 100, 8), 0)
end)

T.test("a spine's height depends only on its name and stays within bounds", function()
    local h = Shelf.spineHeight("Atlas of the Heart.pdf", 100)
    T.eq(h, Shelf.spineHeight("Atlas of the Heart.pdf", 100))
    assert(h >= 80 and h <= 100)
end)

T.done()
