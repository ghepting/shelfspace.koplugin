local _ = require("gettext")
local ConfirmBox = require("ui/widget/confirmbox")
local DataStorage = require("datastorage")
local Device = require("device")
local ButtonDialog = require("ui/widget/buttondialog")
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
local About = require("shelfspace/about")
local Details = require("shelfspace/details")
local ScanCache = require("shelfspace/scancache")
local Scanner = require("shelfspace/scanner")
local ShelfScreen = require("shelfspace/screen")
local Updater = require("shelfspace/updater")

local ShelfSpace = WidgetContainer:extend {
    name = "shelfspace",
    is_doc_only = false,
}

function ShelfSpace:init()
    self.ui.menu:registerToMainMenu(self)

    -- Opening a book from ShelfSpace hands the screen over to the reader. ShelfSpace.resume
    -- remembers where the person was; it lives on the class because the file manager and the
    -- reader each load their own copy of this plugin. When the file manager is back after
    -- that book, ShelfSpace is shown again as it was.
    local resume = ShelfSpace.resume
    if not resume then return end
    local document = self.ui.document
    if document then
        if document.file == resume.file then resume.opened = true end
    elseif resume.opened then
        ShelfSpace.resume = nil
        UIManager:scheduleIn(0.3, function() self:showOverview(resume) end)
    end
end

function ShelfSpace:addToMainMenu(menu_items)
    menu_items.shelfspace = {
        sorting_hint = "tools",
        text = _("ShelfSpace"),
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
    local cache_dir = DataStorage:getDataDir() .. "/cache/shelfspace"
    local cache_file = cache_dir .. "/scan.lua"
    local previous = self.tree or ScanCache.load(cache_file, self.root)
    if previous then -- KOReader's own files change in place, so that folder is always read afresh
        local data = self.koreader_dir
        for dir in pairs(previous) do
            if dir == data or dir:sub(1, #data + 1) == data .. "/" then previous[dir] = nil end
        end
    end
    local function finish(tree)
        self.tree = tree
        lfs.mkdir(DataStorage:getDataDir() .. "/cache")
        lfs.mkdir(cache_dir)
        ScanCache.save(cache_file, self.root, tree, self.koreader_dir)
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
    end, previous)
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
                .. _("Everything that is not your books or KOReader's data: the system, its firmware, hidden folders and the filesystem itself. ShelfSpace leaves it alone, because deleting the wrong thing could stop the device from starting."),
        }
    end)
end

-- Re-reads free space and redraws whichever tab is showing.
function ShelfSpace:refresh()
    if not self.screen or self.screen.closed then return end
    self.usage = util.diskUsage(self.root)
    self.screen:refresh()
end

-- `state` (from openBook) brings back the tab, folder, search, sort and page that were showing.
function ShelfSpace:showOverview(state)
    local usage = util.diskUsage(libraryPath())
    if not usage.total or usage.total == 0 then
        UIManager:show(InfoMessage:new { text = _("Could not read storage usage.") })
        return
    end
    self.usage = usage
    state = state or {}
    self.screen = ShelfScreen:new { plugin = self, tab = state.tab, dir = state.dir, query = state.query, status = state.status, sort = state.sort, descending = state.descending }
    self.screen.pages.browse = state.page
    UIManager:show(self.screen)
    self:scan(function() self:refresh() end)
end

-- Asks before deleting `entry` (listed in `dir`), then updates the tree and screen.
-- One dialog at a time: a second tap while one is up (easy on a slow e-ink screen) is ignored,
-- so confirmations can't stack on top of each other.
function ShelfSpace:showDialog(make)
    -- Not called `dialog`: inside a book the reader gives every plugin a `dialog` field that
    -- points at itself, which would make this guard refuse to show anything.
    if self.popup and UIManager:isWidgetShown(self.popup) then return end
    self.popup = make()
    UIManager:show(self.popup)
end

