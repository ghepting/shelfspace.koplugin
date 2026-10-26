local T = dofile((debug.getinfo(1, "S").source:match("^@(.*)/[^/]+$") or ".") .. "/helper.lua")
local Progress = require("shelfspace/progress")

print("progress")

T.test("a book that was never opened has not been started", function()
    local p = Progress.describe({ been_opened = false })
    T.eq(p.label, "Not started")
    T.eq(p.fraction, 0)
    T.eq(Progress.describe(nil).label, "Not started")
end)

T.test("a finished book is full and says so, whatever its saved percentage", function()
    local p = Progress.describe({ been_opened = true, status = "complete", percent_finished = 0.4 })
    T.eq(p.label, "Finished")
    T.eq(p.fraction, 1)
end)

T.test("a book in progress shows its percentage, rounded", function()
    local p = Progress.describe({ been_opened = true, status = "reading", percent_finished = 0.184 })
    T.eq(p.label, "18% read")
    T.eq(p.fraction, 0.184)
    T.eq(Progress.describe({ been_opened = true, percent_finished = 0.186 }).label, "19% read")
end)

T.test("a book opened but barely read is under one percent, and one with no saved position has not been started", function()
    T.eq(Progress.describe({ been_opened = true, percent_finished = 0.002 }).label, "<1% read")
    T.eq(Progress.describe({ been_opened = true }).label, "Not started")
    T.eq(Progress.describe({ been_opened = true, percent_finished = 0 }).label, "Not started")
end)

T.test("a percentage past the end is capped at the whole book", function()
    local p = Progress.describe({ been_opened = true, status = "reading", percent_finished = 1.2 })
    T.eq(p.fraction, 1)
    T.eq(p.label, "100% read")
end)

T.done()
