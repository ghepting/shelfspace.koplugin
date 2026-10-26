-- Finds books that exist more than once and suggests which copy to keep. Pure logic: the caller supplies
-- the files and a way to compare two of them, so it runs the same under the tests as on a device.
local Duplicates = {}

-- How well a format reads on an e-ink screen: lower is better. PDFs are fixed-layout, so they come last.
local FORMATS = {
    epub = 1, kepub = 1,
    mobi = 2, azw = 2, azw3 = 2, azw4 = 2,
    fb2 = 3, fbz = 3, docx = 3, rtf = 3, txt = 3, htm = 3, html = 3, chm = 3, zip = 3,
    djvu = 4, cbz = 4, cbr = 4,
    pdf = 5,
}
local OTHER_FORMAT = 4

function Duplicates.extension(name)
    return (name:match("%.([^./]+)$") or ""):lower()
end

function Duplicates.formatRank(name)
    return FORMATS[Duplicates.extension(name)] or OTHER_FORMAT
end

-- A name with the things that differ between copies of one book taken out: the extension, case,
-- punctuation, and the " (1)" or " copy" a download or a file manager adds.
function Duplicates.key(name)
    local base = name:gsub("%.[^./]+$", "")
    base = base:gsub("%.kepub$", "")
    base = base:lower()
    local before
    repeat -- more than one suffix can stack: "Dune (1) copy"
        before = base
        base = base:gsub("%s*%(%d%d?%)%s*$", ""):gsub("%s*%[%d%d?%]%s*$", "")
        base = base:gsub("[%s_%-]+copy%s*%d*%s*$", ""):gsub("[%s_%-]+copy%s*%(%d%d?%)%s*$", "")
    until base == before
    base = base:gsub("[%c%p%s]+", " ") -- punctuation, whitespace; bytes of non-ASCII letters are kept
    base = base:gsub("^%s+", ""):gsub("%s+$", "")
    return base
end

-- Names too generic to say two files are one book.
local GENERIC = { cover = true, book = true, untitled = true, document = true, unknown = true, ebook = true }

-- Groups `files` ({ path, name, size, modified? }) into sets of copies. `same(a, b)` says whether two
-- files of equal size hold the same bytes. A set is "exact" when every copy is the same file, and
-- "same" when the copies only share a title (a different format, edition or download).
function Duplicates.find(files, same)
    local parent = {}
    local function find(x)
        while parent[x] ~= x do
            parent[x] = parent[parent[x]]
            x = parent[x]
        end
        return x
    end
    local function union(a, b)
        a, b = find(a), find(b)
        if a ~= b then parent[b] = a end
    end
    for i = 1, #files do parent[i] = i end

    local by_key = {}
    for i, f in ipairs(files) do
        local key = Duplicates.key(f.name)
        if key ~= "" and not GENERIC[key] then
            by_key[key] = by_key[key] or {}
            table.insert(by_key[key], i)
        end
    end
    for _, group in pairs(by_key) do
        for j = 2, #group do union(group[1], group[j]) end
    end

    -- Identical files under different names are found by size first, so only files that could match are compared.
    local content = {}
    for i = 1, #files do content[i] = i end
    local function cfind(x)
        while content[x] ~= x do content[x] = content[content[x]]; x = content[x] end
        return x
    end
    local by_size = {}
    for i, f in ipairs(files) do
        if f.size and f.size > 0 then
            by_size[f.size] = by_size[f.size] or {}
            table.insert(by_size[f.size], i)
        end
    end
    for _, group in pairs(by_size) do
        for a = 1, #group - 1 do
            for b = a + 1, #group do
                local x, y = cfind(group[a]), cfind(group[b])
                if x ~= y and same(files[group[a]], files[group[b]]) then
                    content[y] = x
                    union(group[a], group[b])
                end
            end
        end
    end

    local sets_by_root, order = {}, {}
    for i = 1, #files do
        local root = find(i)
        if not sets_by_root[root] then
            sets_by_root[root] = { copies = {}, indexes = {} }
            table.insert(order, root)
        end
        table.insert(sets_by_root[root].copies, files[i])
        table.insert(sets_by_root[root].indexes, i)
    end

    local sets = {}
    for _, root in ipairs(order) do
        local s = sets_by_root[root]
        if #s.copies > 1 then
            local identical = true
            local c = cfind(s.indexes[1])
            for _, i in ipairs(s.indexes) do
                if cfind(i) ~= c then identical = false break end
            end
            s.kind = identical and "exact" or "same"
            s.title = Duplicates.title(s.copies)
            s.id = Duplicates.key(s.title)
            s.indexes = nil
            table.insert(sets, s)
        end
    end
    return sets
end

-- The name to call a set by: the shortest copy name, without its extension.
function Duplicates.title(copies)
    local best
    for _, f in ipairs(copies) do
        local shown = f.name:gsub("%.[^./]+$", "")
        if not best or #shown < #best then best = shown end
    end
    return best
end

local function depth(path)
    local _, n = path:gsub("/", "")
    return n
end

