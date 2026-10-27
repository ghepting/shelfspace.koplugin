local T = dofile((debug.getinfo(1, "S").source:match("^@(.*)/[^/]+$") or ".") .. "/helper.lua")
local Zones = require("shelfspace/zones")

print("passing touches on to KOReader")

-- A host the way KOReader builds one: ordered touch zones, each with an id, a range that matches or not, and a handler.
local function zone(id, matches, taken, fired)
    return {
        def = { id = id },
        gs_range = { match = function() return matches end },
        handler = function() fired[#fired + 1] = id return taken end,
    }
end

T.test("the menu's zones and the ones you configured may be passed on; the rest may not", function()
    T.eq(Zones.allowed("filemanager_tap", false, {}), true)
    T.eq(Zones.allowed("readermenu_swipe", true, {}), true)
    T.eq(Zones.allowed("tap_forward", true, {}), false, "a page turn is never passed on")
    T.eq(Zones.allowed("filemanager_tap", true, {}), false, "the file manager's menu zones are not a book's")
    T.eq(Zones.allowed("readerhighlight_tap", true, {}), false)
    T.eq(Zones.allowed("tap_top_left_corner", false, { tap_top_left_corner = {} }), true, "a gesture you set")
end)

T.test("a touch is passed to the first allowed zone that matches and takes it", function()
    local fired = {}
    local host = { _ordered_touch_zones = {
        zone("tap_forward", true, true, fired),
        zone("filemanager_tap", false, true, fired),
        zone("filemanager_swipe", true, true, fired),
        zone("filemanager_swipe_later", true, true, fired),
    } }
    T.eq(Zones.forward({ ges = "swipe" }, host), true)
    T.eq(table.concat(fired, ","), "filemanager_swipe")
end)

T.test("a zone that matches but declines leaves the touch for the next", function()
    local fired = {}
    local host = { _ordered_touch_zones = {
        zone("filemanager_a", true, false, fired), zone("filemanager_b", true, true, fired),
    } }
    T.eq(Zones.forward({}, host), true)
    T.eq(table.concat(fired, ","), "filemanager_a,filemanager_b")
end)

T.test("nothing matching means nothing is taken", function()
    local host = { _ordered_touch_zones = { zone("filemanager_tap", false, true, {}) } }
    T.eq(Zones.forward({}, host), false)
    T.eq(Zones.forward({}, nil), false)
end)

T.test("the zones of the host's modules count, but the file list's own do not", function()
    local fired = {}
    local list = { _ordered_touch_zones = { zone("filemanager_row_tap", true, true, fired) } }
    local menu = { _ordered_touch_zones = { zone("filemanager_menu_tap", true, true, fired) } }
    local host = { _ordered_touch_zones = {}, list, menu, file_chooser = list }
    T.eq(Zones.forward({}, host), true)
    T.eq(table.concat(fired, ","), "filemanager_menu_tap")
end)

T.test("a book's gestures use the reader's menu zones", function()
    local fired = {}
    local host = { document = {}, _ordered_touch_zones = { zone("filemanager_tap", true, true, fired), zone("readermenu_tap", true, true, fired) } }
    T.eq(Zones.forward({}, host), true)
    T.eq(table.concat(fired, ","), "readermenu_tap")
end)

T.test("an edge swipe you configured runs first; one you did not is left alone", function()
    local fired = {}
    local zones = { zone("one_finger_swipe_top_edge_left", true, true, fired) }
    local with = { _ordered_touch_zones = zones, gestures = { gestures = { one_finger_swipe_top_edge_left = {} } } }
    T.eq(Zones.forwardUserFirst({ ges = "swipe" }, with), true)
    T.eq(Zones.forwardUserFirst({ ges = "swipe" }, { _ordered_touch_zones = zones }), false)
    T.eq(Zones.forwardUserFirst({ ges = "tap" }, with), false, "only swipes and holds")
end)

T.done()
