local Button = require("ui/widget/button")
local Device = require("device")
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local InputContainer = require("ui/widget/container/inputcontainer")
local LineWidget = require("ui/widget/linewidget")
local Size = require("ui/size")
local TextWidget = require("ui/widget/textwidget")
local TitleBar = require("ui/widget/titlebar")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local util = require("util")
local _ = require("gettext")
local T = require("ffi/util").template
local Screen = Device.screen

local Theme = require("shelfspace/theme")

-- Free space, a usage bar and a books / KOReader / other breakdown.
-- `breakdown` stays nil while the library scan is running.
local Overview = InputContainer:extend{
    usage = nil, -- { total, used, available } in bytes
    breakdown = nil, -- { books, koreader, other } in bytes
    on_browse = nil,
}

-- A solid w x h block; FrameContainer takes its size from its content.
local function block(w, h, color, radius)
    return FrameContainer:new{
        bordersize = 0, padding = 0, margin = 0, radius = radius, background = color,
        HorizontalGroup:new{ HorizontalSpan:new{ width = w }, VerticalSpan:new{ width = h } },
    }
end

function Overview:init()
    self.dimen = Geom:new{ x = 0, y = 0, w = Screen:getWidth(), h = Screen:getHeight() }
    self.covers_fullscreen = true
    if Device:hasKeys() then
        self.key_events.Close = { { Device.input.group.Back } }
    end
    self.theme = Theme.get()
    self:rebuild()
end

function Overview:setBreakdown(breakdown)
    if self.closed then return end
    self.breakdown = breakdown
    self:rebuild()
    UIManager:setDirty(self, "ui")
end

function Overview:buildBar(width, height)
    local th, u, b = self.theme, self.usage, self.breakdown
    local inner = width - 2 * Size.border.thin
    local parts
    if b then
        parts = { { b.books, th.books }, { b.koreader, th.koreader }, { b.other, th.other } }
    else
        parts = { { u.used, th.other } }
    end
    local row = HorizontalGroup:new{}
    local used_w = 0
    for _, part in ipairs(parts) do
        local w = math.floor(inner * part[1] / u.total)
        if w > 0 then
            table.insert(row, block(w, height, part[2]))
            used_w = used_w + w
        end
    end
    table.insert(row, block(inner - used_w, height, th.free))
    return FrameContainer:new{
        bordersize = Size.border.thin, padding = 0, margin = 0,
        radius = Size.radius.button, color = th.ink, background = th.free,
        row,
    }
end

function Overview:buildRow(width, color, label, size_text)
    local th = self.theme
    local dot = Screen:scaleBySize(14)
    local gap = Screen:scaleBySize(12)
    local face = Font:getFace("cfont", 22)
    local label_w = TextWidget:new{ text = label, face = face, bold = true, fgcolor = th.ink }
    local size_w = TextWidget:new{ text = size_text, face = face, fgcolor = th.ink }
    local spacer = width - dot - gap - label_w:getSize().w - size_w:getSize().w
    return HorizontalGroup:new{
        align = "center",
        FrameContainer:new{
            bordersize = Size.border.thin, padding = 0, margin = 0,
            radius = dot, color = th.ink, background = color,
            HorizontalGroup:new{ HorizontalSpan:new{ width = dot }, VerticalSpan:new{ width = dot } },
        },
        HorizontalSpan:new{ width = gap },
        label_w,
        HorizontalSpan:new{ width = math.max(spacer, 0) },
        size_w,
    }
end

function Overview:rebuild()
    local th, u, b = self.theme, self.usage, self.breakdown
    local pad = Screen:scaleBySize(16)
    local width = self.dimen.w - 2 * pad
    local row_h = Screen:scaleBySize(44)

    local titlebar = TitleBar:new{
        width = self.dimen.w,
        fullscreen = true,
        title = _("Shelf Space"),
        with_bottom_line = true,
        close_callback = function() self:onClose() end,
        show_parent = self,
    }

    local body = VerticalGroup:new{
        align = "left",
        TextWidget:new{ text = util.getFriendlySize(u.available), face = Font:getFace("tfont", 44), fgcolor = th.ink },
        TextWidget:new{
            text = T(_("free of %1"), util.getFriendlySize(u.total)),
            face = Font:getFace("cfont", 22), fgcolor = th.muted,
        },
        VerticalSpan:new{ width = pad },
        self:buildBar(width, Screen:scaleBySize(22)),
        VerticalSpan:new{ width = pad },
    }

    local rows
    if b then
        rows = {
            { th.books, _("Books"), util.getFriendlySize(b.books) },
            { th.koreader, _("KOReader data"), util.getFriendlySize(b.koreader) },
            { th.other, _("Other files"), util.getFriendlySize(b.other) },
            { th.free, _("Free"), util.getFriendlySize(u.available) },
        }
    else
        rows = {
            { th.other, _("Used"), util.getFriendlySize(u.used) },
            { th.free, _("Free"), util.getFriendlySize(u.available) },
        }
    end
    for _, r in ipairs(rows) do
        table.insert(body, FrameContainer:new{
            bordersize = 0, padding = 0, margin = 0, height = row_h,
            VerticalGroup:new{
                align = "left",
                VerticalSpan:new{ width = Screen:scaleBySize(10) },
                self:buildRow(width, r[1], r[2], r[3]),
                VerticalSpan:new{ width = Screen:scaleBySize(10) },
                LineWidget:new{ dimen = Geom:new{ w = width, h = Size.line.thin }, background = th.line },
            },
        })
    end
    if not b then
        table.insert(body, VerticalSpan:new{ width = Screen:scaleBySize(8) })
        table.insert(body, TextWidget:new{
            text = _("Scanning your library…"),
            face = Font:getFace("cfont", 20), fgcolor = th.muted,
        })
    end

    table.insert(body, VerticalSpan:new{ width = pad })
    table.insert(body, Button:new{
        text = _("Browse by size"),
        width = width,
        radius = Size.radius.button,
        background = th.chip,
        enabled = b ~= nil,
        callback = function()
            if self.on_browse then self.on_browse() end
        end,
    })

    self[1] = FrameContainer:new{
        bordersize = 0, padding = 0, margin = 0, background = th.bg,
        width = self.dimen.w, height = self.dimen.h,
        VerticalGroup:new{
            align = "left",
            titlebar,
            FrameContainer:new{ bordersize = 0, padding = pad, margin = 0, background = th.bg, body },
        },
    }
end

function Overview:onShow()
    UIManager:setDirty(self, function() return "ui", self.dimen end)
end

function Overview:onCloseWidget()
    self.closed = true
    UIManager:setDirty(nil, "ui")
end

function Overview:onClose()
    UIManager:close(self)
    return true
end

return Overview
