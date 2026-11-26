-- Keeps the last scan on disk so the next one only re-reads folders that changed.
--
-- One line per folder and one per thing in it, tab-separated: "D", its size, its modification time and its path; then for each entry
-- its kind (f a file, d a folder, s a book's sidecar folder), size, modification time and name. Paths are not written for
-- entries, since they are the folder's path and the name. Plain lines, not a Lua table, because a big library would make a
-- Lua file too large for LuaJIT to load (it has a limit on the strings in one chunk), and lines are quicker to read and write.
local ScanCache = {}

local HEADER = "shelfspace-scan 2"

local function within(dir, skip)
    return dir == skip or dir:sub(1, #skip + 1) == skip .. "/"
end

local function num(v) return v and string.format("%.0f", v) or "" end

-- Writes `tree` for library `root`; the KOReader data folder (`skip`) is left out because its files change in place, which a
-- folder's modification time doesn't show. A folder with a name holding a tab or a line break is left out too (it is read
-- again next time), since the lines could not hold it.
function ScanCache.save(path, root, tree, skip)
    local out = { HEADER .. "\t" .. root }
    for dir, node in pairs(tree) do
        if not (skip and within(dir, skip)) and not dir:find("[\t\n]") then
            local lines, ok = { "D\t" .. num(node.size) .. "\t" .. num(node.modified) .. "\t" .. dir }, true
            for _, e in ipairs(node.entries) do
                if e.name:find("[\t\n]") then ok = false break end
                local kind = e.is_dir and (e.hidden and "s" or "d") or "f"
                lines[#lines + 1] = kind .. "\t" .. num(e.size) .. "\t" .. num(e.modified) .. "\t" .. e.name
            end
            if ok then out[#out + 1] = table.concat(lines, "\n") end
        end
    end
    local tmp = path .. ".tmp"
    local f = io.open(tmp, "w")
    if not f then return false end
    f:write(table.concat(out, "\n"), "\n")
    f:close()
    return os.rename(tmp, path) and true or false
end

-- The saved tree for `root`, or nil when there is none, it is unreadable, or it is for another library (or from an older
-- ShelfSpace, which wrote it another way: the next scan reads everything once and saves it again).
function ScanCache.load(path, root)
    local f = io.open(path, "r")
    if not f then return nil end
    local first = f:read("*l")
    if first ~= HEADER .. "\t" .. root then
        f:close()
        return nil
    end
    local tree, entries, prefix = {}, nil, nil
    for line in f:lines() do
        local kind, size, modified, name = line:match("^(%a)\t([^\t]*)\t([^\t]*)\t(.*)$")
        if kind == "D" then
            entries = {}
            tree[name] = { size = tonumber(size) or 0, entries = entries, modified = tonumber(modified) }
            prefix = name:sub(-1) == "/" and name or name .. "/"
        elseif kind and entries then
            local is_dir = kind ~= "f"
            entries[#entries + 1] = {
                name = name, path = prefix .. name, size = tonumber(size) or 0, modified = tonumber(modified),
                is_dir = is_dir or nil, hidden = is_dir and kind == "s" or nil,
            }
        else
            f:close()
            return nil -- a line that is not ours: trust none of it
        end
    end
    f:close()
    return tree
end

return ScanCache
