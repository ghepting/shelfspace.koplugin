local _ = require("gettext")
local ConfirmBox = require("ui/widget/confirmbox")
local DataStorage = require("datastorage")
local Device = require("device")
local InfoMessage = require("ui/widget/infomessage")
local Menu = require("ui/widget/menu")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local ffiUtil = require("ffi/util")
local util = require("util")
local N_ = _.ngettext
local T = ffiUtil.template

local Cleanup = require("shelfspace/cleanup")
local Deleter = require("shelfspace/deleter")
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
-- the result in self.tree for the browser.
function ShelfSpace:scan(on_done)
    self.root = libraryPath()
    local koreader_dir = DataStorage:getDataDir()
    self.koreader_dir = ffiUtil.realpath(koreader_dir) or koreader_dir
    Scanner.scan(self.root, function(tree)
        if tree[self.koreader_dir] then
            self.tree = tree
            on_done()
            return
        end
        Scanner.scan(self.koreader_dir, function(extra)
            for dir, node in pairs(extra) do tree[dir] = node end
            self.tree = tree
            on_done()
        end)
    end)
end

-- Books = visible top-level entries; "other" is whatever the partition holds beyond that.
function ShelfSpace:breakdown(usage)
    local books = 0
    for _, e in ipairs(self.tree[self.root].entries) do
        if e.name:sub(1, 1) ~= "." and e.path ~= self.koreader_dir then
            books = books + e.size
        end
    end
    local koreader = self.tree[self.koreader_dir].size
    return { books = books, koreader = koreader, other = math.max(usage.used - books - koreader, 0) }
end

function ShelfSpace:refreshOverview()
    if not self.overview or self.overview.closed then return end
    local usage = util.diskUsage(self.root)
    self.overview:update(usage, self:breakdown(usage))
end

function ShelfSpace:showOverview()
    local usage = util.diskUsage(libraryPath())
    if not usage.total or usage.total == 0 then
        UIManager:show(InfoMessage:new { text = _("Could not read storage usage.") })
        return
    end
    self.overview = Overview:new {
        usage = usage,
        on_browse = function() self:browse() end,
        on_koreader = function() self:showKoreaderData() end,
    }
    UIManager:show(self.overview)
    self:scan(function() self:refreshOverview() end)
end

-- Asks before deleting `entry` (listed in `dir`), then updates the tree and screens.
function ShelfSpace:confirmDelete(entry, dir, redraw)
    local open_file = self.ui.document and self.ui.document.file
    if Deleter.holdsOpenBook(entry, open_file) then
        UIManager:show(InfoMessage:new { text = _("You are reading this book, so it can't be deleted.") })
        return
    end
    local lines = {
        T(_("Delete %1?"), entry.name),
        T(_("Frees %1."), util.getFriendlySize(entry.size)),
    }
    if entry.is_dir then
        local files = Deleter.countFiles(self.tree, entry)
        table.insert(lines, T(N_("Contains %1 file.", "Contains %1 files.", files), files))
    end
    local sidecars = Deleter.countSidecars(self.tree, entry)
    if sidecars > 0 then
        table.insert(lines, T(N_("Also removes the reading progress and notes of %1 book.",
            "Also removes the reading progress and notes of %1 books.", sidecars), sidecars))
    end
    table.insert(lines, _("This cannot be undone."))
    UIManager:show(ConfirmBox:new {
        text = table.concat(lines, "\n\n"),
        ok_text = _("Delete"),
        ok_callback = function()
            if Deleter.delete(entry) then
                Scanner.remove(self.tree, self.root, dir, entry)
                redraw()
                self:refreshOverview()
            else
                UIManager:show(InfoMessage:new { text = T(_("Failed to delete:\n%1"), entry.path) })
            end
        end,
    })
end

-- Shows folders and files largest-first. Tap a folder to open it; tap a file,
-- or hold anything, to delete it.
function ShelfSpace:browse()
    local root, tree = self.root, self.tree
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
        for _, e in ipairs(tree[dir].entries) do
            if not e.hidden then table.insert(entries, e) end
        end
        table.sort(entries, function(a, b) return a.size > b.size end)
        for _, e in ipairs(entries) do
            local ask = function() self:confirmDelete(e, dir, function() show(dir) end) end
            table.insert(items, {
                text = e.is_dir and (e.name .. "/") or e.name,
                mandatory = util.getFriendlySize(e.size),
                callback = e.is_dir and function() show(e.path) end or ask,
                hold_callback = ask,
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
                onMenuHold = function(_, item)
                    if item.hold_callback then item.hold_callback() end
                    return true
                end,
                close_callback = function() UIManager:close(menu) end,
            }
            UIManager:show(menu)
        end
    end
    show(root)
end

-- Lists what KOReader can regenerate or no longer needs; tap one to clear it.
function ShelfSpace:showKoreaderData()
    local book_open = self.ui.document ~= nil
    local menu
    local function show()
        local targets = Cleanup.targets(self.tree, self.koreader_dir, book_open)
        local items, total = {}, 0
        for _i, t in ipairs(targets) do
            local label = t.title
            if t.count then label = T(_("%1 (%2)"), t.title, t.count) end
            local clearable = t.size > 0 and not t.blocked
            if clearable then total = total + t.size end
            table.insert(items, {
                text = label,
                mandatory = util.getFriendlySize(t.size),
                dim = not clearable,
                callback = function()
                    if t.blocked then
                        UIManager:show(InfoMessage:new { text = t.blocked })
                    elseif t.size > 0 then
                        self:confirmClear(t, show)
                    end
                end,
            })
        end
        local title = T(_("KOReader data (%1)"), util.getFriendlySize(self.tree[self.koreader_dir].size))
        if menu then
            menu:switchItemTable(title, items)
        else
            menu = Menu:new {
                title = title,
                item_table = items,
                covers_fullscreen = true,
                is_borderless = true,
                onMenuSelect = function(_, item)
                    if item.callback then item.callback() end
                    return true
                end,
                close_callback = function() UIManager:close(menu) end,
            }
            UIManager:show(menu)
        end
    end
    show()
end

function ShelfSpace:confirmClear(target, redraw)
    UIManager:show(ConfirmBox:new {
        text = T(_("Clear %1?\n\nFrees %2."), target.title:lower(), util.getFriendlySize(target.size)),
        ok_text = _("Clear"),
        ok_callback = function()
            target.clear()
            local busy = InfoMessage:new { text = _("Updating…") }
            UIManager:show(busy)
            UIManager:nextTick(function()
                self:scan(function()
                    UIManager:close(busy)
                    redraw()
                    self:refreshOverview()
                end)
            end)
        end,
    })
end

return ShelfSpace
