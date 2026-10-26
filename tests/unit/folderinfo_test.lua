local T = dofile((debug.getinfo(1, "S").source:match("^@(.*)/[^/]+$") or ".") .. "/helper.lua")
local Folderinfo = require("shelfspace/folderinfo")

print("folder info")

local function folder(name, size, modified) return { name = name, size = size, modified = modified, is_dir = true } end

T.test("a folder's card says its name, how many files and how big, and where it is", function()
    local text = Folderinfo.text(folder("Sci-Fi", 5200, nil), "Library", 2, nil)
    T.eq(text, "Sci-Fi/\n\n2 files · 5200 B\nIn: Library")
end)

T.test("one file is not '1 files'", function()
    assert(Folderinfo.text(folder("Solo", 10), "Manga", 1, nil):find("1 file · 10 B", 1, true))
end)

T.test("a locked folder says why, in lower case after 'Locked:'", function()
    local text = Folderinfo.text(folder("Sci-Fi", 1), "Library", 2, "Holds the book you are reading")
    assert(text:find("Locked: holds the book you are reading", 1, true), text)
    assert(not Folderinfo.text(folder("Sci-Fi", 1), "Library", 2, nil):find("Locked", 1, true))
end)

T.test("the change date is shown when the folder has one", function()
    assert(Folderinfo.text(folder("Sci-Fi", 1, os.time()), "Library", 2, nil):find("Changed: ", 1, true))
end)

T.done()
