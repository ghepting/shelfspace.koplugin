local T = dofile((debug.getinfo(1, "S").source:match("^@(.*)/[^/]+$") or ".") .. "/helper.lua")

-- Colours as plain strings, so Theme.get() can be read as data.
package.preload["ffi/blitbuffer"] = function()
    local b = {}
    for _, name in ipairs({ "WHITE", "BLACK", "GRAY_4", "GRAY_5", "GRAY_7", "GRAY_9", "GRAY_B", "GRAY_D", "GRAY_E" }) do
        b["COLOR_" .. name] = name == "WHITE" and "white" or name == "BLACK" and "black" or "gray:" .. name
    end
    return b
end
local Theme = require("shelfspace/theme")

print("theme")

T.test("the page is white and the text black", function()
    local th = Theme.get()
    T.eq(th.bg, "white")
    T.eq(th.ink, "black")
end)

T.test("every colour is black, white or a gray: ShelfSpace has none of its own", function()
    for key, value in pairs(Theme.get()) do
        assert(value == "white" or value == "black" or tostring(value):find("^gray:"), key .. " is not black, white or a gray")
    end
end)

T.test("no two chart slices share a shade", function()
    local th, seen = Theme.get(), {}
    for _, key in ipairs({ "books", "koreader", "other", "free_space" }) do
        assert(not seen[th[key]], key .. " shares a shade with " .. tostring(seen[th[key]]))
        seen[th[key]] = key
    end
end)

T.test("a delete button is as dark as the text, so it reads on any screen", function()
    local th = Theme.get()
    T.eq(th.danger, th.ink)
end)

T.test("files are shaded by type, and unknown ones fall back to the rule shade", function()
    local th = Theme.get()
    T.eq(Theme.kind(th, { name = "x", is_dir = true }), th.folder)
    T.eq(Theme.kind(th, { name = "a.EPUB" }), th.epub)
    T.eq(Theme.kind(th, { name = "a.pdf" }), th.pdf)
    T.eq(Theme.kind(th, { name = "a.cbz" }), th.comic)
    T.eq(Theme.kind(th, { name = "a.so" }), th.line)
end)

T.done()
