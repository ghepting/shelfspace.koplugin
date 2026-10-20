local lfs = require("libs/libkoreader-lfs")
local UIManager = require("ui/uimanager")

local Scanner = {}

local BATCH = 300 -- entries listed per UI tick, so the screen stays responsive

-- Walks `root` in chunks and calls on_done(tree), where tree[dir] is
-- { size = bytes, entries = { {name, path, is_dir, size}, ... } }.
-- Symlinks are skipped so loops and other filesystems are never followed.
function Scanner.scan(root, on_done)
    local tree = {}
    local stack = { root }

    local function step()
        local n = 0
        while #stack > 0 and n < BATCH do
            local dir = table.remove(stack)
            local node = { size = 0, entries = {} }
            tree[dir] = node
            local prefix = dir:sub(-1) == "/" and dir or dir .. "/"
            local ok, iter, dir_obj = pcall(lfs.dir, dir)
            if ok then
                for name in iter, dir_obj do
                    if name ~= "." and name ~= ".." then
                        n = n + 1
                        local path = prefix .. name
                        local attr = lfs.symlinkattributes(path)
                        if attr and attr.mode == "directory" then
                            table.insert(node.entries, { name = name, path = path, is_dir = true, size = 0 })
                            table.insert(stack, path)
                        elseif attr and attr.mode == "file" then
                            table.insert(node.entries, { name = name, path = path, size = attr.size })
                        end
                    end
                end
            end
        end
        if #stack > 0 then
            UIManager:scheduleIn(0, step)
            return
        end
        local function total(path)
            local node = tree[path]
            local sum = 0
            for _, e in ipairs(node.entries) do
                if e.is_dir then e.size = total(e.path) end
                sum = sum + e.size
            end
            node.size = sum
            return sum
        end
        total(root)
        on_done(tree)
    end

    UIManager:scheduleIn(0, step)
end

return Scanner
