--[[
Bookshelf micro-module: a ShelfSpace object. See micromodules/README.md in bookshelf.koplugin for the contract.

A piece that stands on a shelf among the books and shows how full the device is: a conical flask, a glass of water, a whiskey glass, a
decanter, a stack of books, a pillar candle or an inkwell and quill. It has no card, like an ornament: it stands on the plank (or sits
centred among covers) with the figure on a small tag. Every piece but the stack is full when the device has plenty of room; the stack
grows as the device fills. The level is the live free space. Which piece it is, is that card's own setting (long-press it, or choose when
adding). A tap opens ShelfSpace; nothing here deletes anything.

The art is layers of PNG (art/), put together by shelfspace/pieces.lua, which does the arithmetic; this only turns its answer into widgets.
]]
local MODULE_DIR = ...
local _ = require("lib/bookshelf_i18n").gettext

local function load(rel)
    local ok, mod = pcall(dofile, MODULE_DIR .. "/../shelfspace/" .. rel)
    return ok and mod or nil
end

local Live = load("livesummary.lua")
local Pieces = load("pieces.lua")
local Summary = load("summary.lua")
local okSpec, SPEC = pcall(dofile, MODULE_DIR .. "/../art/spec.lua")
if not (Live and Pieces and Summary and okSpec and SPEC) then return {} end -- ShelfSpace's own files are not where they should be: offer nothing

-- What can stand for the space. The key is what is stored on the card, so it never changes.
local OBJECTS = {
    { key = "flask", name = _("Conical flask") },
    { key = "glass", name = _("Glass of water") },
    { key = "whiskey", name = _("Whiskey glass") },
    { key = "decanter", name = _("Decanter") },
    { key = "stack", name = _("Stack of books") },
    { key = "candle", name = _("Pillar candle") },
    { key = "inkwell", name = _("Inkwell and quill") },
}
local DEFAULT = "flask"

local function guard(fn)
    local ok, result = xpcall(fn, debug.traceback)
    if ok then return result end
    require("logger").warn("ShelfSpace object failed:", result)
    return nil
end

-- One layer of art as a widget: the sprite scaled to the op's size, and cut to the rows it shows.
local function layerWidget(op, art_dir)
    local RenderImage = require("ui/renderimage")
    local Blitbuffer = require("ffi/blitbuffer")
    local ImageWidget = require("ui/widget/imagewidget")
    local w = math.max(1, math.floor(op.w + 0.5))
    local rows = op.to - op.from
    local full_h = math.max(1, math.floor(op.h / rows + 0.5))
    local bb = RenderImage:renderImageFile(art_dir .. "/" .. op.file .. ".png", false, w, full_h)
    if not bb then return nil end
    if op.from > 0 or op.to < 1 then
        local r0 = math.floor(op.from * full_h + 0.5)
        local h = math.max(1, math.floor(op.to * full_h + 0.5) - r0)
        local cut = Blitbuffer.new(w, h, bb:getType())
        cut:blitFrom(bb, 0, 0, 0, r0, w, h)
        bb:free()
        bb = cut
    end
    return ImageWidget:new{ image = bb, image_disposable = true, alpha = true }
end

-- After a change the shelf is laid out again once, as Bookshelf's own ornament Swap does when its picker closes (a rebuild drops the
-- cached rows too).
local function redraw(bw)
    if not (bw and bw._rebuild) then return end
    bw:_rebuild()
    require("ui/uimanager"):setDirty(bw, "ui")
end

-- Writes one setting of the card. Changed in place in the stored list, not by handing a new table to the host (owner.save swaps the
-- module's table for a copy, and the shelf's cached rows kept drawing from the old one: the first change showed, later ones were saved
-- but not drawn).
local function store(ctx, field, value)
    local TabModel = require("lib/bookshelf_tab_model")
    local tabs, changed = TabModel.load(), false
    for _i, t in ipairs(tabs) do
        for _j, m in ipairs(t.shelf_modules or {}) do
            if ctx.entry and m.id == ctx.entry.id then m[field], changed = value, true end
        end
    end
    if ctx.entry then ctx.entry[field] = value end
    if changed then TabModel.save(tabs) else ctx.config:set(field, value) end -- not on a shelf: the host's own way
end

