local T = dofile((debug.getinfo(1, "S").source:match("^@(.*)/[^/]+$") or ".") .. "/helper.lua")
local Pie = require("shelfspace/pie")

local function near(a, b) return math.abs(a - b) < 1e-9 end

print("pie")

T.test("a turn is measured clockwise from 12 o'clock", function()
    assert(near(Pie.fraction(0, -1), 0), "top")
    assert(near(Pie.fraction(1, 0), 0.25), "right")
    assert(near(Pie.fraction(0, 1), 0.5), "bottom")
    assert(near(Pie.fraction(-1, 0), 0.75), "left")
end)

T.test("slices tile the whole turn, skipping empty ones", function()
    local arcs = Pie.layout({ { fraction = 0.6, id = "a" }, { fraction = 0, id = "gone" }, { fraction = 0.4, id = "b" } })
    T.eq(#arcs, 2)
    assert(near(arcs[1].from, 0) and near(arcs[1].to, arcs[2].from) and near(arcs[2].to, 1))
end)

T.test("a tiny slice is widened so it stays visible and tappable", function()
    local arcs = Pie.layout({ { fraction = 0.999, id = "a" }, { fraction = 0.001, id = "tiny" } })
    assert(arcs[2].to - arcs[2].from > 0.0075, "tiny slice too thin")
end)

T.test("a point lands in the slice that holds it", function()
    local arcs = Pie.layout({ { fraction = 0.5, id = "a" }, { fraction = 0.5, id = "b" } })
    T.eq(Pie.arcAt(arcs, 0.25).slice.id, "a")
    T.eq(Pie.arcAt(arcs, 0.75).slice.id, "b")
    T.eq(Pie.arcAt(arcs, 0).slice.id, "a")
    T.eq(Pie.arcAt(arcs, 0.9999).slice.id, "b")
end)

T.test("nothing to draw gives no arcs", function()
    T.eq(#Pie.layout({ { fraction = 0 } }), 0)
    T.eq(Pie.arcAt({}, 0.5), nil)
end)

T.test("one full slice covers the whole turn", function()
    local one = Pie.layout({ { fraction = 1, id = "x" } })
    T.eq(#one, 1)
    assert(near(one[1].from, 0) and near(one[1].to, 1))
end)

T.done()
