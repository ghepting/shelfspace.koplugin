local Search = {}

Search.MODES = { "size", "name", "new" }

-- Orders `entries` in place: "size" largest first, "name" A to Z, "new" most recently changed first.
function Search.sort(entries, mode)
    local function name(e) return e.name:lower() end
    table.sort(entries, function(a, b)
        if mode == "name" then
            if name(a) ~= name(b) then return name(a) < name(b) end
        elseif mode == "new" then
            local ma, mb = a.modified or 0, b.modified or 0
            if ma ~= mb then return ma > mb end
        elseif a.size ~= b.size then
            return a.size > b.size
        end
        if name(a) ~= name(b) then return name(a) < name(b) end
        return a.path < b.path
    end)
end

-- Every visible file and folder under `dir` whose name holds all the words in `query`
-- (any case). Returns the entries and, for each, the folder it sits in relative to `dir`.
function Search.find(tree, dir, query)
    local words = {}
    for word in query:lower():gmatch("%S+") do table.insert(words, word) end
    local found, where = {}, {}
    if #words == 0 then return found, where end

    local function walk(path, rel)
        local node = tree[path]
        if not node then return end
        for _, e in ipairs(node.entries) do
            if not e.hidden then
                local lower, hit = e.name:lower(), true
                for _, word in ipairs(words) do
                    if not lower:find(word, 1, true) then hit = false break end
                end
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
