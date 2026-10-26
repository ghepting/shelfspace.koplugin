-- Facts about a folder, read from the scan.
local Stats = {}

-- The type a file is counted under: its lower-cased extension, or "other" when it has none.
function Stats.extension(name)
    return (name:match("%.([^.]+)$") or "other"):lower()
end

-- How many files are under `path`, and the bytes per file extension.
function Stats.summarize(tree, path)
    local out = { files = 0, exts = {} }
    local function walk(dir)
        local node = tree[dir]
        if not node then return end
        for i, e in ipairs(node.entries) do
            if e.is_dir then
                if not e.hidden then walk(e.path) end
            else
                out.files = out.files + 1
                local ext = Stats.extension(e.name)
                out.exts[ext] = (out.exts[ext] or 0) + e.size
            end
        end
    end
    walk(path)
    return out
end

-- Bytes per file type for the files under `path` that `include(entry)` accepts, not looking inside dot-folders
-- (.kobo, .adds and the like: the device's own, never part of a library). For the type chips.
function Stats.typeBytes(tree, path, include)
    local exts = {}
    local function walk(dir)
        local node = tree[dir]
        if not node then return end
        for _, e in ipairs(node.entries) do
            if e.is_dir then
                if not e.hidden and e.name:sub(1, 1) ~= "." then walk(e.path) end
            elseif include(e) then
                local ext = Stats.extension(e.name)
                exts[ext] = (exts[ext] or 0) + e.size
            end
        end
    end
    walk(path)
    return exts
end

-- The `n` biggest extensions as { { ext = "cbz", percent = 61 }, ... }.
function Stats.topExtensions(exts, n)
    local total, list = 0, {}
    for ext, bytes in pairs(exts) do
        total = total + bytes
        table.insert(list, { ext = ext, bytes = bytes })
    end
    table.sort(list, function(a, b) return a.bytes > b.bytes end)
    local top = {}
    for i = 1, math.min(n, #list) do
        top[i] = { ext = list[i].ext, percent = total > 0 and math.floor(100 * list[i].bytes / total + 0.5) or 0 }
    end
    return top
end

-- The tags for KOReader's folder: how much of it each part is (see shareChips), or, when none of the parts
-- can be cleared, one tag saying so instead of a share of things that all stay. `clearable` counts the
-- parts that can be cleared.
function Stats.dataChips(parts, total, n, clearable, all_clear)
    if clearable == 0 then return { all_clear } end
    return Stats.shareChips(parts, total, n)
end

-- The `n` biggest of `parts` ({ { name, bytes }, ... }) as chip texts like "CACHE 73%", each as a
-- share of `total`; a share too small to round to 1% reads "<1%". Empty parts are left out.
function Stats.shareChips(parts, total, n)
    local list = {}
    for _, p in ipairs(parts) do
        if p.bytes > 0 then table.insert(list, p) end
    end
    table.sort(list, function(a, b)
        if a.bytes ~= b.bytes then return a.bytes > b.bytes end
        return a.name < b.name
    end)
    local chips = {}
    for i = 1, math.min(n, #list) do
        local share = total > 0 and list[i].bytes / total or 0
        local text = share > 0 and share < 0.005 and "<1%" or math.floor(100 * share + 0.5) .. "%"
        chips[i] = list[i].name .. " " .. text
    end
    return chips
end

return Stats
