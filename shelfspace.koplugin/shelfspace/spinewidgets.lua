-- The drawing for ShelfSpace's Bookshelf card: a shelf of spines, a stack of flat books, and the little squares of a legend. Each kind
-- of thing on the device is its own kind of book, in the tones of the storage bar (the card's ink, a middle tone and a light one),
-- and free space is the empty slot from the logo, drawn as a dashed outline.
--
--   books     hardcovers: dark, with a band near the head and the foot, and some with a label plate
--   koreader  leather-bound volumes: a middle tone, with raised ribs and a label at the head
--   other     paperbacks: light, with a dark title strip and a mark at the foot
--   free      dashed outline
--
-- Everything is drawn with rectangles and takes its colours from the card it stands on, so it holds up on any theme.
local Geom = require("ui/geometry")
local Widget = require("ui/widget/widget")
local Blitbuffer = require("ffi/blitbuffer")

local SW = {}

-- A fixed pseudo-random number from 0 to 1 for each n, so the heights are staggered the same way every time, with no ramps.
function SW.rnd(n)
    local x = math.sin(n * 12.9898 + 78.233) * 43758.5453
    return x - math.floor(x)
end

-- A height from base to base + span, for the i-th spine.
function SW.height(i, base, span)
    return base + math.floor(SW.rnd(i * 31 + base * 7 + span) * (span + 1))
end

local function lum(color, default)
    local ok, v = pcall(function() return color:getColor8().a end)
    return ok and type(v) == "number" and v or default
end

-- The colours a card gives the drawing: its ink and its surface, and the tones between them. `paint(bb, x, y, w, h, color)` is how
-- a rectangle gets painted (Bookshelf's own, so a colour stays a colour), or bb:paintRect.
function SW.palette(ink, card, paint)
    local l_ink, l_card = lum(ink, 0), lum(card, 238)
    local function tone(t) -- 0 is the ink, 1 is the card
        return Blitbuffer.Color8(math.floor(l_ink + (l_card - l_ink) * t + 0.5))
    end
    return {
        ink = ink, card = card, tone = tone,
        books = ink, koreader = tone(0.45), other = tone(0.80),
        rib = tone(0.15), plank = tone(0.55),
        paint = paint or function(bb, x, y, w, h, c) bb:paintRect(x, y, w, h, c) end,
    }
end

local function rect(p, bb, x, y, w, h, c)
    if w > 0 and h > 0 then p.paint(bb, x, y, w, h, c) end
end

-- A dashed outline, `t` thick, with dashes `d` long and `g` apart.
local function dashed(p, bb, x, y, w, h, t, d, g)
    local function line(px, py, len, horizontal)
        local pos = 0
        while pos < len do
            local seg = math.min(d, len - pos)
            if horizontal then rect(p, bb, px + pos, py, seg, t, p.ink) else rect(p, bb, px, py + pos, t, seg, p.ink) end
            pos = pos + d + g
        end
    end
    line(x, y, w, true); line(x, y + h - t, w, true)
    line(x, y, h, false); line(x + w - t, y, h, false)
end

-- One spine at (x, y) from its top, w wide and h tall. kind is "k" (books), "m" (KOReader), "l" (other) or "g" (free); v is 0, 1 or
-- 2, a variation so a run is not a row of copies.
local function spine(p, bb, kind, v, x, y, w, h, line)
    if kind == "g" then
        dashed(p, bb, x, y, w, h, math.max(1, line), math.max(3, line * 2), math.max(2, line))
        return
    end
    local fill = ({ k = p.books, m = p.koreader, l = p.other })[kind]
    rect(p, bb, x, y, w, h, p.ink) -- the outline
    rect(p, bb, x + line, y + line, w - 2 * line, h - 2 * line, fill)
    local ix, iw = x + line, w - 2 * line
    if kind == "k" then
        local band = math.max(1, line)
        rect(p, bb, ix, y + math.floor(h * 0.18), iw, band, p.card)
        rect(p, bb, ix, y + h - math.floor(h * 0.18) - band, iw, band, p.card)
        if v == 1 then rect(p, bb, ix, y + math.floor(h * 0.40), iw, band, p.card) end
        if v == 2 then rect(p, bb, ix + math.floor(iw * 0.18), y + math.floor(h * 0.38), iw - 2 * math.floor(iw * 0.18), math.floor(h * 0.24), p.card) end
    elseif kind == "m" then
        local step, thick = math.max(4, line * 3), math.max(1, line)
        local yy = y + line
        if v == 2 then step = math.max(3, line * 2) end
        while yy + thick <= y + h - line do
            rect(p, bb, ix, yy, iw, thick, p.rib)
            yy = yy + step
        end
        if v == 1 then
            rect(p, bb, ix + math.floor(iw * 0.14), y + math.floor(h * 0.10), iw - 2 * math.floor(iw * 0.14), math.floor(h * 0.18), p.card)
        end
    else -- paperback
        local top = y + math.floor(h * (v == 1 and 0.12 or 0.38))
        rect(p, bb, ix, top, iw, math.max(2, math.floor(h * (v == 1 and 0.14 or 0.20))), p.ink)
        if v ~= 2 then
            local m = math.floor(iw * 0.25)
            rect(p, bb, ix + m, y + h - math.floor(h * 0.16), iw - 2 * m, math.max(2, math.floor(h * 0.08)), p.ink)
        end
    end
end

-- A row of spines standing on a plank. `spines` is a list of { kind, w, h, v }; a row is only as wide as the spines and gaps in it.
local SpineRow = Widget:extend{ width = 0, height = 0, plank = 0, gap = 1, line = 2, p = nil, spines = nil }

function SpineRow:getSize() return Geom:new{ w = self.width, h = self.height } end

function SpineRow:paintTo(bb, x, y)
    self.dimen = Geom:new{ x = x, y = y, w = self.width, h = self.height }
    local p, base = self.p, y + self.height - self.plank
    local cx = x
    for _, s in ipairs(self.spines) do
        spine(p, bb, s.kind, s.v or 0, cx, base - s.h, s.w, s.h, self.line)
        cx = cx + s.w + self.gap
    end
    rect(p, bb, x, base, self.width, self.plank, p.ink)
    rect(p, bb, x, base + self.line, self.width, math.max(0, self.plank - self.line), p.plank)
end

-- Builds the row of spines for a width: as many as fit, shared out by `slots` ({ k, m, l, g }, as Summary.slots gives them).
-- `w`, `gap` are a spine's width and the space between; `base`, `span` its height range.
function SW.shelfSpines(width, slots, o)
    local spines, idx = {}, 0
    local function add(kind, n, w, base, span, off)
        for i = 1, n do
            spines[#spines + 1] = { kind = kind, w = w, h = SW.height(idx, base, span), v = (i - 1 + off) % 3 }
            idx = idx + 1
        end
    end
    add("k", slots.k, o.w, o.base, o.span, 0)
    add("m", slots.m, math.max(o.line * 4 + 1, o.w - o.narrow), math.max(o.line * 6, o.base - o.shorter), math.floor(o.span / 2), 2)
    add("l", slots.l, o.w, o.base - math.floor(o.shorter / 2), o.span - 2, 5)
    add("g", slots.g, o.w, o.base, o.span, 0)
    return spines
end

function SW.shelf(width, slots, p, o)
    local spines = SW.shelfSpines(width, slots, o)
    local height = 0
    for _, s in ipairs(spines) do height = math.max(height, s.h) end
    return SpineRow:new{ width = width, height = height + o.plank, plank = o.plank, gap = o.gap, line = o.line, p = p, spines = spines }
end

-- How many spines fit across `width`.
function SW.fit(width, w, gap)
    return math.max(3, math.floor((width + gap) / (w + gap)))
end

-- A stack of flat books, growing up from the bottom: the books of each kind, then dashed empty slots. `slots` is { k, m, l, g };
-- `bh` is a book's thickness and `gh` an empty slot's.
local Stack = Widget:extend{ width = 0, height = 0, p = nil, books = nil, gap = 2, line = 2 }

function Stack:getSize() return Geom:new{ w = self.width, h = self.height } end

function Stack:paintTo(bb, x, y)
    self.dimen = Geom:new{ x = x, y = y, w = self.width, h = self.height }
    local p, line = self.p, self.line
    local cy = y + self.height -- books are laid from the bottom
    for _, b in ipairs(self.books) do
        cy = cy - b.h
        local bx, bw = x + b.dx, self.width - b.dx - b.dx2
        if b.kind == "g" then
            dashed(p, bb, bx, cy, bw, b.h, math.max(1, line), math.max(3, line * 2), math.max(2, line))
        else
            local fill = ({ k = p.books, m = p.koreader, l = p.other })[b.kind]
            rect(p, bb, bx, cy, bw, b.h, p.ink)
            rect(p, bb, bx + line, cy + line, bw - 2 * line, b.h - 2 * line, fill)
            local ix, iw = bx + line, bw - 2 * line
            local iy, ih = cy + line, b.h - 2 * line
            if b.kind == "k" then
                local band = math.max(1, line)
                rect(p, bb, ix + math.floor(iw * 0.14), iy, band, ih, p.card)
                rect(p, bb, ix + iw - math.floor(iw * 0.14) - band, iy, band, ih, p.card)
            elseif b.kind == "m" then
                local step, xx = math.max(4, line * 3), ix + line
                while xx + line <= ix + iw - line do
                    rect(p, bb, xx, iy, math.max(1, line), ih, p.rib)
                    xx = xx + step
                end
            else
                local m1 = ix + math.floor(iw * 0.38)
                rect(p, bb, m1, iy, math.floor(iw * 0.20), ih, p.ink)
            end
        end
        cy = cy - self.gap
    end
end

function SW.stack(width, slots, p, o)
    local books = {}
    local function off(i) return o.sway * (i % 3) end
    local n = 0
    local function add(kind, count, h)
        for i = 1, count do
            n = n + 1
            books[#books + 1] = { kind = kind, h = h, dx = off(n), dx2 = off(n + 1) }
        end
    end
    add("k", slots.k, o.bh)
    add("m", slots.m, o.bh - o.line)
    add("l", slots.l, o.bh)
    add("g", slots.g, o.gh)
    local height = 0
    for _, b in ipairs(books) do height = height + b.h + o.gap end
    return Stack:new{ width = width, height = math.max(0, height - o.gap), p = p, books = books, gap = o.gap, line = o.line }
end

-- A small square of a kind's tone, for a legend.
local Swatch = Widget:extend{ size = 0, p = nil, kind = "k", line = 1 }

function Swatch:getSize() return Geom:new{ w = self.size, h = self.size } end

function Swatch:paintTo(bb, x, y)
    self.dimen = Geom:new{ x = x, y = y, w = self.size, h = self.size }
    local p, s, l = self.p, self.size, self.line
    if self.kind == "g" then
        dashed(p, bb, x, y, s, s, l, math.max(2, l * 2), l)
        return
    end
    local fill = ({ k = p.books, m = p.koreader, l = p.other })[self.kind]
    rect(p, bb, x, y, s, s, p.ink)
    rect(p, bb, x + l, y + l, s - 2 * l, s - 2 * l, fill)
end

function SW.swatch(kind, size, p, line)
    return Swatch:new{ kind = kind, size = size, p = p, line = line or 1 }
end

return SW
