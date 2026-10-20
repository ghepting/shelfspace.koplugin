local BookList = require("ui/widget/booklist")
local _ = require("gettext")
local DocSettings = require("docsettings")
local ReadCollection = require("readcollection")
local ReadHistory = require("readhistory")
local ffiUtil = require("ffi/util")

-- Deletes a file or folder the way KOReader's own file manager does, so reading
-- progress, history and collections go with it.
local Deleter = {}

-- Walks a tree entry, calling visit(file_path) for every file under it.
local function eachFile(tree, entry, visit)
    if not entry.is_dir then
        visit(entry.path)
        return
    end
    local node = tree[entry.path]
    for _, e in ipairs(node and node.entries or {}) do
        eachFile(tree, e, visit)
    end
end

-- How many files under `entry` have saved reading progress or metadata.
function Deleter.countSidecars(tree, entry)
    local n = 0
    eachFile(tree, entry, function(path)
        if DocSettings:hasSidecarFile(path) then n = n + 1 end
    end)
    return n
end

function Deleter.countFiles(tree, entry)
    local n = 0
    eachFile(tree, entry, function() n = n + 1 end)
    return n
end

-- True when `open_file` (the book on screen, if any) is `entry` or inside it.
function Deleter.holdsOpenBook(entry, open_file)
    if not open_file then return false end
    return open_file == entry.path or open_file:sub(1, #entry.path + 1) == entry.path .. "/"
end

local function within(path, dir)
    return path == dir or path:sub(1, #dir + 1) == dir .. "/"
end

-- Why `path` must not be deleted from here, or nil when it may be. Covers KOReader
-- itself, its data (the KOReader tab clears the safe parts), and hidden top-level
-- folders such as .kobo (the Kobo's own database) and .adds (where KOReader is installed).
function Deleter.protectedReason(path, root, koreader_dir)
    if within(koreader_dir, path) then
        return _("KOReader is installed here.")
    elseif within(path, koreader_dir) then
        return _("This is KOReader's own data. Use the KOReader tab to clear what is safe.")
    end
    local top = path:sub(#root + 2):match("^[^/]+")
    if top and top:sub(1, 1) == "." then
        return _("This is a system folder, so it can't be deleted here.")
    end
end

function Deleter.delete(entry)
    local path = entry.path
    if not entry.is_dir then
        if not os.remove(path) then return false end
        BookList.resetBookInfoCache(path)
        DocSettings.updateLocation(path) -- removes the sidecar
        ReadHistory:fileDeleted(path)
        ReadCollection:removeItem(path)
        return true
    end
    if not ffiUtil.purgeDir(path) then return false end
    ReadHistory:folderDeleted(path) -- also removes the sidecars
    ReadCollection:removeItemsByPath(path)
    local fm = require("apps/filemanager/filemanager").instance
    if fm then fm.folder_shortcuts:updateItemsByPath(nil, path) end
    return true
end

return Deleter
