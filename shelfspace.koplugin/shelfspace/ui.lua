local CenterContainer = require("ui/widget/container/centercontainer")
local Device = require("device")
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local InputContainer = require("ui/widget/container/inputcontainer")
local LineWidget = require("ui/widget/linewidget")
local LeftContainer = require("ui/widget/container/leftcontainer")
local Size = require("ui/size")
local TextWidget = require("ui/widget/textwidget")
local Widget = require("ui/widget/widget")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local _ = require("gettext")
local T = require("ffi/util").template

local Icons = require("shelfspace/icons")
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

-- A title with a line of small print under it, grouped tight. A text box is taller than its letters (it leaves room above for
-- tall letters and below for the tails of g and y), so two stacked boxes float apart; the title is measured shorter here, which
-- closes the gap. Text is not clipped to its box, so nothing is cut off. `under` may be nil.
function UI.stack(title, under)
    title.forced_height = math.floor(title:getSize().h * 0.8)
    local group = VerticalGroup:new{ align = "left", title }
    if under then table.insert(group, under) end
    return group
end

-- A solid w x h block; FrameContainer takes its size from its content.
function UI.block(w, h, color, radius)
    return FrameContainer:new{
        bordersize = 0, padding = 0, margin = 0, radius = radius, background = color,
        HorizontalGroup:new{ HorizontalSpan:new{ width = w }, VerticalSpan:new{ width = h } },
    }
end

-- KOReader paints a container's border first and its contents over it, so square fills
-- poke out of rounded corners. This paints the child, masks the four corners with the
-- page colour, then draws the rounded outline on top, giving fills a clean rounded edge.
local RoundedClip = WidgetContainer:extend{ radius = 0, bg = nil, color = nil, border = 0 }

function RoundedClip:getSize()
    return self[1]:getSize()
end

function RoundedClip:paintTo(bb, x, y)
    local size = self:getSize()
    self[1]:paintTo(bb, x, y)
    local r = math.min(self.radius, math.floor(size.h / 2), math.floor(size.w / 2))
    for dy = 0, r - 1 do
        local dist = r - (dy + 0.5)
        local mask = math.floor(r - math.sqrt(r * r - dist * dist) + 0.5)
        if mask > 0 then
            bb:paintRect(x, y + dy, mask, 1, self.bg)
            bb:paintRect(x + size.w - mask, y + dy, mask, 1, self.bg)
            bb:paintRect(x, y + size.h - 1 - dy, mask, 1, self.bg)
            bb:paintRect(x + size.w - mask, y + size.h - 1 - dy, mask, 1, self.bg)
        end
    end
    if self.border > 0 then
        bb:paintBorder(x, y, size.w, size.h, self.border, self.color, r, true)
    end
end

function UI.rounded(th, widget, radius, border)
    return RoundedClip:new{ radius = radius, bg = th.bg, color = th.ink, border = border or 0, widget }
end

-- A rounded button of our own. KOReader's Button flashes by inverting its whole rectangle
-- when tapped and doesn't restore the rounded corners afterwards, and it only greys a disabled
-- button's label. Here a disabled button is a flat pale pill, and a tap just calls back.
-- opts: text, size, width (fixed, else as wide as the label), enabled, callback,
-- background (fill of an enabled button; none = white with an outline), color (its label), disabled_background.
function UI.button(th, opts)
    local enabled = opts.enabled ~= false
    local border = Size.border.button
    local pad_h, pad_v = opts.pad_h or sp(12), opts.pad_v or sp(6)
    -- `icon` (a widget) stands in for the text.
    local label = opts.icon or UI.text(opts.text, opts.size or 15,
        { bold = true, color = enabled and (opts.color or th.ink) or th.muted })
    local content = label
    if opts.width then
        content = CenterContainer:new{
            dimen = Geom:new{ w = opts.width - 2 * (border + pad_h), h = label:getSize().h },
            label,
        }
    end
    local fill, line
    if not enabled then
        fill = opts.disabled_background or th.free
        line = fill
    elseif opts.background then
        fill = opts.background
        line = opts.border_color or fill
    else
        fill, line = th.white, th.ink
    end
    local frame = FrameContainer:new{
        bordersize = border, color = line, background = fill, radius = Size.radius.button, margin = 0,
        padding = pad_v, padding_left = pad_h, padding_right = pad_h,
        content,
    }
    if enabled and opts.callback then
        return UI.tappable(frame, opts.callback)
    end
    return frame
