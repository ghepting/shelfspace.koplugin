local CenterContainer = require("ui/widget/container/centercontainer")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local IconWidget = require("ui/widget/iconwidget")
local OverlapGroup = require("ui/widget/overlapgroup")
local Size = require("ui/size")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local util = require("util")
local _ = require("gettext")
local T = require("ffi/util").template

local Donut = require("shelfspace/donut")
local UI = require("shelfspace/ui")
local sp = UI.sp

-- Where the device's storage went, at the top of the Library: the donut on the left and, beside it, a row for each of
-- books, KOReader data, other files and free space. The rows are the chart's legend and its controls: Books narrows the list
-- below to every book, KOReader opens its tab, Other explains itself; Free has nothing to open. Tapping a slice does the same.
return function(screen, th, width)
    local plugin = screen.plugin
    local u = plugin.usage
    local b = plugin.tree and plugin:breakdown(u) or nil

    local go = {
        books = function() screen:toggleBooks() end,
        koreader = function() screen:switchTab("koreader") end,
        other = function() plugin:explainOther(b) end,
    }

    -- { key (names the colour and the tint), label, size in bytes, what a tap does, and whether it is the lit one }
    local rows, slices
    if b then
        rows = {
            { "books", _("Books"), b.books, go.books, screen.only_books },
            { "koreader", _("KOReader"), b.koreader, go.koreader },
            { "other", _("Other"), b.other, nil, false, go.other },
            { "free", _("Free"), u.available },
        }
        slices = {
            { fraction = b.books / u.total, color = th.books, on_tap = go.books },
            { fraction = b.koreader / u.total, color = th.koreader, on_tap = go.koreader },
            { fraction = b.other / u.total, color = th.other, on_tap = go.other },
            { fraction = u.available / u.total, color = th.free_space },
        }
    else
        rows = { { "other", _("Used"), u.used }, { "free", _("Free"), u.available } }
        slices = {
            { fraction = u.used / u.total, color = th.other },
            { fraction = u.available / u.total, color = th.free_space },
        }
    end

    local diameter = math.floor(width * 0.32)
    local gap = sp(14)
    local legend_w = width - diameter - gap
    local row_h = math.floor((diameter - 3 * sp(6)) / 4)
    local dot = sp(16)

    local function legend_row(r)
        local key, label, bytes, on_tap, lit, on_info = r[1], r[2], r[3], r[4], r[5], r[6]
        local inner_w = legend_w - 2 * sp(12)
        local size_w = UI.text(util.getFriendlySize(bytes), 18, { color = th.muted })
        local tail_w = on_tap and sp(22) or (on_info and sp(30) or 0)
        local tail
        if on_info then
            tail = IconWidget:new{ icon = "notice-info", alpha = true, width = sp(24), height = sp(24) }
        elseif on_tap then
            tail = UI.text("›", 26, { color = th.muted })
        end
        local color = ({ books = th.books, koreader = th.koreader, other = th.other, free = th.free_space })[key]
        local name_w = inner_w - dot - sp(10) - size_w:getSize().w - sp(8) - tail_w
        local row = HorizontalGroup:new{
            align = "center",
            FrameContainer:new{
                bordersize = Size.border.thin, padding = 0, margin = 0, radius = sp(4), color = th.ink, background = color,
                HorizontalGroup:new{ HorizontalSpan:new{ width = dot }, VerticalSpan:new{ width = dot } },
            },
            HorizontalSpan:new{ width = sp(10) },
            UI.text(label, 18, { bold = true, color = th.ink, max_width = name_w }),
            HorizontalSpan:new{ width = math.max(0, name_w - UI.text(label, 18, { bold = true, max_width = name_w }):getSize().w) },
            size_w,
            HorizontalSpan:new{ width = sp(8) },
            tail or HorizontalSpan:new{ width = 0 },
        }
        local framed = FrameContainer:new{
            -- A lit row (Books, while the list is narrowed to books) gets a black outline; the rest have none.
            bordersize = lit and Size.border.thick or Size.border.thin, radius = sp(8), margin = 0, padding = 0,
            color = lit and th.ink or th["tint_" .. key], background = th["tint_" .. key],
            CenterContainer:new{ dimen = Geom:new{ w = legend_w, h = row_h }, row },
        }
        return (on_tap or on_info) and UI.tappable(framed, on_tap or on_info) or framed
    end

    local legend = VerticalGroup:new{ align = "left" }
    for i, r in ipairs(rows) do
        if i > 1 then table.insert(legend, VerticalSpan:new{ width = sp(6) }) end
        table.insert(legend, legend_row(r))
    end

    local used_share = u.total > 0 and u.used / u.total or 0
    local donut = Donut:new{
        diameter = diameter, bg = th.bg, ink = th.ink, slices = slices,
        on_tap = function(slice) if slice.on_tap then slice.on_tap() end end,
    }
    local chart = OverlapGroup:new{
        dimen = Geom:new{ w = diameter, h = diameter },
        donut,
        CenterContainer:new{
            dimen = Geom:new{ w = diameter, h = diameter },
            VerticalGroup:new{
                align = "center",
                UI.text(string.format("%d%%", 100 - math.floor(used_share * 100 + 0.5)), 30, { face = "tfont", color = th.ink }),
                UI.text(_("free"), 15, { color = th.ink }),
                UI.text(T(_("of %1"), util.getFriendlySize(u.total)), 13, { color = th.muted }),
            },
        },
    }
    return HorizontalGroup:new{ align = "center", chart, HorizontalSpan:new{ width = gap }, legend }
end
