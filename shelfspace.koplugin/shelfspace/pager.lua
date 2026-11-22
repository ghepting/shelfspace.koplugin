-- The pager row: |< < Page 1 of 3 > >| across the width it is given, the arrows at the ends and the page in the middle, made of the
-- same Buttons as KOReader's file browser: its chevrons at its size (DGENERIC_ICON_SIZE, with a Button's padding round it), a flash
-- on a tap, an arrow with nowhere to go dimmed, and a tap on the page number to go to a page.
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

-- on_page(n) is called with the page to show. opts.cell_w: the width of an arrow's cell (see geometry); opts.show_parent: the
-- widget the buttons are drawn in (the screen), which KOReader refreshes when a button flashes on a tap.
--
-- The parts are KOReader's own, as in its file browser: the arrows are Buttons, so they flash when tapped and a disabled one is
-- dimmed the stock way, and "Page 1 of 3" is a Button too, which asks for a page number to go to.
function Pager.row(th, width, page, pages, on_page, opts)
    local BD = require("ui/bidi")
    local Button = require("ui/widget/button")
    local CenterContainer = require("ui/widget/container/centercontainer")
    local Geom = require("ui/geometry")
    local HorizontalGroup = require("ui/widget/horizontalgroup")
    local InputDialog = require("ui/widget/inputdialog")
    local UIManager = require("ui/uimanager")

    opts = opts or {}
    local geo = Pager.geometry(width, opts.cell_w)
    local first, prev, nxt, last = "chevron.first", "chevron.left", "chevron.right", "chevron.last"
    if BD.mirroredUILayout() then -- the row is mirrored, so the arrows are too, as in KOReader's menus
        first, prev, nxt, last = last, nxt, prev, first
    end
    local function cell(icon, target)
        return CenterContainer:new{
            dimen = Geom:new{ w = geo.cell_w, h = geo.h },
            Button:new{
                icon = icon, icon_width = geo.icon, icon_height = geo.icon, bordersize = 0, background = th.bg,
                enabled = target ~= nil, show_parent = opts.show_parent,
                callback = function() if target then on_page(target) end end,
            },
        }
    end

    -- Tapping the page number asks which page to go to, as in KOReader's file browser.
    local function ask()
        local dialog
        local function go()
            local n = tonumber(dialog:getInputText())
            if not n then return end
            UIManager:close(dialog)
            on_page(math.max(1, math.min(pages, math.floor(n))))
        end
        dialog = InputDialog:new{
            title = _("Go to page"), input_type = "number", input_hint = T("(1 - %1)", pages),
            buttons = { {
                { text = _("Cancel"), id = "close", callback = function() UIManager:close(dialog) end },
                { text = _("Go to page"), is_enter_default = true, callback = go },
            } },
        }
        UIManager:show(dialog)
        dialog:onShowKeyboard()
    end
    local label = Button:new{
        text = T(_("Page %1 of %2"), page, pages), text_font_bold = false, bordersize = 0, background = th.bg,
        max_width = geo.centre_w, show_parent = opts.show_parent,
        callback = function() if pages > 1 then ask() end end, -- a list of one page has nowhere to go
    }

    return HorizontalGroup:new{
        cell(first, page > 1 and 1 or nil),
        cell(prev, page > 1 and page - 1 or nil),
        CenterContainer:new{ dimen = Geom:new{ w = geo.centre_w, h = geo.h }, label },
        cell(nxt, page < pages and page + 1 or nil),
        cell(last, page < pages and pages or nil),
    }
end

return Pager
