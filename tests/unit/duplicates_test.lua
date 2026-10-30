local T = dofile((debug.getinfo(1, "S").source:match("^@(.*)/[^/]+$") or ".") .. "/helper.lua")
local Duplicates = require("shelfspace/duplicates")

print("finding duplicate books")

local function file(path, size, modified)
    return { path = path, name = path:match("[^/]+$"), size = size, modified = modified or 0 }
end

-- Two files are "the same bytes" when the test says so by listing their paths.
local function sameWhen(pairs_)
    return function(a, b)
        for _, p in ipairs(pairs_) do
            if (p[1] == a.path and p[2] == b.path) or (p[1] == b.path and p[2] == a.path) then return true end
        end
        return false
    end
end
local never = function() return false end

T.test("the key ignores extension, case, punctuation and copy suffixes", function()
    T.eq(Duplicates.key("Project Hail Mary.epub"), "project hail mary")
    T.eq(Duplicates.key("project_hail-mary.PDF"), "project hail mary")
    T.eq(Duplicates.key("Project Hail Mary (1).epub"), "project hail mary")
    T.eq(Duplicates.key("Project Hail Mary - copy.epub"), "project hail mary")
    T.eq(Duplicates.key("Project Hail Mary (2) copy.epub"), "project hail mary")
    T.eq(Duplicates.key("Dune.kepub.epub"), "dune")
end)

T.test("different books do not share a key", function()
    assert(Duplicates.key("Dune.epub") ~= Duplicates.key("Dune Messiah.epub"))
    assert(Duplicates.key("Hyperion (1989).epub") ~= Duplicates.key("Hyperion.epub"), "a year is part of the name")
end)

