local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local LineWidget = require("ui/widget/linewidget")
local Size = require("ui/size")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local util = require("util")
local _ = require("gettext")
local T = require("ffi/util").template

local UI = require("shelfspace/ui")
local sp = UI.sp

-- Free space, a usage bar and a books / KOReader / other breakdown.
return function(screen, th, width)
    local plugin = screen.plugin
    local u = plugin.usage
    local b = plugin.tree and plugin:breakdown(u) or nil

    local hero = UI.hero(th, width, {
        color = th.accent,
        label = _("STORAGE"),
        title = util.getFriendlySize(u.available),
        subtitle = T(_("free of %1"), util.getFriendlySize(u.total)),
        chips = { b and _("SCANNED") or _("SCANNING…") },
    })

    local parts
    if b then
        parts = { { b.books, th.books }, { b.koreader, th.koreader }, { b.other, th.other } }
    else
        parts = { { u.used, th.other } }
    end
    local inner = width - 2 * Size.border.thin
    local bar_h = sp(22)
    local row = HorizontalGroup:new{}
    local used_w = 0
    for i, part in ipairs(parts) do
        local w = math.floor(inner * part[1] / u.total)
        if w > 0 then
            table.insert(row, UI.block(w, bar_h, part[2]))
            used_w = used_w + w
        end
    end
    table.insert(row, UI.block(inner - used_w, bar_h, th.free))
    local bar = FrameContainer:new{
        bordersize = Size.border.thin, padding = 0, margin = 0,
        radius = Size.radius.button, color = th.ink, background = th.free, row,
    }

    local function legend(color, label, size_text)
        local dot, gap = sp(14), sp(12)
        local label_w = UI.text(label, 22, { bold = true, color = th.ink })
        local size_w = UI.text(size_text, 22, { color = th.ink })
        local spacer = width - dot - gap - label_w:getSize().w - size_w:getSize().w
        return VerticalGroup:new{
            align = "left",
            VerticalSpan:new{ width = sp(10) },
            HorizontalGroup:new{
                align = "center",
                FrameContainer:new{
                    bordersize = Size.border.thin, padding = 0, margin = 0, radius = dot, color = th.ink,
                    background = color,
                    HorizontalGroup:new{ HorizontalSpan:new{ width = dot }, VerticalSpan:new{ width = dot } },
                },
                HorizontalSpan:new{ width = gap }, label_w,
                HorizontalSpan:new{ width = math.max(spacer, 0) }, size_w,
            },
            VerticalSpan:new{ width = sp(10) },
            LineWidget:new{ dimen = Geom:new{ w = width, h = Size.line.thin }, background = th.line },
        }
    end

    local body = VerticalGroup:new{ align = "left", bar, VerticalSpan:new{ width = sp(8) } }
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
    for i, r in ipairs(rows) do
        table.insert(body, legend(r[1], r[2], r[3]))
    end
    return { hero = hero, body = body }
end
