local Blitbuffer = require("ffi/blitbuffer")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local InputContainer = require("ui/widget/container/inputcontainer")
local Screen = require("device").screen

local Pie = require("shelfspace/pie")

local TWO_PI = 2 * math.pi

-- A donut chart drawn once into its own buffer, with smooth edges and thin gaps between
-- slices. Tapping a slice calls on_tap(slice).
-- Fields: diameter, bg (the page colour), hole (inner radius as a share of the outer one),
-- slices = { { fraction, color, ... }, ... } clockwise from 12 o'clock, on_tap.
local Donut = InputContainer:extend{
    diameter = 200,
    hole = 0.62,
    slices = nil,
    bg = nil,
    on_tap = nil,
}

local instances = 0

local function clamp01(v) return v < 0 and 0 or (v > 1 and 1 or v) end

function Donut:init()
    local d = self.diameter
    self.dimen = Geom:new{ w = d, h = d }
    self.arcs = Pie.layout(self.slices)
    self:render()

    -- A name of its own: tap events travel to child widgets, so a shared one could be answered elsewhere.
    instances = instances + 1
    local name = "TapDonut" .. instances
    self.ges_events = { [name] = { GestureRange:new{ ges = "tap", range = self.dimen } } }
    self["on" .. name] = function(_, _, ges) return self:onTapAt(ges) end
end

function Donut:render()
    local d = self.diameter
    local buf = Blitbuffer.new(d, d, Screen.bb:getType())
    buf:paintRectRGB32(0, 0, d, d, self.bg)
    self.buf = buf

    local arcs = self.arcs
    local bg = self.bg:getColorRGB32()
    for _, arc in ipairs(arcs) do arc.rgb = arc.slice.color:getColorRGB32() end

    local center = d / 2
    local outer = d / 2 - 1
    local inner = outer * self.hole
    local gap = #arcs > 1 and 1 or 0 -- pixels of page colour between neighbouring slices

    for py = 0, d - 1 do
        local dy = py + 0.5 - center
        for px = 0, d - 1 do
            local dx = px + 0.5 - center
            local dist = math.sqrt(dx * dx + dy * dy)
            if dist <= outer + 1 and dist >= inner - 1 then
                local cover = clamp01(outer - dist + 0.5) * clamp01(dist - inner + 0.5)
                if cover > 0 then
                    local turn = Pie.fraction(dx, dy)
                    local arc = Pie.arcAt(arcs, turn)
                    if gap > 0 then
                        -- Distance in pixels to the nearest slice boundary.
                        local nearest = math.huge
                        for _, a in ipairs(arcs) do
                            local diff = math.abs(turn - a.from)
                            diff = math.min(diff, 1 - diff)
                            nearest = math.min(nearest, diff * TWO_PI * dist)
                        end
                        cover = cover * clamp01(nearest - gap * 0.6)
                    end
                    if cover >= 0.999 then
                        buf:setPixel(px, py, arc.slice.color)
                    elseif cover > 0.004 then
                        local c = arc.rgb
                        buf:setPixel(px, py, Blitbuffer.ColorRGB32(
                            math.floor(bg.r + (c.r - bg.r) * cover + 0.5),
                            math.floor(bg.g + (c.g - bg.g) * cover + 0.5),
                            math.floor(bg.b + (c.b - bg.b) * cover + 0.5), 0xFF))
                    end
                end
            end
        end
    end
end

function Donut:getSize()
    return self.dimen
end

function Donut:paintTo(bb, x, y)
    self.dimen.x, self.dimen.y = x, y
    bb:blitFrom(self.buf, x, y, 0, 0, self.diameter, self.diameter)
end

-- The slice under a tap, or nil for a tap in the hole or outside the ring.
function Donut:sliceAt(pos)
    local half = self.diameter / 2
    local dx = pos.x - (self.dimen.x + half)
    local dy = pos.y - (self.dimen.y + half)
    local dist = math.sqrt(dx * dx + dy * dy)
    if dist > half or dist < half * self.hole then return nil end
    local arc = Pie.arcAt(self.arcs, Pie.fraction(dx, dy))
    return arc and arc.slice
end

function Donut:onTapAt(ges)
    local slice = ges and ges.pos and self:sliceAt(ges.pos)
    if slice and self.on_tap then
        self.on_tap(slice)
        return true
    end
end

return Donut
