-- Keeps the last scan on disk so the next one only re-reads folders that changed.
local ScanCache = {}

local function write(v, out)
    local t = type(v)
    if t == "table" then
        out[#out + 1] = "{"
        for k, x in pairs(v) do
            out[#out + 1] = "["
            write(k, out)
            out[#out + 1] = "]="
            write(x, out)
            out[#out + 1] = ","
        end
        out[#out + 1] = "}"
    elseif t == "string" then
        out[#out + 1] = string.format("%q", v)
    else
        out[#out + 1] = tostring(v)
    end
end

-- Writes `tree` for library `root`; the KOReader data folder is left out because its files change
-- in place, which a folder's modification time doesn't show.
function ScanCache.save(path, root, tree, skip)
    local keep = {}
    for dir, node in pairs(tree) do
        if dir ~= skip and dir:sub(1, #skip + 1) ~= skip .. "/" then keep[dir] = node end
    end
    local out = { "return " }
    write({ root = root, tree = keep }, out)
    local tmp = path .. ".tmp"
    local f = io.open(tmp, "w")
    if not f then return false end
    f:write(table.concat(out))
    f:close()
    return os.rename(tmp, path) and true or false
end

-- The saved tree for `root`, or nil when there is none, it is unreadable, or it is for another library.
function ScanCache.load(path, root)
    local chunk = loadfile(path)
    if not chunk then return nil end
    local ok, data = pcall(chunk)
    if not ok or type(data) ~= "table" or data.root ~= root or type(data.tree) ~= "table" then return nil end
    return data.tree
end

return ScanCache
