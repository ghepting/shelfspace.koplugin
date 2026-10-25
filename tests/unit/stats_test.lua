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

T.done()
