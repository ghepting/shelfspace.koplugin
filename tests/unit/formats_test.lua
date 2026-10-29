local T = dofile((debug.getinfo(1, "S").source:match("^@(.*)/[^/]+$") or ".") .. "/helper.lua")
local Formats = require("shelfspace/formats")

print("formats")

-- Every format KOReader opens, as it is written in a file name: { name suffix, counted as, kind, tile letters }.
local SUPPORTED = {
    -- reflowable e-books and documents
    { "epub", "epub", "book", "EPUB" }, { "kepub.epub", "epub", "book", "EPUB" }, { "kepub", "epub", "book", "EPUB" },
    { "mobi", "mobi", "book", "MOBI" }, { "prc", "mobi", "book", "MOBI" },
    { "fb2", "fb2", "book", "FB2" }, { "fb2.zip", "fb2", "book", "FB2" }, { "fbz", "fb2", "book", "FB2" },
    { "doc", "doc", "document", "DOC" }, { "docx", "docx", "document", "DOCX" }, { "rtf", "rtf", "document", "RTF" },
    { "txt", "txt", "document", "TXT" }, { "text", "txt", "document", "TXT" },
    { "md", "md", "document", "MD" }, { "markdown", "md", "document", "MD" },
    { "html", "html", "document", "HTML" }, { "htm", "html", "document", "HTML" }, { "chm", "chm", "document", "CHM" },
    { "pdb", "pdb", "book", "PDB" },
    -- fixed layout and scans
    { "pdf", "pdf", "fixed", "PDF" }, { "djvu", "djvu", "fixed", "DJVU" }, { "djv", "djvu", "fixed", "DJVU" },
    { "xps", "xps", "fixed", "XPS" }, { "oxps", "xps", "fixed", "XPS" },
    -- comics and pictures
    { "cbz", "cbz", "comic", "CBZ" }, { "cbt", "cbt", "comic", "CBT" }, { "zip", "zip", "comic", "ZIP" },
    { "jpg", "jpg", "image", "JPG" }, { "jpeg", "jpg", "image", "JPG" }, { "png", "png", "image", "PNG" },
    { "bmp", "bmp", "image", "BMP" }, { "webp", "webp", "image", "WEBP" }, { "gif", "gif", "image", "GIF" },
    -- more that KOReader registers
    { "epub3", "epub", "book", "EPUB" }, { "fb3", "fb3", "book", "FB3" },
    { "odt", "odt", "document", "ODT" }, { "docm", "docm", "document", "DOCM" }, { "xhtml", "xhtml", "document", "XHTM" }, { "htmlz", "htmlz", "document", "HTML" },
    { "txt.zip", "txt", "document", "TXT" }, { "md.zip", "md", "document", "MD" }, { "html.zip", "html", "document", "HTML" },
    { "htm.zip", "html", "document", "HTML" }, { "rtf.zip", "rtf", "document", "RTF" }, { "log.zip", "log", "document", "LOG" },
    { "tif", "tif", "image", "TIF" }, { "svg", "svg", "image", "SVG" }, { "jp2", "jp2", "image", "JP2" }, { "ppm", "ppm", "image", "PPM" },
}

-- "epub" in three cases: as written, in capitals, and in a mix.
local function cases(suffix)
    local mixed = suffix:gsub("()(%a)", function(i, c) return i % 2 == 1 and c:upper() or c end)
    return { suffix, suffix:upper(), mixed }
end

T.test("every format is counted, kinded and labelled the same in any case", function()
    for _, f in ipairs(SUPPORTED) do
        for _, suffix in ipairs(cases(f[1])) do
            local name = "Some Book." .. suffix
            T.eq(Formats.extension(name), f[2], name .. " is counted as " .. f[2])
            T.eq(Formats.kind(name), f[3], name .. " is a " .. f[3])
            T.eq(Formats.label(name), f[4], name .. " is labelled " .. f[4])
        end
    end
end)

