-- Lays entries out as books on shelves: each spine is as wide as the file is big, and a shelf
-- is filled until the next spine would not fit.
local Shelf = {}

-- A spine's width: its share of the biggest entry, kept between `min_w` and `max_w`.
function Shelf.spineWidth(size, largest, min_w, max_w)
    local w = largest > 0 and math.floor(size / largest * max_w) or min_w
    return math.max(min_w, math.min(max_w, w))
end

-- `entries` in order, split into shelves of at most `width` pixels, `gap` between spines.
-- Returns { { {entry =, w =}, ... }, ... }.
function Shelf.pack(entries, width, min_w, max_w, gap)
    local largest = 0
    for _, e in ipairs(entries) do largest = math.max(largest, e.size) end
    local shelves, row, used = {}, {}, 0
    for _, e in ipairs(entries) do
        local w = Shelf.spineWidth(e.size, largest, min_w, max_w)
        local need = w + (#row > 0 and gap or 0)
        if #row > 0 and used + need > width then
            shelves[#shelves + 1] = row
            row, used, need = {}, 0, w
        end
        row[#row + 1] = { entry = e, w = w }
        used = used + need
    end
    if #row > 0 then shelves[#shelves + 1] = row end
    return shelves
end

-- A steady height for a name between 0.8 and 1 of `full`, so a shelf looks like books, not bars.
function Shelf.spineHeight(name, full)
    local sum = 0
    for i = 1, #name do sum = sum + name:byte(i) end
    return math.floor(full * (0.8 + (sum % 5) * 0.05))
end

return Shelf
