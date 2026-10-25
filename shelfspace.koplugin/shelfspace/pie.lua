-- Geometry for a pie or donut: where each slice sits, and which slice a point is in.
local Pie = {}

-- Smallest share a non-empty slice is drawn with, so a tiny slice is still visible and tappable.
local MIN_SHARE = 0.008

-- slices: { { fraction = 0..1, ... }, ... } in drawing order, clockwise from 12 o'clock.
-- Returns { { from, to, slice } } over 0..1, skipping empty slices; the shares are
-- widened to MIN_SHARE and re-normalised so the arcs always fill the whole turn.
function Pie.layout(slices)
    local shown, total = {}, 0
    for i, s in ipairs(slices) do
        shown[i] = s.fraction > 0 and math.max(s.fraction, MIN_SHARE) or 0
        total = total + shown[i]
    end
    local arcs = {}
    if total <= 0 then return arcs end
    local at = 0
    for i, s in ipairs(slices) do
        if shown[i] > 0 then
            local to = at + shown[i] / total
            table.insert(arcs, { from = at, to = to, slice = s })
            at = to
        end
    end
    arcs[#arcs].to = 1
    return arcs
end

-- The turn (0..1, clockwise from 12 o'clock) of a point offset (dx, dy) from the centre; y grows downward.
function Pie.fraction(dx, dy)
    local turn = math.atan2(dx, -dy) / (2 * math.pi)
    return turn < 0 and turn + 1 or turn
end

-- The arc holding `fraction`, or nil when there are none.
function Pie.arcAt(arcs, fraction)
    for _, arc in ipairs(arcs) do
        if fraction >= arc.from and fraction < arc.to then return arc end
    end
    return arcs[#arcs]
end

return Pie
