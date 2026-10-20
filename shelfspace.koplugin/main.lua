local _ = require("gettext")
local DataStorage = require("datastorage")
local Device = require("device")
local InfoMessage = require("ui/widget/infomessage")
local Menu = require("ui/widget/menu")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local ffiUtil = require("ffi/util")
local util = require("util")
local T = ffiUtil.template

local Overview = require("shelfspace/overview")
local Scanner = require("shelfspace/scanner")

local ShelfSpace = WidgetContainer:extend {
    name = "shelfspace",
    is_doc_only = false,
}

function ShelfSpace:init()
    self.ui.menu:registerToMainMenu(self)
end

function ShelfSpace:addToMainMenu(menu_items)
    menu_items.shelfspace = {
        sorting_hint = "tools",
        text = _("Shelf Space"),
        callback = function() self:showOverview() end,
    }
end

local function libraryPath()
    local path = G_reader_settings:readSetting("home_dir") or Device.home_dir or DataStorage:getDataDir()
    return ffiUtil.realpath(path) or path
end

-- Scans the library (and KOReader's data dir when it lives elsewhere), keeping
-- the result in self.tree for the browser. on_done(tree, root, koreader_dir).
function ShelfSpace:scan(on_done)
    local root = libraryPath()
    local koreader_dir = DataStorage:getDataDir()
    koreader_dir = ffiUtil.realpath(koreader_dir) or koreader_dir
    Scanner.scan(root, function(tree)
        if tree[koreader_dir] then
            self.tree = tree
            on_done(tree, root, koreader_dir)
            return
        end
        Scanner.scan(koreader_dir, function(extra)
            for dir, node in pairs(extra) do tree[dir] = node end
            self.tree = tree
            on_done(tree, root, koreader_dir)
        end)
    end)
end

-- Books = visible top-level entries; "other" is whatever the partition holds beyond that.
local function breakdown(tree, root, koreader_dir, usage)
    local books = 0
    for _, e in ipairs(tree[root].entries) do
        if e.name:sub(1, 1) ~= "." and e.path ~= koreader_dir then
            books = books + e.size
        end
    end
    local koreader = tree[koreader_dir].size
    return { books = books, koreader = koreader, other = math.max(usage.used - books - koreader, 0) }
end

function ShelfSpace:showOverview()
    local usage = util.diskUsage(libraryPath())
    if not usage.total or usage.total == 0 then
        UIManager:show(InfoMessage:new { text = _("Could not read storage usage.") })
        return
    end
    local overview = Overview:new {
        usage = usage,
        on_browse = function() self:browse() end,
    }
    UIManager:show(overview)
    self:scan(function(tree, root, koreader_dir)
        overview:setBreakdown(breakdown(tree, root, koreader_dir, usage))
    end)
end

-- Shows folders and files largest-first; tap a folder to drill in.
function ShelfSpace:browse()
    local root = libraryPath()
    local tree = self.tree
    if not tree then return end
    local menu
    local function show(dir)
        local items = {}
        if dir ~= root then
            local parent = dir:match("^(.*)/[^/]+$")
            table.insert(items, {
                text = "⬆ " .. _("Up"),
                callback = function() show(tree[parent] and parent or root) end,
            })
        end
        local entries = {}
        for i, e in ipairs(tree[dir].entries) do entries[i] = e end
        table.sort(entries, function(a, b) return a.size > b.size end)
        for _, e in ipairs(entries) do
            table.insert(items, {
                text = e.is_dir and (e.name .. "/") or e.name,
                mandatory = util.getFriendlySize(e.size),
                callback = e.is_dir and function() show(e.path) end or nil,
            })
        end
        local name = dir == root and _("Library") or dir:match("[^/]+$")
        local title = T(_("%1 (%2)"), name, util.getFriendlySize(tree[dir].size))
        if menu then
            menu:switchItemTable(title, items)
        else
            menu = Menu:new {
                title = title,
                item_table = items,
                covers_fullscreen = true,
                is_borderless = true,
                -- Menu closes itself after a selection by default; here a tap drills in.
                onMenuSelect = function(_, item)
                    if item.callback then item.callback() end
                    return true
                end,
                close_callback = function() UIManager:close(menu) end,
            }
            UIManager:show(menu)
        end
    end
    show(root)
end

return ShelfSpace
