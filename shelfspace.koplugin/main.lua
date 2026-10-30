local _ = require("gettext")
local ConfirmBox = require("ui/widget/confirmbox")
local DataStorage = require("datastorage")
local Device = require("device")
local BookList = require("ui/widget/booklist")
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
local Changelog = require("shelfspace/changelog")
local Details = require("shelfspace/details")
local Duplicates = require("shelfspace/duplicates")
local Installer = require("shelfspace/installer")
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

function ShelfSpace:isShowing()
    return self.screen ~= nil and not self.screen.closed and UIManager:isWidgetShown(self.screen)
end

-- ShelfSpace is a submenu under KOReader's Tools menu, where plugins are expected.
function ShelfSpace:addToMainMenu(menu_items)
    menu_items.shelfspace = {
        sorting_hint = "tools",
        text = _("ShelfSpace"),
        -- KOReader's own menu opens the submenu and ignores this; Bookshelf's start menu launches a plugin
        -- through the entry's callback, straight into ShelfSpace.
        callback = function() self:showOverview() end,
        sub_item_table = {
            {
                text_func = function() return self:isShowing() and _("Close ShelfSpace") or _("Open ShelfSpace") end,
                callback = function()
                    if self:isShowing() then self.screen:onClose() else self:showOverview() end
                end,
                separator = true,
            },
            { text = _("About"), callback = function() self:showAbout() end },
            {
                text = _("Check for updates"),
                callback = function() self:checkForUpdates(About.info(self.path).version) end,
            },
            { text = _("Changelog"), callback = function() self:showChangelog() end },
        },
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
    self:findDuplicates()
    self.screen:refresh()
end

-- Every book KOReader can open that ShelfSpace may look at: not KOReader's own folder, not hidden folders.
function ShelfSpace:bookFiles()
    local files, tree, data = {}, self.tree, self.koreader_dir
    local function walk(dir)
        local node = tree[dir]
        for _, e in ipairs(node and node.entries or {}) do
            if e.hidden or e.path == data or e.name:sub(1, 1) == "." then
                -- sidecar folders, KOReader's data and system folders are not part of the library
            elseif e.is_dir then
                walk(e.path)
            elseif Deleter.isBook(e) then
                table.insert(files, e)
            end
        end
    end
    walk(self.root)
    return files
end

-- How far through a copy you are, and whether it is the book open right now: what decides the copy to keep.
function ShelfSpace:copyInfo(copy)
    local info = BookList.getBookInfo(copy.path)
    local progress = 0
    if info and info.been_opened then
        progress = (info.status == "complete") and 1 or (tonumber(info.percent_finished) or 0)
    end
    return { progress = progress, locked = self.ui.document ~= nil and self.ui.document.file == copy.path }
end

-- Looks for books that are in the library more than once and keeps the result in self.duplicates, each set
-- with its copies best-first (the first is the one to keep) and the reason why. Sets you chose to keep
-- as they are go in self.ignored_duplicates. Two files are compared byte for byte only when they are the same size, and a comparison is
-- remembered until either file changes.
function ShelfSpace:findDuplicates()
    if not self.tree then return end
    local started = time.now()
    self.same_cache = self.same_cache or {}
    local function same(a, b)
        local key = table.concat({ a.path, a.size, a.modified or 0, b.path, b.modified or 0 }, "|")
        local known = self.same_cache[key]
        if known == nil then
            known = Duplicates.sameBytes(a.path, b.path)
            self.same_cache[key] = known
        end
        return known
    end
    local dismissed = G_reader_settings:readSetting("shelfspace_dismissed_duplicates") or {}
    local sets, ignored = {}, {}
    for _, set in ipairs(Duplicates.find(self:bookFiles(), same)) do
        table.sort(set.copies, function(a, b) return a.path < b.path end)
        local best, why = Duplicates.suggest(set, function(c) return self:copyInfo(c) end)
        local first = table.remove(set.copies, best)
        table.insert(set.copies, 1, first)
        set.reason = why
        set.free = Duplicates.savings(set, 1)
        if Duplicates.isIgnored(dismissed, set) then
            set.ignored = true
            table.insert(ignored, set)
        else
            table.insert(sets, set)
        end
    end
    local function biggest(a, b) return a.free > b.free end
    table.sort(sets, biggest)
    table.sort(ignored, biggest)
    self.duplicates, self.ignored_duplicates = sets, ignored
    logger.info(string.format("ShelfSpace: %d duplicate sets (%d kept on purpose) in %d ms", #sets, #ignored, time.to_ms(time.since(started))))
end

-- Leaves a set alone from now on: it moves to "kept on purpose".
function ShelfSpace:keepAll(set)
    local dismissed = G_reader_settings:readSetting("shelfspace_dismissed_duplicates") or {}
    dismissed[set.id] = #set.copies
    G_reader_settings:saveSetting("shelfspace_dismissed_duplicates", dismissed)
    self:findDuplicates()
    if self.screen and not self.screen.closed then self.screen:closeSet() end
end

-- The way back from keepAll: the set is listed again.
function ShelfSpace:stopIgnoring(set)
    local dismissed = G_reader_settings:readSetting("shelfspace_dismissed_duplicates") or {}
    dismissed[set.id] = nil
    G_reader_settings:saveSetting("shelfspace_dismissed_duplicates", dismissed)
    self:findDuplicates()
    if self.screen and not self.screen.closed then self.screen:showActiveDuplicates() end
end

-- Asks, then clears every copy of `set` except the one at `keep`.
function ShelfSpace:confirmClearCopies(set, keep)
    local items, names, size, sidecars = {}, {}, 0, 0
    for i, copy in ipairs(set.copies) do
        if i ~= keep then
            table.insert(items, copy)
            size = size + copy.size
            if i <= 4 then table.insert(names, copy.path:sub(#self.root + 2)) end
            if Deleter.countSidecars(self.tree, copy) > 0 then sidecars = sidecars + 1 end
        end
    end
    if #items == 0 then return end
    if #items > 4 then table.insert(names, T(_("and %1 more"), #items - 4)) end
    local lines = {
        T(N_("Clear %1 copy of %2?", "Clear %1 copies of %2?", #items), #items, set.title),
        _("KEEPS") .. "\n" .. set.copies[keep].path:sub(#self.root + 2),
        _("CLEARS") .. "\n" .. table.concat(names, "\n"),
        T(_("Frees %1."), util.getFriendlySize(size)),
    }
    if sidecars > 0 then
        table.insert(lines, T(N_("Includes the reading progress and notes of %1 copy.",
            "Includes the reading progress and notes of %1 copies.", sidecars), sidecars))
    end
    table.insert(lines, _("This cannot be undone."))
    self:showDialog(function()
        return ConfirmBox:new {
            text = table.concat(lines, "\n\n"),
            ok_text = _("Clear"),
            ok_callback = function()
                self:deleteMany(items, function()
                    -- Whatever you decided about this set is done with: a later duplicate of the book is a new question.
                    local dismissed = G_reader_settings:readSetting("shelfspace_dismissed_duplicates") or {}
                    if dismissed[set.id] then
                        dismissed[set.id] = nil
                        G_reader_settings:saveSetting("shelfspace_dismissed_duplicates", dismissed)
                    end
                    if self.screen and not self.screen.closed then self.screen:closeSet() end
                end)
            end,
        }
    end)
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
    self.screen.pages.library = state.page
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
        sort = screen.sort, descending = screen.descending, page = screen.pages.library,
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
                {
                    { text = _("Check for updates"), callback = act(function() self:checkForUpdates(info.version) end) },
                    { text = _("Changelog"), callback = act(function() self:showChangelog() end) },
                },
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

-- The release notes of every release. They are kept on the device after the first fetch, so reading them
-- needs no network; a fetch happens only when there is nothing kept yet, or when "Refresh" is tapped.
function ShelfSpace:changelogFile()
    return DataStorage:getDataDir() .. "/cache/shelfspace/changelog.json"
end

function ShelfSpace:keptChangelog()
    local file = io.open(self:changelogFile(), "rb")
    if not file then return nil end
    local text = file:read("*a")
    file:close()
    local ok, releases = pcall(require("json").decode, text)
    local entries = ok and Changelog.entries(releases) or {}
    return #entries > 0 and entries or nil
end

-- Fetches the releases, keeps them, and calls done(entries) or done(nil, why not).
function ShelfSpace:fetchChangelog(done)
    require("ui/network/manager"):runWhenOnline(function()
        local busy = InfoMessage:new { text = _("Fetching the changelog…") }
        UIManager:show(busy)
        UIManager:forceRePaint()
        local body, err = Updater.get(Updater.RELEASES)
        UIManager:close(busy)
        local ok, releases = false, nil
        if body then ok, releases = pcall(require("json").decode, body) end
        local entries = ok and Changelog.entries(releases) or {}
        if #entries == 0 then
            done(nil, err or _("GitHub's answer had no releases in it"))
            return
        end
        lfs.mkdir(DataStorage:getDataDir() .. "/cache")
        lfs.mkdir(DataStorage:getDataDir() .. "/cache/shelfspace")
        local file = io.open(self:changelogFile(), "wb")
        if file then
            file:write(body)
            file:close()
        end
        done(entries)
    end)
end

-- One release per page, newest first, in KOReader's own text viewer.
function ShelfSpace:showChangelog(index)
    local entries = self:keptChangelog()
    if not entries then
        self:fetchChangelog(function(fetched, err)
            if fetched then self:showChangelog(1) else self:notify(T(_("Could not fetch the changelog\n\n%1"), err)) end
        end)
        return
    end
    index = math.max(1, math.min(index or 1, #entries))
    local viewer
    local function go(to)
        return function()
            UIManager:close(viewer)
            self:showChangelog(to)
        end
    end
    local function enabled(on, callback) return { enabled = on, callback = on and callback or function() end } end
    local older, newer = enabled(index < #entries, go(index + 1)), enabled(index > 1, go(index - 1))
    older.text, newer.text = "\xE2\x80\xB9 " .. _("Older"), _("Newer") .. " \xE2\x80\xBA"
    viewer = require("ui/widget/textviewer"):new {
        title = T(_("Changelog (%1 of %2)"), index, #entries),
        text = Changelog.render(entries[index]),
        buttons_table = {
            { older, newer },
            {
                {
                    text = _("Refresh"),
                    callback = function()
                        UIManager:close(viewer)
                        self:fetchChangelog(function(fetched, err)
                            if fetched then self:showChangelog(1) else self:showChangelog(index) self:notify(T(_("Could not refresh\n\n%1"), err)) end
                        end)
                    end,
                },
                { text = _("Close"), callback = function() UIManager:close(viewer) end },
            },
        },
    }
    UIManager:show(viewer)
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

-- A device set up by something else (an Ansible playbook, say) that pins ShelfSpace's version is marked with
-- shelfspace_updates_managed, and an update installed here would be undone, or worse, downgraded by it.
-- Why an update cannot be installed here, or nil when it can: the device's setup manages the version, or this
-- copy is a link to a source checkout, which an update would swap out from under the developer.
function ShelfSpace:updateBlockedReason()
    if G_reader_settings:isTrue("shelfspace_updates_managed") then
        return _("This device's setup manages ShelfSpace's version, so updates are not installed from here.")
    end
    if lfs.symlinkattributes(self.path, "mode") == "link" then
        return _("This copy of ShelfSpace is a link to a source checkout, so it is updated with git, not from here.")
    end
end

function ShelfSpace:showUpdateResult(current, result)
    local blocked = self:updateBlockedReason()
    self:showDialog(function()
        local dialog
        local function act(fn)
            return function()
                UIManager:close(dialog)
                fn()
            end
        end
        local rows = {}
        local text = Updater.message(result, current)
        if result.state == "available" then
            if blocked then
                text = text .. "\n\n" .. blocked
            elseif result.asset then
                table.insert(rows, { { text = _("Update now"), callback = act(function() self:confirmInstall(current, result) end) } })
            end
            if result.page then
                table.insert(rows, { { text = _("Release page (QR)"), callback = function() self:showQR(_("ShelfSpace release"), result.page) end } })
            end
            table.insert(rows, { { text = _("Close"), callback = act(function() end) } })
            -- A viewer scrolls long release notes and keeps its buttons on screen, which a dialog's title does not.
            dialog = require("ui/widget/textviewer"):new { title = _("Update available"), text = text, buttons_table = rows }
            return dialog
        end
        table.insert(rows, { { text = _("Close"), callback = act(function() end) } })
        dialog = ButtonDialog:new { title = text, title_align = "center", buttons = rows }
        return dialog
    end)
end

function ShelfSpace:confirmInstall(current, result)
    local blocked = self:updateBlockedReason()
    if blocked then self:notify(blocked) return end
    self:showDialog(function()
        return ConfirmBox:new {
            text = T(_("Update ShelfSpace from %1 to %2?\n\nThis downloads %3, checks it against GitHub's checksum, installs it and offers to restart KOReader. If anything goes wrong nothing is changed, and the current version is kept as shelfspace.koplugin.old."),
                current, result.latest, util.getFriendlySize(result.asset.size or 0)),
            ok_text = _("Update"),
            ok_callback = function() self:installUpdate(result) end,
        }
    end)
end

-- Downloads, checks and installs the release in `result` (see Updater.interpret) over this plugin.
function ShelfSpace:installUpdate(result)
    -- The confirm box is still up while its callback runs, and showDialog shows nothing over a popup.
    if self.popup then UIManager:close(self.popup) end
    local busy = InfoMessage:new { text = _("Updating ShelfSpace…") }
    UIManager:show(busy)
    UIManager:forceRePaint()
    local cache = DataStorage:getDataDir() .. "/cache"
    lfs.mkdir(cache)
    lfs.mkdir(cache .. "/shelfspace")
    local ok, err = Installer.install(result.asset, result.latest, self.path, cache .. "/shelfspace/update.zip")
    UIManager:close(busy)
    if not ok then
        self:notify(T(_("The update was not installed, and nothing was changed.\n\n%1"), tostring(err)))
        return
    end
    local can_restart = Device:canRestart()
    self:showDialog(function()
        return ConfirmBox:new {
            text = can_restart and T(_("ShelfSpace %1 is installed.\n\nRestart KOReader to start using it."), result.latest)
                or T(_("ShelfSpace %1 is installed.\n\nQuit KOReader and open it again to start using it."), result.latest),
            ok_text = can_restart and _("Restart now") or _("Quit now"),
            cancel_text = _("Later"),
            ok_callback = function()
                if can_restart then UIManager:restartKOReader() else UIManager:quit() end
            end,
        }
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
function ShelfSpace:deleteMany(items, after)
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
            if after then after() end
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
