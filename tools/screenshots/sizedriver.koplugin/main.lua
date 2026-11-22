local UIManager = require("ui/uimanager")
local Device = require("device")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local logger = require("logger")
-- Opens ShelfSpace in a KOReader running at one screen size, visits each tab (and the selected state of the lists), saves a PNG of
-- each, and checks that nothing runs off the bottom of the screen. Run it through tools/screenshots/sizes.sh.
local OUT = assert(os.getenv("SHOT_OUT"), "SHOT_OUT is not set") .. "/"

local Driver = WidgetContainer:extend{ name = "zsizedriver", is_doc_only = false }

-- Waits until KOReader has settled, then calls `fn`: nothing waiting to be drawn or refreshed, and no task due soon (the scanner works in
-- small scheduled steps, a dialog paints on the next tick). `cap` seconds is the most it waits, for anything that never settles. This
-- replaces fixed waits, which spent most of a run doing nothing: a screen is built and drawn in a few milliseconds.
-- A fresh data folder makes KOReader show a passing message ("Book info cache database updated.") that closes itself a few seconds
-- later. The run does not wait for it: it is closed before the first step, so it is never on top of what is being checked or shot.
local function closeMessages()
    local InfoMessage = require("ui/widget/infomessage")
    for k = #UIManager._window_stack, 1, -1 do
        local w = UIManager._window_stack[k].widget
        if getmetatable(w) == InfoMessage then UIManager:close(w) end
    end
end

local function settle(cap, fn)
    local time = require("ui/time")
    local deadline, quiet = time.now() + time.s(cap), 0
    local function poll()
        local busy = next(UIManager._dirty) ~= nil or #UIManager._refresh_stack > 0
        if not busy then
            local soon = time.now() + time.s(0.25)
            for _, task in ipairs(UIManager._task_queue) do
                if task.action ~= poll and task.time < soon then busy = true break end
            end
        end
        quiet = busy and 0 or quiet + 1
        if quiet >= 2 or time.now() >= deadline then return fn() end
        UIManager:scheduleIn(0.05, poll)
    end
    UIManager:scheduleIn(0.05, poll)
end

