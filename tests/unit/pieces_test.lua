local T = dofile((debug.getinfo(1, "S").source:match("^@(.*)/[^/]+$") or ".") .. "/helper.lua")
local Pieces = require("shelfspace/pieces")
local spec = dofile((debug.getinfo(1, "S").source:match("^@(.*)/[^/]+$") or ".") .. "/../../shelfspace.koplugin/art/spec.lua")

print("the shelf pieces")

-- a type whose words are half as wide as they are tall, one character at a time
local function width(text, size) return #text * size * 0.5 end
local function lay(id, free, extra)
    local p = { s = 1, free = free, num = "26.4", unit = "GB free", width = width }
    for k, v in pairs(extra or {}) do p[k] = v end
    return Pieces.layout(spec, id, p)
end
local function find(r, file)
    for _, op in ipairs(r.ops) do if op.file == file then return op end end
end

T.test("every piece has its art in the spec and lays out at any amount of free space", function()
    for _, id in ipairs(Pieces.ORDER) do
        for _, free in ipairs({ 0, 0.005, 0.1, 0.5, 0.82, 1 }) do
            local r = lay(id, free)
            assert(#r.ops > 0, id .. " draws something")
            assert(r.label and r.label.w > 0, id .. " has a place for the figure")
            for _, op in ipairs(r.ops) do assert(op.w > 0 and op.h > 0, id .. " " .. op.file .. " has a size") end
        end
    end
end)

T.test("free space is what fills a piece, except the stack, which is what is used", function()
    T.eq(Pieces.fill("flask", 1), 1)
    T.eq(Pieces.fill("flask", 0.4), 0.4)
    T.eq(Pieces.fill("flask", 0), 0.01, "never emptier than the 1% look")
    T.eq(Pieces.fill("flask", 0.4, "used"), 0.6)
    T.eq(Pieces.fill("stack", 0.4), 0.6 + 0 * 1)
    T.eq(Pieces.fill("stack", 1), 0.01)
    T.eq(Pieces.fill("stack", 0.4, "used"), 0.4)
end)

T.test("the liquid sinks as the free space shrinks", function()
    local high, low = lay("glass", 0.9).surface, lay("glass", 0.2).surface
    assert(high < low, "a fuller glass has its surface higher up (smaller y)")
    local floor = spec.glass.liq.floor
    assert(lay("glass", 0).surface <= floor - 8, "even an empty one keeps a sliver")
end)

T.test("a cone holds more near the top, so half the volume is below half the height", function()
    local o = spec.flask
    local by_volume = Pieces.levelY(o, 0.5)
    local by_height = Pieces.levelY(o, 0.5, true)
    assert(by_volume > by_height, "the flask is half full by volume lower down than by height")
end)

T.test("the liquid is cut from its surface down, and the surface sprite is as wide as the inside there", function()
    local r = lay("whiskey", 0.5)
    local liquid, cap = find(r, "whiskey-liquid"), find(r, "whiskey-cap")
    assert(liquid.from > 0 and liquid.to == 1, "only the rows below the surface show")
    T.eq(math.floor(cap.w + 0.5), math.floor(2 * Pieces.ihwAt(spec.whiskey, r.surface) + 2 + 0.5), "cap width")
    local full = lay("whiskey", 1)
    assert(find(full, "whiskey-liquid").from < liquid.from, "fuller shows more of the liquid")
end)

T.test("the whiskey's ice is there only with the setting, and its tint is cut at the surface", function()
    assert(find(lay("whiskey", 0.8), "whiskey-iceClear"), "ice")
    T.eq(find(lay("whiskey", 0.8, { ice = false }), "whiskey-iceClear"), nil)
end)

T.test("the inkwell's quill is behind the bottle and its stem goes in front of the back", function()
    local r = lay("inkwell", 0.7)
    local order = {}
    for i, op in ipairs(r.ops) do order[op.file] = i end
    assert(order["inkwell-quill"] < order["inkwell-back"], "quill first")
    assert(order["inkwell-stem"] > order["inkwell-back"] and order["inkwell-stem"] < order["inkwell-front"], "stem in the glass")
end)

T.test("the flask wears the shared tag over its mouth, centred, with no flag beside it", function()
    local r = lay("flask", 0.5, { s = 2 })
    local tag = find(r, Pieces.TAG)
    assert(tag, "tag")
    T.eq(find(r, "flask-flag"), nil)
    T.eq(math.floor(tag.x + tag.w / 2 + 0.5), math.floor(spec.flask.cx * 2 + 0.5), "centred on the flask")
    assert(tag.y + tag.h <= 2 * 1 + 0.001, "above the mouth")
end)

T.test("every label is the one shared tag at one size", function()
    local sizes = {}
    for _, id in ipairs({ "flask", "glass", "whiskey", "decanter", "stack", "candle", "inkwell" }) do
        local r = lay(id, 0.6, { s = id == "glass" and 1 or 2 })
        local tag = find(r, Pieces.TAG)
        assert(tag, id .. " wears the tag")
        sizes[#sizes + 1] = string.format("%.1f", tag.w)
    end
    for _, w in ipairs(sizes) do T.eq(w, sizes[1], "tag width") end
end)

T.test("with the label switched off no piece wears a tag or a figure", function()
    for _, id in ipairs({ "flask", "glass", "whiskey", "decanter", "stack", "candle", "inkwell" }) do
        local r = lay(id, 0.6, { no_label = true })
        T.eq(find(r, Pieces.TAG), nil, id .. " has no tag")
        T.eq(r.label, nil, id .. " has no figure")
    end
end)

T.test("the figure is the biggest that fits, 1.35 times its unit", function()
    local fit = Pieces.fitFigure("26.4", "GB free", 68, 44, width)
    T.eq(fit.big, math.floor(fit.f * 1.35 + 0.5), "ratio")
    assert(width("GB free", fit.f) <= 58 and width("26.4", fit.big) <= 58, "fits")
    local bigger = Pieces.fitFigure("26.4", "GB free", 68, 44, function(t, s) return width(t, s) / 100 end)
    assert(bigger.f >= fit.f, "more room, no smaller")
end)

T.test("the candle burns down with the free space and goes out at the end", function()
    local lit, nearly = lay("candle", 0.8), lay("candle", 0.01)
    assert(find(lit, "candle-flame") and not find(lit, "candle-smoke"), "lit")
    assert(find(nearly, "candle-smoke") and not find(nearly, "candle-flame"), "out, with smoke")
    assert(find(lit, "candle-wax").from < find(nearly, "candle-wax").from, "more wax when fuller")
    -- the drips never hang below the dish
    local top = find(nearly, "candle-waxTop")
    assert(top.y + top.h <= spec.candle.dishTop + 0.001, "cut at the dish rim")
end)

T.test("the stack grows by adding books, up to eight, and never past the top of the art", function()
    T.eq(lay("stack", 1).books, 1, "an empty disk is one book")
    local most = lay("stack", 0)
    assert(most.books >= 7 and most.books <= Pieces.BOOKS, "a full disk is a tall stack")
    local top = math.huge
    for _, op in ipairs(most.ops) do if op.file ~= Pieces.TAG and not op.file:match("^stack%-top") then top = math.min(top, op.y) end end
    assert(top >= 0, "the books are inside the piece (the top face and the tag ride above it)")
    assert(lay("stack", 0.5).books < most.books, "half full is fewer books")
end)

T.test("the stack is seen from slightly above: every book's cover shows on top (the book above stands over it), and the bottom one has a taller, rounded foot", function()
    for _, free in ipairs({ 1, 0.5, 0 }) do
        local r = lay("stack", free)
        local order = {}
        for i, op in ipairs(r.ops) do order[op.file] = i end
        local tops = 0
        for i = 1, r.books do
            local face, book = order["stack-top" .. (i - 1)], order["stack-book" .. (i - 1)]
            assert(face and book and face == book + 1, "book " .. i .. " has its top face drawn right after it")
            tops = tops + 1
        end
        T.eq(tops, r.books, "one top face a book")
    end
    local r = lay("stack", 0)
    local bottom, nxt = find(r, "stack-book0"), find(r, "stack-book1")
    local b = spec.stack.books[1]
    local b2 = spec.stack.books[2]
    -- height over width, in art units: a book is as thick as drawn times the stack's 1.4, the bottom one by the foot more
    local function shape(op, book, extra) return op.h / op.w, (book.h + 4 + extra) * 1.4 / (book.w + 4) end
    local got, want = shape(bottom, b, Pieces.STACK_FOOT)
    assert(math.abs(got - want) < 1e-6, "taller by the foot")
    got, want = shape(nxt, b2, 0)
    assert(math.abs(got - want) < 1e-6, "the others are as drawn")
end)

T.done()