end

-- Every checkbox is this big, so the ones in the Library and in the KOReader tab line up and look the same.
UI.CHECKBOX = sp(28)

-- A rounded square, filled with a tick when `checked`.
-- opts: mixed (some of a group are ticked: shows a dash), disabled (a row that cannot be ticked), size.
function UI.checkbox(th, checked, opts)
    opts = opts or {}
    local size = opts.size or UI.CHECKBOX
    local filled = (checked or opts.mixed) and not opts.disabled
    local border = Size.border.thick
    -- A box that cannot be ticked is no box at all, just a padlock the size of one, so it reads as locked rather than empty.
    if opts.disabled then
        local lock = Icons.lockWidget(math.floor(size * 1.1), th.muted)
        if lock then return CenterContainer:new{ dimen = Geom:new{ w = size, h = size }, lock } end
    end
    local inner
    if filled then
        local mark = size - 2 * border
        inner = Icons.tickWidget(opts.mixed and "dash" or "tick", mark, th.white)
            or CenterContainer:new{ dimen = Geom:new{ w = mark, h = mark }, UI.text(opts.mixed and "–" or "✓", math.floor(size * 0.62), { bold = true, color = th.white }) }
    else
        inner = HorizontalGroup:new{ HorizontalSpan:new{ width = size - 2 * border }, VerticalSpan:new{ width = size - 2 * border } }
    end
    return FrameContainer:new{
        bordersize = border, color = opts.disabled and th.muted or th.ink, radius = math.floor(size / 4), margin = 0, padding = 0,
        background = filled and th.accent or (opts.disabled and th.bg or th.white),
        inner,
    }
end

-- A row of small dots, w x h, to lead the eye across a gap (from a label to the box it belongs to).
local Dotted = Widget:extend{ width = 0, height = 0, color = nil }

function Dotted:getSize() return Geom:new{ w = self.width, h = self.height } end

function Dotted:paintTo(bb, x, y)
    self.dimen = Geom:new{ x = x, y = y, w = self.width, h = self.height }
    local dot, step = math.max(2, sp(2)), sp(7)
    local top = y + math.floor((self.height - dot) / 2)
    for dx = 0, self.width - dot, step do bb:paintRect(x + dx, top, dot, dot, self.color) end
end

-- The "Select all" line above a list of rows: the label at the left, a soft dotted line leading across to its checkbox at the
-- right, in the column of the row boxes under it (a row ends with `gap` after its box). Tapping the line ticks or clears them all.
-- opts: label, checked, mixed, disabled, on_tap.
function UI.selectAll(th, width, gap, opts)
    local box = UI.checkbox(th, opts.checked, { mixed = opts.mixed, disabled = opts.disabled })
    local pad = sp(8)
    -- As much room as the label wants, but a stretch of dots is always left between it and the box.
    local label = UI.text(opts.label, 15, { bold = true, color = th.ink, max_width = width - gap - box:getSize().w - 2 * pad - sp(40) })
    local dots = width - gap - box:getSize().w - label:getSize().w - 2 * pad
    local line = HorizontalGroup:new{
        align = "center",
        label,
        HorizontalSpan:new{ width = pad },
        dots > 0 and Dotted:new{ width = dots, height = box:getSize().h, color = th.line } or HorizontalSpan:new{ width = 0 },
        HorizontalSpan:new{ width = pad },
        box,
        HorizontalSpan:new{ width = gap },
    }
    return (opts.on_tap and not opts.disabled) and UI.tappable(line, opts.on_tap) or line
end

-- opts: active (filled, for a switched-on filter), on_tap (makes the chip tappable), icon (a widget that
-- stands in for the text, drawn on the page colour).
function UI.chip(th, text, opts)
    opts = opts or {}
    local chip = FrameContainer:new{
        bordersize = Size.border.thin, color = th.ink, radius = sp(16), margin = 0,
        background = opts.active and th.accent or nil,
        padding = opts.icon and sp(2) or sp(4), padding_left = opts.icon and sp(14) or sp(10), padding_right = opts.icon and sp(14) or sp(10),
        opts.icon or UI.text(text, 13, { bold = true, color = opts.active and th.white or th.ink }),
    }
    return opts.on_tap and UI.tappable(chip, opts.on_tap) or chip
end

