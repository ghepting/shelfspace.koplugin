-- What a multi-select amounts to, kept free of KOReader so it can be tested on its own.
local Selection = {}

local function parentOf(path)
    return path:match("^(.*)/[^/]+$")
end

-- The entries to act on: no duplicates, and nothing that sits inside a selected folder, which
-- deleting the folder already covers. Returned in name order.
function Selection.collapse(entries)
    local list, seen = {}, {}
    for _, e in ipairs(entries) do
        if not seen[e.path] then
            seen[e.path] = true
            table.insert(list, e)
        end
    end
    -- Shorter paths first, so a folder is always looked at before anything inside it.
    table.sort(list, function(a, b)
        if #a.path ~= #b.path then return #a.path < #b.path end
        return a.path < b.path
    end)
    local kept, folders = {}, {}
    for _, e in ipairs(list) do
        local inside, parent = false, parentOf(e.path)
        while parent and parent ~= "" do
            if folders[parent] then inside = true break end
            parent = parentOf(parent)
        end
        if not inside then
            table.insert(kept, e)
            if e.is_dir then folders[e.path] = true end
        end
    end
    table.sort(kept, function(a, b)
        local la, lb = a.name:lower(), b.name:lower()
        if la ~= lb then return la < lb end
        return a.path < b.path
    end)
    return kept
end

function Selection.size(entries)
    local total = 0
    for _, e in ipairs(entries) do total = total + e.size end
    return total
end

return Selection