-- Opens a book in the reader, remembering where we were so closing it brings us back.
-- Where the person is in ShelfSpace (tab, folder, search, filters, sort, page), so it can be shown again as
-- it was when a book they opened, or closed, from here is done with.
function ShelfSpace:resumeState(file, opened)
    local screen = self.screen
    return {
        file = file, opened = opened, tab = screen.tab, dir = screen.dir, query = screen.query, status = screen.status,
        sort = screen.sort, descending = screen.descending, page = screen.pages.browse,
    }
end

-- Opens a book in the reader, remembering where we were so closing it brings us back.
function ShelfSpace:openBook(path)
    local screen = self.screen
    -- The book already open: close ShelfSpace and carry on reading it.
    if self.ui.document and self.ui.document.file == path then
        screen:onClose()
        return
    end
    ShelfSpace.resume = self:resumeState(path)
    screen:onClose()
    UIManager:nextTick(function()
        require("apps/reader/readerui"):showReader(path)
    end)
end

-- Closes the book that was open before ShelfSpace was, so it can be deleted, and brings ShelfSpace back
-- where it was once the reader has gone: the same hand-over as opening a book, the other way round.
function ShelfSpace:closeBook()
    local document = self.ui.document
    if not document then return end
    ShelfSpace.resume = self:resumeState(document.file, true)
    self.screen:onClose()
    UIManager:nextTick(function() self.ui:onHome() end)
end

function ShelfSpace:showDetails(entry, dir)
    Details.show(self, entry, dir, Deleter.blockedReason(entry, self:deleteContext()))
end

-- The card for a folder (long press on its row).
function ShelfSpace:showFolder(entry, dir)
    Details.showFolder(self, entry, dir, Deleter.blockedReason(entry, self:deleteContext()))
end

-- The ShelfSpace card: version, build, what it runs on, and ways to get help or check for a newer release.
function ShelfSpace:aboutInfo()
    local info = About.info(self.path)
    info.library = self.root
    info.usage = self.usage
    return info
end

-- A QR code for `url`: nobody can click a link on an e-reader, but a phone can scan one.
function ShelfSpace:showQR(title, url)
    UIManager:show(require("ui/widget/qrmessage"):new { title = title, text = url })
end

function ShelfSpace:showAbout()
    local info = self:aboutInfo()
    self:showDialog(function()
        local dialog
        local function act(fn)
            return function()
                UIManager:close(dialog)
                fn()
            end
        end
        dialog = ButtonDialog:new {
            title = About.lines(info),
            title_align = "center",
            buttons = {
                { { text = _("Check for updates"), callback = act(function() self:checkForUpdates(info.version) end) } },
                {
                    { text = _("Repository (QR)"), callback = function() self:showQR(_("ShelfSpace on GitHub"), About.repoUrl()) end },
                    { text = _("Report a problem (QR)"), callback = function() self:showQR(_("Report a problem"), About.issueUrl(info)) end },
                },
                { { text = _("Close"), callback = act(function() end) } },
            },
        }
        return dialog
    end)
end

-- Asks GitHub for the latest release, when online, and says what it found. Runs only when asked.
function ShelfSpace:checkForUpdates(current)
    require("ui/network/manager"):runWhenOnline(function()
        local busy = InfoMessage:new { text = _("Checking for updates…") }
        UIManager:show(busy)
        UIManager:forceRePaint()
        local result = Updater.check(current)
        UIManager:close(busy)
        self:showUpdateResult(current, result)
    end)
end

function ShelfSpace:showUpdateResult(current, result)
    self:showDialog(function()
        local dialog
        local function act(fn)
            return function()
                UIManager:close(dialog)
                fn()
            end
        end
        local rows = {}
        if result.state == "available" and result.page then
            table.insert(rows, { { text = _("Release page (QR)"), callback = function() self:showQR(_("ShelfSpace release"), result.page) end } })
        end
        table.insert(rows, { { text = _("Close"), callback = act(function() end) } })
        dialog = ButtonDialog:new { title = Updater.message(result, current), title_align = "center", buttons = rows }
        return dialog
    end)
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

