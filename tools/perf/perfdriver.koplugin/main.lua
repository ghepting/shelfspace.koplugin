-- Opens ShelfSpace on a large made-up library and times what a person does with it: the scan (first and again), building the
-- Library, selecting a row, the Finished filter, turning a page, the badges, deleting many books at once, and the other tabs; and
-- how much memory it takes while open and leaves behind once closed.
-- Prints one "PERF <step> <ms>" line per step, then "perfdriver: done", and quits. It deletes books, so it only runs on the
-- library tools/perf/make-library.py builds (PERF_LIBRARY).
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local logger = require("logger")
local time = require("ui/time")

local Driver = WidgetContainer:extend{ name = "perfdriver", is_doc_only = false }

local function closeMessages()
    local InfoMessage = require("ui/widget/infomessage")
    for k = #UIManager._window_stack, 1, -1 do
        local w = UIManager._window_stack[k].widget
        if getmetatable(w) == InfoMessage then UIManager:close(w) end
    end
end

-- What Lua holds, after a full collection, in MB.
local function heap()
    collectgarbage("collect")
    collectgarbage("collect")
    return collectgarbage("count") / 1024
end

local function report(step, started, extra)
    logger.info(string.format("PERF %-22s %7.1f ms%s", step, time.to_ms(time.since(started)) * 1.0, extra and ("  " .. extra) or ""))
end

-- Times a step that is done when it returns.
local function timed(step, fn)
    local started = time.now()
    fn()
    report(step, started)
end

function Driver:init()
    if self.ui.document then return end
    assert(os.getenv("PERF_LIBRARY"), "PERF_LIBRARY is not set")
    local util = require("util")
    util.diskUsage = function() return { total = 32000000000, used = 20000000000, available = 12000000000 } end
    local P -- ShelfSpace loads after this plugin (plugins load by name), so it is looked up when the run starts
    local function S() return P.screen end

    local steps = {}
    local function add(fn) table.insert(steps, fn) end
    local function nextStep()
        local fn = table.remove(steps, 1)
        if not fn then
            logger.info("perfdriver: done")
            UIManager:quit()
            return
        end
        UIManager:scheduleIn(0.05, function() fn(nextStep) end)
    end

    -- The first scan reads every folder; the second has the cache from the first.
    local base
    add(function(go)
        closeMessages()
        base = heap()
        logger.info(string.format("PERF %-22s %7.1f MB", "memory before opening", base))
        local started = time.now()
        local scan = P.scan
        P.scan = function(plugin, done)
            scan(plugin, function()
                report("open, first scan", started, string.format("%d folders, %d files", require("shelfspace/scanner").count(P.tree)))
                P.scan = scan
                done()
                go()
            end)
        end
        P:showOverview()
    end)
    add(function(go)
        S():onClose()
        P.tree = nil
        local started = time.now()
        local scan = P.scan
        P.scan = function(plugin, done)
            scan(plugin, function() report("open, cached scan", started) P.scan = scan done() go() end)
        end
        P:showOverview()
    end)
    add(function(go)
        timed("refresh after a scan", function() P:refresh() end)
        timed("  of which duplicates", function() P:findDuplicates() end)
        local f = require("datastorage"):getDataDir() .. "/cache/shelfspace/scan.txt"
        logger.info(string.format("PERF %-22s %7.1f MB", "saved scan", (require("libs/libkoreader-lfs").attributes(f, "size") or 0) / 1e6))
        go()
    end)
    add(function(go)
        logger.info(string.format("PERF %-22s %7.1f MB", "memory while open", heap() - base))
        go()
    end)
    add(function(go) timed("build Library", function() S():refresh() end) go() end)
    add(function(go)
        local e = S().plugin.tree[P.root].entries[1]
        timed("select a row", function() S():toggle(e) end)
        timed("unselect it", function() S():toggle(e) end)
        go()
    end)
    add(function(go) timed("All books", function() S():toggleBooks() end) go() end)
    add(function(go) timed("next page", function() S():setPage(2) end) go() end)
    add(function(go)
        local entries = S().list_cache.entries
        local page = {}
        for i = 1, math.min(#entries, S().per_page or 10) do page[i] = entries[i] end
        timed("select a page", function() S():select(page, true) end)
        go()
    end)
    add(function(go) S().selected = {} timed("Finished filter", function() S():showFinished() end) go() end)
    add(function(go)
        local e = S().plugin.tree[P.root].entries[1]
        timed("select, Finished on", function() S():toggle(e) end)
        S().selected = {}
        go()
    end)
    add(function(go) timed("Large files", function() S():showLarge() end) go() end)
    add(function(go) timed("clear filters", function() S():clearFilters() end) go() end)
    add(function(go)
        timed("badges (fresh)", function() S().shortcuts_at = nil S():refresh() end)
        go()
    end)
    -- Deleting many: every finished book in the library, in one go, as the Finished badge offers.
    add(function(go)
        local Search, Deleter, BookList = require("shelfspace/search"), require("shelfspace/deleter"), require("ui/widget/booklist")
        local items = Search.find(P.tree, P.root, nil, nil, function(e) return Deleter.isBook(e) and BookList.getBookStatus(e.path) == "complete" end)
        -- The files themselves (and their sidecars) going is KOReader's and the disk's; the rest is ShelfSpace keeping its tree up to date.
        local Scanner = require("shelfspace/scanner")
        local own, remove = 0, Scanner.remove
        Scanner.remove = function(...)
            local t = time.now()
            remove(...)
            own = own + time.since(t)
        end
        local started = time.now()
        P:deleteMany(items, function()
            Scanner.remove = remove
            report("delete finished", started, string.format("%d books, of which updating the tree %.0f ms", #items, time.to_ms(own)))
            go()
        end)
    end)
    add(function(go) timed("KOReader tab", function() S():switchTab("koreader") end) go() end)
    add(function(go) timed("duplicates (find)", function() P:findDuplicates() end) go() end)
    add(function(go) timed("Duplicates tab", function() S():switchTab("duplicates") end) go() end)
    add(function(go) S():onClose() go() end)
    add(function(go)
        -- What ShelfSpace leaves behind once closed, while you go on reading: its own scan, and the reading status of every book it
        -- asked KOReader about (KOReader's cache, which it never empties by itself).
        logger.info(string.format("PERF %-22s %7.1f MB", "memory after closing", heap() - base))
        local n = 0
        for _ in pairs(require("ui/widget/booklist").book_info_cache) do n = n + 1 end
        logger.info(string.format("PERF %-22s %7d books", "  KOReader's status cache", n))
        go()
    end)

    UIManager:scheduleIn(0.5, function() P = self.ui.shelfspace nextStep() end)
end

return Driver