-- Which copy to keep. `info(copy)` gives { progress = 0..1, locked = bool }: the copy being read, then the
-- one furthest through, is never the one to go. After that the format that reads best on e-ink, the one
-- nearest the library root, and the newest. Returns the index and why, as one of
-- "reading", "progress", "format", "location" or "newest".
function Duplicates.suggest(set, info)
    local function better(a, b)
        local ia, ib = info(a), info(b)
        if (ia.locked or false) ~= (ib.locked or false) then return ia.locked and "reading" or nil end
        local pa, pb = ia.progress or 0, ib.progress or 0
        if pa ~= pb then return pa > pb and "progress" or nil end
        local fa, fb = Duplicates.formatRank(a.name), Duplicates.formatRank(b.name)
        if fa ~= fb then return fa < fb and "format" or nil end
        local da, db = depth(a.path), depth(b.path)
        if da ~= db then return da < db and "location" or nil end
        if (a.modified or 0) ~= (b.modified or 0) then return (a.modified or 0) > (b.modified or 0) and "newest" or nil end
        return nil
    end
    local best = 1
    for i = 2, #set.copies do
        if better(set.copies[i], set.copies[best]) then best = i end
    end
    -- The reason is what set the winner apart from its closest rival: the latest rule that had to decide.
    local order = { reading = 1, progress = 2, format = 3, location = 4, newest = 5 }
    local reason
    for i = 1, #set.copies do
        if i ~= best then
            local r = better(set.copies[best], set.copies[i])
            if r and (not reason or order[r] > order[reason]) then reason = r end
        end
    end
    return best, reason or "newest"
end

-- What sets copy `i` apart from the others in `set`: a list of { id, text? } facts worth a tag. Only real
-- differences are listed (a tag every copy would carry says nothing): "suggested" for the copy to keep,
-- "most_read" when one copy is furthest through, a worse format ("fixed_layout" for a PDF, else "older_format"),
-- "newest" and "smallest" when exactly one copy is. `info(copy)` is as for suggest.
function Duplicates.tags(set, i, info)
    local copy = set.copies[i]
    local tags = {}
    if i == 1 then table.insert(tags, { id = "suggested" }) end
    local function unique(value_of, want)
        local n = 0
        for _, c in ipairs(set.copies) do
            if value_of(c) == want then n = n + 1 end
        end
        return n == 1
    end
    local most = 0
    for _, c in ipairs(set.copies) do most = math.max(most, info(c).progress or 0) end
    local mine = info(copy).progress or 0
    if most > 0 and mine == most and unique(function(c) return info(c).progress or 0 end, most) then
        table.insert(tags, { id = "most_read", percent = math.floor(mine * 100) })
    end
    local best, rank = OTHER_FORMAT + 1, Duplicates.formatRank(copy.name)
    for _, c in ipairs(set.copies) do best = math.min(best, Duplicates.formatRank(c.name)) end
    if rank > best then
        table.insert(tags, { id = Duplicates.extension(copy.name) == "pdf" and "fixed_layout" or "older_format" })
    end
    local newest, smallest = 0, math.huge
    for _, c in ipairs(set.copies) do
        newest = math.max(newest, c.modified or 0)
        smallest = math.min(smallest, c.size)
    end
    if unique(function(c) return c.modified or 0 end, newest) and (copy.modified or 0) == newest then
        table.insert(tags, { id = "newest" })
    end
    if unique(function(c) return c.size end, smallest) and copy.size == smallest then
        table.insert(tags, { id = "smallest" })
    end
    return tags
end

-- Whether `set` is one you chose to keep as it is. `dismissed` maps a set's id to how many copies it had when
-- you chose (or `true`, from an older version, for any number): a new copy of the book brings the set back.
function Duplicates.isIgnored(dismissed, set)
    local n = dismissed[set.id]
    if n == true then return true end
    return type(n) == "number" and #set.copies <= n
end

-- What clearing every copy but `keep` frees.
function Duplicates.savings(set, keep)
    local sum = 0
    for i, f in ipairs(set.copies) do
        if i ~= keep then sum = sum + f.size end
    end
    return sum
end

-- The most that could be freed across all sets, keeping the largest copy of each: the figure to show before
-- anything is chosen. (Keeping the largest is the least that clearing frees.)
function Duplicates.reclaimable(sets)
    local total = 0
    for _, set in ipairs(sets) do
        local largest, sum = 0, 0
        for _, f in ipairs(set.copies) do
            largest = math.max(largest, f.size)
            sum = sum + f.size
        end
        total = total + (sum - largest)
    end
    return total
end

-- Compares two files byte for byte, in chunks, stopping at the first difference.
function Duplicates.sameBytes(path_a, path_b)
    local a, b = io.open(path_a, "rb"), io.open(path_b, "rb")
    if not a or not b then
        if a then a:close() end
        if b then b:close() end
        return false
    end
    local same = true
    while true do
        local x, y = a:read(65536), b:read(65536)
        if x ~= y then same = false break end
        if not x then break end
    end
    a:close()
    b:close()
    return same
end

return Duplicates
