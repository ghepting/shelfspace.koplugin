local T = dofile((debug.getinfo(1, "S").source:match("^@(.*)/[^/]+$") or ".") .. "/helper.lua")
local Selection = require("shelfspace/selection")

local function e(path, size, is_dir)
    return { name = path:match("[^/]+$"), path = path, size = size or 1, is_dir = is_dir }
end

print("selection")

T.test("a folder swallows what is inside it", function()
    local kept = Selection.collapse({ e("/r/Manga/vol1.cbz"), e("/r/Manga", 9, true), e("/r/b.epub") })
    T.eq(T.names(kept), "b.epub|Manga")
end)

T.test("nested folders collapse to the outermost", function()
    local kept = Selection.collapse({ e("/r/a/b/c", 1, true), e("/r/a", 5, true), e("/r/a/b/c/x.epub") })
    T.eq(T.names(kept), "a")
end)

T.test("a folder whose name starts like another is not inside it", function()
    local kept = Selection.collapse({ e("/r/a", 1, true), e("/r/a b", 1, true), e("/r/a/x.epub") })
    T.eq(T.names(kept), "a|a b")
end)

T.test("a file is never a parent", function()
    local kept = Selection.collapse({ e("/r/a.epub"), e("/r/a.epub.bak") })
    T.eq(T.names(kept), "a.epub|a.epub.bak")
end)

T.test("duplicates count once", function()
    local x = e("/r/x.epub", 7)
    T.eq(#Selection.collapse({ x, x, e("/r/x.epub", 7) }), 1)
end)

T.test("size adds up only what is kept", function()
    local kept = Selection.collapse({ e("/r/d", 100, true), e("/r/d/f.epub", 40), e("/r/g.epub", 5) })
    T.eq(Selection.size(kept), 105)
end)

T.test("nothing selected is nothing", function()
    T.eq(#Selection.collapse({}), 0)
    T.eq(Selection.size({}), 0)
end)

T.done()
