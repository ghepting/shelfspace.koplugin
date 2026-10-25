local T = dofile((debug.getinfo(1, "S").source:match("^@(.*)/[^/]+$") or ".") .. "/helper.lua")

-- The parts of KOReader that deleter.lua loads, as stand-ins: only "which files can KOReader open" matters here.
local OPENABLE = { epub = true, pdf = true, cbz = true, mobi = true }
package.preload["ui/widget/booklist"] = function() return {} end
package.preload["docsettings"] = function() return {} end
package.preload["readcollection"] = function() return {} end
package.preload["readhistory"] = function() return {} end
package.preload["document/documentregistry"] = function()
    return { hasProvider = function(_, path) return OPENABLE[(path:match("%.([^.]+)$") or ""):lower()] or false end }
end
local Deleter = require("shelfspace/deleter")

print("what can be deleted")

local function file(path) return { name = path:match("[^/]+$"), path = path, size = 1 } end
local function dir(path, hidden) return { name = path:match("[^/]+$"), path = path, size = 1, is_dir = true, hidden = hidden } end

-- A Kobo-shaped library: books at the top, KOReader under .adds, system folders hidden.
local tree = {
    ["/lib"] = { entries = {
        file("/lib/Dune.epub"), file("/lib/readme.txt"), dir("/lib/Sci-Fi"), dir("/lib/Mixed"), dir("/lib/Deep"),
        dir("/lib/.kobo"), dir("/lib/.adds"), dir("/lib/Dune.sdr", true), dir("/lib/a.epub.bak-folder"),
    } },
    ["/lib/Sci-Fi"] = { entries = { file("/lib/Sci-Fi/Hyperion.epub"), file("/lib/Sci-Fi/cover.JPG"), file("/lib/Sci-Fi/book.opf"),
                                    dir("/lib/Sci-Fi/Hyperion.sdr", true) } },
    ["/lib/Sci-Fi/Hyperion.sdr"] = { entries = { file("/lib/Sci-Fi/Hyperion.sdr/metadata.epub.lua") } },
    ["/lib/Mixed"] = { entries = { file("/lib/Mixed/Notes.epub"), file("/lib/Mixed/plugin.so") } },
    ["/lib/Deep"] = { entries = { dir("/lib/Deep/a"), file("/lib/Deep/ok.pdf") } },
    ["/lib/Deep/a"] = { entries = { dir("/lib/Deep/a/b") } },
    ["/lib/Deep/a/b"] = { entries = { file("/lib/Deep/a/b/stray.dat") } },
    ["/lib/.kobo"] = { entries = { file("/lib/.kobo/KoboReader.sqlite") } },
    ["/lib/.adds"] = { entries = { dir("/lib/.adds/koreader"), dir("/lib/.adds/koreader-old") } },
    ["/lib/.adds/koreader"] = { entries = { dir("/lib/.adds/koreader/plugins") } },
    ["/lib/.adds/koreader/plugins"] = { entries = {} },
    ["/lib/.adds/koreader-old"] = { entries = { file("/lib/.adds/koreader-old/old.epub") } },
    ["/lib/a.epub.bak-folder"] = { entries = {} },
}

local function reason(entry, open_file)
    return Deleter.blockedReason(entry, { tree = tree, root = "/lib", koreader_dir = "/lib/.adds/koreader", open_file = open_file, cache = {} })
end

T.test("a book KOReader can open can be deleted", function()
    T.eq(reason(file("/lib/Dune.epub")), nil)
end)

T.test("a file KOReader does not manage cannot", function()
    T.eq(reason(file("/lib/readme.txt")), "Not a book KOReader manages")
end)

T.test("a folder of books and their covers can be deleted, sidecar folders ignored", function()
    T.eq(reason(dir("/lib/Sci-Fi")), nil)
end)

T.test("one stray file stops a whole folder", function()
    T.eq(reason(dir("/lib/Mixed")), "Has files KOReader doesn't manage")
end)

T.test("a stray file deep inside stops every folder above it", function()
    T.eq(reason(dir("/lib/Deep")), "Has files KOReader doesn't manage")
end)

T.test("hidden top-level folders are system folders", function()
    T.eq(reason(dir("/lib/.kobo")), "System folder")
    T.eq(reason(file("/lib/.kobo/KoboReader.sqlite")), "System folder")
end)

T.test("KOReader's install, and the folders above it, are locked", function()
    T.eq(reason(dir("/lib/.adds/koreader")), "KOReader is installed here")
    T.eq(reason(dir("/lib/.adds")), "KOReader is installed here")
end)

T.test("what is inside KOReader's folder is left to the KOReader tab", function()
    T.eq(reason(dir("/lib/.adds/koreader/plugins")), "KOReader's data: see the KOReader tab")
end)

T.test("the book being read, and its folder, are locked", function()
    T.eq(reason(file("/lib/Sci-Fi/Hyperion.epub"), "/lib/Sci-Fi/Hyperion.epub"), "You are reading this book")
    T.eq(reason(dir("/lib/Sci-Fi"), "/lib/Sci-Fi/Hyperion.epub"), "You are reading this book")
end)

T.test("a name that merely starts like a locked one is not locked", function()
    T.eq(reason(file("/lib/Dune.epub"), "/lib/Dune.epub.bak"), nil)                -- open file is longer
    T.eq(reason(dir("/lib/a.epub.bak-folder"), "/lib/a.epub"), nil)                -- sibling of the open book
    T.eq(reason(dir("/lib/.adds/koreader-old")), "System folder")                   -- hidden, not "installed here"
end)

T.test("only a book KOReader can open counts as a book, not a cover or an unknown file", function()
    T.eq(Deleter.isBook(file("/lib/Dune.epub")), true)
    T.eq(Deleter.isBook(file("/lib/Sci-Fi/cover.JPG")), false)
    T.eq(Deleter.isBook(file("/lib/Mixed/plugin.so")), false)
end)

T.test("companion file types match whatever their case", function()
    T.eq(reason(file("/lib/Sci-Fi/cover.JPG")), nil)
end)

T.done()
