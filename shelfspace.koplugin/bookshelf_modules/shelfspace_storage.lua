--[[
Bookshelf micro-module: ShelfSpace storage. See micromodules/README.md in bookshelf.koplugin for the contract.

One card for how full the device is and what could be freed: the storage bar drawn as a shelf of spines (a run of books for each of
Books, KOReader and Other, then the dashed empty slot from ShelfSpace's logo for the free space). It reads a small summary ShelfSpace
saves after each scan, so it draws at once and never scans; only the free space is read live. A tap opens ShelfSpace: on the Library,
or, on the rows that say so, on Duplicates or the KOReader tab. It never deletes anything.

It picks a layout from the cell it is given: a small shelf (1 x 1), a shelf with the number (wide), the shelf with a legend and the
two ways in (a larger square), or a stack of flat books (tall).
]]
local MODULE_DIR = ...
local _ = require("lib/bookshelf_i18n").gettext

local function load(rel)
    local ok, mod = pcall(dofile, MODULE_DIR .. "/../shelfspace/" .. rel)
    return ok and mod or nil
end

local Summary = load("summary.lua")
local SW = load("spinewidgets.lua")
local Live = load("livesummary.lua")
if not (Summary and SW and Live) then return {} end -- ShelfSpace's own files are not where they should be: offer nothing

local summary = Live.read

-- The host draws a bare title when a render fails and says nothing, so a failure is logged here, with where it happened.
local function guard(fn)
    local ok, result = xpcall(fn, debug.traceback)
    if ok then return result end
    require("logger").warn("ShelfSpace storage card failed:", result)
    return nil
end

local function totalText(total)
    local gb = 1000 ^ 3 -- as KOReader counts a GB
    if total >= gb then return string.format("%d GB", math.floor(total / gb + 0.5)) end
    local n, u = Summary.figure(total)
    return n .. " " .. u
end

return {
    key = "shelfspace_storage",
    title = _("ShelfSpace storage"),
    summary = _("From ShelfSpace's last scan. Works offline."),
    min_w = 1,
    min_h = 1,

    render = function(ctx) return guard(function()
        local Kit = require("lib/bookshelf_module_kit")
        local TextWidget = require("lib/bookshelf_colour_text")
        local VerticalGroup = require("ui/widget/verticalgroup")
        local VerticalSpan = require("ui/widget/verticalspan")
        local HorizontalGroup = require("ui/widget/horizontalgroup")
        local HorizontalSpan = require("ui/widget/horizontalspan")
        local FrameContainer = require("ui/widget/container/framecontainer")
        local LineWidget = require("ui/widget/linewidget")
        local Geom = require("ui/geometry")

        local s, scanned = summary()
        if not s then return nil end

        -- The card's own colours: Bookshelf points these at the card being drawn while it renders.
        local ink, muted, card = Kit.COLOR_PRIMARY, Kit.COLOR_MUTED, Kit.CARD_BG
        local Color = select(2, pcall(require, "lib/bookshelf_color"))
        local paint = type(Color) == "table" and Color.paintRect or nil
        local p = SW.palette(ink, card, paint)

        local W, H = math.max(50, ctx.width or 50), ctx.height
        local sc = Kit.sc(ctx.scale)
        local shares = Summary.shares(s)
        local num, unit = Summary.figure(s.free)
        local state = Summary.state(s)
        local reclaim = Summary.reclaimable(s)

        local function text(str, size, o)
            o = o or {}
            local face, bold = Kit.face(size, ctx.scale, { bold = o.bold })
            return TextWidget:new{ text = str, face = face, bold = bold, fgcolor = o.muted and muted or ink, max_width = o.max_w }
        end

        local function brand(size)
            local Icons = load("icons.lua")
            local mark
            if Icons and Icons.markWidget then
                local ok, w = pcall(Icons.markWidget, sc(size * 1.15), ink, card)
                mark = ok and w or nil
            end
            local label = text("ShelfSpace", size, { bold = true, muted = true })
            if not mark then return label end
            return HorizontalGroup:new{ align = "center", mark, HorizontalSpan:new{ width = sc(4) }, label }
        end

        local function chip()
            if not state then return nil end
            local label = ({ low = _("LOW"), almost = _("ALMOST FULL"), full = _("FULL") })[state]
            local filled = state ~= "full"
            return FrameContainer:new{
                bordersize = sc(2), color = ink, radius = sc(8), margin = 0, padding = sc(1), padding_left = sc(6), padding_right = sc(6),
                background = filled and ink or card,
                TextWidget:new{ text = label, face = Kit.face(10, ctx.scale, { bold = true }), bold = true, fgcolor = filled and card or ink },
            }
        end

        local function saving()
            if not scanned or reclaim <= 0 then return nil end
            local n, u = Summary.figure(reclaim)
            return text(n .. " " .. u .. " " .. _("could be freed"), 13, { muted = true, max_w = W })
        end

        local function legend(width)
            local row = HorizontalGroup:new{ align = "center" }
            local sw = sc(9)
            local names = { { "k", _("Books") }, { "m", _("KOReader") }, { "l", _("Other") } }
            for i, e in ipairs(names) do
                if i > 1 then row[#row + 1] = HorizontalSpan:new{ width = sc(8) } end
                row[#row + 1] = SW.swatch(e[1], sw, p, math.max(1, sc(1)))
                row[#row + 1] = HorizontalSpan:new{ width = sc(3) }
                row[#row + 1] = text(e[2], 11)
            end
            return row:getSize().w <= width and row or nil
        end

        local function shelfOpts(base, span)
            return { w = sc(15), gap = sc(2), line = math.max(1, sc(2)), base = sc(base), span = sc(span), plank = sc(7), narrow = sc(4), shorter = sc(10) }
        end
        local function shelf(width, base, span)
            local o = shelfOpts(base, span)
            local n = SW.fit(width, o.w, o.gap)
            return SW.shelf(width, Summary.slots(n, shares), p, o)
        end

        -- "21.4 GB free" as a number with its unit and, when it fits, how big the device is.
        local function headline(size, of)
            local g = HorizontalGroup:new{ align = "bottom", text(num, size, { bold = true }), HorizontalSpan:new{ width = sc(4) },
                text(unit .. " " .. _("free") .. (of and (" " .. _("of") .. " " .. totalText(s.total)) or ""), math.floor(size * 0.46), { muted = true }) }
            local c = chip()
            if c then
                g[#g + 1] = HorizontalSpan:new{ width = sc(6) }
                g[#g + 1] = c
            end
            return g
        end

        local regions = {}
        -- Rows that open somewhere: a label, an amount and a chevron, with a rule above. Their rects go to the host.
        local function tapRow(width, y, label, amount, id)
            local rule = LineWidget:new{ dimen = Geom:new{ w = width, h = math.max(1, sc(1)) }, background = muted }
            local right = text(amount .. " ›", 12, { bold = true })
            local left = text(label, 12, { max_w = math.max(sc(20), width - right:getSize().w - sc(8)) }) -- a text widget will not take a width of nothing
            local h = left:getSize().h + sc(5)
            local row = VerticalGroup:new{ align = "left", rule,
                HorizontalGroup:new{ align = "center", left, HorizontalSpan:new{ width = math.max(0, width - left:getSize().w - right:getSize().w) }, right },
                VerticalSpan:new{ width = sc(3) } }
            local rh = row:getSize().h
            regions[#regions + 1] = { id = id, x = 0, y = y, w = width, h = rh }
            return row, rh
        end

        local function taps(width, y)
            local out, used = VerticalGroup:new{ align = "left" }, 0
            if not scanned or width < sc(120) then return nil, 0 end -- too narrow for a label beside an amount
            local d = Summary.figure(s.duplicates)
            local entries = {}
            if s.duplicates > 0 then
                local n, u = Summary.figure(s.duplicates)
                entries[#entries + 1] = { _("Duplicate books") .. " · " .. s.duplicate_sets, n .. " " .. u, "duplicates" }
            end
            if s.koreader_clearable > 0 then
                local n, u = Summary.figure(s.koreader_clearable)
                entries[#entries + 1] = { _("KOReader's files"), n .. " " .. u, "koreader" }
            end
            for _i, e in ipairs(entries) do
                local row, rh = tapRow(width, y + used, e[1], e[2], e[3])
                out[#out + 1] = row
                used = used + rh
            end
            return #entries > 0 and out or nil, used
        end

        local function fits(widget) return not H or H <= 0 or widget:getSize().h <= H end

        -- LAYOUTS, richest first within a shape; the first that fits the cell wins.
        local layouts = {}

        function layouts.mini()
            return VerticalGroup:new{ align = "center",
                brand(10), VerticalSpan:new{ width = sc(3) }, shelf(W, 24, 14), VerticalSpan:new{ width = sc(3) },
                text(num .. " " .. unit .. " " .. _("free"), 15, { bold = true }) }
        end

        local function wide(with_legend)
            local left, right = brand(13), headline(24, with_legend or false)
            local g = VerticalGroup:new{ align = "left",
                HorizontalGroup:new{ align = "center", left, HorizontalSpan:new{ width = math.max(sc(6), W - left:getSize().w - right:getSize().w) }, right },
                VerticalSpan:new{ width = sc(4) }, shelf(W, 26, 18) }
            if with_legend then
                local lg = legend(W)
                if lg then g[#g + 1] = VerticalSpan:new{ width = sc(4) }; g[#g + 1] = lg end
            end
            local sv = saving()
            if sv then g[#g + 1] = VerticalSpan:new{ width = sc(3) }; g[#g + 1] = sv end
            return g
        end
        function layouts.wide() return wide(false) end
        function layouts.wide_legend() return wide(true) end

        function layouts.large()
            local g = VerticalGroup:new{ align = "left", brand(13), VerticalSpan:new{ width = sc(2) }, headline(30, true),
                VerticalSpan:new{ width = sc(5) }, shelf(W, 36, 22) }
            local lg = legend(W)
            if lg then g[#g + 1] = VerticalSpan:new{ width = sc(5) }; g[#g + 1] = lg end
            local y = g:getSize().h + sc(6)
            local t = taps(W, y)
            if t then g[#g + 1] = VerticalSpan:new{ width = sc(6) }; g[#g + 1] = t end
            return g
        end

        -- A stack of flat books growing up from the bottom of the cell; what is above and below it is built first, so the stack takes
        -- whatever height is left.
        local function tall(with_legend, with_taps)
            local top = VerticalGroup:new{ align = "left", brand(11), VerticalSpan:new{ width = sc(4) }, text(num, 30, { bold = true }),
                text(unit .. " " .. _("free") .. " " .. _("of") .. " " .. totalText(s.total), 12, { muted = true, max_w = W }) }
            local c = chip()
            if c then top[#top + 1] = VerticalSpan:new{ width = sc(3) }; top[#top + 1] = c end
            local bottom = VerticalGroup:new{ align = "left" }
            if with_legend then
                local lg = VerticalGroup:new{ align = "left" }
                for _i, e in ipairs({ { "k", _("Books") }, { "m", _("KOReader") }, { "l", _("Other") } }) do
                    lg[#lg + 1] = HorizontalGroup:new{ align = "center", SW.swatch(e[1], sc(9), p, math.max(1, sc(1))), HorizontalSpan:new{ width = sc(4) }, text(e[2], 11) }
                end
                bottom[#bottom + 1] = lg
                bottom[#bottom + 1] = VerticalSpan:new{ width = sc(4) }
            end
            local sv = saving()
            if sv then bottom[#bottom + 1] = sv end
            local bh, gap = sc(15), sc(2)
            local rows = 8
            if H and H > 0 then
                local tapsH = 0
                local t
                if with_taps then
                    local probe = regions
                    regions = {}
                    t, tapsH = taps(W, 0)
                    regions = probe
                end
                local left = H - top:getSize().h - bottom:getSize().h - tapsH - sc(10)
                rows = math.floor(left / (bh + gap))
                if rows < 4 then return nil end
                rows = math.min(rows, 16)
            end
            local stack = SW.stack(W, Summary.slots(rows, shares), p, { bh = bh, gh = sc(22), gap = gap, line = math.max(1, sc(2)), sway = sc(3) })
            local g = VerticalGroup:new{ align = "left", top, VerticalSpan:new{ width = sc(6) }, stack, VerticalSpan:new{ width = sc(6) }, bottom }
            if with_taps then
                local t = taps(W, g:getSize().h + sc(4))
                if t then g[#g + 1] = VerticalSpan:new{ width = sc(4) }; g[#g + 1] = t end
            end
            return g
        end

        -- Which layouts to try, by the shape of the cell.
        local shape = ctx.shape or Kit.shape(W, H)
        local order
        if shape == "tall" then
            order = { function() return tall(true, true) end, function() return tall(false, true) end, function() return tall(false, false) end, layouts.mini }
        elseif shape == "wide" then
            order = { W >= 3.5 * (H or 1e9) and layouts.wide_legend or layouts.wide, layouts.wide, layouts.mini }
        else
            order = { layouts.large, layouts.wide, layouts.mini }
        end
        local widget
        for i, build in ipairs(order) do
            regions = {}
            local w = build()
            -- Groups cache their size, and these were measured while they were still being filled.
            if w and w.resetLayout then w:resetLayout() end
            if w and (fits(w) or i == #order) then widget = w break end
        end
        if not widget then return nil end
        if ctx.set_tap_regions then ctx.set_tap_regions(regions) end
        return widget
    end) end,

    on_tap = function(ctx)
        local Kit = require("lib/bookshelf_module_kit")
        local plugin = Kit.plugin(MODULE_DIR)
        if not plugin then return end
        local tab = ({ duplicates = "duplicates", koreader = "koreader" })[ctx.tapped_region or ""] or "library"
        plugin:showOverview({ tab = tab })
    end,
}
