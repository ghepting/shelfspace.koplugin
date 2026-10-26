local _ = require("shelfspace/i18n")
local ffiUtil = require("ffi/util")
local lfs = require("libs/libkoreader-lfs")

-- What KOReader can regenerate or no longer needs. Sizes come from the scan,
-- so nothing here walks the disk until something is actually cleared.
local Cleanup = {}

local function sizeOf(tree, path)
    return tree[path] and tree[path].size or 0
end

-- Empties a folder but keeps the folder itself.
local function clearContents(dir)
    if lfs.attributes(dir, "mode") ~= "directory" then return end
    for name in lfs.dir(dir) do
        if name ~= "." and name ~= ".." then
            local path = dir .. "/" .. name
            if lfs.attributes(path, "mode") == "directory" then
                ffiUtil.purgeDir(path)
            else
                os.remove(path)
            end
        end
    end
end

-- Sidecar folders whose book is gone. Only the "next to the book" location is
-- covered; the other two metadata locations can't be matched back to a book.
function Cleanup.orphans(tree, koreader_dir, root)
    local found = {}
    local data_prefix = koreader_dir .. "/"
    for dir, node in pairs(tree) do
        -- Skip KOReader's own folder and hidden folders (.kobo and the like). Only the part
        -- below the library counts: the library itself may sit under a dot-folder.
        local rel = dir:sub(#root + 1)
        if dir ~= koreader_dir and dir:sub(1, #data_prefix) ~= data_prefix and not rel:find("/%.") then
            local stems = {}
            for _, e in ipairs(node.entries) do
                if not e.is_dir then stems[e.name:match("(.*)%.") or e.name] = true end
            end
            for _, e in ipairs(node.entries) do
                if e.is_dir and e.hidden and not stems[e.name:sub(1, -5)] then
                    table.insert(found, e)
                end
            end
        end
    end
    return found
end

-- Each target: { title, note, size, clear = function, blocked = reason or nil, safe = true if
-- it is always harmless to clear }.
-- `book_open` is true while a document is on screen.
function Cleanup.targets(tree, koreader_dir, book_open, root)
    local data = koreader_dir
    local targets = {}

    local cache_size = sizeOf(tree, data .. "/cache/cr3cache") + sizeOf(tree, data .. "/cache/tmpcr3cache")
    table.insert(targets, {
        title = _("Rendering cache"),
        short = _("CACHE"),
        note = _("Rebuilt as needed"),
        safe = true,
        size = cache_size,
        blocked = book_open and _("Close the book first; its cache is in use.") or nil,
        clear = function()
            clearContents(data .. "/cache/cr3cache")
            clearContents(data .. "/cache/tmpcr3cache")
        end,
    })

    table.insert(targets, {
        title = _("Update downloads"),
        short = _("UPDATES"),
        note = _("Old KOReader packages"),
        safe = true,
        size = sizeOf(tree, data .. "/ota"),
        clear = function() clearContents(data .. "/ota") end,
    })

    local logs, log_size = {}, 0
    for _, e in ipairs(tree[data] and tree[data].entries or {}) do
        if not e.is_dir and e.name:match("^crash") then
            table.insert(logs, e.path)
            log_size = log_size + e.size
        end
    end
    table.insert(targets, {
        title = _("Crash logs"),
        short = _("LOGS"),
        note = _("crash.log and friends"),
        safe = true,
        size = log_size,
        clear = function()
            -- Truncate: the running process may hold the file open, so deleting wouldn't free it.
            for _, path in ipairs(logs) do
                local f = io.open(path, "w")
                if f then f:close() end
            end
        end,
    })

    table.insert(targets, {
        title = _("Screenshots"),
        short = _("SCREENSHOTS"),
        note = _("Saved by KOReader"),
        size = sizeOf(tree, data .. "/screenshots"),
        clear = function() clearContents(data .. "/screenshots") end,
    })

    local orphans, orphan_size = Cleanup.orphans(tree, koreader_dir, root), 0
    for _, e in ipairs(orphans) do orphan_size = orphan_size + e.size end
    table.insert(targets, {
        title = _("Orphaned reading progress"),
        short = _("PROGRESS"),
        note = _("Notes for books no longer here"),
        size = orphan_size,
        count = #orphans,
        clear = function()
            for _, e in ipairs(orphans) do ffiUtil.purgeDir(e.path) end
        end,
    })

    return targets
end

return Cleanup
