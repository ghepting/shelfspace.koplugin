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

return Stats
