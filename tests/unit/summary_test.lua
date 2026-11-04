local T = dofile((debug.getinfo(1, "S").source:match("^@(.*)/[^/]+$") or ".") .. "/helper.lua")
local Summary = require("shelfspace/summary")

print("the saved summary")

local GB = 1000 ^ 3 -- as KOReader's util.getFriendlySize counts, so a figure matches the ones ShelfSpace shows on its own screens
local MB = 1000 ^ 2

local function near(actual, expected, eps)
    assert(math.abs(actual - expected) <= eps, string.format("expected about %s, got %s", expected, actual))
end

local function device(free_pct, books, koreader, other)
    local total = 32 * GB
    return Summary.valid(Summary.build({
        usage = { total = total, free = total * free_pct },
        breakdown = { books = books * GB, koreader = koreader * GB, other = other * GB },
    }))
end

T.test("a summary read back must be a whole one", function()
    local good = Summary.build({ usage = { total = 100, free = 40 }, breakdown = { books = 30, koreader = 10, other = 20 } })
    assert(Summary.valid(good), "a good one is accepted")
    T.eq(Summary.valid(nil), nil)
    T.eq(Summary.valid({}), nil)
    local bad = Summary.build({ usage = { total = 100, free = 40 }, breakdown = {} })
    bad.books = -1
    T.eq(Summary.valid(bad), nil)
    bad = Summary.build({ usage = { total = 0, free = 0 }, breakdown = {} })
    T.eq(Summary.valid(bad), nil)
    good.v = 2
    T.eq(Summary.valid(good), nil)
end)

T.test("free space is read from KOReader's `available`, which is what util.diskUsage calls it", function()
    local s = Summary.build({ usage = { total = 100, used = 60, available = 40 }, breakdown = {} })
    T.eq(s.free, 40)
end)

T.test("what could be freed adds duplicates to KOReader's clearable files", function()
    local s = Summary.build({ usage = { total = 100, free = 40 }, duplicates = 172 * MB, koreader_clearable = 221 * MB })
    T.eq(Summary.reclaimable(s), 393 * MB)
end)

T.test("the shares of the device add up to one", function()
    local sh = Summary.shares(device(0.5, 8, 2, 6))
    near(sh.k + sh.m + sh.l + sh.g, 1, 1e-9)
    near(sh.g, 0.5, 1e-9)
end)

T.test("shares are fitted to what is used, whatever the scan was out by", function()
    local sh = Summary.shares(device(0.5, 20, 5, 5)) -- books, KOReader and other come to more than the used half
    near(sh.k + sh.m + sh.l, 0.5, 1e-9)
    near(sh.k + sh.m + sh.l + sh.g, 1, 1e-9)
end)

T.test("with no breakdown, all that is used is shown as one kind", function()
    local sh = Summary.shares(Summary.valid(Summary.build({ usage = { total = 100, free = 25 }, breakdown = {} })))
    near(sh.k, 0.75, 1e-9)
    T.eq(sh.m, 0)
end)

local function slots(n, free, k, m, l)
    return Summary.slots(n, { k = k, m = m, l = l, g = free })
end
local function total(o) return o.k + o.m + o.l + o.g end

T.test("slots always add up to the row", function()
    for _, n in ipairs({ 4, 6, 9, 13, 14, 30 }) do
        for _, free in ipairs({ 0, 0.01, 0.1, 0.33, 0.5, 0.98, 1 }) do
            local used = 1 - free
            local o = slots(n, free, used * 0.6, used * 0.1, used * 0.3)
            T.eq(total(o), n)
        end
    end
end)

T.test("free space is sized first: half free is half the slots, not shorted for a small category", function()
    local o = slots(6, 0.5, 0.25, 0.05, 0.20)
    T.eq(o.g, 3)
    T.eq(o.k + o.m + o.l, 3)
    T.eq(o.k, 1); T.eq(o.m, 1); T.eq(o.l, 1)
end)

T.test("nearly empty keeps room for the one spine of what is there", function()
    local o = slots(6, 0.98, 0.01, 0.004, 0.006)
    T.eq(o.g, 5)
    T.eq(o.k, 1)
    T.eq(o.m + o.l, 0)
end)

T.test("any free space keeps at least one ghost; none drops them", function()
    T.eq(slots(13, 0.01, 0.6, 0.12, 0.27).g, 1)
    T.eq(slots(13, 0, 0.61, 0.12, 0.27).g, 0)
end)

T.test("an empty device is all ghosts", function()
    local o = slots(8, 1, 0, 0, 0)
    T.eq(o.g, 8)
    T.eq(o.k + o.m + o.l, 0)
end)

T.test("with fewer slots than kinds only the biggest kinds show", function()
    local o = slots(4, 0.5, 0.3, 0.05, 0.15) -- 2 for ghosts, 2 left for 3 kinds
    T.eq(o.g, 2)
    T.eq(o.k, 1); T.eq(o.l, 1); T.eq(o.m, 0)
end)

T.test("a headline number changes its unit as it shrinks", function()
    local n, u = Summary.figure(21.4 * GB)
    T.eq(n, "21.4"); T.eq(u, "GB")
    n, u = Summary.figure(320 * MB)
    T.eq(n, "320"); T.eq(u, "MB")
    n, u = Summary.figure(512 * 1000)
    T.eq(n, "512"); T.eq(u, "kB")
    n, u = Summary.figure(0)
    T.eq(n, "0"); T.eq(u, "B")
end)

T.test("a headline number is KOReader's own figure for the same bytes (a GB is 1000 MB, as util.getFriendlySize counts)", function()
    local n, u = Summary.figure(28300000000)
    T.eq(n, "28.3"); T.eq(u, "GB") -- the number the Library tab prints as "28.3 GB"
end)

T.test("a chip says low, almost full or full, and nothing when there is room", function()
    local function st(free_pct) return Summary.state(device(free_pct, 10, 1, 1)) end
    T.eq(st(0.5), nil)
    T.eq(st(0.10), nil)
    T.eq(st(0.099), "low")
    T.eq(st(0.019), "almost")
    T.eq(st(0), "full")
    T.eq(Summary.state(Summary.valid(Summary.build({ usage = { total = 100 * MB, free = 500 * 1000 }, breakdown = {} }))), "full")
end)

T.done()
