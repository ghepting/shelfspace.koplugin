local _ = require("gettext")
local Device = require("device")
local InfoMessage = require("ui/widget/infomessage")
local Menu = require("ui/widget/menu")
local Scanner = require("scanner")
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
        sub_item_table = {
            { text = _("Free space"), callback = function() self:showOverview() end },
            { text = _("Browse by size"), callback = function() self:browse() end },
        },
    }
end

local function libraryPath()
    return G_reader_settings:readSetting("home_dir") or Device.home_dir or "/"
end

-- Scans the library, then shows folders and files largest-first; tap a folder to drill in.
function ShelfSpace:browse()
    local root = libraryPath()
    local scanning = InfoMessage:new { text = _("Scanning…") }
    UIManager:show(scanning)
    Scanner.scan(root, function(tree)
        UIManager:close(scanning)
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
            for i, e in ipairs(tree[dir].entries) do entries[i] = e end
            table.sort(entries, function(a, b) return a.size > b.size end)
            for _, e in ipairs(entries) do
                table.insert(items, {
                    text = e.is_dir and (e.name .. "/") or e.name,
                    mandatory = util.getFriendlySize(e.size),
                    callback = e.is_dir and function() show(e.path) end or nil,
                })
            end
            local title = T(_("%1 (%2)"), dir, util.getFriendlySize(tree[dir].size))
            if menu then
                menu:switchItemTable(title, items)
            else
                menu = Menu:new {
                    title = title,
                    item_table = items,
                    covers_fullscreen = true,
                    is_borderless = true,
                    close_callback = function() UIManager:close(menu) end,
                }
                UIManager:show(menu)
            end
        end
        show(root)
    end)
end

-- Free/used space on the partition that holds the library.
function ShelfSpace:showOverview()
    local path = libraryPath()
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
