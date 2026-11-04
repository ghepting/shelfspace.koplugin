-- The shelf pieces that stand for how full the device is: a conical flask, a glass of water, a whiskey glass, a decanter, a stack of
-- books, a pillar candle and an inkwell with a quill. Each is drawn from layers of art (art/<piece>-<layer>.png, geometry in
-- art/spec.lua) and this works out where every layer goes for a given amount of free space. It is pure arithmetic, so it runs under
-- the tests as on a device; the module that stands on the shelf turns the result into widgets.
--
-- The rules were settled in the Shelf Piece Lab:
--   * Every piece but the stack shows FREE space as "full": 100% free is full, 0% is nearly empty. The stack is what is stored, so
--     it follows USED space. Nothing goes emptier than the 1% look (a sliver of liquid, a single book, a stub of wax).
--   * A vessel's liquid is one tall sprite cut from the surface down; the surface is found by volume (a cone holds more near the top).
--   * Every label except the flask's flag is one shared tag at one size; the flask's flag grows until its smaller line is legible.
--   * Books keep their own thickness; the stack grows by adding books, never by squeezing them.
--
-- Positions come back in pixels (the art's units times `s`), as ops: { file, x, y, w, h, from, to } where `from`/`to` (fractions of the
-- sprite's height, default 0 and 1) say which rows of it show.
local Pieces = {}

Pieces.ORDER = { "flask", "glass", "whiskey", "decanter", "stack", "candle", "inkwell" }
-- How tall each piece stands, as a share of the shelf row: the pieces are not the same size in life.
Pieces.HEIGHT = { flask = 74, glass = 70, whiskey = 56, decanter = 80, inkwell = 64, candle = 78, stack = 72 }

Pieces.RATIO = 1.2 -- the figure against its unit line
Pieces.LINE_GAP = 2 -- px of air between the figure and the unit line, on top of the lines being tucked together
Pieces.TAG = "glass-tag" -- the one tag every piece but the flask wears
Pieces.TAG_SCALE = 0.9 -- px per art unit, at the lab's shelf row height
Pieces.ROW = 190 -- ... which was this tall
Pieces.SET_BACK = 4.5-- how far back from the shelf's front edge a piece stands, px at the lab's row height
Pieces.MIN_LABEL = 11
Pieces.MAX_GROW = 2.6
Pieces.BOOKS = 8
Pieces.STACK_TOP = 7 -- art units: a book's cover seen from above (stack-top<N>.png)
Pieces.STACK_FOOT = 3 -- art units: how much taller the bottom book is, for its rounded foot

local function round(v) return math.floor(v + 0.5) end

-- The share of the inside that is filled, for a piece: the free share, or the used share when `meaning` is "used"; the stack takes the other one.
function Pieces.fill(id, free, meaning)
    free = math.max(0, math.min(1, free))
    local share = meaning == "used" and 1 - free or free
    if id == "stack" then share = 1 - share end
    return math.max(0.01, share)
end

-- Half the inside width at height y (the vessel's `ihw` is sampled every 2 units from its liquid's top).
function Pieces.ihwAt(piece, y)
    local n = #piece.ihw
    local f = math.max(0, math.min(n - 1, (y - piece.liq.top) / 2))
    local i = math.floor(f)
    local t = f - i
    return piece.ihw[i + 1] * (1 - t) + piece.ihw[math.min(n, i + 2)] * t
end

-- Where the surface sits when a fraction `frac` of the inside is filled: by volume (the default) or by height.
function Pieces.levelY(piece, frac, by_height)
    local top, floor, n = piece.liq.top, piece.liq.floor, #piece.ihw
    local y
    if by_height then
        y = floor - frac * (floor - top)
    else
        local total = 0
        for i = 1, n do total = total + piece.ihw[i] ^ 2 end
        local acc = 0
        y = top
        for i = n, 1, -1 do
            local a = piece.ihw[i] ^ 2
            acc = acc + a
            if acc >= frac * total then
                local t = (frac * total - (acc - a)) / a
                y = top + 2 * (i - 1) + 2 * (1 - t)
                break
            end
        end
    end
    y = math.min(y, floor - 8)
    return math.max(y, top + (frac < 1 and 6 or 0))
end

-- The biggest type that fits the figure into a label's body (bw x bh px): the unit line at size `f`, the figure at RATIO times that,
-- the lines tucked 16% together. `width(text, size)` is the width of text in that size. Returns { f, big, tight } (sizes in px).
function Pieces.fitFigure(num, unit, bw, bh, width)
    local W, H = bw - 10, bh - 6
    -- When the figure is what stops the type from being bigger, it loses its decimals ("128.5" is "128") before the type shrinks.
    local whole = num:match("^(%d+)%.%d+$")
    if whole == "0" then whole = nil end
    local f, text = 6, num
    for size = 30, 6, -1 do
        local big = round(size * Pieces.RATIO)
        local tight = round(big * 0.16) - Pieces.LINE_GAP
        if width(unit, size) <= W and big + size - tight <= H then
            if width(num, big) <= W then f, text = size, num; break end
            if whole and width(whole, big) <= W then f, text = size, whole; break end
        end
    end
    local big = round(f * Pieces.RATIO)
    return { f = f, big = big, tight = round(big * 0.16) - Pieces.LINE_GAP, text = text }
end

-- Lays one piece out. `spec` is art/spec.lua; `p` says how:
--   s          px per art unit (how big the piece stands)
--   free       the free share of the device (0 to 1)
--   meaning    "free" (default) or "used": what a full piece stands for
--   num, unit  the figure and its unit line ("26.4", "GB free")
--   width      width(text, size_px) for the figure's type
--   tag        px per art unit of the shared tag (default: Pieces.TAG_SCALE)
--   min_label  the smallest the flag's unit line may be, px (default Pieces.MIN_LABEL)
--   thick      book thickness, 1 = as drawn (default 1.4)
--   by_height  find a liquid's level by height rather than volume
--   ice        false leaves the whiskey's ice out
-- Returns { ops = { ... }, label = { x, y, w, h, f, big, tight } or nil, box = { x0, y0, x1, y1 }, surface = <art units> }.
function Pieces.layout(spec, id, p)
    local o = spec[id]
    local s = p.s
    local ops, box = {}, { x0 = 0, y0 = 0, x1 = o.W * s, y1 = o.H * s }
    local function grow(x, y, w, h)
        box.x0, box.y0 = math.min(box.x0, x), math.min(box.y0, y)
        box.x1, box.y1 = math.max(box.x1, x + w), math.max(box.y1, y + h)
    end
    -- a sprite, its top left and size in art units; `from`/`to` crop it (fractions of its height)
    local function add(file, x, y, w, h, from, to)
        from, to = from or 0, to or 1
        if to <= from then return end
        local op = { file = file, x = x * s, y = (y + from * h) * s, w = w * s, h = (to - from) * h * s, from = from, to = to }
        ops[#ops + 1] = op
        grow(op.x, op.y, op.w, op.h)
        return op
    end
    local function layer(name, from, to)
        local l = o.layers[name]
        return add(id .. "-" .. name, l.x, l.y, l.w, l.h, from, to)
    end
    local frac = Pieces.fill(id, p.free, p.meaning)
    local result = { ops = ops, box = box }

    -- The figure in the body (x, y, w, h px) of a label drawn at scale `sc`
    local function figure(x, y, w, h)
        local fit = Pieces.fitFigure(p.num, p.unit, w, h, p.width)
        return { x = x, y = y, w = w, h = h, f = fit.f, big = fit.big, tight = fit.tight, text = fit.text }
    end
    -- The shared tag, centred on cx and resting on `bottom` (px)
    local function tag(cx, bottom)
        if p.no_label then return end -- the label is switched off for this piece
        local ts = p.tag or Pieces.TAG_SCALE
        local a, b = spec.glass.layers.tag, spec.glass.label
        local w, h = a.w * ts, a.h * ts
        local left, top = cx - w / 2, bottom - h
        ops[#ops + 1] = { file = Pieces.TAG, x = left, y = top, w = w, h = h, from = 0, to = 1 }
        grow(left, top, w, h)
        result.label = figure((left / ts + b.bodyX) * ts, (top / ts + b.bodyY) * ts, b.bodyW * ts, b.bodyH * ts)
    end

    if o.kind == "vessel" then
        local surface = Pieces.levelY(o, frac, p.by_height)
        local ihw = Pieces.ihwAt(o, surface)
        result.surface = surface
        if id == "inkwell" then layer("quill") end
        layer("back")
        if id == "inkwell" then layer("stem") end
        local liquid = o.layers.liquid
        layer("liquid", math.max(0, (surface - liquid.y) / liquid.h), 1)
        local cap_w = 2 * ihw + 2
        add(id .. "-cap", o.cx - cap_w / 2, surface - 6, cap_w, 12)
        if id == "whiskey" and p.ice ~= false then
            local ib, cube_bottom = 56, 68
            local bottom = surface + 0.6 * ib
            if bottom - ib < o.liq.top then bottom = o.liq.top + ib end
            bottom = math.min(o.liq.floor - 1, bottom)
            local sy, sx = bottom - cube_bottom, o.cx - 39 - 6
            add("whiskey-iceClear", sx, sy, o.ice.w, o.ice.h)
            if surface < bottom then add("whiskey-iceTint", sx, sy, o.ice.w, o.ice.h, math.max(0, (surface - sy) / o.ice.h), 1) end
        end
        layer("front")
        if id == "flask" or id == "decanter" then tag(o.cx * s, 1 * s) -- resting on the mouth or the stopper
        elseif id == "inkwell" then tag(o.cx * s, 0) -- over the bottle, not the leaning quill
        else
            local t = o.layers.tag
            tag((t.x + t.w / 2) * s, (t.y + t.h) * s) -- on top, where it always was
        end
    elseif o.kind == "candle" then
        local wax_h = math.max(12, frac * o.full)
        local top = o.dishTop - wax_h
        local wax = o.layers.wax
        if top < wax.y + wax.h then layer("wax", math.max(0, (top - wax.y) / wax.h), 1) end
        -- the melted top: its drips would hang below the dish rim when the wax is low, so they are cut at the rim
        local wt = o.layers.waxTop
        local spill = (top - 9 + wt.h) - o.dishTop
        add("candle-waxTop", wt.x, top - 9, wt.w, wt.h, 0, spill > 0 and 1 - spill / wt.h or 1)
        local lit = frac > 0.03
        local fl = lit and o.layers.flame or o.layers.smoke
        local rise = lit and 82 or 74
        add(lit and "candle-flame" or "candle-smoke", fl.x, top - rise, fl.w, fl.h)
        layer("dish")
        tag(o.cx * s, (top - rise - 4) * s)
    elseif o.kind == "stack" then
        local thick = p.thick or 1.4
        local books = o.books
        local function height(i) return books[i].h * thick end
        -- books keep their own thickness: add them until the piece's art runs out of room
        local fit, run = 0, 0
        for i = 1, #books do
            run = run + height(i) + 1
            if run > o.base - 4 then break end
            fit = i
        end
        local n = math.min(fit, math.max(1, round(frac * Pieces.BOOKS)))
        local y = o.base
        for i = 1, n do
            local b, h = books[i], height(i)
            local k = h / b.h
            y = y - h
            -- the bottom book is drawn with a rounded foot (a few units taller below), as the other pieces have, to stand on the plank
            local foot = i == 1 and Pieces.STACK_FOOT * k or 0
            local x = o.cx - (b.w + 4) / 2 + b.dx
            add("stack-book" .. (i - 1), x, y - 2 * k, b.w + 4, b.h * k + 4 * k + foot)
            -- seen from slightly above, like the standing spines: every book's cover shows on top, and the book above stands over it, so
            -- only what sticks out past that one is seen (all of it on the top book)
            add("stack-top" .. (i - 1), x, y - 2 * k - Pieces.STACK_TOP * k + 1.5 * k, b.w + 4, Pieces.STACK_TOP * k)
            y = y - 1
        end
        result.books = n
        tag(o.cx * s, (y + 4 - Pieces.STACK_TOP) * s) -- on top of the stack
    end
    return result
end

return Pieces
