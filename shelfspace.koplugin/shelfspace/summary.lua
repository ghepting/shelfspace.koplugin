-- A small summary of the last scan, for a place that must draw at once and cannot wait for a scan: the card ShelfSpace offers
-- Bookshelf. Pure logic, so it runs under the tests as on a device. The numbers are bytes.
local Summary = {}

Summary.KEY = "shelfspace_summary"

local FIELDS = { "total", "free", "books", "koreader", "other", "duplicates", "duplicate_sets", "koreader_clearable" }

-- What the card needs, from what a scan found. `usage` is { total, free, used }, `breakdown` is { books, koreader, other }.
function Summary.build(o)
    local usage, b = o.usage or {}, o.breakdown or {}
    return {
        v = 1,
        time = o.time or 0,
        total = usage.total or 0,
        free = usage.available or usage.free or 0, -- KOReader's util.diskUsage calls it `available`
        books = b.books or 0,
        koreader = b.koreader or 0,
        other = b.other or 0,
        duplicates = o.duplicates or 0,
        duplicate_sets = o.duplicate_sets or 0,
        koreader_clearable = o.koreader_clearable or 0,
    }
end

-- A summary read back from settings, or nil when it is not one: every number there, none negative, a total to measure against.
function Summary.valid(t)
    if type(t) ~= "table" or t.v ~= 1 then return nil end
    local out = { v = 1, time = tonumber(t.time) or 0 }
    for _, k in ipairs(FIELDS) do
        local n = tonumber(t[k])
        if not n or n < 0 then return nil end
        out[k] = n
    end
    if out.total <= 0 then return nil end
    out.free = math.min(out.free, out.total)
    return out
end

-- What could be freed, and from where.
function Summary.reclaimable(s)
    return s.duplicates + s.koreader_clearable
end

-- The device as four shares of its whole, adding up to one: books (k), KOReader (m), everything else (l) and free space (g).
function Summary.shares(s)
    local total = s.total > 0 and s.total or 1
    local g = math.max(0, math.min(1, s.free / total))
    local used = 1 - g
    local k, m, l = s.books / total, s.koreader / total, s.other / total
    local sum = k + m + l
    if sum <= 0 then return { k = used, m = 0, l = 0, g = g } end -- nothing is known about what is on it: all of it is "used"
    local f = used / sum -- fit the three to what is used, whatever rounding the scan left
    return { k = k * f, m = m * f, l = l * f, g = g }
end

-- Shares out `n` slots (spines, or books in a stack) among the shares from `shares`. The free space is sized first from its true
-- share, with at least one slot while there is any and at least one slot left for what is used; the used categories share what is
-- left, each at least one slot, and with fewer slots than categories only the biggest show. Returns { k, m, l, g } adding up to n.
function Summary.slots(n, sh)
    local used = sh.k + sh.m + sh.l
    local keys = {}
    for _, k in ipairs({ "k", "m", "l" }) do
        if sh[k] > 0 then keys[#keys + 1] = k end
    end
    table.sort(keys, function(a, b) return sh[a] > sh[b] end)
    local g = sh.g > 0 and math.floor(sh.g / (used + sh.g) * n + 0.5) or 0
    if sh.g > 0 then g = math.max(1, g) end
    if used > 0 then g = math.min(g, n - 1) end
    local left = n - g
    local out = { k = 0, m = 0, l = 0, g = g }
    if #keys == 0 then return out end
    if left <= #keys then
        for i = 1, left do out[keys[i]] = 1 end
        return out
    end
    local target = {}
    for _, k in ipairs(keys) do
        target[k] = sh[k] / used * left
        out[k] = math.max(1, math.floor(target[k]))
    end
    local function sum()
        local t = 0
        for _, k in ipairs(keys) do t = t + out[k] end
        return t
    end
    while sum() < left do -- the category furthest below its target takes the next slot
        local best = keys[1]
        for _, k in ipairs(keys) do
            if target[k] - out[k] > target[best] - out[best] then best = k end
        end
        out[best] = out[best] + 1
    end
    while sum() > left do -- or the one furthest above its target gives one up (never below one)
        local best
        for _, k in ipairs(keys) do
            if out[k] > 1 and (not best or out[k] - target[k] > out[best] - target[best]) then best = k end
        end
        if not best then break end
        out[best] = out[best] - 1
    end
    return out
end

-- A size as a number and a unit, for a headline: "21.4" "GB", "320" "MB", "0" "B". 1000 to the step, as KOReader's util.getFriendlySize
-- counts, so a figure here is the same as the one ShelfSpace shows on its own screens.
function Summary.figure(bytes)
    bytes = math.max(0, bytes or 0)
    local gb, mb = 1000 ^ 3, 1000 ^ 2
    if bytes >= gb then return string.format("%.1f", bytes / gb), "GB" end
    if bytes >= mb then return string.format("%d", math.floor(bytes / mb + 0.5)), "MB" end
    if bytes >= 1000 then return string.format("%d", math.floor(bytes / 1000 + 0.5)), "kB" end
    return string.format("%d", bytes), "B"
end

-- How full the device is, for a chip: nil with plenty of room, "low" under a tenth free, "almost" under a fiftieth, "full" at none
-- (under a megabyte counts as none).
function Summary.state(s)
    local share = s.total > 0 and s.free / s.total or 0
    if s.free < 1000 ^ 2 then return "full" end
    if share < 0.02 then return "almost" end
    if share < 0.10 then return "low" end
    return nil
end

return Summary
