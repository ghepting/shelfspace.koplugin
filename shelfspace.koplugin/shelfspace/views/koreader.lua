local CenterContainer = require("ui/widget/container/centercontainer")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local LineWidget = require("ui/widget/linewidget")
local RightContainer = require("ui/widget/container/rightcontainer")
local Size = require("ui/size")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local util = require("util")
local _ = require("gettext")
local T = require("ffi/util").template

local Cleanup = require("shelfspace/cleanup")
local UI = require("shelfspace/ui")
local sp = UI.sp

local ROW_H = sp(62)

-- KOReader's own data: what can be cleared, each with its size and a Clear button.
return function(screen, th, width)
    local plugin = screen.plugin
    local tree = plugin.tree
    if not tree then
        return { hero = UI.hero(th, width, {
            color = th.koreader, label = _("DATA"), title = _("KOReader"), subtitle = _("Scanning…"),
        }), message = _("Scanning your library…") }
    end

    local targets = Cleanup.targets(tree, plugin.koreader_dir, plugin.ui.document ~= nil)
    local can_free, safe_free, safe = 0, 0, {}
    for i, t in ipairs(targets) do
        if t.size > 0 and not t.blocked then
            can_free = can_free + t.size
            if t.safe then
                safe_free = safe_free + t.size
                table.insert(safe, t)
            end
        end
    end

    local hero = UI.hero(th, width, {
        color = th.koreader,
        label = _("DATA"),
        title = util.getFriendlySize(tree[plugin.koreader_dir].size),
        subtitle = _("KOReader's own data"),
        chips = { T(_("CAN FREE %1"), util.getFriendlySize(can_free)) },
    })

    local gap = sp(10)
    local size_w = sp(78)
    local body = VerticalGroup:new{ align = "left" }
    for i, t in ipairs(targets) do
        local clearable = t.size > 0
        local button = UI.button(th, {
            text = _("Clear"),
            size = 15,
            enabled = clearable,
            callback = function()
                if t.blocked then
                    plugin:notify(t.blocked)
                else
                    plugin:confirmClear({ t }, t.title:lower())
                end
            end,
        })
        local label = t.count and T(_("%1 (%2)"), t.title, t.count) or t.title
        local text_w = width - size_w - button:getSize().w - 2 * gap
        local title = UI.text(label, 19, { bold = true, color = clearable and th.ink or th.muted, max_width = text_w })
        local note = UI.text(t.blocked or t.note, 14, { color = th.muted, max_width = text_w })
        local used = math.max(title:getSize().w, note:getSize().w)
        table.insert(body, FrameContainer:new{
            bordersize = 0, padding = 0, margin = 0,
            VerticalGroup:new{
                align = "left",
                CenterContainer:new{
                    dimen = Geom:new{ w = width, h = ROW_H - Size.line.thin },
                    HorizontalGroup:new{
                        align = "center",
                        VerticalGroup:new{ align = "left", title, note },
                        HorizontalSpan:new{ width = text_w - used },
                        RightContainer:new{
                            dimen = Geom:new{ w = size_w, h = sp(30) },
                            UI.text(util.getFriendlySize(t.size), 17, { bold = true, color = th.ink }),
                        },
                        HorizontalSpan:new{ width = gap },
                        button,
                    },
                },
                LineWidget:new{ dimen = Geom:new{ w = width, h = Size.line.thin }, background = th.line },
            },
        })
    end
    local bottom = UI.button(th, {
        text = T(_("Clear cache, updates and logs · %1"), util.getFriendlySize(safe_free)),
        width = width,
        enabled = safe_free > 0,
        background = th.chip,
        disabled_background = th.bg,
        callback = function()
            plugin:confirmClear(safe, _("cache, updates and logs"))
        end,
    })
    return { hero = hero, body = body, bottom = bottom }
end
