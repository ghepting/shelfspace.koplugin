-- A small modal menu: a title and a grid of buttons, each with an icon in front of its label. KOReader's own
-- button dialog shows an icon or a label, never both. Tapping outside closes it, as does the Back key.
local Device = require("device")
local CenterContainer = require("ui/widget/container/centercontainer")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local InputContainer = require("ui/widget/container/inputcontainer")
local LineWidget = require("ui/widget/linewidget")
local Size = require("ui/size")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local Screen = Device.screen

local Icons = require("shelfspace/icons")
local UI = require("shelfspace/ui")
local sp = UI.sp

-- rows = { { { text, icon = <Icons.actionWidget name>, callback }, ... }, ... }: one to a row fills it.
local MenuDialog = InputContainer:extend{
    modal = true,
    title = nil,
    rows = nil,
    theme = nil,
}

function MenuDialog:init()
    local th = self.theme
    self.dimen = Geom:new{ x = 0, y = 0, w = Screen:getWidth(), h = Screen:getHeight() }
    if Device:hasKeys() then self.key_events.Close = { { Device.input.group.Back } } end
    self.ges_events.TapClose = { GestureRange:new{ ges = "tap", range = self.dimen } }

    local pad, gap = sp(14), sp(10)
    local inner = math.min(math.floor(self.dimen.w * 0.88), sp(560)) - 2 * (pad + Size.border.window)
    local body = VerticalGroup:new{ align = "center" }
    if self.title then
        table.insert(body, UI.text(self.title, 22, { color = th.ink }))
        table.insert(body, VerticalSpan:new{ width = sp(10) })
        table.insert(body, LineWidget:new{ dimen = Geom:new{ w = inner, h = Size.line.thin }, background = th.line })
        table.insert(body, VerticalSpan:new{ width = sp(12) })
    end
    for r, row in ipairs(self.rows) do
        local width = math.floor((inner - gap * (#row - 1)) / #row)
        local line = HorizontalGroup:new{ align = "center" }
        for c, cell in ipairs(row) do
            if c > 1 then table.insert(line, HorizontalSpan:new{ width = gap }) end
            table.insert(line, UI.button(th, {
                text = cell.text, size = 18, width = width,
                label_icon = cell.icon and Icons.actionWidget(cell.icon, sp(24), th.ink, th.white),
                callback = function()
                    UIManager:close(self)
                    cell.callback()
                end,
            }))
        end
        table.insert(body, line)
        if r < #self.rows then table.insert(body, VerticalSpan:new{ width = gap }) end
    end
    self.frame = FrameContainer:new{
        bordersize = Size.border.window, radius = Size.radius.window, margin = 0, padding = pad,
        background = th.white, color = th.ink,
        body,
    }
    self[1] = CenterContainer:new{ dimen = self.dimen, self.frame }
end

function MenuDialog:onTapClose(arg, ges)
    if self.frame.dimen and ges.pos and not ges.pos:intersectWith(self.frame.dimen) then
        UIManager:close(self)
    end
    return true
end

function MenuDialog:onClose()
    UIManager:close(self)
    return true
end

function MenuDialog:onShow()
    UIManager:setDirty(self, function() return "ui", self.frame.dimen end)
end

function MenuDialog:onCloseWidget()
    UIManager:setDirty(nil, "ui")
end

return MenuDialog
