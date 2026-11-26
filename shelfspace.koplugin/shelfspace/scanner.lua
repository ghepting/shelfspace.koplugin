local lfs = require("libs/libkoreader-lfs")
local UIManager = require("ui/uimanager")

local Scanner = {}

local BATCH = 300 -- entries listed per UI tick, so the screen stays responsive

-- Fills in every size under `path` from its entries; returns the total.
function Scanner.total(tree, path)
    local node = tree[path]
    local sum = 0
    for _, e in ipairs(node.entries) do
        if e.is_dir then e.size = Scanner.total(tree, e.path) end
        sum = sum + e.size
    end
    node.size = sum
    return sum
end

-- Folder and file counts across the whole tree, for the timing log.
function Scanner.count(tree)
    local dirs, files = 0, 0
    for _, node in pairs(tree) do
        dirs = dirs + 1
        for _, e in ipairs(node.entries) do
            if not e.is_dir then files = files + 1 end
        end
    end
    return dirs, files
end

-- Takes `entry` out of `dir`'s listing (and, for a folder, everything under it out of the tree); returns its size.
local function drop(tree, dir, entry)
    local entries = tree[dir].entries
    for i, e in ipairs(entries) do
        if e == entry then table.remove(entries, i) break end
    end
    if entry.is_dir then
        local function forget(path)
            local node = tree[path]
            if not node then return end
            tree[path] = nil
            for _, e in ipairs(node.entries) do
                if e.is_dir then forget(e.path) end
            end
        end
        forget(entry.path)
    end
    return entry.size or 0
end

-- Drops `entry` (a file or folder) from the tree, along with a deleted book's sidecar folder, and takes its size off `dir`
-- and every folder above it up to `root`. Only those folders change, so nothing else is added up again: deleting a few
-- thousand books at once costs a few thousand short walks up the tree, not a few thousand totals of the whole library.
function Scanner.remove(tree, root, dir, entry)
    if not tree[dir] then return end
    local freed = drop(tree, dir, entry)
    if not entry.is_dir then
        local sidecar = (entry.name:match("(.*)%.") or entry.name) .. ".sdr"
        for _, e in ipairs(tree[dir].entries) do
            if e.is_dir and e.name == sidecar then
                freed = freed + drop(tree, dir, e)
                break
            end
        end
    end
    local path = dir
    while true do
        local node = tree[path]
        node.size = node.size - freed
        if path == root then return end
        local up = path:match("^(.*)/[^/]+$")
        local parent = up and tree[up]
        if not parent then return end
        for _, e in ipairs(parent.entries) do -- the folder's own row in the folder above shows the same total
            if e.path == path then e.size = node.size break end
        end
        path = up
    end
end

-- Walks `root` in chunks and calls on_done(tree, read), where `read` is how many folders were read from the disk (the rest
-- kept their listing from `previous`), and tree[dir] is
-- { size = bytes, entries = { {name, path, is_dir, size}, ... } }.
-- Symlinks are skipped so loops and other filesystems are never followed.
-- `previous` (an earlier tree) lets a folder whose modification time has not changed keep its
-- listing without being read again; its sub-folders are still checked.
function Scanner.scan(root, on_done, previous)
    local tree = {}
    local stack = { root }
    local read = 0

    local function step()
        local n = 0
        while #stack > 0 and n < BATCH do
            local dir = table.remove(stack)
            local modified = lfs.attributes(dir, "modification")
            local old = previous and previous[dir]
            local node = { size = 0, entries = {}, modified = modified }
            tree[dir] = node
            local prefix = dir:sub(-1) == "/" and dir or dir .. "/"
            local ok, iter, dir_obj
            if old and modified and old.modified == modified then
                node.entries = old.entries
                n = n + 1
                for _, e in ipairs(node.entries) do
                    if e.is_dir then table.insert(stack, e.path) end
                end
            else
                ok, iter, dir_obj = pcall(lfs.dir, dir)
                read = read + 1
            end
            if ok then
                for name in iter, dir_obj do
                    if name ~= "." and name ~= ".." then
                        n = n + 1
                        local path = prefix .. name
                        local attr = lfs.symlinkattributes(path)
                        if attr and attr.mode == "directory" then
                            -- Sidecar folders count toward sizes but aren't listed.
                            table.insert(node.entries, {
                                name = name, path = path, is_dir = true, size = 0,
                                modified = attr.modification,
                                hidden = name:sub(-4) == ".sdr",
                            })
                            table.insert(stack, path)
                        elseif attr and attr.mode == "file" then
                            table.insert(node.entries, { name = name, path = path, size = attr.size, modified = attr.modification })
                        end
                    end
                end
            end
        end
        if #stack > 0 then
            UIManager:scheduleIn(0, step)
            return
        end
        Scanner.total(tree, root)
        on_done(tree, read)
    end

    UIManager:scheduleIn(0, step)
end

return Scanner
