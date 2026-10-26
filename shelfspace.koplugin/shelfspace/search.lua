local Stats = require("shelfspace/stats")

local Search = {}

-- The ways Browse can be ordered. A category starts in its usual direction: biggest, newest and most
-- recently opened first, names A to Z. `descending` is that direction; the arrow button flips it.
Search.SORTS = {
    { id = "size", label = "Size", short = "Size", descending = true },
    { id = "name", label = "Name", short = "Name", descending = false },
    { id = "new", label = "Date modified", short = "Date", descending = true },
    { id = "opened", label = "Last opened", short = "Last opened", descending = true },
}

-- The category with this id (Size when it is unknown).
function Search.sortBy(id)
    for _, option in ipairs(Search.SORTS) do
        if option.id == id then return option end
    end
    return Search.SORTS[1]
end

-- Orders `entries` in place by category `mode` (an id from Search.SORTS). `descending` means biggest,
-- newest or most recently opened first, and Z to A for names. Ties fall back to name, then path.
-- `opened(entry)` gives the time a book was last opened, or nil; only "opened" uses it, and anything
-- without a time (folders, books never opened) comes last in either direction.
function Search.sort(entries, mode, descending, opened)
    local function name(e) return e.name:lower() end
    local function key(e)
        if mode == "size" then return e.size end
        if mode == "new" then return e.modified or 0 end
        if mode == "opened" then return opened and opened(e) or nil end
    end
    table.sort(entries, function(a, b)
        if mode == "name" then
            if name(a) ~= name(b) then
                if descending then return name(a) > name(b) else return name(a) < name(b) end
            end
            return a.path < b.path
        end
        local ka, kb = key(a), key(b)
        if ka and kb and ka ~= kb then
            if descending then return ka > kb else return ka < kb end
        elseif (ka == nil) ~= (kb == nil) then
            return ka ~= nil
        end
        if name(a) ~= name(b) then return name(a) < name(b) end
        return a.path < b.path
    end)
end

-- Every visible file and folder under `dir` whose name holds all the words in `query`
-- (any case), and, when `ext` is given, only files of that type (see Stats.extension).
-- Needs a query or an `ext`. Returns the entries and, for each, the folder it sits in
-- relative to `dir`.
-- Which books Browse shows, by reading status. `id` is what KOReader's BookList.getBookStatus returns.
Search.STATUSES = {
    { id = nil, label = "All files", short = "All" },
    { id = "complete", label = "Finished books", short = "Finished", noun = "finished" },
    { id = "new", label = "Never read", short = "Never read", noun = "unread" },
}

-- The status option with this id (nil is "All files").
function Search.status(id)
    for _, option in ipairs(Search.STATUSES) do
        if option.id == id then return option end
    end
    return Search.STATUSES[1]
end

function Search.find(tree, dir, query, ext, include)
    local words = {}
    for word in (query or ""):lower():gmatch("%S+") do table.insert(words, word) end
    local found, where = {}, {}
    if #words == 0 and not ext and not include then return found, where end

    local function walk(path, rel)
        local node = tree[path]
        if not node then return end
        for _, e in ipairs(node.entries) do
            -- Dot-entries are the device's own (.kobo, .adds, AppleDouble files) and sidecar folders are
            -- KOReader's: neither is part of a search through the library.
            if not e.hidden and e.name:sub(1, 1) ~= "." then
                local lower, hit = e.name:lower(), true
                for _, word in ipairs(words) do
                    if not lower:find(word, 1, true) then hit = false break end
                end
                if hit and ext and (e.is_dir or Stats.extension(e.name) ~= ext) then hit = false end
                -- `include` (a test on one file) leaves out folders: it asks about a book, not a place.
                if hit and include and (e.is_dir or not include(e)) then hit = false end
                if hit then
                    table.insert(found, e)
                    where[e] = rel
                end
                if e.is_dir then walk(e.path, rel == "" and e.name or (rel .. "/" .. e.name)) end
            end
        end
    end
    walk(dir, "")
    return found, where
end

return Search