T.test("a name's own case, or dots in the title, do not change its format", function()
    T.eq(Formats.extension("a.b.c.EPUB"), "epub")
    T.eq(Formats.extension("Dr. Who 2.0 (1963).PDF"), "pdf")
    T.eq(Formats.extension("SAGA V1.CBZ"), "cbz")
    T.eq(Formats.extension("Mixed.KePub.ePuB"), "epub")
    T.eq(Formats.extension("Mixed.Fb2.ZIP"), "fb2")
end)

T.test("a zip is a comic archive, unless it is a format KOReader reads zipped (name.fb2.zip, name.txt.zip, ...)", function()
    T.eq(Formats.kind("pages.zip"), "comic")
    T.eq(Formats.kind("pages.fb2.zip"), "book")
    T.eq(Formats.kind("notes.txt.zip"), "document")
    T.eq(Formats.kind("page.HTM.ZIP"), "document")
    T.eq(Formats.kind("notes.docx.zip"), "comic", "only the formats KOReader registers zipped")
    T.eq(Formats.kind("holiday.jpg.zip"), "comic")
end)

T.test("a file with no extension, or one nobody knows, is other", function()
    T.eq(Formats.extension("README"), nil)
    T.eq(Formats.kind("README"), "other")
    T.eq(Formats.label("README"), "?")
    T.eq(Formats.kind("driver.so"), "other")
    T.eq(Formats.label("driver.so"), "SO")
    T.eq(Formats.kind("book.kfx"), "other", "KFX is not something KOReader opens")
    T.eq(Formats.kind(".hidden"), "other")
end)

T.test("a tile never has more than four letters", function()
    T.eq(Formats.label("a.markdown"), "MD")
    T.eq(Formats.label("a.tiff"), "TIFF")
    T.eq(Formats.label("a.verylongextension"), "VERY")
end)

T.test("the name without its extension drops the half of a compound one too, in any case", function()
    T.eq(Formats.stem("Dune.epub"), "Dune")
    T.eq(Formats.stem("Dune.kepub.epub"), "Dune")
    T.eq(Formats.stem("Dune.KEPUB.EPUB"), "Dune")
    T.eq(Formats.stem("Dune.fb2.zip"), "Dune")
    T.eq(Formats.stem("Dune.FB2.ZIP"), "Dune")
    T.eq(Formats.stem("Dune.txt.zip"), "Dune")
    T.eq(Formats.stem("Dune.TXT.ZIP"), "Dune")
    T.eq(Formats.stem("Dune.docx.zip"), "Dune.docx", "a docx is not read zipped")
    T.eq(Formats.stem("Dune.1.2.pdf"), "Dune.1.2")
    T.eq(Formats.stem("Saga.kepub.cbz"), "Saga.kepub", "only an epub has a kepub half")
end)

T.test("EPUB reads best on e-ink and fixed layouts come last, in any case", function()
    assert(Formats.rank("a.epub") < Formats.rank("a.mobi"))
    assert(Formats.rank("a.mobi") < Formats.rank("a.fb2"))
    assert(Formats.rank("a.fb2") < Formats.rank("a.pdf"))
    T.eq(Formats.rank("a.EPUB"), Formats.rank("a.epub"))
    T.eq(Formats.rank("a.kepub.epub"), Formats.rank("a.epub"))
    T.eq(Formats.rank("a.PRC"), Formats.rank("a.mobi"))
    T.eq(Formats.rank("a.unknown"), Formats.OTHER_RANK)
    assert(Formats.isFixedLayout("a.PDF") and Formats.isFixedLayout("a.djv") and Formats.isFixedLayout("a.oxps"))
    assert(not Formats.isFixedLayout("a.epub") and not Formats.isFixedLayout("a.cbz"))
end)

T.test("every extension in the table has a kind, and the five kinds are all used", function()
    local seen = {}
    for _, f in ipairs(Formats.known()) do seen[f.kind] = true end
    for _, kind in ipairs({ "book", "document", "fixed", "comic", "image" }) do assert(seen[kind], kind .. " has no format") end
end)

T.done()
