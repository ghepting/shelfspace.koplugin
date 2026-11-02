local UIManager = require("ui/uimanager")
local Device = require("device")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local logger = require("logger")
-- Opens ShelfSpace in a KOReader running at one screen size, visits each tab (and the selected state of the lists), saves a PNG of
-- each, and checks that nothing runs off the bottom of the screen. Run it through tools/screenshots/sizes.sh.
local OUT = assert(os.getenv("SHOT_OUT"), "SHOT_OUT is not set") .. "/"

local Driver = WidgetContainer:extend{ name = "zsizedriver", is_doc_only = false }

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
            if widget.ges_events and widget.dimen and widget.dimen.w > w * 0.4 and widget.dimen.h > Device.screen:getHeight() * 0.1 then
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
        { function() logger.info("sizedriver: done, " .. failed .. " failed") UIManager:quit() end, 0 },
    }
    local i = 0
    local function nxt()
        i = i + 1
        local step = steps[i]
        if not step then return end
        local ok, err = pcall(step[1])
        if not ok then failed = failed + 1 logger.err("SIZE FAIL step " .. i .. ": " .. tostring(err)) end
        UIManager:scheduleIn(step[2], nxt)
    end
    UIManager:scheduleIn(3, nxt)
end

return Driver