-- Asks once before deleting everything in `entries` (already collapsed by Selection).
function ShelfSpace:confirmDeleteMany(entries)
    local ctx = self:deleteContext()
    local items = {}
    for i, e in ipairs(entries) do
        if not Deleter.blockedReason(e, ctx) then table.insert(items, e) end
    end
    if #items == 0 then
        self:notify(_("Nothing selected can be deleted."))
        return
    end
    local size, files, sidecars, names = 0, 0, 0, {}
    for i, e in ipairs(items) do
        size = size + e.size
        files = files + Deleter.countFiles(self.tree, e)
        sidecars = sidecars + Deleter.countSidecars(self.tree, e)
        if i <= 4 then table.insert(names, e.name .. (e.is_dir and "/" or "")) end
    end
    if #items > 4 then table.insert(names, T(_("and %1 more"), #items - 4)) end
    local lines = {
        T(N_("Delete %1 item?", "Delete %1 items?", #items), #items),
        table.concat(names, "\n"),
        T(_("Frees %1."), util.getFriendlySize(size)),
        T(N_("%1 file in total.", "%1 files in total.", files), files),
    }
    if sidecars > 0 then
        table.insert(lines, T(N_("Also removes the reading progress and notes of %1 book.",
            "Also removes the reading progress and notes of %1 books.", sidecars), sidecars))
    end
    table.insert(lines, _("This cannot be undone."))
    self:showDialog(function()
        return ConfirmBox:new {
            text = table.concat(lines, "\n\n"),
            ok_text = _("Delete"),
            ok_callback = function() self:deleteMany(items) end,
        }
    end)
end

-- Deletes one entry per tick so the screen stays alive, then leaves select mode.
function ShelfSpace:deleteMany(items)
    local busy = InfoMessage:new { text = T(N_("Deleting %1 item…", "Deleting %1 items…", #items), #items) }
    UIManager:show(busy)
    local failed, at = {}, 0
    local function step()
        at = at + 1
        local entry = items[at]
        if not entry then
            UIManager:close(busy)
            self.block_cache = {}
            if self.screen and not self.screen.closed then self.screen:setSelecting(false) end
            self:refresh()
            if #failed > 0 then
                self:notify(T(_("Could not delete %1 of %2:\n%3"), #failed, #items, table.concat(failed, "\n")))
            end
            return
        end
        local dir = entry.path:match("^(.*)/[^/]+$") or self.root
        if lfs.attributes(entry.path, "mode") == nil or Deleter.delete(entry) then
            Scanner.remove(self.tree, self.root, dir, entry)
        else
            table.insert(failed, entry.name)
        end
        UIManager:scheduleIn(0, step)
    end
    UIManager:nextTick(step)
end

-- Asks before clearing `targets` (from Cleanup), then rescans and redraws.
-- `label` names what is cleared; left out, the targets' own titles are listed. Anything that
-- is the person's own (not rebuilt by KOReader) is called out, since it cannot come back.
function ShelfSpace:confirmClear(targets, label)
    local size, titles, own = 0, {}, false
    for i, t in ipairs(targets) do
        size = size + t.size
        table.insert(titles, t.title:lower())
        if not t.safe then own = true end
    end
    label = label or table.concat(titles, ", ")
    local text = T(_("Clear %1?\n\nFrees %2."), label, util.getFriendlySize(size))
    if own and #targets > 1 then
        text = text .. "\n\n" .. _("Screenshots and reading progress are yours, and cannot be recovered.")
    end
    self:showDialog(function()
        return ConfirmBox:new {
            text = text,
            ok_text = _("Clear"),
            ok_callback = function()
                for i, t in ipairs(targets) do t.clear() end
                if self.screen and not self.screen.closed then self.screen.selecting, self.screen.selected = false, {} end
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
