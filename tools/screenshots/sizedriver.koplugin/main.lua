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
