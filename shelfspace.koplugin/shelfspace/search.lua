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
}

-- Orders `entries` in place by an option from Search.OPTIONS. Ties fall back to name, then path.
function Search.sort(entries, option)
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
function Search.find(tree, dir, query, ext)
    local words = {}
    for word in (query or ""):lower():gmatch("%S+") do table.insert(words, word) end
    local found, where = {}, {}
    if #words == 0 and not ext then return found, where end

    local function walk(path, rel)
        local node = tree[path]
        if not node then return end
        for _, e in ipairs(node.entries) do
            if not e.hidden then
                local lower, hit = e.name:lower(), true
                for _, word in ipairs(words) do
                    if not lower:find(word, 1, true) then hit = false break end
                end
                if hit and ext and (e.is_dir or Stats.extension(e.name) ~= ext) then hit = false end
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
