-- Passing touches on to KOReader underneath ShelfSpace. KOReader hands a touch to the topmost widget only, and the
-- gestures that open its top menu, plus any you have set in its Gestures settings (corner taps, edge swipes for
-- brightness, the refresh swipe), are zones registered on the file manager (or the reader), not on whatever is
-- on top of it. So while ShelfSpace is up none of them fire unless ShelfSpace passes the touch on.
--
-- Only a short list of zones is safe to pass on: the menu's own, and the ones you configured. Everything else
-- the host registers (a row tap in the file list, a page turn in a book) would act on a screen you cannot see.
local Zones = {}

-- The gestures a reader may have given their own action that ShelfSpace's paging also uses: they run theirs first.
local USER_FIRST = {
    one_finger_swipe_top_edge_left = true, one_finger_swipe_top_edge_right = true,
    one_finger_swipe_bottom_edge_left = true, one_finger_swipe_bottom_edge_right = true,
    hold_top_left_corner = true, hold_top_right_corner = true,
    hold_bottom_left_corner = true, hold_bottom_right_corner = true,
}

-- Whether the zone `id` may be passed on: the menu's zones ("filemanager_" in the file manager, "readermenu_" in
-- a book), and any gesture the reader configured. `user` maps the configured ones' ids.
function Zones.allowed(id, in_book, user)
    if user and user[id] then return true end
    return id:find(in_book and "^readermenu_" or "^filemanager_") ~= nil
end

-- Walks the host's touch zones (and its modules') and runs the first allowed one that matches `ev`.
local function walk(ev, host, allowed)
    local lists = { host._ordered_touch_zones }
    for _, child in ipairs(host) do
        -- the file list's own zones cover the body of the screen: a tap in a gap would open a file you cannot see
        if child ~= host.file_chooser and type(child) == "table" and child._ordered_touch_zones then
            lists[#lists + 1] = child._ordered_touch_zones
        end
    end
    for _, zones in ipairs(lists) do
        for _, zone in ipairs(zones) do
            local id = zone.def and zone.def.id
            if id and allowed(id) and zone.gs_range:match(ev) and zone.handler(ev) then return true end
        end
    end
    return false
end

local function configured(host)
    return (host.gestures and host.gestures.gestures) or {}
end

-- Passes `ev` (a gesture) to KOReader's own zones; true when one took it.
function Zones.forward(ev, host)
    if not (host and ev) then return false end
    local user, in_book = configured(host), host.document ~= nil
    return walk(ev, host, function(id) return Zones.allowed(id, in_book, user) end)
end

-- The swipes and holds you gave an action of your own at the screen's edges run ahead of ShelfSpace's own use of
-- them (paging); one you have not set is left to ShelfSpace.
function Zones.forwardUserFirst(ev, host)
    if not (host and ev) or (ev.ges ~= "swipe" and ev.ges ~= "hold") then return false end
    local user = configured(host)
    return walk(ev, host, function(id) return USER_FIRST[id] and user[id] ~= nil end)
end

return Zones