function Driver:init()
    if self.ui.document then return end
    local P = self.ui.shelfspace
    local failed = 0
    local function S() return P.screen end
    -- The page is a column; it fits when the column is no taller than the screen.
    local function fits(name)
        local column = S()[1][1]
        column:resetLayout()
        local h, screen_h = column:getSize().h, Device.screen:getHeight()
        local ok = h <= screen_h
        if not ok then failed = failed + 1 end
        logger.info(string.format("SIZE %s %s: page is %d px of %d", ok and "PASS" or "FAIL", name, h, screen_h))
    end
    local function shot(name)
        fits(name)
        Device.screen:shot(OUT .. name .. ".png")
    end
    -- A copy's card answers a tap anywhere on it, not only where its text is. Taps what a tap at (x, y) would reach: the tappable, deepest
    -- first, whose area as last drawn holds the point. The second copy is the one kept when this runs, so a tap that reaches the first card
    -- changes the keeper back to it.
    local function state_tap(where, fraction)
        local Geom = require("ui/geometry")
        local set = S():currentSet()
        local w = Device.screen:getWidth()
        local cards = {}
        local function walk(widget)
            for _, child in ipairs(widget) do if type(child) == "table" then walk(child) end end
            if widget.ges_events and widget.dimen and widget.dimen.w > w * 0.4 and widget.dimen.h > Device.screen:getHeight() * 0.04 then
                for name in pairs(widget.ges_events) do
                    if name:match("^TapRow") then table.insert(cards, { dimen = widget.dimen, on = widget["on" .. name] }) end
                end
            end
        end
        walk(S()[1])
        table.sort(cards, function(a, b) return a.dimen.y < b.dimen.y end)
        local first = cards[1]
        local ok = false
        if first then
            local x = math.floor(first.dimen.x + (first.dimen.w - 20) * fraction)
            local y = first.dimen.y + math.floor(first.dimen.h / 2)
            if first.dimen:contains(Geom:new{ x = x, y = y, w = 0, h = 0 }) then
                first.on()
                ok = S():keeper(set) == 1
            end
        end
        S():setKeeper(set, 2)
        if not ok then failed = failed + 1 end
        logger.info(string.format("SIZE %s a tap on the %s of a copy's card chooses it", ok and "PASS" or "FAIL", where))
    end
    local function check(name, ok)
        if not ok then failed = failed + 1 end
        logger.info(string.format("SIZE %s %s", ok and "PASS" or "FAIL", name))
    end
    local pages_shown = {}
    local sideways = Device.screen:getWidth() > Device.screen:getHeight()
    local function check_pages(tab)
        local before = pages_shown[tab]
        local pages, rows = S().page_count, S().per_page
        check(string.format("hiding the summary on %s: %d rows a page (was %d), %d page(s) (was %d)", tab, rows, before[2], pages, before[1]),
            (sideways and rows >= before[2] or rows > before[2]) and pages <= before[1])
    end
    local steps = {
        { function() P:showOverview() end, 4 },
        { function() shot("library") end, 1 },
        { function() S():switchTab("koreader") end, 2 },
        { function() shot("koreader") end, 1 },
        { function() S():toggleKey(require("shelfspace/cleanup").targets(P.tree, P.koreader_dir, false, P.root)[1].title) end, 2 },
        { function() shot("koreader-selected") end, 1 },
        { function() S():switchTab("duplicates") end, 2 },
        { function() shot("duplicates") end, 1 },
        { function() S():openSet(P.duplicates[1].id) end, 2 },
        { function() shot("duplicates-set") end, 1 },
        { function() S():setKeeper(S():currentSet(), 2) end, 2 },
        { function() state_tap("text side", 0.2) end, 2 },
        { function() state_tap("right edge", 1) end, 2 },
        { function() S():closeSet() S():switchTab("library") for _, e in ipairs(P.tree[P.root].entries) do if e.name == "Comics" then S():toggle(e) end end end, 2 },
        { function() shot("library-selected") end, 1 },
        { function() S():clearSelection() S():setDir(P.root .. "/Comics") end, 2 },
        { function() shot("library-folder") end, 1 },
        { function() S():setDir(P.root) S():toggleFilter("epub") end, 2 },
        { function() shot("library-filtered") end, 1 },
        -- With the chart and summary hidden, every tab still fits. Upright the list gains the rows the chart took; sideways it already had the
        -- full height beside the column, so it gains width instead and keeps its rows. Either way it needs no more pages than before.
        { function() S():toggleFilter("epub") S():setPage(1) pages_shown.library = { S().page_count, S().per_page } end, 2 },
        { function() S():switchTab("koreader") pages_shown.koreader = { S().page_count, S().per_page } end, 2 },
        { function() S():switchTab("library") S():toggleSummary() end, 2 },
        { function() shot("library-hidden") check_pages("library") end, 1 },
        { function() S():switchTab("koreader") end, 2 },
        { function() shot("koreader-hidden") check_pages("koreader") end, 1 },
        { function() S():switchTab("duplicates") end, 2 },
        { function() shot("duplicates-hidden") end, 1 },
        { function() S():openSet(P.duplicates[1].id) end, 2 },
        { function() shot("duplicates-set-hidden") check("a set of duplicates keeps its title and Back", not S():summaryHideable()) end, 1 },
        { function() S():closeSet() S():switchTab("library") S():toggleSummary() end, 2 },
        { function() shot("library-shown-again") check("the summary comes back", not S().summary_hidden) end, 1 },
        { function() logger.info("sizedriver: done, " .. failed .. " failed") UIManager:quit() end, 0 },
    }
    local i = 0
    local function nxt()
        i = i + 1
        local step = steps[i]
        if not step then return end
        local ok, err = pcall(step[1])
        if not ok then failed = failed + 1 logger.err("SIZE FAIL step " .. i .. ": " .. tostring(err)) end
        settle(math.max(step[2], 1), nxt)
    end
    settle(10, function() closeMessages() settle(1, nxt) end)
end

return Driver
