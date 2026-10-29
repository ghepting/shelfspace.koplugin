local T = dofile((debug.getinfo(1, "S").source:match("^@(.*)/[^/]+$") or ".") .. "/helper.lua")
local Progress = require("shelfspace/progress")

print("progress")

T.test("a book that was never opened is at 0%", function()
    T.eq(Progress.cell({ been_opened = false }), "0%")
    T.eq(Progress.cell(nil), "0%")
end)

T.test("a finished book says Read, whatever its saved percentage", function()
    T.eq(Progress.cell({ been_opened = true, status = "complete", percent_finished = 0.4 }), "Read")
    T.eq(Progress.cell({ been_opened = true, status = "complete" }), "Read")
end)

T.test("a book in progress shows its percentage, rounded down", function()
    T.eq(Progress.cell({ been_opened = true, status = "reading", percent_finished = 0.184 }), "18%")
    T.eq(Progress.cell({ been_opened = true, percent_finished = 0.186 }), "18%")
    T.eq(Progress.cell({ been_opened = true, percent_finished = 0.999 }), "99%", "only a finished book is 100%")
end)

T.test("a book opened but barely read, or with no saved position, is at 0%", function()
    T.eq(Progress.cell({ been_opened = true, percent_finished = 0.002 }), "0%")
    T.eq(Progress.cell({ been_opened = true }), "0%")
    T.eq(Progress.cell({ been_opened = true, percent_finished = 0 }), "0%")
end)

T.test("a position at or past the end is Read", function()
    T.eq(Progress.cell({ been_opened = true, status = "reading", percent_finished = 1 }), "Read")
    T.eq(Progress.cell({ been_opened = true, status = "reading", percent_finished = 1.2 }), "Read")
end)

T.test("the meter's fraction agrees with the text: 0 for unread, 1 for Read, in between rounded the same way", function()
    T.eq(Progress.fraction(nil), 0)
    T.eq(Progress.fraction({ been_opened = false }), 0)
    T.eq(Progress.fraction({ been_opened = true, status = "complete", percent_finished = 0.4 }), 1)
    T.eq(Progress.fraction({ been_opened = true, percent_finished = 1.2 }), 1)
    T.eq(Progress.fraction({ been_opened = true, percent_finished = 0.25 }), 0.25)
    T.eq(Progress.fraction({ been_opened = true }), 0)
    T.eq(Progress.fraction({ been_opened = true, percent_finished = -0.5 }), 0)
end)

T.done()
