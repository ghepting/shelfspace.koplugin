local T = dofile((debug.getinfo(1, "S").source:match("^@(.*)/[^/]+$") or ".") .. "/helper.lua")
local Pager = require("shelfspace/pager")

print("pager")

local function at(factor) return function(n) return math.floor(n * factor + 0.5) end end

T.test("the arrows are a stock Button's size: KOReader's icon with a Button's padding round it", function()
    local g = Pager.geometry(600, nil, at(1), 40)
    T.eq(g.icon, 40, "icon")
    T.eq(g.button, 44, "button")
    T.eq(g.h, 44, "row height")
    T.eq(g.cell_w, 56, "cell")
    T.eq(g.centre_w, 600 - 4 * 56, "middle")
end)

T.test("a narrow cell asked for is never smaller than a stock Button, so it is as easy to tap", function()
    local g = Pager.geometry(500, 40, at(1), 40)
    T.eq(g.cell_w, 44, "cell")
    T.eq(g.centre_w, 500 - 4 * 44, "middle")
end)

T.test("everything scales with the screen", function()
    local g = Pager.geometry(1200, nil, at(2), 40)
    T.eq(g.icon, 80, "icon")
    T.eq(g.h, 88, "row height")
    T.eq(g.cell_w, 112, "cell")
end)

T.test("a bigger icon setting makes the row and the cells grow to hold it", function()
    local g = Pager.geometry(600, nil, at(1), 60)
    T.eq(g.h, 64, "row height")
    T.eq(g.cell_w, 64, "cell")
end)

T.test("the middle never goes below nothing on a very narrow list", function()
    T.eq(Pager.geometry(100, nil, at(1), 40).centre_w, 0)
end)

T.done()
