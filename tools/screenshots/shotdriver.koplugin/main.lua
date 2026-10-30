local UIManager = require("ui/uimanager")
local Device = require("device")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local lfs = require("libs/libkoreader-lfs")
local logger = require("logger")
-- Drives ShelfSpace through every screen in a running KOReader, saves each as a PNG, and checks what it does along the way (it deletes
-- files, so it only runs against the sample library tools/screenshots/make-library.sh builds). Paths come from the environment:
-- SHOT_OUT is the folder the PNGs go in, SHOT_LIBRARY the library.
local OUT = assert(os.getenv("SHOT_OUT"), "SHOT_OUT is not set") .. "/"

local Driver = WidgetContainer:extend{ name = "shotdriver", is_doc_only = false }

local pass, fail = 0, 0
local function check(name, ok, detail)
    if ok then
        pass = pass + 1
        logger.info("TEST PASS " .. name)
    else
        fail = fail + 1
        logger.err("TEST FAIL " .. name .. ": " .. tostring(detail))
    end
end

function Driver:init()
    if self.ui.document then return end
    -- Pretend to be an 8 GB device: the Mac's own disk would make every slice vanish.
    local util = require("util")
    util.diskUsage = function() return { total = 8000000000, used = 5100000000, available = 2900000000 } end
    local P = self.ui.shelfspace
    local function S() return P.screen end
    local root = assert(os.getenv("SHOT_LIBRARY"), "SHOT_LIBRARY is not set")
    local Search = require("shelfspace/search")
    local Deleter = require("shelfspace/deleter")
    local state = {}
    local stash = root .. "/../stash"
    -- The format fixtures stay out of the library while the screens for the README are taken, and are put back for their own checks.
    local function stash_formats(away)
        lfs.mkdir(stash)
        for _, name in ipairs({ "Formats", "Shouting", "Mixed" }) do
            if away then os.rename(root .. "/" .. name, stash .. "/" .. name) else os.rename(stash .. "/" .. name, root .. "/" .. name) end
        end
    end
    local Formats = require("shelfspace/formats")
    local Theme = require("shelfspace/theme")
    local DocumentRegistry = require("document/documentregistry")
    local ctx_for = function() return P:deleteContext() end
    -- What each fixture file in Formats/ and Shouting/ should be, by the extension it was made with.
    local EXPECT = {
        epub = "book", ["kepub.epub"] = "book", mobi = "book", prc = "book", fb2 = "book", ["fb2.zip"] = "book", pdb = "book",
        doc = "document", docx = "document", rtf = "document", txt = "document", text = "document", md = "document", markdown = "document",
        html = "document", htm = "document", chm = "document",
        pdf = "fixed", djvu = "fixed", djv = "fixed", xps = "fixed", oxps = "fixed",
        cbz = "comic", cbt = "comic", zip = "comic",
        jpg = "image", jpeg = "image", png = "image", bmp = "image", webp = "image", gif = "image",
        ["txt.zip"] = "document", ["html.zip"] = "document", ["md.zip"] = "document", epub3 = "book", fb3 = "book", odt = "document", docm = "document",
        tif = "image", svg = "image",
    }
    -- This KOReader build opens none of these, though the formats list names them (it registers no provider for the extension).
    local NOT_OPENED = { text = true, markdown = true, oxps = true, bmp = true }
    local function formats_report(folder, pattern)
        local missing, locked, wrong, n = {}, {}, {}, 0
        for _, e in ipairs(P.tree[folder].entries) do
            local ext = pattern(e.name)
            if ext == "azw3" or ext == "kfx" then ext = nil end -- not read by KOReader: checked on their own
            if ext then
                ext = ext:lower()
                n = n + 1
                local kind = Theme.kindName(e)
                local provider = DocumentRegistry:hasProvider(e.path) and true or false
                local reason = require("shelfspace/deleter").blockedReason(e, ctx_for())
                logger.info(string.format("FORMAT %-34s counted=%-5s kind=%-8s tile=%-4s provider=%-5s book=%-5s supported=%-5s blocked=%s",
                    e.name, require("shelfspace/stats").extension(e.name), kind, Formats.label(e.name), tostring(provider),
                    tostring(require("shelfspace/deleter").isBook(e)), tostring(require("shelfspace/deleter").isSupported(e)), tostring(reason)))
                if EXPECT[ext] ~= kind then wrong[#wrong + 1] = e.name .. "=" .. kind .. " (wanted " .. tostring(EXPECT[ext]) .. ")" end
                if not provider and not NOT_OPENED[ext] then missing[#missing + 1] = e.name end
                if reason and not NOT_OPENED[ext] then locked[#locked + 1] = e.name end
                if NOT_OPENED[ext] then state.not_opened = (state.not_opened or 0) + 1 end
            end
        end
        return n, missing, locked, wrong
    end

    local function closeDialogs()
        if P.popup then UIManager:close(P.popup) P.popup = nil end
        for i = #UIManager._window_stack, 1, -1 do
            local w = UIManager._window_stack[i].widget
            if w ~= S() and w.name ~= "shotdriver" and w.is_always_active ~= true and w ~= self.ui and w.covers_fullscreen ~= true then
                UIManager:close(w)
            end
        end
    end
    local function setColour(on)
        G_reader_settings:saveSetting("color_rendering", on)
        require("document/canvascontext"):setColorRenderingEnabled(on)
        if S() then S():onClose() end
        P:showOverview()
    end
    local function entry(dir, name)
        for _, e in ipairs(P.tree[dir].entries) do if e.name == name then return e end end
    end
    local function exists(path) return lfs.attributes(path, "mode") ~= nil end
    -- Presses OK on the open confirmation: closes it the way a tap would, then runs what OK does.
    local function ok_dialog()
        local popup = P.popup
        if popup and popup.ok_callback then
            UIManager:close(popup)
            P.popup = nil
            popup.ok_callback()
        end
    end

    -- { shot name or nil, action, seconds to wait before the shot (and the next step) }
    local steps = {
        ---------------------------------------------------------------- colour screen
        { nil, function() stash_formats(true) end, 0 },
        { "library", function() setColour(true) end, 4 },
        { nil, function()
            check("starts on the Library tab", S().tab == "library", S().tab)
            state.sets = #(P.duplicates or {})
            check("three sets of duplicates are found", state.sets == 3, state.sets)
            check("four books in Sci-Fi", #Search.find(P.tree, root .. "/Sci-Fi", nil, nil, Deleter.isBook) == 4)
            check("four EPUBs in Sci-Fi by type", #Search.find(P.tree, root .. "/Sci-Fi", nil, "epub") == 4)
            check("a search finds both copies of Dune", #Search.find(P.tree, root, "dune") == 2, #Search.find(P.tree, root, "dune"))
        end, 0 },
        { "library-books", function() S():toggleBooks() end, 2 },
        { nil, function() check("Books narrows the list", S().only_books == true) end, 0 },
        { "library-books-sorted", function() S():setSort("name") end, 2 },
        { "library-folder", function() S():toggleBooks() S():setSort("size") S():setDir(root .. "/Manuals") end, 2 },
        { nil, function() check("Books turned off again", S().only_books == false) check("folder opens", S().dir == root .. "/Manuals", S().dir) end, 0 },
        { "library-search", function() S():setDir(root) S():setQuery("dune") end, 2 },
        { "library-type", function() S():setQuery(nil) S():toggleFilter("epub") end, 2 },
        { "library-status", function() S():toggleFilter("epub") S():setStatus("complete") end, 2 },
        { "library-empty", function() S():setQuery("zzzz") end, 2 },
        { "library-filter-dialog", function() S():clearFilters() S():askFilter() end, 2 },
        { nil, function()
            closeDialogs()
            check("clearFilters resets everything", not S().query and not S().filter and not S().status and not S().only_books)
        end, 1 },
        { "library-select", function()
            S():setDir(root .. "/Comics") S():setSelecting(true)
            local e = P.tree[root .. "/Comics"].entries
            S():select({ e[1], e[2] }, true)
        end, 2 },
        { nil, function()
            check("two rows ticked", #S():chosen() == 2, #S():chosen())
            S():switchTab("koreader")
            check("a selection belongs to its tab", not S().selecting and next(S().selected) == nil)
            S():switchTab("library")
        end, 1 },
        { "koreader", function() S():switchTab("koreader") end, 2 },
        { "duplicates", function() S():switchTab("duplicates") end, 2 },
        { "duplicates-compare", function() S():openSet(P.duplicates[#P.duplicates].id) end, 2 },
        { "duplicates-compare-other", function() local set = S():currentSet() S():setKeeper(set, 2) end, 2 },
        { nil, function() local set = S():currentSet() check("the copy you tap is the one kept", S():keeper(set) == 2, S():keeper(set)) end, 0 },
        { "duplicates-confirm", function() local set = S():currentSet() P:confirmClearCopies(set, S():keeper(set)) end, 2 },
        { nil, function() closeDialogs() end, 1 },
        { "duplicates-kept", function()
            local set = S():currentSet() P:keepAll(set) S():showIgnoredDuplicates()
            check("Keep all moves the set to kept on purpose", #(P.ignored_duplicates or {}) == 1 and #P.duplicates == state.sets - 1)
        end, 2 },
        { "duplicates-list-after", function()
            P:stopIgnoring(P.ignored_duplicates[1]) S():showActiveDuplicates()
            check("Stop ignoring puts it back", #(P.ignored_duplicates or {}) == 0 and #P.duplicates == state.sets)
        end, 2 },
        { "menu", function() S():switchTab("library") S():showMenu() end, 2 },
        { nil, function() closeDialogs() end, 1 },
        { "about", function() local r = P.root P.root = "/mnt/onboard" P:showAbout() P.root = r end, 2 },
        { nil, function() closeDialogs() end, 1 },
        { "changelog", function() P:showChangelog() end, 6 },
        { nil, function() closeDialogs() end, 1 },
        { "details", function() local e = entry(root .. "/Sci-Fi", "Dune.epub") S():switchTab("library") S():setDir(root .. "/Sci-Fi") P:showDetails(e, root .. "/Sci-Fi") end, 2 },
        { nil, function() closeDialogs() end, 1 },
        { "delete", function() local e = entry(root .. "/Sci-Fi", "Neuromancer.epub") P:confirmDelete(e, root .. "/Sci-Fi") end, 2 },
        { nil, function() closeDialogs() S():setDir(root) end, 1 },
        { "koreader-data", function() S():switchTab("koreader") end, 2 },
        { "clear-several", function()
            S():setSelecting(true)
            S():toggleKey("Rendering cache") S():toggleKey("Update downloads")
        end, 2 },
        { "clear-several-confirm", function()
            local clearable = {}
            local Cleanup = require("shelfspace/cleanup")
            for _, t in ipairs(Cleanup.targets(P.tree, P.koreader_dir, false, P.root)) do if t.size > 0 and S().selected[t.title] then clearable[#clearable + 1] = t end end
            P:confirmClear(clearable)
        end, 2 },
        { nil, function() closeDialogs() S():setSelecting(false) S():switchTab("library") end, 1 },
        ---------------------------------------------------------------- gray screen
        { nil, function() setColour(false) end, 4 },
        { "gray-library", function() end, 0 },
        { nil, function() stash_formats(false) S():onClose() P:showOverview() end, 5 },
        { nil, function()
            state.sets = #P.duplicates
            check("with the format fixtures back there are four sets (Emma in three spellings)", state.sets == 4, state.sets)
        end, 0 },
        { "gray-formats-1", function() S():setDir(root .. "/Formats") S():setPage(1) end, 2 },
        { "gray-formats-2", function() S():setPage(2) end, 2 },
        { nil, function() S():setDir(root) end, 1 },
        { "gray-library-books", function() S():toggleBooks() end, 2 },
        { "gray-library-select", function()
            S():toggleBooks() S():setDir(root .. "/Comics") S():setSelecting(true)
            local e = P.tree[root .. "/Comics"].entries
            S():select({ e[1], e[2] }, true)
        end, 2 },
        { nil, function() S():setSelecting(false) end, 1 },
        { "gray-koreader", function() S():switchTab("koreader") end, 2 },
        { "gray-duplicates", function() S():switchTab("duplicates") end, 2 },
        { "gray-duplicates-compare", function() S():openSet(P.duplicates[#P.duplicates].id) end, 2 },
        { "gray-menu", function() S():switchTab("library") S():showMenu() end, 2 },
        { nil, function() closeDialogs() end, 1 },
        { nil, function() setColour(true) end, 4 },
        ---------------------------------------------------------------- every format, in lower case and in capitals
        { "formats-readme", function() S():setDir(root .. "/Mixed") S():setPage(1) end, 2 },
        { "formats-1", function() S():setDir(root .. "/Formats") S():setPage(1) end, 2 },
        { "formats-2", function() S():setPage(2) end, 2 },
        { "formats-3", function() S():setPage(3) end, 2 },
        { "formats-4", function() S():setPage(4) end, 2 },
        { "formats-5", function() S():setPage(5) end, 2 },
        { "formats-6", function() S():setPage(6) end, 2 },
        { "formats-7", function() S():setPage(7) end, 2 },
        { nil, function()
            local n, missing, locked, wrong = formats_report(root .. "/Formats", function(name) return name:match("^(%S+) sample") end)
            check("all 40 formats are in Formats/ (lower case)", n == 40, n)
            check("every format has the right kind", #wrong == 0, table.concat(wrong, "; "))
            check("KOReader opens every format (it has a provider)", #missing == 0, table.concat(missing, ", "))
            check("every format can be deleted (none is locked)", #locked == 0, table.concat(locked, ", "))
            check("only the four formats this KOReader does not register are left unopened (text, markdown, oxps, bmp)", state.not_opened == 4, state.not_opened)
            state.not_opened = 0
            for _, name in ipairs({ "azw3 sample.azw3", "kfx sample.kfx" }) do
                local e = entry(root .. "/Formats", name)
                check(name .. " is listed but is not a book", e ~= nil and not Deleter.isBook(e), name)
            end
        end, 0 },
        { "shouting-1", function() S():setDir(root .. "/Shouting") S():setPage(1) end, 2 },
        { "shouting-2", function() S():setPage(2) end, 2 },
        { "shouting-3", function() S():setPage(3) end, 2 },
        { nil, function()
            local n, missing, locked, wrong = formats_report(root .. "/Shouting", function(name)
                local rest = name:match("^SHOUT (.+)$")
                return rest and rest:sub(1, (#rest - 1) / 2) -- "FB2.ZIP.FB2.ZIP" is the format twice, once as the name and once as the extension
            end)
            check("all 40 formats are in Shouting/ (capitals)", n == 40, n)
            check("capitals: every format has the right kind", #wrong == 0, table.concat(wrong, "; "))
            check("capitals: the same four are the ones KOReader does not open", state.not_opened == 4, state.not_opened)
            check("capitals: KOReader opens every format", #missing == 0, table.concat(missing, ", "))
            check("capitals: every format can be deleted", #locked == 0, table.concat(locked, ", "))
            local epubs = {}
            for _, e in ipairs((Search.find(P.tree, root, nil, "epub"))) do epubs[e.name] = true end
            check("the epub filter finds EPUB, KEPUB.EPUB and kepub.epub alike", epubs["SHOUT EPUB.EPUB"] and epubs["SHOUT KEPUB.EPUB.KEPUB.EPUB"] and epubs["kepub.epub sample.kepub.epub"] and epubs["epub sample.epub"], next(epubs))
            check("a search for 'shout' finds the 40 files and the folder named Shouting", #Search.find(P.tree, root, "shout") == 41, #Search.find(P.tree, root, "shout"))
            local emma
            for _, set in ipairs(P.duplicates) do if set.title:lower():find("emma", 1, true) then emma = set end end
            check("Emma in three spellings is one set of three", emma ~= nil and #emma.copies == 3, emma and #emma.copies)
            check("the suggested copy is an EPUB, not the MOBI", emma ~= nil and Formats.extension(emma.copies[1].name) == "epub", emma and emma.copies[1].name)
            check("its title has no half extension", emma ~= nil and not emma.title:find(".", 1, true), emma and emma.title)
        end, 0 },
        ---------------------------------------------------------------- deleting for real (the library is rebuilt before each run)
        { nil, function()
            local e = entry(root .. "/Classics", "Frankenstein.fb2")
            check("the file to delete is in the tree", e ~= nil)
            P:deleteMany({ e })
        end, 3 },
        { nil, function()
            check("deleting one file removes it from disk", not exists(root .. "/Classics/Frankenstein.fb2"))
            check("and from the tree", entry(root .. "/Classics", "Frankenstein.fb2") == nil)
            check("the others are untouched", exists(root .. "/Classics/Dracula.epub"))
        end, 0 },
        { nil, function()
            S():setDir(root .. "/Comics") S():setSelecting(true)
            local by_name = {}
            for _, x in ipairs(P.tree[root .. "/Comics"].entries) do by_name[x.name] = x end
            S():select({ by_name["Saga v1.cbz"], by_name["Saga v2.cbz"] }, true)
            check("the Delete bar appears for a selection", S().bar_hits ~= nil and #S().bar_hits == 2)
            S().bar_hits[2].callback()
        end, 2 },
        { "delete-several-confirm", function() ok_dialog() end, 3 },
        { nil, function()
            check("deleting several removes them from disk", not exists(root .. "/Comics/Saga v1.cbz") and not exists(root .. "/Comics/Saga v2.cbz"))
            check("a row that was not ticked stays", exists(root .. "/Comics/Maus.cbz"))
            check("selection mode ends afterwards", not S().selecting)
        end, 0 },
        { nil, function()
            local set
            for _, s in ipairs(P.duplicates) do if s.title:find("Mistborn") then set = s end end
            check("a Mistborn set exists", set ~= nil)
            if not set then return end
            local keep = S():keeper(set)
            state.kept = set.copies[keep].path
            state.cleared = set.copies[keep == 1 and 2 or 1].path
            P:confirmClearCopies(set, keep)
        end, 2 },
        { nil, function() ok_dialog() end, 4 },
        { nil, function()
            check("clearing copies keeps the one chosen", state.kept and exists(state.kept), state.kept)
            check("and removes the other", state.cleared and not exists(state.cleared), state.cleared)
            check("the set is gone from the list", #P.duplicates == state.sets - 1, #P.duplicates)
        end, 0 },
        { "library-after", function() S():switchTab("library") S():setDir(root) end, 2 },
    }
    local i = 0
    local function nextStep()
        i = i + 1
        local s = steps[i]
        if not s then
            logger.info(string.format("TESTS %d passed, %d failed", pass, fail))
            logger.info("shotdriver: done")
            UIManager:quit(0)
            return
        end
        local ok, err = pcall(s[2])
        if not ok then
            fail = fail + 1
            logger.err("TEST FAIL step " .. tostring(s[1] or i) .. " raised: " .. tostring(err))
        end
        UIManager:scheduleIn(s[3], function()
            if s[1] then
                Device.screen:shot(OUT .. s[1] .. ".png")
                logger.info("shotdriver: shot " .. s[1])
            end
            nextStep()
        end)
    end
    UIManager:scheduleIn(4, nextStep)
end

return Driver
