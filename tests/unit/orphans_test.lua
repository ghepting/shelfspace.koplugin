local T = dofile((debug.getinfo(1, "S").source:match("^@(.*)/[^/]+$") or ".") .. "/helper.lua")
local Cleanup = require("shelfspace/cleanup")

local function e(name, is_dir, hidden) return { name = name, is_dir = is_dir, hidden = hidden, size = 0, path = name } end

print("orphaned reading progress")

local tree = {
    ["/home/.emu/lib"] = { entries = { e("Gone.sdr", true, true), e("Kept.epub"), e("Kept.sdr", true, true), e(".kobo", true) } },
    ["/home/.emu/lib/.kobo"] = { entries = { e("Hid.sdr", true, true) } },
}

T.test("a sidecar with no book beside it is an orphan, even when the library sits under a dot-folder", function()
    local found = Cleanup.orphans(tree, "/data", "/home/.emu/lib")
    T.eq(#found, 1)
    T.eq(found[1].name, "Gone.sdr")
end)

T.test("a sidecar whose book is still there is not", function()
    for _, f in ipairs(Cleanup.orphans(tree, "/data", "/home/.emu/lib")) do T.eq(f.name == "Kept.sdr", false) end
end)

T.test("hidden folders inside the library are left alone", function()
    for _, f in ipairs(Cleanup.orphans(tree, "/data", "/home/.emu/lib")) do T.eq(f.name == "Hid.sdr", false) end
end)

T.done()
