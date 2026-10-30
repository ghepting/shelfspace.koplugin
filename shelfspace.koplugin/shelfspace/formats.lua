-- What ShelfSpace knows about file formats: which extension a file is counted under (so "x.kepub.epub", "x.fb2.zip" and the
-- aliases of a format are one type in the filters and the tiles), what kind of thing it is (so a tile and a row get a
-- colour), the few letters on its tile, and how well it reads on an e-ink screen. Pure logic, so the tests can check every
-- format KOReader opens.
local Formats = {}

-- Other spellings of the same format.
local ALIASES = {
    kepub = "epub", -- Kobo's EPUB
    prc = "mobi", -- Mobipocket
    fbz = "fb2",
    htm = "html",
    markdown = "md",
    text = "txt",
    jpeg = "jpg",
    djv = "djvu",
    oxps = "xps",
    epub3 = "epub",
}

-- Formats KOReader reads zipped, as "name.txt.zip" (KOReader registers these); the zip is not a comic then.
local ZIPPED = { fb2 = true, htm = true, html = true, md = true, rtf = true, txt = true, log = true }

-- What each format is, for the colour of its tile and its row.
--   book: reflowable e-books. document: reflowable documents and web pages. fixed: fixed-layout pages (a PDF, a scan).
--   comic: archives of pages, read as a comic. image: a lone picture.
local KINDS = {
    book = { "epub", "mobi", "azw", "azw3", "azw4", "fb2", "fb3", "pdb" },
    document = { "doc", "docx", "docm", "odt", "rtf", "txt", "md", "html", "xhtml", "htmlz", "chm", "cfb", "pptx", "xlsx", "xml", "log", "py", "sh" },
    fixed = { "pdf", "djvu", "xps" },
    comic = { "cbz", "cbt", "cbr", "zip" },
    image = { "jpg", "png", "bmp", "webp", "gif", "tif", "tiff", "svg", "jp2", "j2k", "jxr", "hdp", "wdp", "pbm", "pgm", "pnm", "ppm", "pam" },
}
local KIND_OF = {}
for kind, list in pairs(KINDS) do
    for _, ext in ipairs(list) do KIND_OF[ext] = kind end
end

-- How well a format reads on an e-ink screen: lower is better. Fixed-layout formats come last.
local RANK = {
    epub = 1,
    mobi = 2, azw = 2, azw3 = 2, azw4 = 2,
    fb2 = 3, fb3 = 3, pdb = 3, doc = 3, docx = 3, docm = 3, odt = 3, rtf = 3, txt = 3, md = 3, html = 3, xhtml = 3, htmlz = 3, chm = 3, zip = 3,
    djvu = 4, cbz = 4, cbr = 4, cbt = 4,
    pdf = 5, xps = 5,
}
Formats.OTHER_RANK = 4

-- The extension a file is counted under, lower case: "epub" for "a.kepub.epub", "fb2" for "a.fb2.zip" and "a.fbz",
-- "jpg" for "a.JPEG". nil when the name has none.
function Formats.extension(name)
    local lower = name:lower()
    local last = lower:match("%.([^./]+)$")
    if not last then return nil end
    if last == "zip" then
        local inner = lower:match("%.([^./]+)%.zip$")
        if inner and ZIPPED[inner] then return ALIASES[inner] or inner end
    end
    return ALIASES[last] or last
end

-- "book", "document", "fixed", "comic", "image", or "other" for anything KOReader does not read as one of those.
function Formats.kind(name)
    return KIND_OF[Formats.extension(name) or ""] or "other"
end

-- The few letters on a file's tile: its extension in capitals, at most four ("?" when it has none).
function Formats.label(name)
    return (Formats.extension(name) or "?"):upper():sub(1, 4)
end

function Formats.rank(name)
    return RANK[Formats.extension(name) or ""] or Formats.OTHER_RANK
end

-- True for a format drawn as fixed pages, which reads worse on a small e-ink screen than one that reflows.
function Formats.isFixedLayout(name)
    return Formats.kind(name) == "fixed"
end

-- The name without its extension, and without the half of a compound one: "Dune" for "Dune.kepub.epub", "Dune.fb2.zip", "Dune.txt.zip", "Dune.epub".
function Formats.stem(name)
    local stem = name:gsub("%.[^./]+$", "")
    local ext = name:lower():match("%.([^./]+)$")
    if ext == "epub" then
        stem = stem:gsub("%.[Kk][Ee][Pp][Uu][Bb]$", "")
    elseif ext == "zip" then
        local inner = name:lower():match("%.([^./]+)%.zip$")
        if inner and ZIPPED[inner] then stem = stem:gsub("%.[^./]+$", "") end
    end
    return stem
end

-- Every extension listed under a kind, for the tests.
function Formats.known()
    local list = {}
    for ext, kind in pairs(KIND_OF) do list[#list + 1] = { ext = ext, kind = kind } end
    table.sort(list, function(a, b) return a.ext < b.ext end)
    return list
end

return Formats
