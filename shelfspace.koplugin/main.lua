local _ = require("gettext")
local ConfirmBox = require("ui/widget/confirmbox")
local DataStorage = require("datastorage")
local Device = require("device")
local InfoMessage = require("ui/widget/infomessage")
local UIManager = require("ui/uimanager")
local logger = require("logger")
local time = require("ui/time")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local ffiUtil = require("ffi/util")
local lfs = require("libs/libkoreader-lfs")
local util = require("util")
local N_ = _.ngettext
local T = ffiUtil.template

local Deleter = require("shelfspace/deleter")
local Scanner = require("shelfspace/scanner")
local ShelfScreen = require("shelfspace/screen")

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
    self.block_cache = {}
    self.root = libraryPath()
    local koreader_dir = DataStorage:getDataDir()
    self.koreader_dir = ffiUtil.realpath(koreader_dir) or koreader_dir
    local started = time.now()
    local function finish(tree)
        self.tree = tree
        local dirs, files = Scanner.count(tree)
        logger.info(string.format("ShelfSpace: scanned %d folders, %d files in %d ms",
            dirs, files, time.to_ms(time.since(started))))
        on_done()
    end
    Scanner.scan(self.root, function(tree)
        if tree[self.koreader_dir] then
            finish(tree)
            return
        end
        Scanner.scan(self.koreader_dir, function(extra)
            for dir, node in pairs(extra) do tree[dir] = node end
            finish(tree)
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

-- Says what "Other files" is and why it can't be browsed or deleted.
function ShelfSpace:explainOther(b)
    self:showDialog(function()
        return InfoMessage:new {
            text = T(_("Other files: %1"), util.getFriendlySize(b.other)) .. "\n\n"
                .. _("Everything that is not your books or KOReader's data: the system, its firmware, hidden folders and the filesystem itself. Shelf Space leaves it alone, because deleting the wrong thing could stop the device from starting."),
        }
    end)
end

-- Re-reads free space and redraws whichever tab is showing.
function ShelfSpace:refresh()
    if not self.screen or self.screen.closed then return end
    self.usage = util.diskUsage(self.root)
    self.screen:refresh()
end

function ShelfSpace:showOverview()
    local usage = util.diskUsage(libraryPath())
    if not usage.total or usage.total == 0 then
        UIManager:show(InfoMessage:new { text = _("Could not read storage usage.") })
        return
    end
    self.usage = usage
    self.screen = ShelfScreen:new { plugin = self }
    UIManager:show(self.screen)
    self:scan(function() self:refresh() end)
end

-- Asks before deleting `entry` (listed in `dir`), then updates the tree and screen.
-- One dialog at a time: a second tap while one is up (easy on a slow e-ink screen) is ignored,
-- so confirmations can't stack on top of each other.
function ShelfSpace:showDialog(make)
    if self.dialog and UIManager:isWidgetShown(self.dialog) then return end
    self.dialog = make()
    UIManager:show(self.dialog)
end

function ShelfSpace:notify(text)
    self:showDialog(function() return InfoMessage:new { text = text } end)
end

function ShelfSpace:deleteContext()
    return {
        tree = self.tree, root = self.root, koreader_dir = self.koreader_dir,
        open_file = self.ui.document and self.ui.document.file,
        cache = self.block_cache,
    }
end

function ShelfSpace:confirmDelete(entry, dir)
    local reason = Deleter.blockedReason(entry, self:deleteContext())
    if reason then
        self:notify(reason)
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
    self:showDialog(function()
        return ConfirmBox:new {
            text = table.concat(lines, "\n\n"),
            ok_text = _("Delete"),
            ok_callback = function()
                -- Already gone (deleted elsewhere in the meantime) counts as done.
                local gone = lfs.attributes(entry.path, "mode") == nil
                if gone or Deleter.delete(entry) then
                    self.block_cache = {}
                    Scanner.remove(self.tree, self.root, dir, entry)
                    self:refresh()
                else
                    self:notify(T(_("Failed to delete:\n%1"), entry.path))
                end
            end,
        }
    end)
end

-- Asks before clearing `targets` (from Cleanup), then rescans and redraws.
function ShelfSpace:confirmClear(targets, label)
    local size = 0
    for i, t in ipairs(targets) do size = size + t.size end
    self:showDialog(function()
        return ConfirmBox:new {
            text = T(_("Clear %1?\n\nFrees %2."), label, util.getFriendlySize(size)),
            ok_text = _("Clear"),
            ok_callback = function()
                for i, t in ipairs(targets) do t.clear() end
                local busy = InfoMessage:new { text = _("Updating…") }
                UIManager:show(busy)
                UIManager:nextTick(function()
                    self:scan(function()
                        UIManager:close(busy)
                        self:refresh()
                    end)
                end)
            end,
        }
    end)
end

return ShelfSpace