-- A floating bar of actions, a dark pill: a label, then buttons. `buttons` is a list of
-- { text, callback, danger }; the `danger` one is the light, filled button and the rest are outlined. Returns the bar and its buttons' widgets (their `dimen` is where they were
-- last drawn), so that whoever draws the bar can pass taps on to them.
-- opts.compact: a slimmer bar, as tall as the pager row, for drawing in the middle of it.
function UI.floatingBar(th, label, buttons, opts)
    local compact = opts and opts.compact
    local row = HorizontalGroup:new{ align = "center", UI.text(label, compact and 14 or 16, { bold = true, color = th.white }) }
    local hits = {}
    for _, b in ipairs(buttons) do
        table.insert(row, HorizontalSpan:new{ width = sp(compact and 10 or 12) })
        -- On the bar's dark ground the main action is the light button, and the other is outlined in light.
        local button = UI.button(th, {
            text = b.text, size = compact and 14 or 15, callback = b.callback,
            pad_v = compact and sp(2) or nil, pad_h = compact and sp(10) or nil,
            background = b.danger and th.white or th.ink, color = b.danger and th.ink or th.white,
            border_color = th.white,
        })
        table.insert(row, button)
        table.insert(hits, { widget = button, callback = b.callback })
    end
    local bar = FrameContainer:new{
        bordersize = 0, margin = 0, radius = sp(compact and 22 or 26), background = th.ink,
        padding = compact and sp(3) or sp(10), padding_left = compact and sp(16) or sp(20), padding_right = compact and sp(9) or sp(12),
        row,
    }
    return bar, hits
end

-- A rounded track with a filled share of it.
function UI.bar(th, width, height, fraction, fill)
    fraction = math.max(0, math.min(1, fraction))
    local filled = math.floor(width * fraction)
    local row = HorizontalGroup:new{}
    if filled > 0 then table.insert(row, UI.block(filled, height, fill)) end
    table.insert(row, UI.block(width - filled, height, th.free))
    return UI.rounded(th, row, math.floor(height / 2))
end

-- Wraps a widget so a tap (and optionally a hold) on it calls back.
local tappables = 0

function UI.tappable(widget, on_tap, on_hold)
    local size = widget:getSize()
    local c = InputContainer:new{ dimen = Geom:new{ w = size.w, h = size.h }, widget }
    -- Event names are unique per tappable: events travel down to child widgets, so a
    -- button inside a tappable row would otherwise answer the row's tap with its own.
    tappables = tappables + 1
    local tap, hold = "TapRow" .. tappables, "HoldRow" .. tappables
    c.ges_events = {
        [tap] = { GestureRange:new{ ges = "tap", range = c.dimen } },
        [hold] = { GestureRange:new{ ges = "hold", range = c.dimen } },
    }
    c["on" .. tap] = function()
        if on_tap then on_tap() end
        return true
    end
    c["on" .. hold] = function()
        if on_hold then on_hold() end
        return true
    end
    return c
end

-- tabs = { { id, label }, ... }: pills side by side, the active one filled.
function UI.tabbar(th, width, tabs, active, on_select)
    local h = sp(40)
    local border = Size.border.button
    local row = HorizontalGroup:new{}
    for i, tab in ipairs(tabs) do
        local on = tab.id == active
        local label = UI.text(tab.label, 15, { bold = true, color = on and th.white or th.ink })
        local pill = FrameContainer:new{
            bordersize = border, color = on and th.accent or th.ink, radius = math.floor(h / 2), margin = 0, padding = 0,
            background = on and th.accent or th.bg,
            CenterContainer:new{ dimen = Geom:new{ w = label:getSize().w + 2 * sp(18), h = h - 2 * border }, label },
        }
        if i > 1 then table.insert(row, HorizontalSpan:new{ width = sp(8) }) end
        table.insert(row, UI.tappable(pill, function() on_select(tab.id) end))
    end
    return row
end

-- « ‹ Page 1 of 3 › » ; on_page(n) is called with the page to show.
-- The pager row's measures: its height, the width of each arrow, and the width of what is between the arrows.
-- `cell` narrows the arrows, to leave the middle more room when the page is not wide.
function UI.pagerGeometry(width, cell)
    local cell_w = cell or sp(56)
    return { h = sp(44), cell_w = cell_w, centre_w = width - 4 * cell_w }
end

