local _ = require("gettext")
local Device = require("device")
local InfoMessage = require("ui/widget/infomessage")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local util = require("util")
local T = require("ffi/util").template

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

-- Free/used space on the partition that holds the library.
function ShelfSpace:showOverview()
    local path = G_reader_settings:readSetting("home_dir") or Device.home_dir or "/"
    local usage = util.diskUsage(path)
    if not usage or not usage.total or usage.total == 0 then
        UIManager:show(InfoMessage:new { text = _("Could not read storage usage.") })
        return
    end
    UIManager:show(InfoMessage:new {
        text = T(_("Free: %1\nUsed: %2\nTotal: %3"),
            util.getFriendlySize(usage.available),
            util.getFriendlySize(usage.used),
            util.getFriendlySize(usage.total)),
    })
end

return ShelfSpace
