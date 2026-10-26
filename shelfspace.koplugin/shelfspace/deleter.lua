local BookList = require("ui/widget/booklist")
local _ = require("gettext")
local DocSettings = require("docsettings")
local DocumentRegistry = require("document/documentregistry")
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

local function within(path, dir)
    return path == dir or path:sub(1, #dir + 1) == dir .. "/"
end

-- Files that travel with a book and are harmless to remove along with it.
local COMPANIONS = { jpg = true, jpeg = true, png = true, gif = true, webp = true, opf = true }

local function isManaged(name, path)
    local ext = (name:match("%.([^.]+)$") or ""):lower()
    return COMPANIONS[ext] or DocumentRegistry:hasProvider(path)
end

-- A single picture is something KOReader can open, but it is not a book: it has no reading progress, and
-- it is not what a "never read" or "finished" list is about.
local PICTURES = { png = true, jpg = true, jpeg = true, gif = true, bmp = true, webp = true, svg = true, tif = true, tiff = true }

-- A book KOReader can open: not a companion file such as a cover image, and not a lone picture. Used for
-- what Browse shows about books (type tags, % Read, the Show filters), not for what may be deleted.
function Deleter.isBook(entry)
    local ext = entry.name:match("%.([^.]+)$")
    if ext and PICTURES[ext:lower()] then return false end
    return DocumentRegistry:hasProvider(entry.path) and true or false
end

-- True when every file under `entry` is a book KOReader can open or a companion
-- of one. Sidecar folders are KOReader's own and don't count against it.
local function holdsOnlyBooks(tree, entry, cache)
    if cache[entry.path] ~= nil then return cache[entry.path] end
    local ok = true
    local function walk(e)
        if not ok then return end
        if not e.is_dir then
            if not isManaged(e.name, e.path) then ok = false end
        elseif not e.hidden then
            local node = tree[e.path]
            for i, child in ipairs(node and node.entries or {}) do walk(child) end
        end
    end
    walk(entry)
    cache[entry.path] = ok
    return ok
end

-- Why `entry` can't be deleted from here (a short line for the row), or nil when it can.
-- ctx = { tree, root, koreader_dir, open_file, cache }. Anything KOReader doesn't manage is
-- off limits, which keeps system folders safe on every device without listing them:
-- only books KOReader can open, and folders holding nothing else, can go.
function Deleter.blockedReason(entry, ctx)
    local path = entry.path
    if ctx.open_file and within(ctx.open_file, path) then
        return _("You are reading this book")
    elseif within(ctx.koreader_dir, path) then
        return _("KOReader is installed here")
    elseif within(path, ctx.koreader_dir) then
        return _("KOReader's data: see the KOReader tab")
    end
    local top = path:sub(#ctx.root + 2):match("^[^/]+")
    if top and top:sub(1, 1) == "." then
        return _("System folder")
    end
    if entry.is_dir then
        if not holdsOnlyBooks(ctx.tree, entry, ctx.cache) then
            return _("Has files KOReader doesn't manage")
        end
    elseif not isManaged(entry.name, path) then
        return _("Not a book KOReader manages")
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