T.test("the same name in two formats is one set, marked as the same book", function()
    local sets = Duplicates.find({
        file("/lib/Andy Weir - Project Hail Mary.epub", 9400),
        file("/lib/dl/Andy Weir - Project Hail Mary.pdf", 31200),
        file("/lib/Dune.epub", 700),
    }, never)
    T.eq(#sets, 1)
    T.eq(#sets[1].copies, 2)
    T.eq(sets[1].kind, "same")
end)

T.test("identical copies are an exact set", function()
    local sets = Duplicates.find({
        file("/lib/A.epub", 100), file("/lib/Old/A.epub", 100),
    }, sameWhen({ { "/lib/A.epub", "/lib/Old/A.epub" } }))
    T.eq(#sets, 1)
    T.eq(sets[1].kind, "exact")
end)

T.test("a renamed copy is found by its contents", function()
    local sets = Duplicates.find({
        file("/lib/A.epub", 100), file("/lib/something else.epub", 100), file("/lib/B.epub", 100),
    }, sameWhen({ { "/lib/A.epub", "/lib/something else.epub" } }))
    T.eq(#sets, 1)
    T.eq(#sets[1].copies, 2)
    T.eq(sets[1].kind, "exact")
end)

T.test("files of the same size but different contents are not duplicates", function()
    T.eq(#Duplicates.find({ file("/lib/A.epub", 100), file("/lib/B.epub", 100) }, never), 0)
end)

T.test("a set mixing an identical pair with a different edition is the same book, not exact", function()
    local sets = Duplicates.find({
        file("/lib/Dune.epub", 100), file("/lib/Old/Dune.epub", 100), file("/lib/Dune (1).epub", 120),
    }, sameWhen({ { "/lib/Dune.epub", "/lib/Old/Dune.epub" } }))
    T.eq(#sets, 1)
    T.eq(#sets[1].copies, 3)
    T.eq(sets[1].kind, "same")
end)

T.test("generic names are never treated as one book", function()
    T.eq(#Duplicates.find({ file("/lib/a/cover.epub", 1), file("/lib/b/cover.epub", 2) }, never), 0)
end)

T.test("seventeen copies make one set", function()
    local files = { file("/lib/Dune.epub", 100) }
    for i = 1, 16 do table.insert(files, file("/lib/Dune (" .. i .. ").epub", 100 + i)) end
    local sets = Duplicates.find(files, never)
    T.eq(#sets, 1)
    T.eq(#sets[1].copies, 17)
end)

print("choosing the copy to keep")

local function suggest(copies, info)
    return Duplicates.suggest({ copies = copies }, function(c) return info[c.path] or {} end)
end

T.test("the book being read is always kept", function()
    local a, b = file("/lib/Dune.pdf", 5), file("/lib/Dune.epub", 5)
    local i, why = suggest({ a, b }, { ["/lib/Dune.pdf"] = { locked = true } })
    T.eq(i, 1)
    T.eq(why, "reading")
end)

T.test("reading progress beats a better format", function()
    local a, b = file("/lib/Dune.pdf", 5), file("/lib/Dune.epub", 5)
    local i, why = suggest({ a, b }, { ["/lib/Dune.pdf"] = { progress = 0.4 } })
    T.eq(i, 1)
    T.eq(why, "progress")
end)

T.test("with no progress, the format that reads best on e-ink wins", function()
    local i, why = suggest({ file("/lib/Dune.pdf", 5), file("/lib/Dune.mobi", 5), file("/lib/Dune.epub", 5) }, {})
    T.eq(i, 3)
    T.eq(why, "format")
end)

T.test("an epub and a kepub rank the same, so the one nearer the root wins", function()
    local i, why = suggest({ file("/lib/old/Dune.kepub.epub", 5), file("/lib/Dune.epub", 5) }, {})
    T.eq(i, 2)
    T.eq(why, "location")
end)

T.test("identical copies in one folder: the newest wins", function()
    local i, why = suggest({ file("/lib/Dune.epub", 5, 100), file("/lib/Dune (1).epub", 5, 200) }, {})
    T.eq(i, 2)
    T.eq(why, "newest")
end)

T.test("savings and the most that could be freed", function()
    local set = { copies = { file("/lib/a.epub", 100), file("/lib/b.epub", 40), file("/lib/c.epub", 10) } }
    T.eq(Duplicates.savings(set, 1), 50)
    T.eq(Duplicates.savings(set, 3), 140)
    T.eq(Duplicates.reclaimable({ set, { copies = { file("/x/a.epub", 7), file("/x/b.epub", 7) } } }), 57)
end)

local function tagIds(set, i, info)
    local ids = {}
    for _, tag in ipairs(Duplicates.tags(set, i, function(c) return info[c.path] or {} end)) do ids[#ids + 1] = tag.id end
    return table.concat(ids, ",")
end

T.test("tags name only what sets a copy apart", function()
    local set = { copies = { file("/lib/B.epub", 100, 5), file("/lib/B (1).epub", 100, 5), file("/lib/B.pdf", 400, 5) } }
    T.eq(tagIds(set, 1, {}), "suggested")
    T.eq(tagIds(set, 2, {}), "")
    T.eq(tagIds(set, 3, {}), "fixed_layout")
end)

T.test("the furthest-read, newest and smallest copy are tagged when exactly one is", function()
    local set = { copies = { file("/lib/B.epub", 100, 9), file("/lib/B (1).epub", 120, 5), file("/lib/B.mobi", 130, 5) } }
    local info = { ["/lib/B.epub"] = { progress = 0.35 } }
    T.eq(tagIds(set, 1, info), "suggested,most_read,newest,smallest")
    T.eq(tagIds(set, 3, info), "older_format")
end)

T.test("a set you kept comes back when a new copy appears", function()
    local set = { id = "dune", copies = { {}, {} } }
    T.eq(Duplicates.isIgnored({}, set), false)
    T.eq(Duplicates.isIgnored({ dune = 2 }, set), true)
    T.eq(Duplicates.isIgnored({ dune = 1 }, set), false, "a third copy is a new question")
    T.eq(Duplicates.isIgnored({ dune = true }, set), true, "older versions saved a plain yes")
    T.eq(Duplicates.isIgnored({ other = 2 }, set), false)
end)

T.test("sameBytes compares files byte for byte", function()
    local dir = os.tmpname()
    os.remove(dir)
    os.execute("mkdir -p " .. dir)
    local function write(name, text) local f = io.open(dir .. "/" .. name, "wb"); f:write(text); f:close() end
    write("a", string.rep("x", 200000)); write("b", string.rep("x", 200000)); write("c", string.rep("x", 199999) .. "y")
    T.eq(Duplicates.sameBytes(dir .. "/a", dir .. "/b"), true)
    T.eq(Duplicates.sameBytes(dir .. "/a", dir .. "/c"), false)
    T.eq(Duplicates.sameBytes(dir .. "/a", dir .. "/missing"), false)
    os.execute("rm -rf " .. dir)
end)

T.test("the key is the same for every spelling and case of a format, compound ones included", function()
    for _, name in ipairs({ "Dune.EPUB", "dune.epub", "DUNE.KEPUB.EPUB", "Dune.kepub.epub", "dune.Mobi", "Dune.PRC", "Dune.FB2.ZIP", "Dune.fb2.zip",
        "DUNE.Docx", "Dune.PDF", "Dune.DJVU", "Dune.XPS", "Dune.TXT", "Dune.Html", "Dune.cbz" }) do
        T.eq(Duplicates.key(name), "dune", name)
    end
end)

T.test("one book in four spellings is one set, titled without a half extension", function()
    local sets = Duplicates.find({
        file("/lib/a/Dune.EPUB", 100), file("/lib/b/dune.kepub.epub", 110), file("/lib/c/DUNE.mobi", 120), file("/lib/d/Dune.fb2.zip", 90),
    }, never)
    T.eq(#sets, 1)
    T.eq(#sets[1].copies, 4)
    T.eq(sets[1].kind, "same")
    local title = Duplicates.title(sets[1].copies)
    T.eq(title:lower(), "dune", "the shortest name, with no .kepub or .fb2 left on it")
    assert(not title:find(".", 1, true), "a half extension is left on " .. title)
end)

T.test("the extension, whatever its case or form, ranks the format", function()
    assert(Duplicates.formatRank("a.EPUB") < Duplicates.formatRank("a.MOBI"))
    T.eq(Duplicates.formatRank("a.KEPUB.EPUB"), Duplicates.formatRank("a.epub"))
    T.eq(Duplicates.formatRank("a.PRC"), Duplicates.formatRank("a.mobi"))
    T.eq(Duplicates.extension("a.FB2.ZIP"), "fb2")
    T.eq(Duplicates.extension("README"), "")
end)

T.test("every fixed-layout format is tagged as one, in any case", function()
    local set = { copies = { file("/lib/B.EPUB", 100, 5), file("/lib/B.PDF", 100, 5), file("/lib/B.djv", 100, 5), file("/lib/B.OXPS", 100, 5) } }
    T.eq(tagIds(set, 2, {}), "fixed_layout")
    T.eq(tagIds(set, 3, {}), "fixed_layout")
    T.eq(tagIds(set, 4, {}), "fixed_layout")
end)

T.done()
