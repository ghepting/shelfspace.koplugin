local CenterContainer = require("ui/widget/container/centercontainer")
local Device = require("device")
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local InputContainer = require("ui/widget/container/inputcontainer")
local Size = require("ui/size")
local TextWidget = require("ui/widget/textwidget")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local _ = require("gettext")
local T = require("ffi/util").template
local Screen = Device.screen

-- Small building blocks shared by the screens.
local UI = {}

function UI.sp(n) return Screen:scaleBySize(n) end
local sp = UI.sp

function UI.text(text, size, opts)
    opts = opts or {}
    return TextWidget:new{
        text = text,
        face = Font:getFace(opts.face or "cfont", size),
        bold = opts.bold,
        fgcolor = opts.color,
        max_width = opts.max_width,
    }
end

-- A solid w x h block; FrameContainer takes its size from its content.
function UI.block(w, h, color, radius)
    return FrameContainer:new{
        bordersize = 0, padding = 0, margin = 0, radius = radius, background = color,
        HorizontalGroup:new{ HorizontalSpan:new{ width = w }, VerticalSpan:new{ width = h } },
    }
end

function UI.chip(th, text)
    return FrameContainer:new{
        bordersize = Size.border.thin, color = th.ink, radius = sp(14),
        padding = sp(2), padding_left = sp(9), padding_right = sp(9), margin = 0,
        UI.text(text, 13, { bold = true, color = th.ink }),
    }
end

-- A rounded track with a filled share of it.
function UI.bar(th, width, height, fraction, fill)
    fraction = math.max(0, math.min(1, fraction))
    local radius = math.floor(height / 4)
    local filled = math.floor(width * fraction)
    local row = HorizontalGroup:new{}
    if filled > 0 then table.insert(row, UI.block(filled, height, fill, radius)) end
    table.insert(row, UI.block(width - filled, height, th.free))
    return FrameContainer:new{
        bordersize = 0, padding = 0, margin = 0, radius = radius, background = th.free, row,
    }
end

-- Wraps a widget so a tap (and optionally a hold) on it calls back.
function UI.tappable(widget, on_tap, on_hold)
    local size = widget:getSize()
    local c = InputContainer:new{ dimen = Geom:new{ w = size.w, h = size.h }, widget }
    c.ges_events = {
        TapRow = { GestureRange:new{ ges = "tap", range = c.dimen } },
        HoldRow = { GestureRange:new{ ges = "hold", range = c.dimen } },
    }
    c.onTapRow = function()
        if on_tap then on_tap() end
        return true
    end
    c.onHoldRow = function()
        if on_hold then on_hold() end
        return true
    end
    return c
end

-- tabs = { { id, label }, ... }; the active one is filled.
function UI.tabbar(th, width, tabs, active, on_select)
    local h = sp(42)
    local border = Size.border.thin
    local inner = width - 2 * border
    local cell_w = math.floor(inner / #tabs)
    local row = HorizontalGroup:new{}
    for i, tab in ipairs(tabs) do
        local on = tab.id == active
        local w = (i == #tabs) and (inner - cell_w * (#tabs - 1)) or cell_w
        local cell = FrameContainer:new{
            bordersize = 0, padding = 0, margin = 0, background = on and th.accent or th.bg,
            CenterContainer:new{
                dimen = Geom:new{ w = w, h = h },
                UI.text(tab.label, 15, { bold = true, color = on and th.white or th.ink }),
            },
        }
        table.insert(row, UI.tappable(cell, function() on_select(tab.id) end))
    end
    return FrameContainer:new{
        bordersize = border, padding = 0, margin = 0, radius = Size.radius.button, color = th.ink, row,
    }
end

-- « ‹ Page 1 of 3 › » ; on_page(n) is called with the page to show.
function UI.pager(th, width, page, pages, on_page)
    local h = sp(44)
    local cell_w = sp(56)
    local function cell(label, target)
        local c = CenterContainer:new{
            dimen = Geom:new{ w = cell_w, h = h },
            UI.text(label, 26, { color = target and th.ink or th.line }),
        }
        if not target then return c end
        return UI.tappable(c, function() on_page(target) end)
    end
    return HorizontalGroup:new{
        cell("«", page > 1 and 1 or nil),
        cell("‹", page > 1 and page - 1 or nil),
        CenterContainer:new{
            dimen = Geom:new{ w = width - 4 * cell_w, h = h },
            UI.text(T(_("Page %1 of %2"), page, pages), 16, { bold = true, color = th.ink }),
        },
        cell("›", page < pages and page + 1 or nil),
        cell("»", page < pages and pages or nil),
    }
end

-- spec: { color, label, title, subtitle, chips = { text... }, progress = { fraction, left, right } }
function UI.hero(th, width, spec)
    local cover_w, cover_h = sp(84), sp(108)
    local gap = sp(14)
    local info_w = width - cover_w - gap
    -- Shrink the label until it fits the tile.
    local label_max = cover_w - sp(12)
    local label
    for size = 15, 10, -1 do
        label = UI.text(spec.label, size, { bold = true, color = th.white })
        if label:getSize().w <= label_max then break end
    end
    if label:getSize().w > label_max then
        label = UI.text(spec.label, 10, { bold = true, color = th.white, max_width = label_max })
    end
    local cover = FrameContainer:new{
        bordersize = 0, padding = 0, margin = 0, radius = sp(8), background = spec.color,
        CenterContainer:new{ dimen = Geom:new{ w = cover_w, h = cover_h }, label },
    }
    local info = VerticalGroup:new{ align = "left" }
    table.insert(info, UI.text(spec.title, 30, { face = "tfont", color = th.ink, max_width = info_w }))
    table.insert(info, UI.text(spec.subtitle, 18, { color = th.muted, max_width = info_w }))
    if spec.chips and #spec.chips > 0 then
        local chips = HorizontalGroup:new{}
        for i, text in ipairs(spec.chips) do
            if i > 1 then table.insert(chips, HorizontalSpan:new{ width = sp(6) }) end
            table.insert(chips, UI.chip(th, text))
        end
        table.insert(info, VerticalSpan:new{ width = sp(6) })
        table.insert(info, chips)
    end
    if spec.progress then
        local p = spec.progress
        local left = UI.text(p.left, 14, { bold = true, color = th.ink })
        local right = UI.text(p.right, 14, { bold = true, color = th.ink })
        local gap2 = sp(8)
        local bar_w = info_w - left:getSize().w - right:getSize().w - 2 * gap2
        table.insert(info, VerticalSpan:new{ width = sp(8) })
        table.insert(info, HorizontalGroup:new{
            align = "center",
            left, HorizontalSpan:new{ width = gap2 },
            UI.bar(th, math.max(bar_w, sp(20)), sp(12), p.fraction, th.accent),
            HorizontalSpan:new{ width = gap2 }, right,
        })
    end
    return HorizontalGroup:new{ align = "center", cover, HorizontalSpan:new{ width = gap }, info }
end

return UI