-- A small picture of one piece for the picker: the art without its figure, standing on a line `th` px down, as big as fits
-- a cell `cw` x `th`. Returns an OverlapGroup of that size.
local function thumbnail(id, cw, th)
    local OverlapGroup = require("ui/widget/overlapgroup")
    local Geom = require("ui/geometry")
    local o = SPEC[id]
    local function lay(s)
        -- the stack at its tallest (a full disk), the rest part full
        local l = Pieces.layout(SPEC, id, { s = s, free = id == "stack" and 0 or 0.6, num = "0", unit = "", width = function() return 0 end })
        local ops, x0, y0, x1 = {}, math.huge, math.huge, -math.huge
        for _i, op in ipairs(l.ops) do
            if op.file ~= Pieces.TAG and op.file ~= "flask-flag" then
                ops[#ops + 1] = op
                x0, y0, x1 = math.min(x0, op.x), math.min(y0, op.y), math.max(x1, op.x + op.w)
            end
        end
        return ops, x0, y0, x1
    end
    local s = Pieces.HEIGHT[id] / 80 * th / o.base -- the tallest piece (80) fills the cell, the rest keep their proportion
    local ops, x0, y0, x1 = lay(s)
    local k = math.min(1, (cw - 12) / (x1 - x0), (th - 6) / (o.base * s - y0))
    if k < 1 then s = s * k; ops, x0, y0, x1 = lay(s) end
    local ox = math.floor((cw - (x1 - x0)) / 2 - x0 + 0.5)
    if id == "inkwell" or id == "flask" then -- on the bottle, not the whole drawing (the quill leans out; the flask's sprite is padded)
        local half = id == "flask" and o.cx * s or math.max(o.cx * s - x0, x1 - o.cx * s)
        ox = math.floor(cw / 2 - o.cx * s + 0.5)
        if 2 * half > cw - 12 then s = s * (cw - 12) / (2 * half); ops, x0, y0, x1 = lay(s); ox = math.floor(cw / 2 - o.cx * s + 0.5) end
    end
    local oy = math.floor(th - 6 - o.base * s + 0.5)
    local items = {}
    for _i, op in ipairs(ops) do
        local widget = layerWidget(op, MODULE_DIR .. "/../art")
        if widget then
            widget.overlap_offset = { math.floor(op.x + ox + 0.5), math.floor(op.y + oy + 0.5) }
            items[#items + 1] = widget
        end
    end
    return OverlapGroup:new{ dimen = Geom:new{ w = cw, h = th }, unpack(items) }
end

-- The picker: a grid of small pictures with their names. Calls on_pick(key) with the one tapped; the current one has a heavy border.
local function chooseObject(current, on_pick, on_closed)
    local UIManager = require("ui/uimanager")
    local Blitbuffer = require("ffi/blitbuffer")
    local Device = require("device")
    local Screen = Device.screen
    local Geom = require("ui/geometry")
    local Size = require("ui/size")
    local Kit = require("lib/bookshelf_module_kit")
    local InputContainer = require("ui/widget/container/inputcontainer")
    local CenterContainer = require("ui/widget/container/centercontainer")
    local FrameContainer = require("ui/widget/container/framecontainer")
    local VerticalGroup = require("ui/widget/verticalgroup")
    local VerticalSpan = require("ui/widget/verticalspan")
    local HorizontalGroup = require("ui/widget/horizontalgroup")
    local HorizontalSpan = require("ui/widget/horizontalspan")
    local TextBoxWidget = require("ui/widget/textboxwidget")
    local TextWidget = require("ui/widget/textwidget")
    local GestureRange = require("ui/gesturerange")

    local sw, sh = Screen:getWidth(), Screen:getHeight()
    local cols = 4
    local gap, pad = Screen:scaleBySize(8), Screen:scaleBySize(12)
    local box_w = math.min(math.floor(sw * 0.94), Screen:scaleBySize(560))
    local cell_w = math.floor((box_w - 2 * pad - (cols - 1) * gap) / cols)
    local th = math.floor(cell_w * 0.95)
    local name_face = Kit.face(15, 100, { bold = true })
    local name_h
    do
        local probe = TextWidget:new{ text = "Ag", face = name_face, bold = true }
        name_h = probe:getSize().h * 2 + Screen:scaleBySize(2)
        probe:free()
    end

    local cells = {}
    local rows = VerticalGroup:new{ align = "left" }
    local row
    for i, e in ipairs(OBJECTS) do
        if (i - 1) % cols == 0 then
            if row then rows[#rows + 1] = row; rows[#rows + 1] = VerticalSpan:new{ width = gap } end
            row = HorizontalGroup:new{ align = "top" }
        elseif row then
            row[#row + 1] = HorizontalSpan:new{ width = gap }
        end
        local is_current = e.key == current
        local inner = VerticalGroup:new{ align = "center",
            thumbnail(e.key, cell_w - 2 * Screen:scaleBySize(3), th),
            -- every name gets room for two lines, so the cells are one height whatever the name
            CenterContainer:new{ dimen = Geom:new{ w = cell_w - 2 * Screen:scaleBySize(6), h = name_h },
                TextBoxWidget:new{ text = e.name, face = name_face, bold = true, width = cell_w - 2 * Screen:scaleBySize(6), alignment = "center" } },
        }
        local cell = FrameContainer:new{
            -- the selected one has the heavy border; the padding takes up the difference so every cell is one size
            bordersize = is_current and Screen:scaleBySize(3) or Screen:scaleBySize(1),
            color = is_current and Blitbuffer.COLOR_BLACK or Blitbuffer.COLOR_GRAY,
            radius = Size.radius.default, padding = Screen:scaleBySize(is_current and 1 or 3), margin = 0, background = Blitbuffer.COLOR_WHITE,
            inner,
        }
        cells[#cells + 1] = { widget = cell, key = e.key }
        row[#row + 1] = cell
    end
    if row then rows[#rows + 1] = row end

    local title = TextWidget:new{ text = _("What stands for your space"), face = Kit.face(18, 100, { bold = true }), bold = true }
    local frame = FrameContainer:new{
        bordersize = Size.border.window, radius = Size.radius.window, padding = pad, margin = 0, background = Blitbuffer.COLOR_WHITE,
        VerticalGroup:new{ align = "center", title, VerticalSpan:new{ width = pad }, rows },
    }

    local Dialog = InputContainer:extend{ modal = true }
    local dialog = Dialog:new{
        dimen = Geom:new{ x = 0, y = 0, w = sw, h = sh },
        ges_events = { Tap = { GestureRange:new{ ges = "tap", range = Geom:new{ x = 0, y = 0, w = sw, h = sh } } } },
        key_events = { Close = { { "Back" } } },
        CenterContainer:new{ dimen = Geom:new{ w = sw, h = sh }, frame },
    }
    function dialog:onTap(_a, ges)
        for _i, c in ipairs(cells) do
            if c.widget.dimen and ges.pos:intersectWith(c.widget.dimen) then
                -- write the choice first, then close: the shelf is rebuilt from onCloseWidget, which runs inside the close
                self.picked = true
                on_pick(c.key)
                UIManager:close(self)
                return true
            end
        end
        if not (frame.dimen and ges.pos:intersectWith(frame.dimen)) then UIManager:close(self) end -- outside: cancel
        return true
    end
    function dialog:onClose() UIManager:close(self); return true end
    -- However it closes, once it has: a pick rebuilds the shelf (the caller's on_closed), as Bookshelf's Swap does
    function dialog:onCloseWidget()
        UIManager:setDirty(nil, "ui")
        if self.picked and on_closed then pcall(on_closed) end
    end
    UIManager:show(dialog)
    UIManager:setDirty(dialog, "ui") -- the whole dialog, not just what the closing menu left dirty
end

return {
    key = "shelfspace_object",
    title = _("ShelfSpace object"),
    summary = _("An object that shows how full the device is. Works offline."),
    -- No card behind it: it stands on the plank, as an ornament does.
    bare = true,
    -- It sizes itself to the cell: one render at the cell's size.
    self_sized = true,
    start_w = 1,
    start_h = 1,

    render = function(ctx) return guard(function()
        local Kit = require("lib/bookshelf_module_kit")
        local TextWidget = require("lib/bookshelf_colour_text")
        local Blitbuffer = require("ffi/blitbuffer")
        local OverlapGroup = require("ui/widget/overlapgroup")
        local CenterContainer = require("ui/widget/container/centercontainer")
        local BottomContainer = require("ui/widget/container/bottomcontainer")
        local Screen = require("device").screen
        local Geom = require("ui/geometry")

        local s = Live.read()
        if not s then return nil end
        local num, unit = Summary.figure(s.free)
        local id = ctx.config and ctx.config:get("object", DEFAULT) or DEFAULT
        if not SPEC[id] then id = DEFAULT end
        local o = SPEC[id]
        local W = math.max(30, ctx.width or 30)
        local H = (ctx.height and ctx.height > 0) and ctx.height or math.floor(W * 1.6)
        local row = H / Pieces.ROW -- the lab drew the pieces on a shelf row this tall; everything that is a fixed size there scales with it

        -- The figure's type is sized in pixels (the art is), whatever the device's own scaling.
        local em = Screen:scaleBySize(100) / 100
        local function face(px) return Kit.face(math.max(1, math.floor(px / em + 0.5)), 100, { bold = true }) end
        local function text(str, px)
            local f, bold = face(px)
            return TextWidget:new{ text = str, face = f, bold = bold, fgcolor = Blitbuffer.COLOR_BLACK }
        end
        local function width(str, px)
            local t = text(str, px)
            local w = t:getSize().w
            t:free()
            return w
        end

        local free_share = s.total and s.total > 0 and s.free / s.total or 0
        local p = {
            s = Pieces.HEIGHT[id] / 100 * H / o.base, free = free_share, num = num, unit = unit .. " " .. _("free"), width = width,
            tag = Pieces.TAG_SCALE * row, min_label = Pieces.MIN_LABEL * row,
            no_label = ctx.config and ctx.config:get("label", true) == false,
        }
        local layout = Pieces.layout(SPEC, id, p)
        -- Never wider than the cell: stand it smaller if it would be.
        -- The inkwell is centred on its bottle, not on the whole drawing: the quill leans out to one side and would pull the bottle off centre.
        local function span(l, scale)
            local b = l.box
            if id == "inkwell" then
                local half = math.max(o.cx * scale - b.x0, b.x1 - o.cx * scale)
                return 2 * half, half - o.cx * scale
            elseif id == "flask" then
                -- the flask's sprite is twice as wide as the flask (room that the side flag once took): centre on the glass itself
                local half = o.cx * scale
                for _i, op in ipairs(l.ops) do
                    if op.file == Pieces.TAG then half = math.max(half, op.w / 2) end
                end
                return 2 * half, half - o.cx * scale
            end
            return b.x1 - b.x0, -b.x0
        end
        local wide = span(layout, p.s)
        if wide > W then
            p.s = p.s * W / wide
            layout = Pieces.layout(SPEC, id, p)
        end

        local box = layout.box
        local width_px, dx = span(layout, p.s)
        local dy = -box.y0
        local gw = math.max(1, math.floor(width_px + 0.5))
        -- The group ends at the piece's base line, so it stands on the plank; what hangs below (a shadow) is drawn over the plank.
        -- set back from the shelf's front edge by `lift`, as the plants stand, so the bases sit on the top of the plank and not at its lip
        local lift = math.floor(Pieces.SET_BACK * row + 0.5)
        local gh = math.max(1, math.floor(o.base * p.s + dy + 0.5) + lift)
        local items = {}
        for _i, op in ipairs(layout.ops) do
            local widget = layerWidget(op, MODULE_DIR .. "/../art")
            if widget then
                widget.overlap_offset = { math.floor(op.x + dx + 0.5), math.floor(op.y + dy + 0.5) }
                items[#items + 1] = widget
            end
        end
        -- The figure: the number big, its unit under it, tucked together, in the middle of the label's body.
        local label = layout.label
        if label then
            local line1, line2 = text(num, label.big), text(p.unit, label.f)
            local s1, s2 = line1:getSize(), line2:getSize()
            local mid = label.x + label.w / 2 + dx
            local top = label.y + dy + (label.h - 6 - (label.big + label.f - label.tight)) / 2
            line1.overlap_offset = { math.floor(mid - s1.w / 2), math.floor(top - (s1.h - label.big) / 2) }
            line2.overlap_offset = { math.floor(mid - s2.w / 2), math.floor(top + label.big - label.tight - (s2.h - label.f) / 2) }
            items[#items + 1] = line1
            items[#items + 1] = line2
        end
        local group = OverlapGroup:new{ dimen = Geom:new{ w = gw, h = gh }, unpack(items) }
        if ctx.set_tap_regions then ctx.set_tap_regions({}) end
        local Container = (ctx.shelf_view == "spines") and BottomContainer or CenterContainer
        return Container:new{ dimen = Geom:new{ w = W, h = H }, group }
    end) end,

    -- Choose the object when adding; the card keeps it in its own settings.
    on_add = function(_host_ctx, done)
        chooseObject(DEFAULT, function(key) done({ object = key }) end)
    end,

    -- Module settings (long-press): change the object.
    show_settings = function(ctx)
        if not (ctx and ctx.config) then return end
        local UIManager = require("ui/uimanager")
        local ButtonDialog = require("ui/widget/buttondialog")
        local Kit = require("lib/bookshelf_module_kit")
        local dialog
        local label_on = ctx.config:get("label", true) ~= false
        dialog = ButtonDialog:new(Kit.withClose{
            title = _("ShelfSpace object"), title_align = "center", width_factor = 0.8,
            buttons = {
                { { text = _("Change piece\xE2\x80\xA6"), callback = function()
                    UIManager:close(dialog)
                    -- As Bookshelf's own ornament Swap does it: the pick writes the choice, and the shelf is rebuilt once the picker has closed.
                    chooseObject(ctx.config:get("object", DEFAULT), function(key) store(ctx, "object", key) end,
                        function() redraw(ctx.bw) end)
                end } },
                { { text = label_on and _("Hide label") or _("Show label"), callback = function()
                    UIManager:close(dialog)
                    store(ctx, "label", not label_on)
                    redraw(ctx.bw)
                end } },
            },
        })
        UIManager:show(dialog)
    end,

    -- What the card draws depends on these settings, so a change is a changed card.
    cache_key = function(entry) return entry and (tostring(entry.object) .. "|" .. tostring(entry.label)) end,

    on_tap = function(ctx)
        local Kit = require("lib/bookshelf_module_kit")
        local plugin = Kit.plugin(MODULE_DIR)
        if plugin then plugin:showOverview({ tab = "library" }) end
    end,
}
