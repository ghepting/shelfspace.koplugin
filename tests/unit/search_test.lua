local T = dofile((debug.getinfo(1, "S").source:match("^@(.*)/[^/]+$") or ".") .. "/helper.lua")
local Search = require("shelfspace/search")

local function e(name, path, size, modified, is_dir, hidden)
    return { name = name, path = path, size = size, modified = modified, is_dir = is_dir, hidden = hidden }
end

local manga = e("Manga", "/r/Manga", 0, 5, true)
local tree = {
    ["/r"] = { entries = {
        e("DELETE ME - a.epub", "/r/DELETE ME - a.epub", 12, 3), manga, e("b.epub", "/r/b.epub", 80, 7),
        e("Hidden.sdr", "/r/Hidden.sdr", 0, 1, true, true),
    } },
    ["/r/Manga"] = { entries = { e("Vol 1.cbz", "/r/Manga/Vol 1.cbz", 450, 9), e("delete me too.cbz", "/r/Manga/delete me too.cbz", 1, 2) } },
    ["/r/Hidden.sdr"] = { entries = { e("delete me.lua", "/r/Hidden.sdr/delete me.lua", 1, 1) } },
}

print("search")

T.test("finds names holding every word, in any case", function()
    local found, where = Search.find(tree, "/r", "delete  ME")
    T.eq(#found, 2)
    T.eq(where[found[1]], "")
    T.eq(where[found[2]], "Manga")
end)

T.test("never looks inside sidecar folders", function()
    for _, f in ipairs((Search.find(tree, "/r", "delete me"))) do
        if f.path:find("Hidden.sdr", 1, true) then error("found " .. f.path) end
    end
end)

T.test("blank and unmatched queries find nothing", function()
    T.eq(#Search.find(tree, "/r", "   "), 0)
    T.eq(#Search.find(tree, "/r", "zzz"), 0)
end)

T.test("a search stays inside the folder it starts from", function()
    T.eq(#Search.find(tree, "/r/Manga", "delete"), 1)
end)

local function order(mode, descending)
    local list = { tree["/r"].entries[1], manga, tree["/r"].entries[3] }
    Search.sort(list, mode, descending)
    return T.names(list)
end

T.test("size: biggest first, or smallest first", function()
    T.eq(order("size", true), "b.epub|DELETE ME - a.epub|Manga")
    T.eq(order("size", false), "Manga|DELETE ME - a.epub|b.epub")
end)
T.test("name: A to Z, or Z to A", function()
    T.eq(order("name", false), "b.epub|DELETE ME - a.epub|Manga")
    T.eq(order("name", true), "Manga|DELETE ME - a.epub|b.epub")
end)
T.test("date modified: newest first, or oldest first", function()
    T.eq(order("new", true), "b.epub|Manga|DELETE ME - a.epub")
    T.eq(order("new", false), "DELETE ME - a.epub|Manga|b.epub")
end)

T.test("equal keys fall back to name, in both directions", function()
    local ties = { e("b", "/b", 5, 1), e("a", "/a", 5, 1) }
    Search.sort(ties, "size", true); T.eq(T.names(ties), "a|b")
    Search.sort(ties, "size", false); T.eq(T.names(ties), "a|b")
end)

T.test("each category starts in its usual direction", function()
    T.eq(Search.sortBy("size").descending, true)
    T.eq(Search.sortBy("name").descending, false)
    T.eq(Search.sortBy("new").descending, true)
    T.eq(Search.sortBy("opened").descending, true)
    T.eq(Search.sortBy("nonsense").id, "size")
    T.eq(#Search.SORTS, 4)
end)

local mixed = {
    ["/r"] = { entries = {
        e("a.CBZ", "/r/a.CBZ", 5, 1), e("b.epub", "/r/b.epub", 4, 1), e("README", "/r/README", 1, 1),
        e("Manga", "/r/Manga", 0, 1, true), e("old.epub.sdr", "/r/old.epub.sdr", 0, 1, true, true),
    } },
    ["/r/Manga"] = { entries = { e("c.cbz", "/r/Manga/c.cbz", 9, 1), e("notes.txt", "/r/Manga/notes.txt", 1, 1) } },
    ["/r/old.epub.sdr"] = { entries = { e("x.cbz", "/r/old.epub.sdr/x.cbz", 1, 1) } },
}

T.test("a type filter alone lists that type everywhere below, case-insensitively, never folders", function()
    local found, where = Search.find(mixed, "/r", "", "cbz")
    T.eq(#found, 2)
    local names = {}
    for _, f in ipairs(found) do names[f.name] = where[f] end
    T.eq(names["a.CBZ"], "")
    T.eq(names["c.cbz"], "Manga")
end)

T.test("a type filter and a query must both match", function()
    local found = Search.find(mixed, "/r", "c.cbz", "cbz")
    T.eq(T.names(found), "c.cbz")
end)

T.test("files with no extension are filtered as other", function()
    T.eq(T.names((Search.find(mixed, "/r", "", "other"))), "README")
end)

T.test("a filter finds nothing inside sidecar folders", function()
    for _, f in ipairs((Search.find(mixed, "/r", "", "cbz"))) do
        if f.path:find(".sdr", 1, true) then error("found " .. f.path) end
    end
end)

T.test("search and filters never look at dot-entries", function()
    local dots = {
        ["/r"] = { entries = {
            e("book.epub", "/r/book.epub", 5, 1), e(".kobo", "/r/.kobo", 0, 1, true), e("._book.epub", "/r/._book.epub", 1, 1),
            e("Fiction", "/r/Fiction", 0, 1, true),
        } },
        ["/r/.kobo"] = { entries = { e("system.epub", "/r/.kobo/system.epub", 9, 1), e("db.sqlite", "/r/.kobo/db.sqlite", 9, 1) } },
        ["/r/Fiction"] = { entries = { e("novel.epub", "/r/Fiction/novel.epub", 3, 1) } },
    }
    T.eq(T.names((Search.find(dots, "/r", "", "epub"))), "book.epub|novel.epub")
    T.eq(T.names((Search.find(dots, "/r", "", "sqlite"))), "")
    T.eq(T.names((Search.find(dots, "/r", "kobo"))), "")
    T.eq(T.names((Search.find(dots, "/r", "book"))), "book.epub")
end)

T.test("a test on each file narrows the search, reaches into folders, and never returns a folder", function()
    local done = { ["/r/b.epub"] = true, ["/r/Manga/Vol 1.cbz"] = true, ["/r/Manga"] = true }
    local found, where = Search.find(tree, "/r", nil, nil, function(f) return done[f.path] end)
    T.eq(#found, 2)
    T.eq(T.names(found), "Vol 1.cbz|b.epub")
    T.eq(where[found[1]], "Manga")
end)

T.test("a test on each file combines with a name and a type", function()
    local all = function() return true end
    T.eq(T.names((Search.find(tree, "/r", "vol", nil, all))), "Vol 1.cbz")
    T.eq(T.names((Search.find(tree, "/r", nil, "epub", all))), "DELETE ME - a.epub|b.epub")
    T.eq(#(Search.find(tree, "/r", nil, nil, function() return false end)), 0)
end)

T.test("last opened sorts by the time given, newest or oldest first, and leaves the rest for last in both orders", function()
    local times = { ["/r/b.epub"] = 300, ["/r/Manga/Vol 1.cbz"] = 100, ["/r/DELETE ME - a.epub"] = 200 }
    local function times_of(e) return times[e.path] end
    local list = { manga, e("never.epub", "/r/never.epub", 1, 1), e("b.epub", "/r/b.epub", 80, 7),
                   e("Vol 1.cbz", "/r/Manga/Vol 1.cbz", 450, 9), e("DELETE ME - a.epub", "/r/DELETE ME - a.epub", 12, 3) }
    Search.sort(list, "opened", true, times_of)
    T.eq(T.names(list), "b.epub|DELETE ME - a.epub|Vol 1.cbz|Manga|never.epub")
    Search.sort(list, "opened", false, times_of)
    T.eq(T.names(list), "Vol 1.cbz|DELETE ME - a.epub|b.epub|Manga|never.epub")
end)

T.test("last opened with no times at all falls back to name order", function()
    local list = { e("b.epub", "/r/b.epub", 1, 1), e("a.epub", "/r/a.epub", 1, 1) }
    Search.sort(list, "opened", true, nil)
    T.eq(T.names(list), "a.epub|b.epub")
end)

T.test("the status options: all, finished and never read, found by id", function()
    T.eq(Search.status(nil).short, "All")
    T.eq(Search.status("complete").short, "Finished")
    T.eq(Search.status("new").short, "Never read")
    T.eq(Search.status("new").noun, "unread")
    T.eq(Search.status("nonsense").short, "All")
end)

T.test("no query and no filter finds nothing", function()
    T.eq(#Search.find(mixed, "/r", "", nil), 0)
    T.eq(#Search.find(mixed, "/r", nil, nil), 0)
end)

T.done()
