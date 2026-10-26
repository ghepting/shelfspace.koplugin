local Stats = require("shelfspace/stats")

local Search = {}

-- Every way Browse can be ordered; `reverse` flips the primary key only.
Search.OPTIONS = {
    { mode = "size", reverse = false, label = "Largest first", short = "Largest" },
    { mode = "size", reverse = true, label = "Smallest first", short = "Smallest" },
    { mode = "name", reverse = false, label = "Name, A to Z", short = "A–Z" },
    { mode = "name", reverse = true, label = "Name, Z to A", short = "Z–A" },
    { mode = "new", reverse = false, label = "Newest first", short = "Newest" },
    { mode = "new", reverse = true, label = "Oldest first", short = "Oldest" },
    -- By when you last opened the book. Anything without a time (folders, books never opened) comes
    -- last in both orders.
    { mode = "opened", reverse = false, label = "Opened most recently", short = "Last opened" },
    { mode = "opened", reverse = true, label = "Opened longest ago", short = "Longest ago" },
}

-- Orders `entries` in place by an option from Search.OPTIONS. Ties fall back to name, then path.
-- `opened(entry)` gives the time a book was last opened, or nil; only the "opened" orders use it.
function Search.sort(entries, option, opened)
    local mode, flip = option.mode, option.reverse and -1 or 1
    local function name(e) return e.name:lower() end
    table.sort(entries, function(a, b)
        local ka, kb
        if mode == "name" then
            -- Strings can't be negated, so A to Z flips by swapping the sides.
            if name(a) ~= name(b) then
                if flip == 1 then return name(a) < name(b) else return name(a) > name(b) end
            end
            return a.path < b.path
        elseif mode == "opened" then
            local ta, tb = opened and opened(a), opened and opened(b)
            if ta and tb and ta ~= tb then
                if flip == 1 then return ta > tb else return ta < tb end
            elseif (ta == nil) ~= (tb == nil) then
                return ta ~= nil
            end
            if name(a) ~= name(b) then return name(a) < name(b) end
            return a.path < b.path
        elseif mode == "new" then
            ka, kb = -(a.modified or 0), -(b.modified or 0)
        else
            ka, kb = -a.size, -b.size
        end
        if ka ~= kb then return flip * ka < flip * kb end
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
