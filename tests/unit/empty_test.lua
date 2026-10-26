local T = dofile((debug.getinfo(1, "S").source:match("^@(.*)/[^/]+$") or ".") .. "/helper.lua")
local Empty = require("shelfspace/empty")

print("empty")

T.test("a search that finds nothing says so, quotes the search and offers to clear it", function()
    local d = Empty.describe({ query = "delete me", place = "Library" })
    T.eq(d.headline, "No matches")
    T.eq(d.line, "Nothing in Library matches “delete me”.")
    T.eq(d.action, "search")
    T.eq(d.label, "Clear search")
end)

T.test("a status with nothing left says what is missing and offers all files", function()
    local unread = Empty.describe({ status = "new" })
    T.eq(unread.headline, "No unread books"); T.eq(unread.action, "status"); T.eq(unread.label, "Show all files")
    local done = Empty.describe({ status = "complete" })
    T.eq(done.headline, "No finished books"); T.eq(done.action, "status")
end)

T.test("a file type with nothing names the type and the place", function()
    local d = Empty.describe({ ext = "pdf", place = "Manga" })
    T.eq(d.headline, "No PDF files")
    T.eq(d.line, "There are no PDF files in Manga.")
    T.eq(d.action, "filter"); T.eq(d.label, "Clear filter")
end)

T.test("two or more filters together say nothing matches and offer to clear them all", function()
    for _, state in ipairs({ { query = "a", ext = "pdf" }, { query = "a", status = "new" },
                             { ext = "epub", status = "complete" }, { query = "a", ext = "pdf", status = "new" } }) do
        local d = Empty.describe(state)
        T.eq(d.headline, "Nothing matches")
        T.eq(d.action, "all"); T.eq(d.label, "Clear all filters")
    end
end)

T.test("an empty folder with no filters says so, and offers Up only when there is somewhere to go", function()
    local inside = Empty.describe({ place = "Manga", has_parent = true })
    T.eq(inside.headline, "This folder is empty"); T.eq(inside.line, "There is nothing in Manga."); T.eq(inside.action, "up")
    local root = Empty.describe({ place = "Library", has_parent = false })
    T.eq(root.headline, "This folder is empty"); T.eq(root.action, nil); T.eq(root.label, nil)
end)

T.test("the place defaults to Library", function()
    T.eq(Empty.describe({ query = "x" }).line, "Nothing in Library matches “x”.")
end)

T.done()
