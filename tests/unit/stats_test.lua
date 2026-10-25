local T = dofile((debug.getinfo(1, "S").source:match("^@(.*)/[^/]+$") or ".") .. "/helper.lua")
local Stats = require("shelfspace/stats")

print("stats")

T.test("a file is counted under its lower-cased extension", function()
    T.eq(Stats.extension("Vol 1.CBZ"), "cbz")
    T.eq(Stats.extension("a.tar.gz"), "gz")
end)

T.test("a file with no extension is counted as other", function()
    T.eq(Stats.extension("README"), "other")
end)

T.test("sizes add up per type, below visible folders only", function()
    local function f(n, s) return { name = n, size = s } end
    local tree = {
        ["/r"] = { entries = { f("a.epub", 10), { name = "d", path = "/r/d", is_dir = true }, { name = "h.sdr", path = "/r/h.sdr", is_dir = true, hidden = true } } },
        ["/r/d"] = { entries = { f("b.epub", 5), f("c.pdf", 1) } },
        ["/r/h.sdr"] = { entries = { f("m.lua", 99) } },
    }
    local out = Stats.summarize(tree, "/r")
    T.eq(out.files, 3)
    T.eq(out.exts.epub, 15)
    T.eq(out.exts.lua, nil)
end)

T.test("the biggest types come first with their share", function()
    local top = Stats.topExtensions({ cbz = 80, pdf = 15, epub = 5 }, 2)
    T.eq(#top, 2)
    T.eq(top[1].ext, "cbz"); T.eq(top[1].percent, 80)
    T.eq(top[2].ext, "pdf")
end)

T.test("share chips list the biggest few as a percentage of the whole, empty ones left out", function()
    local chips = Stats.shareChips({
        { name = "BOOKS", bytes = 10 }, { name = "OTHER", bytes = 870 }, { name = "FREE", bytes = 120 }, { name = "KOREADER", bytes = 0 },
    }, 1000, 3)
    T.eq(table.concat(chips, "|"), "OTHER 87%|FREE 12%|BOOKS 1%")
end)

T.test("a share too small to round to 1% reads <1%", function()
    local chips = Stats.shareChips({ { name = "A", bytes = 999 }, { name = "B", bytes = 1 } }, 1000, 3)
    T.eq(chips[2], "B <1%")
end)

T.test("equal shares come in name order, and no total means no chips divide by zero", function()
    T.eq(table.concat(Stats.shareChips({ { name = "B", bytes = 5 }, { name = "A", bytes = 5 } }, 10, 3), "|"), "A 50%|B 50%")
    T.eq(Stats.shareChips({ { name = "A", bytes = 5 } }, 0, 3)[1], "A 0%")
end)

T.done()