-- opts.cell_w: the width of an arrow. opts.hide_label: leave the middle (the "Page 1 of 3") empty, for the floating bar to be drawn there.
function UI.pager(th, width, page, pages, on_page, opts)
    local geo = UI.pagerGeometry(width, opts and opts.cell_w)
    local h, cell_w = geo.h, geo.cell_w
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
            dimen = Geom:new{ w = geo.centre_w, h = h },
            (opts and opts.hide_label) and HorizontalSpan:new{ width = 0 }
                or UI.text(T(_("Page %1 of %2"), page, pages), 16, { bold = true, color = th.ink }),
        },
        cell("›", page < pages and page + 1 or nil),
        cell("»", page < pages and pages or nil),
    }
end

-- spec: { icon ("shelfspace", "library" or "koreader"), named (the ShelfSpace mark with its name), color (the tile), title, subtitle, chips = { text | { text, active, on_tap, pinned }... } }
function UI.hero(th, width, spec)
    local icon_size = sp(108)
    local gap = sp(4) -- the icon is drawn with a margin of its own
    local info_w = width - icon_size - gap
    local cover = Icons.widget(spec.icon, icon_size, spec.color, th.bg, spec.named)
        or UI.block(sp(84), icon_size, spec.color, sp(8))
    local info = VerticalGroup:new{ align = "left" }
    table.insert(info, UI.text(spec.title, 30, { face = "tfont", color = th.ink, max_width = info_w }))
    table.insert(info, UI.text(spec.subtitle, 18, { color = th.muted, max_width = info_w }))
    if spec.chips and #spec.chips > 0 then
        local chips, used = HorizontalGroup:new{}, 0
        local function make(chip) return type(chip) == "table" and UI.chip(th, chip.text, chip) or UI.chip(th, chip) end
        -- A chip marked `pinned` goes last and is never left out: room is kept for it before the others are placed.
        local pinned, rest = nil, {}
        for _, chip in ipairs(spec.chips) do
            if type(chip) == "table" and chip.pinned then pinned = make(chip) else rest[#rest + 1] = chip end
        end
        if spec.wrap then
            -- In a column of its own the chips do not fit on one line, so they run on to the next rather than being left out.
            local lines, line, used = VerticalGroup:new{ align = "left" }, HorizontalGroup:new{}, 0
            local all = {}
            for _, chip in ipairs(rest) do all[#all + 1] = make(chip) end
            if pinned then all[#all + 1] = pinned end
            for _, widget in ipairs(all) do
                local w = widget:getSize().w
                if used > 0 and used + sp(6) + w > info_w then
                    table.insert(lines, line)
                    table.insert(lines, VerticalSpan:new{ width = sp(4) })
                    line, used = HorizontalGroup:new{}, 0
                end
                if used > 0 then table.insert(line, HorizontalSpan:new{ width = sp(6) }) used = used + sp(6) end
                table.insert(line, widget)
                used = used + w
            end
            table.insert(lines, line)
            chips = lines
        else
            local reserved = pinned and (pinned:getSize().w + sp(6)) or 0
            for i, chip in ipairs(rest) do
                -- A chip is a plain string, or { text, active, on_tap } when it is a switch.
                local widget = make(chip)
                local w = widget:getSize().w + (i > 1 and sp(6) or 0)
                -- On a narrow screen, chips that would run off the edge are left out.
                if used + w + reserved > info_w and i > 1 then break end
                if i > 1 then table.insert(chips, HorizontalSpan:new{ width = sp(6) }) end
                table.insert(chips, widget)
                used = used + w
            end
            if pinned then
                if #chips > 0 then table.insert(chips, HorizontalSpan:new{ width = sp(6) }) end
                table.insert(chips, pinned)
            end
        end
        table.insert(info, VerticalSpan:new{ width = sp(6) })
        table.insert(info, chips)
    end
    -- Every hero is as tall as the fullest one (title, subtitle, chips),
    -- so the tab bar below it stays put when you switch tabs.
    local full = UI.text("Ag", 30, { face = "tfont" }):getSize().h
        + UI.text("Ag", 18):getSize().h
        + sp(6) + UI.chip(th, "Ag"):getSize().h
    return LeftContainer:new{
        dimen = Geom:new{ w = width, h = math.max(icon_size, full, spec.wrap and info:getSize().h or 0) },
        HorizontalGroup:new{ align = "center", cover, HorizontalSpan:new{ width = gap }, info },
    }
end

return UI
