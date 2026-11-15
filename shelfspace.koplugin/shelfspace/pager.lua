-- The pager row: |< < Page 1 of 3 > >| across the width it is given, the arrows at the ends and the page in the middle. The arrows are
-- KOReader's own chevron icons at the size its file browser draws them (a Button's default icon, DGENERIC_ICON_SIZE, with a Button's
-- padding round it), so they are as big, and as easy to tap, as in the file browser. An arrow that has nowhere to go is dimmed, as there.
--
-- Pure layout, with nothing of one plugin in it; ShelfSpace and SideShelf share it.
local _ = require("gettext")
local T = require("ffi/util").template

local Pager = {}

local function scaler() return function(n) return require("device").screen:scaleBySize(n) end end

-- The row's measures: its height, the width of each arrow's cell, the width between the arrows, and the size of the icon. `cell` asks
-- for narrower (or wider) arrow cells, to leave the middle more room on a narrow list; a cell is never smaller than a stock Button.
-- `scale` turns unscaled sizes into pixels (Screen:scaleBySize unless given) and `icon` is the unscaled icon size (DGENERIC_ICON_SIZE
-- unless given), both so the tests can run without a screen.
function Pager.geometry(width, cell, scale, icon)
    scale = scale or scaler()
    icon = icon or (G_defaults and G_defaults:readSetting("DGENERIC_ICON_SIZE")) or 40
    local icon_px = scale(icon)
    local button = icon_px + 2 * scale(2) -- Size.padding.button on each side, as a Button has
    local h = math.max(scale(44), button)
    local cell_w = math.max(cell or scale(56), button)
    return { h = h, cell_w = cell_w, centre_w = math.max(0, width - 4 * cell_w), icon = icon_px, button = button }
end

-- on_page(n) is called with the page to show. opts.cell_w: the width of an arrow's cell (see geometry).
function Pager.row(th, width, page, pages, on_page, opts)
    local BD = require("ui/bidi")
    local CenterContainer = require("ui/widget/container/centercontainer")
    local Geom = require("ui/geometry")
    local HorizontalGroup = require("ui/widget/horizontalgroup")
    local IconWidget = require("ui/widget/iconwidget")
    local UI = require("shelfspace/ui")

    local geo = Pager.geometry(width, opts and opts.cell_w)
    local first, prev, nxt, last = "chevron.first", "chevron.left", "chevron.right", "chevron.last"
    if BD.mirroredUILayout() then -- the row is mirrored, so the arrows are too, as in KOReader's menus
        first, prev, nxt, last = last, nxt, prev, first
    end
    local function cell(icon, target)
        local c = CenterContainer:new{
            dimen = Geom:new{ w = geo.cell_w, h = geo.h },
            IconWidget:new{ icon = icon, width = geo.icon, height = geo.icon, dim = not target },
        }
        if not target then return c end
        return UI.tappable(c, function() on_page(target) end)
    end
    return HorizontalGroup:new{
        cell(first, page > 1 and 1 or nil),
        cell(prev, page > 1 and page - 1 or nil),
        CenterContainer:new{
            dimen = Geom:new{ w = geo.centre_w, h = geo.h },
            UI.text(T(_("Page %1 of %2"), page, pages), 16, { bold = true, color = th.ink }),
        },
        cell(nxt, page < pages and page + 1 or nil),
        cell(last, page < pages and pages or nil),
    }
end

return Pager
